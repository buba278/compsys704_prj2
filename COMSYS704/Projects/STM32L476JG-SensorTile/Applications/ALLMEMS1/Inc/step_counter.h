/**
  ******************************************************************************
  * @file    step_counter.h
  * @brief   Step detection from 3-axis accelerometer data (#CS704)
  *
  * Usage:
  *   1. Call StepCounter_Init() once at start-up.
  *   2. Call StepCounter_Update() with every new accelerometer sample (in mg),
  *      at a fixed rate of STEP_COUNTER_SAMPLE_HZ.
  *   3. Read the running total with StepCounter_GetSteps().
  *
  * The module has no hardware dependencies, so it can also be compiled and
  * tested on a PC against logged accelerometer data.
  ******************************************************************************
  */

#ifndef STEP_COUNTER_H
#define STEP_COUNTER_H

#include <stdint.h>

/* Rate at which StepCounter_Update() must be called. main.c uses this value to
   configure the sensor-read timer, so the two always agree. */
#define STEP_COUNTER_SAMPLE_HZ   50

/**
  * @brief  Reset the filters and the step count.
  */
void StepCounter_Init(void);

/**
  * @brief  Process one accelerometer sample.
  * @param  ax_mg, ay_mg, az_mg  acceleration on each axis in mg
  * @retval 1 if this sample completed a new step, 0 otherwise
  */
uint8_t StepCounter_Update(int32_t ax_mg, int32_t ay_mg, int32_t az_mg);

/**
  * @brief  Total number of steps detected since StepCounter_Init().
  */
uint32_t StepCounter_GetSteps(void);

/**
  * @brief  Latest filtered, gravity-free acceleration magnitude in mg.
  *         This is the signal the detector thresholds; useful for tuning.
  */
int32_t StepCounter_GetSignal(void);

#endif /* STEP_COUNTER_H */
