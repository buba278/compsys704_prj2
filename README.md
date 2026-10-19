# COMPSYS 704 Project 2 — Pedestrian Dead Reckoning on SensorTile

Firmware for the ST SensorTile (STM32L476JG) that tracks a person's step count and orientation using the on-board LSM303AGR accelerometer and magnetometer, and streams the results over Bluetooth Low Energy to the ST BLE Sensor mobile app.

## Hardware and software requirements

- SensorTile development kit with integrated STLINK-V3 programmer and battery
- [STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html)
- Windows only: [ST virtual COM port driver](https://www.st.com/en/development-tools/stsw-stm32102.html) for `XPRINTF` output over USB
- A serial terminal such as [CoolTerm](http://freeware.the-meiers.org/) or PuTTY
- ST BLE Sensor app ([Android](https://play.google.com/store/apps/details?id=com.st.bluems) / [iOS](https://apps.apple.com/it/app/st-bluems/id993670214))
## Building and running

1. Open STM32CubeIDE and choose **File > Open Projects from File System...**
2. Select the `COMSYS704` folder and tick **only** `COMSYS704/Projects/STM32L476JG-SensorTile/Applications/ALLMEMS1/STM32CubeIDE`.
3. Build the `Debug` configuration (hammer icon), then Run to flash the SensorTile over the STLINK-V3.
4. Hold the board flat and still for the first 1.5 s after power on. The direction it faces then becomes heading 0.
5. Serial debug output: connect a terminal to the board's COM port at 115200 baud, 8 data bits, no parity, 1 stop bit.
6. In the ST BLE Sensor app, connect to the device and plot **Accelerometer** (raw acceleration in mg), **Magnetometer**, or **Gyroscope** (X = step count, Y = heading in degrees, Z = filtered step signal in mg).

## Code structure

All application code is in `COMSYS704/Projects/STM32L476JG-SensorTile/Applications/ALLMEMS1/`.

| File | Purpose |
| --- | --- |
| `Src/main.c` | Sensor initialisation and reading over SPI (`startAcc`, `readAcc`, `startMag`, `readMag`), the 50 Hz sensor loop and BLE transmission |
| `Src/step_counter.c`, `Inc/step_counter.h` | Step detection algorithm, independent of the hardware |
| `Src/heading.c`, `Inc/heading.h` | Relative heading from the magnetometer, and its calibration constants, independent of the hardware |
| `tools/replay_steps.c` (repo root) | PC program that replays a logged serial capture through `step_counter.c`, for tuning |

Both algorithm modules make no hardware calls, so they also compile on a PC. `main.c` reads both sensors every 20 ms (TIM4, 50 Hz), passes the readings to `StepCounter_Update()` and `Heading_Update()`, and sends the results over BLE in the gyroscope characteristic, with steps and heading multiplied by 10.

Debug switches at the top of `main.c`:

| Define | Effect when set to 1 |
| --- | --- |
| `ACC_DEBUG_PRINT` | Prints every accelerometer sample as `ACC=x,y,z` (mg) over USB serial, the input format for `tools/replay_steps.c` |
| `MAG_DEBUG_PRINT` | Prints every magnetometer sample (mG) and the field strength over USB serial |

### Accelerometer

The LSM303AGR accelerometer is configured in `startAcc()`:

| Register | Value | Meaning |
| --- | --- | --- |
| `CTRL_REG1_A` (0x20) | 0x57 | 100 Hz output data rate, X, Y and Z axes enabled |
| `CTRL_REG4_A` (0x23) | 0x99 | Block data update, ±4 g full scale, 12-bit high-resolution mode, SPI 3-wire enabled |

`readAcc()` reads the six output registers in one SPI transfer and converts each axis to mg (1.95 mg/LSB). With the device flat and still, the readings are about (0, 0, ±1000) mg.

### Step counter

`StepCounter_Update()` is called with each accelerometer sample at 50 Hz (`STEP_COUNTER_SAMPLE_HZ`, which also sets the TIM4 sensor timer). For each sample it:

1. takes only the z axis, which is vertical when the board is held flat, so sideways movement and shaking are ignored;
2. subtracts a slow moving average (1 s time constant) to remove gravity, starting from the first reading so power on is not counted as a step;
3. smooths the result with an 8-sample (160 ms) moving average, which keeps the walking bounce but removes faster shaking and the rebound after a heel strike;
4. counts a step when the signal rises above a threshold and then falls back through zero, provided at least 300 ms have passed since the previous step.

The threshold adapts to a quarter of the recent step amplitude, with a minimum of 110 mg, and drops back to the minimum after 2 s without a step. The adjustable constants are at the top of `Src/step_counter.c`.

### Magnetometer

The LSM303AGR magnetometer is configured in `startMag()`:

| Register | Value | Meaning |
| --- | --- | --- |
| `CFG_REG_C_M` (0x62) | 0x30 | I2C disabled (needed for SPI), block data update |
| `CFG_REG_A_M` (0x60) | 0x8C | Temperature compensation, high-resolution, 100 Hz, continuous mode |
| `CFG_REG_B_M` (0x61) | 0x02 | Offset cancellation |

`readMag()` reads the six output registers in one SPI transfer and converts each axis to mG (1.5 mG/LSB).

### Heading

`Heading_Update()` is called with the x and y magnetometer readings at 50 Hz. It:

1. corrects the readings with the calibration constants in `Inc/heading.h` (`MAG_OFFSET_X`, `MAG_OFFSET_Y` and `MAG_SCALE_Y`), so a full turn traces a circle centred on zero;
2. averages the direction over the first 1.5 s (`HEADING_SETTLE_MS`), which becomes heading 0;
3. returns the angle of the field minus that zero direction, 0 to 359 degrees, increasing clockwise.

The calibration only holds near the spot where it was made. To recalibrate, turn the flat board slowly through a full circle at hand height, set each offset to the middle of the smallest and largest reading on that axis and `MAG_SCALE_Y` to the x range divided by the y range, then rebuild and flash.
