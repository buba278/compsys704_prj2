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
4. Serial debug output: connect a terminal to the board's COM port at 115200 baud, 8 data bits, no parity, 1 stop bit.
5. In the ST BLE Sensor app, connect to the device and plot **Accelerometer** (raw acceleration in mg), **Magnetometer**, or **Gyroscope** (X = step count, Y = heading, Z = filtered step signal in mg).

## Code structure

All application code is in `COMSYS704/Projects/STM32L476JG-SensorTile/Applications/ALLMEMS1/`.

| File | Purpose |
| --- | --- |
| `Src/main.c` | Sensor initialisation and reading over SPI (`startAcc`, `readAcc`, `startMag`, `readMag`), the 50 Hz sensor loop and BLE transmission |
| `Src/step_counter.c`, `Inc/step_counter.h` | Step detection algorithm, independent of the hardware |

### Accelerometer

The LSM303AGR accelerometer is configured in `startAcc()`:

| Register | Value | Meaning |
| --- | --- | --- |
| `CTRL_REG1_A` (0x20) | 0x57 | 100 Hz output data rate, X, Y and Z axes enabled |
| `CTRL_REG4_A` (0x23) | 0x99 | Block data update, ±4 g full scale, 12-bit high-resolution mode, SPI 3-wire enabled |

`readAcc()` reads the six output registers in one SPI transfer and converts each axis to mg (1.95 mg/LSB). With the device flat and still, the readings are about (0, 0, ±1000) mg.

### Step counter

`StepCounter_Update()` is called with each accelerometer sample at 50 Hz (`STEP_COUNTER_SAMPLE_HZ`, which also sets the TIM4 sensor timer). For each sample it:

1. takes the magnitude of the acceleration vector, so the result does not depend on device orientation;
2. subtracts a slow moving average to remove gravity;
3. smooths the result with a 5-sample moving average;
4. counts a step when the signal rises above a threshold and then falls back through zero, provided at least 300 ms have passed since the previous step.

The threshold adapts to a quarter of the recent step amplitude, with a minimum of 80 mg. The tunable constants are at the top of `Src/step_counter.c`.
