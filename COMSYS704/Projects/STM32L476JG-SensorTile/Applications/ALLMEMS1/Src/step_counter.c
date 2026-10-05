/**
  ******************************************************************************
  * @file    step_counter.c
  * @brief   Step detection from 3-axis accelerometer data (#CS704)
  *
  * Algorithm (run once per sample):
  *   1. Magnitude      |a| = sqrt(x^2 + y^2 + z^2). Using the magnitude makes
  *                     the detector independent of how the device is oriented.
  *   2. Gravity removal  A slow exponential moving average of |a| tracks the
  *                     constant ~1 g component; subtracting it leaves only the
  *                     acceleration caused by movement, centred on zero. This
  *                     also cancels any sensor offset or scale error.
  *   3. Smoothing      A short moving average removes heel-strike jitter that
  *                     would otherwise produce double peaks.
  *   4. Peak detection The detector "arms" when the signal rises above an
  *                     upper threshold and counts a step when the signal then
  *                     falls back through zero. The threshold adapts to the
  *                     recent step amplitude, with a fixed minimum so that
  *                     standing still does not count.
  *   5. Timing gate    A peak that completes too soon after the previous step
  *                     is rejected, since people cannot step that fast.
  ******************************************************************************
  */

#include <math.h>
#include "step_counter.h"

/* Tunable parameters --------------------------------------------------------*/

/* Gravity filter coefficient. Time constant = 1 / (alpha * sample rate) = 1 s */
#define GRAVITY_ALPHA            0.02f

/* Moving average length in samples (5 samples = 100 ms at 50 Hz) */
#define SMOOTH_LEN               5

/* Smallest peak (mg above the gravity baseline) that can count as a step */
#define MIN_THRESHOLD_MG         80.0f

/* Threshold as a fraction of the recent peak-to-peak step amplitude */
#define THRESHOLD_FRACTION       0.25f

/* How quickly the amplitude estimate follows new steps (0..1) */
#define AMPLITUDE_ALPHA          0.25f

/* Shortest time between two steps: 300 ms, i.e. at most ~3.3 steps per second */
#define MIN_STEP_INTERVAL        ((300 * STEP_COUNTER_SAMPLE_HZ) / 1000)

/* With no step for this long (2 s) the user has stopped: forget the amplitude */
#define IDLE_TIMEOUT             (2 * STEP_COUNTER_SAMPLE_HZ)

/* Private variables ---------------------------------------------------------*/
static uint32_t stepCount;
static float    gravity;                 /* slow average of |a| in mg          */
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
  float x = (float)ax_mg;
  float y = (float)ay_mg;
  float z = (float)az_mg;
  float magnitude;
  float threshold;
  float sum = 0.0f;
  uint8_t i;
  uint8_t stepDetected = 0;

  /* 1. Orientation-independent magnitude */
  magnitude = sqrtf(x * x + y * y + z * z);

  /* 2. Remove gravity. Seed the filter with the first sample so there is no
        start-up transient that could be mistaken for a step. */
  if (!gravityValid) {
    gravity = magnitude;
    gravityValid = 1;
  }
  gravity += GRAVITY_ALPHA * (magnitude - gravity);

  /* 3. Moving average of the gravity-free signal */
  smoothBuf[smoothIdx] = magnitude - gravity;
  smoothIdx = (uint8_t)((smoothIdx + 1) % SMOOTH_LEN);
  for (i = 0; i < SMOOTH_LEN; i++) {
    sum += smoothBuf[i];
  }
  signal = sum / SMOOTH_LEN;

  /* Track the extremes of the current step cycle for the amplitude estimate */
  if (signal > peakMax) {
    peakMax = signal;
  }
  if (signal < peakMin) {
    peakMin = signal;
  }

  if (samplesSinceStep < 0xFFFFFFFFU) {
    samplesSinceStep++;
  }

  /* The user has stopped walking: drop back to the minimum threshold */
  if (samplesSinceStep > IDLE_TIMEOUT) {
    amplitude = 0.0f;
    if (!armed) {
      peakMax = 0.0f;
      peakMin = 0.0f;
    }
  }

  /* 4. Adaptive threshold with a fixed floor */
  threshold = THRESHOLD_FRACTION * amplitude;
  if (threshold < MIN_THRESHOLD_MG) {
    threshold = MIN_THRESHOLD_MG;
  }

  if (!armed) {
    if (signal > threshold) {
      armed = 1;
    }
  } else if (signal < 0.0f) {
    /* The peak has finished (downward zero crossing) */
    armed = 0;

    /* 5. Only count it if enough time has passed since the last step */
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
