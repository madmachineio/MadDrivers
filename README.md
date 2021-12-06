# MadDrivers

![build](https://github.com/madmachineio/MadDrivers/actions/workflows/build.yml/badge.svg)
[![Discord](https://img.shields.io/discord/592743353049808899?&logo=Discord&colorB=7289da)](https://madmachine.io/discord)
[![twitter](https://img.shields.io/twitter/follow/madmachineio?label=%40madmachineio&style=social)](https://twitter.com/madmachineio)

This `MadDrivers` library provides an easy way to use all kinds of devices with your boards. You could directly use the related class to read or write data and don't need to understand the communication details.

## Drivers
You can find some frequently-used hardware here:

| Type                   | Device     | Interface |
|------------------------|------------|-----------|
| Temperature & Humidity | DHTxx      | GPIO      |
| Temperature & Humidity | SHT3x      | I2C       |
| Accelerometer          | ADXL345    | I2C/SPI   |
| Accelerometer          | LIS3DH     | I2C/SPI   |
| Gyroscope              | MPU6050    | I2C       |
| Ultrasonic             | HCSR04     | GPIO      |
| Light                  | BH1750     | I2C       |
| Color                  | VEML6040   | I2C       |
| Display                | ST7789     | SPI       |
| LED matrix             | IS31FL3731 | I2C       |
| Display                | LCD1602    | I2C       |
| RTC                    | DS3231     | I2C       |
| RTC                    | PCF8523    | I2C       |
| RTC                    | PCF8563    | I2C       |
| Pressure               | BMP280     | I2C/SPI   |
| DAC                    | MCP4725    | I2C       |


We will keep adding more drivers. And your contributions are welcome!

## Use drivers

Take the library `SHT3x` for example:

1. Create an executable project. You can refer to [this tutorial](https://docs.madmachine.io/how-to/create-new-project).

2. Open the project and open the file `package.swift`. 

    The `MadDrivers` has already been added to your project by default. You could use all libraries in it. It's better to **specify the specific library** to reduce the build time for your project. Change the statement `.product(name: "MadDrivers", package: "MadDrivers")` to `.product(name: "SHT3x", package: "MadDrivers")` as shown below.

```swift
// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "sht3x",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/madmachineio/MadBoards.git", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/madmachineio/MadDrivers.git", .upToNextMajor(from: "0.0.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "sht3x",
            dependencies: [
                "SwiftIO",
                "MadBoards",
                // use specific library would speed up the compile procedure
                .product(name: "SHT3x", package: "MadDrivers")
            ]),
        .testTarget(
            name: "sht3xTests",
            dependencies: ["sht3x"]),
    ]
)
```

3. Now, you can write code for your project. In the file `main.swift`, import the `SHT3x`, then you could use everything in it to communicate with the sensor.

```swift
import SwiftIO
import MadBoard
import SHT3x

let i2c = I2C(Id.I2C1)
let sensor = SHT3x(i2c)

while true {
    let temperature = sensor.readCelsius()
    let humidity = sensor.readHumidity()
    print(temperature)
    print(humidity)
    sleep(ms: 1000)
}
```


## Try examples

At first, you could try demo projects in the folder [Examples](https://github.com/madmachineio/MadDrivers/tree/main/Examples).

In the Examples folder, there are folders for different devices. Each folder may have one or several projects to help you get started with each device.

```
├── Examples
│   ├── ADXL345
│   │   ├── ReadXYZ
│   ├── DS3232
│   │   ├── Alarm
│   │   ├── ReadTime
│   │   ├── Timer
│   ├── IS31FL3731
│   ├── ├── BreathingLED
│   ├── ├── DrawPixels
│   ├── ├── Frame
│   ├── ├── ScrollingText
│   ├── ...
```
You could download the whole folder and try the examples. [Here](https://docs.madmachine.io/overview/run-your-first-project) is a tutorial about how to run the projects on your board.


