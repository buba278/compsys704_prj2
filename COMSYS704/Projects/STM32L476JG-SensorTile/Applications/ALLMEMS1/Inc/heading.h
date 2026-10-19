/**
  ******************************************************************************
  * @file    heading.h
  * @brief   Relative heading from the magnetometer (#CS704)
  *
  * Usage:
  *   1. Call Heading_Init() once at start-up.
  *   2. Call Heading_Update() with every magnetometer sample (in mG), at a
  *      fixed rate of HEADING_SAMPLE_HZ. Keep the device still until
  *      Heading_IsReady() is 1.
  *   3. Read the angle with Heading_GetDegrees().
  *
  * The heading is relative to the direction the device faced when it settled
  * after start-up (0), and increases clockwise (a 90 degree clockwise turn
  * gives 90, anti-clockwise gives 270).
  *
  * The module has no hardware dependencies, so it can also be compiled and
  * tested on a PC against logged magnetometer data.
  ******************************************************************************
  */

#ifndef HEADING_H
#define HEADING_H

#include <stdint.h>

/* Rate at which Heading_Update() is called, main.c checks it matches the sensor timer */
#define HEADING_SAMPLE_HZ        50

/* mag calibration from SensorTile Live */
#define MAG_OFFSET_X    -206    /* mG */
#define MAG_OFFSET_Y      93    /* mG */
#define MAG_SCALE_Y    1.081f
#define MAG_BASELINE     570    /* mG, clean |B| */
#define MAG_HOLD_PCT      15
/* z values are for tilt compensation, heading.c does not use them yet */
#define MAG_OFFSET_Z      39    /* mG */
#define MAG_SCALE_Z    1.121f

/* Set to 1 if a clockwise turn makes the heading fall (depends on how the chip is mounted) */
#define HEADING_INVERT           1

/* Time spent still after start-up, the zero direction is the average over it */
#define HEADING_SETTLE_MS        1500

void Heading_Init(void);

/**
  * @brief  Process one magnetometer sample.
  * @param  mx_mG, my_mG  raw field on the x and y axes in mG
  */
void Heading_Update(int32_t mx_mG, int32_t my_mG);

/**
  * @brief  Heading in whole degrees, 0 to 359. Stays 0 until Heading_IsReady().
  */
uint32_t Heading_GetDegrees(void);

/**
  * @brief  1 once the start-up settle is done and the zero direction is set.
  */
uint8_t Heading_IsReady(void);

#endif /* HEADING_H */
