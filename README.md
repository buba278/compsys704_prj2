# COMPSYS 704 Project 2 — Pedestrian Dead Reckoning on SensorTile

Firmware for the ST SensorTile (STM32L476JG) that tracks a person's step count and orientation using the on-board LSM303AGR accelerometer and magnetometer, and streams the results over Bluetooth Low Energy to the ST BLE Sensor mobile app.

## Hardware and software requirements

- SensorTile development kit with integrated STLINK-V3 programmer and battery
- [STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html)
- Windows only: [ST virtual COM port driver](https://www.st.com/en/development-tools/stsw-stm32102.html) for `XPRINTF` output over USB
- A serial terminal such as [CoolTerm](http://freeware.the-meiers.org/) or PuTTY
- ST BLE Sensor app ([Android](https://play.google.com/store/apps/details?id=com.st.bluems) / [iOS](https://apps.apple.com/it/app/st-bluems/id993670214))