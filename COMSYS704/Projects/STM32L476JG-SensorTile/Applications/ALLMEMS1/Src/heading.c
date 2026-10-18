/**
  ******************************************************************************
  * @file    heading.c
  * @brief   Relative heading from the magnetometer (#CS704)
  *
  * Algorithm (run once per sample):
  *   1. Calibrate  Subtract the offsets and stretch y so the field traced by
  *                 a full turn is a circle centred on the origin.
  *   2. Settle     For the first HEADING_SETTLE_MS the device must be still.
  *                 The average direction over it is the zero reference.
  *   3. Heading    Angle of the field in the device frame, minus the zero
  *                 reference, wrapped to 0 to 359.
  ******************************************************************************
  */

#include "heading.h"
#include <math.h>

#define RAD_TO_DEG               57.29578f
#define SETTLE_SAMPLES           ((HEADING_SETTLE_MS * HEADING_SAMPLE_HZ) / 1000)

static uint32_t settleCount;
static float sumX, sumY;
static float zeroDeg;
static float outDeg;
static uint8_t ready;

void Heading_Init(void) {
	settleCount = 0;
	sumX = sumY = 0.0f;
	zeroDeg = 0.0f;
	outDeg = 0.0f;
	ready = 0;
}

static float wrap360(float deg) {
	while (deg >= 360.0f) deg -= 360.0f;
	while (deg < 0.0f) deg += 360.0f;
	return deg;
}

void Heading_Update(int32_t mx_mG, int32_t my_mG) {
	float x = (float)(mx_mG - MAG_OFFSET_X);
	float y = (float)(my_mG - MAG_OFFSET_Y) * MAG_SCALE_Y;

	if (!ready) {
		// average x and y then take the angle, averaging angles breaks at 359 to 0
		sumX += x;
		sumY += y;
		if (++settleCount >= SETTLE_SAMPLES) {
			zeroDeg = atan2f(sumY, sumX) * RAD_TO_DEG;
			ready = 1;
		}
		return;
	}

	float deg = atan2f(y, x) * RAD_TO_DEG - zeroDeg;
#if HEADING_INVERT
	deg = -deg;
#endif
	outDeg = wrap360(deg);
}

uint32_t Heading_GetDegrees(void) {
	return (uint32_t)(outDeg + 0.5f) % 360;
}

uint8_t Heading_IsReady(void) {
	return ready;
}
