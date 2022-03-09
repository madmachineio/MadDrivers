# MadDrivers

![build](https://github.com/madmachineio/MadDrivers/actions/workflows/build.yml/badge.svg)
![test](https://github.com/madmachineio/MadDrivers/actions/workflows/host_test.yml/badge.svg)
[![codecov](https://codecov.io/gh/madmachineio/MadDrivers/branch/main/graph/badge.svg?token=PHBKJXWHPN)](https://codecov.io/gh/madmachineio/MadDrivers)
[![Discord](https://img.shields.io/discord/592743353049808899?&logo=Discord&colorB=7289da)](https://madmachine.io/discord)
[![twitter](https://img.shields.io/twitter/follow/madmachineio?label=%40madmachineio&style=social)](https://twitter.com/madmachineio)

This `MadDrivers` library, based on `SwiftIO`, provides an easy way to use all kinds of devices with your boards. You could directly use the related class to read or write data and don't need to understand the communication details.

Note: This library aims to allow you to program the devices easily, so some uncommon errors or rare situations aren't be considered. The `SwiftIO` library can give the messages about the communication and which error occurs if it fails. If you need more detailed results about the device status to ensure security, you can download and modify the code according to your need.

## Drivers
You can find some frequently-used hardware here:

<table>
<thead>
  <tr>
    <th>Type</th>
    <th>Device</th>
    <th>Communication</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td rowspan="2">Accelerometer</td>
    <td>ADXL345</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td>LIS3DH</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td>Color</td>
    <td>VEML6040</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>DAC</td>
    <td>MCP4725</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="3">Dispaly<br></td>
    <td>IS31FL3731</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>LCD1602</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>ST7789</td>
    <td>SPI</td>
  </tr>
    <tr>
    <td rowspan="2">Distance<br></td>
    <td>HCSR04</td>
    <td>GPIO</td>
  </tr>
  <tr>
    <td>VL53L0x</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>Gesture</td>
    <td>APDS9960</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>Gyroscope</td>
    <td>MPU6050</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>Light</td>
    <td>BH1750</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>Magnetometer</td>
    <td>MAG3110</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="2">Pressure</td>
    <td>BME680</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td>BMP280</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td rowspan="3">RTC</td>
    <td>DS3231</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>PCF8523</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>PCF8563</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="3">Temperature &amp; Humidity</td>
    <td>AHTx0</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>DHTxx</td>
    <td>GPIO</td>
  </tr>
  <tr>
    <td>SHT3x</td>
    <td>I2C</td>
  </tr>
</tbody>
</table>

We will keep adding more drivers. And your contributions are welcome!

## Use drivers

Take the library `SHT3x` for example:

1. Create an executable project. You can refer to [this tutorial](https://docs.madmachine.io/how-to/create-new-project).

2. Open the project and open the file `Package.swift`. 

    The `MadDrivers` has already been added to your project by default. You could use all libraries in it. It's better to **specify the specific library** to reduce the build time for your project. Change the statement
    
    `.product(name: "MadDrivers", package: "MadDrivers")` to
    
    `.product(name: "SHT3x", package: "MadDrivers")` as shown below.

```swift
// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "sht3x",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .upToNextMinor(from: "0.0.1")),
        .package(url: "https://github.com/madmachineio/MadBoards.git", .upToNextMinor(from: "0.0.1")),
        .package(url: "https://github.com/madmachineio/MadDrivers.git", .upToNextMinor(from: "0.0.1")),
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

let i2c = I2C(Id.I2C0)
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


