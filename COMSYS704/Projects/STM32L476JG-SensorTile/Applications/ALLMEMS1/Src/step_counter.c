/**
  ******************************************************************************
  * @file    step_counter.c
  * @brief   Step detection from 3-axis accelerometer data (#CS704)
  *
  * Per sample:
  *   1. Vertical axis  Z only, so sideways shaking is ignored.
  *   2. Gravity removal  Slow average of az subtracted, which also cancels
  *                     sensor offset.
  *   3. Smoothing      Moving average to avoid double peaks and shaking.
  *   4. Peak detection Arm above an adaptive threshold (with a fixed floor so
  *                     standing still does not count), count on the downward
  *                     zero crossing.
  *   5. Timing gate    Reject peaks closer than MIN_STEP_INTERVAL.
  ******************************************************************************
  */

#include <math.h>
#include "step_counter.h"

/* Tunable parameters --------------------------------------------------------*/

/* Gravity filter coefficient, 1 s time constant at 50 Hz */
#define GRAVITY_ALPHA            0.02f

/* Moving average length in samples, 160 ms at 50 Hz */
#define SMOOTH_LEN               8

/* Smallest peak (mg above gravity) that can count as a step */
#define MIN_THRESHOLD_MG         110.0f

/* Threshold as a fraction of the recent peak-to-peak step amplitude */
#define THRESHOLD_FRACTION       0.25f

/* How quickly the amplitude estimate follows new steps (0..1) */
#define AMPLITUDE_ALPHA          0.25f

/* Shortest time between two steps, 300 ms in samples */
#define MIN_STEP_INTERVAL        ((300 * STEP_COUNTER_SAMPLE_HZ) / 1000)

/* No step for 2 s in samples: forget the amplitude */
#define IDLE_TIMEOUT             (2 * STEP_COUNTER_SAMPLE_HZ)

/* Private variables ---------------------------------------------------------*/
static uint32_t stepCount;
static float    gravity;                 /* slow average of az in mg           */
static uint8_t  gravityValid;            /* 0 until the first sample is seen   */
static float    smoothBuf[SMOOTH_LEN];   /* ring buffer for the moving average */
static uint8_t  smoothIdx;
static float    signal;                  /* filtered, gravity-free magnitude   */
static uint8_t  armed;                   /* 1 while a peak is in progress      */
static float    peakMax;                 /* highest value in the current step  */
static float    peakMin;                 /* lowest value in the current step   */
static float    amplitude;               /* recent peak-to-peak amplitude      */
static uint32_t samplesSinceStep;

void StepCounter_Init(void)
{
  uint8_t i;

  stepCount = 0;
  gravity = 0.0f;
  gravityValid = 0;
  for (i = 0; i < SMOOTH_LEN; i++) {
    smoothBuf[i] = 0.0f;
  }
  smoothIdx = 0;
  signal = 0.0f;
  armed = 0;
  peakMax = 0.0f;
  peakMin = 0.0f;
  amplitude = 0.0f;
  samplesSinceStep = MIN_STEP_INTERVAL;
}

uint8_t StepCounter_Update(int32_t ax_mg, int32_t ay_mg, int32_t az_mg)
{
  float magnitude = (float)az_mg;   /* vertical axis only */
  float threshold;
  float sum = 0.0f;
  uint8_t i;
  uint8_t stepDetected = 0;

  (void)ax_mg;
  (void)ay_mg;

  /* Seed with the first sample so start-up is not mistaken for a step */
  if (!gravityValid) {
    gravity = magnitude;
    gravityValid = 1;
  }
  gravity += GRAVITY_ALPHA * (magnitude - gravity);

  smoothBuf[smoothIdx] = magnitude - gravity;
  smoothIdx = (uint8_t)((smoothIdx + 1) % SMOOTH_LEN);
  for (i = 0; i < SMOOTH_LEN; i++) {
    sum += smoothBuf[i];
  }
  signal = sum / SMOOTH_LEN;

  if (signal > peakMax) {
    peakMax = signal;
  }
  if (signal < peakMin) {
    peakMin = signal;
  }

  if (samplesSinceStep < 0xFFFFFFFFU) {
    samplesSinceStep++;
  }

  /* Stopped walking, fall back to the minimum threshold */
  if (samplesSinceStep > IDLE_TIMEOUT) {
    amplitude = 0.0f;
    if (!armed) {
      peakMax = 0.0f;
      peakMin = 0.0f;
    }
  }

  threshold = THRESHOLD_FRACTION * amplitude;
  if (threshold < MIN_THRESHOLD_MG) {
    threshold = MIN_THRESHOLD_MG;
  }

  if (!armed) {
    if (signal > threshold) {
      armed = 1;
    }
  } else if (signal < 0.0f) {
    armed = 0;

    if (samplesSinceStep >= MIN_STEP_INTERVAL) {
      stepCount++;
      stepDetected = 1;
      samplesSinceStep = 0;
      amplitude += AMPLITUDE_ALPHA * ((peakMax - peakMin) - amplitude);
    }
    peakMax = 0.0f;
    peakMin = 0.0f;
  }

  return stepDetected;
}

uint32_t StepCounter_GetSteps(void)
{
  return stepCount;
}

int32_t StepCounter_GetSignal(void)
{
  return (int32_t)signal;
}
