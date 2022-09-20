# MadDrivers


![build](https://github.com/madmachineio/MadDrivers/actions/workflows/build.yml/badge.svg)
![test](https://github.com/madmachineio/MadDrivers/actions/workflows/host_test.yml/badge.svg)
[![codecov](https://codecov.io/gh/madmachineio/MadDrivers/branch/main/graph/badge.svg?token=PHBKJXWHPN)](https://codecov.io/gh/madmachineio/MadDrivers)
[![Discord](https://img.shields.io/discord/592743353049808899?&logo=Discord&colorB=7289da)](https://madmachine.io/discord)
[![twitter](https://img.shields.io/twitter/follow/madmachineio?label=%40madmachineio&style=social)](https://twitter.com/madmachineio)

This `MadDrivers` library, based on `SwiftIO`, provides an easy way to use all kinds of devices with your boards. You could directly use the related class to read or write data without worrying about the communication details.

Note: This library aims to simplify the way you program all devices, so some uncommon errors or rare situations aren't considered. The `SwiftIO` library can give the messages about the communication and which error occurs if it fails. If you need more detailed results to ensure security, feel free to download and modify the code according to your need.

## Drivers
The table below lists the existing drivers and will be updated as time goes on.

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
    <td rowspan="3">Color</td>
    <td>AS7341</td>
    <td>I2C</td>
  <tr>
    <td>TCS34725</td>
    <td>I2C</td>
  </tr>
    </tr>
    <tr>
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
    <td rowspan="2">Gas<br></td>
    <td>BME680</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td>SGP30</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>Gesture</td>
    <td>APDS9960</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="2">Gyroscope</td>
    <td>BMI160</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td>MPU6050</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="4">Light</td>
    <td>BH1750</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>LTR390</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>TSL2591</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>VEML7700</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td rowspan="2">Magnetometer</td>
    <td>MAG3110</td>
    <td>I2C</td>
  </tr>
  </tr>
    <tr>
    <td>MLX90393</td>
    <td>I2C/SPI</td>
  </tr>
  <tr>
    <td rowspan="2">Pressure</td>
    <td>BMP280</td>
    <td>I2C/SPI</td>
  </tr>
    <tr>
    <td>MPL3115A2</td>
    <td>I2C</td>
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
    <td rowspan="4">Temperature &amp; Humidity</td>
    <td>AHTx0</td>
    <td>I2C</td>
  </tr>
    <tr>
    <td>DHTxx</td>
    <td>GPIO</td>
  </tr>
  <tr>
    <td>MCP9808</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>SHT3x</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>Thermal</td>
    <td>AMG88xx</td>
    <td>I2C</td>
  </tr>
  <tr>
    <td>Ultraviolet</td>
    <td>VEML6070</td>
    <td>I2C</td>
  </tr>
</tbody>
</table>

We will keep adding more drivers. And your [contributions](#contribute) are welcome!

## Try examples

Let's start by trying demo projects in the folder [Examples](https://github.com/madmachineio/MadDrivers/tree/main/Examples). 

In the folder `Examples`, there are folders for different devices. Each folder may have one or several projects to help you get started with each device.
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
After you download the whole folder, [here](https://docs.madmachine.io/overview/advanced/run-example) is a tutorial about running the code on your board.

## Use drivers

Take the library `SHT3x` for example:

1. [Create](https://docs.madmachine.io/overview/getting-started/create-project) an executable project `ReadSHT3x`.

2. Open the project and open the file `Package.swift`. 

    `MadDrivers` has already been added to the dependency by default, thus you can use all drivers in it. However, it's better to **specify a specific library** to reduce the build time for your project. So change the statement
    `.product(name: "MadDrivers", package: "MadDrivers")` to
    `.product(name: "SHT3x", package: "MadDrivers")` as shown below.

```swift
// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "ReadSHT3x",
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
            name: "ReadSHT3x",
            dependencies: [
                "SwiftIO",
                "MadBoards",
                // use specific library would speed up the compile procedure
                .product(name: "SHT3x", package: "MadDrivers")
            ]),
        .testTarget(
            name: "ReadSHT3xTests",
            dependencies: ["ReadSHT3x"]),
    ]
)
```

3. In the file `main.swift`, import the `SHT3x`, then you could use everything in it to communicate with the sensor.

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

4. If more drivers are needed, you can repeat 2 and 3 above.



## Contribute

First of all, a big thanks to you for taking the time to contribute 🥰! Any corrections, enhancements and supplements are welcome! 

If you want to use some sensors which is not included in the `MadDrivers`, you can **[open an issue](https://github.com/madmachineio/MadDrivers/issues)** or **[create a pull request](https://github.com/madmachineio/MadDrivers/pulls)** from your own fork.


### How can I contribute from my own fork

1. **Fork** the MadDrivers repository to your GitHub account by clicking the Fork button in the top right corner of this page.

2. **Clone** the repo to your local computer.
```bash
git clone https://github.com/YOUR-USERNAME/MadDrivers.git
```

3. Enter the directory you just cloned.
```bash
cd MadDrivers
```

4. **Create a new branch** `feature/add_sht3x` off of main for your changes.
```bash
git checkout -b feature/add_sht3x
```

5. Start to work on your driver and test your code using the sensor. Check [the driver guide](#driver-guide) for some extra info.

6. After you implement the driver, **push** your changes to your repo.
```bash
git push --set-upstream origin feature/add_sht3x
```

7. Go to your forked repo and click the button **Compare & pull request** to propose your changes to the upstream repo.

8. Click the button **Create pull request**.

9. After your request is sent, the CI will check your PR automatically.  If no error occurs and no modification is required, your request will be reviewed and merged into `main` branch. 

### To-do list

If you would like to create a new driver, below is our to-do list of sensors for your reference. Feel free to propose more sensors.

| Type                                 | Sensors       | Communication |
| ------------------------------------ | ------------- | ------------- |
| Temperature                          | ADT7410       | I2C           |
| Temperature                          | TMP102        | I2C           |
| Temperature/humidity                 | HTS221        | I2C/SPI       |
| Temperature/humidity                 | HTU21D        | I2C           |
| Temperature/humidity                 | SI7021        | I2C           |
| Pressure/Temperature                 | MPL115A2      | I2C           |
| Temperature/Humidity/Pressure        | BME280        | I2C/SPI       |
| Pressure                             | BMP085/BMP180 | I2C           |
| Pressure                             | BMP388        | I2C/SPI       |
| Pressure                             | MS5611        | I2C/SPI       |
| Air quality                          | CCS811        | I2C           |
| CO2                                  | SCD4X         | I2C           |
| IR Thermal Camera                    | MLX90640      | I2C           |
| UV/IR/ambient light                  | SI1145        | I2C           |
| Capacitive touch                     | MPR121        | I2C           |
| Current/power monitor                | INA260        | I2C           |
| RF Transceiver                       | NRF24L01      | SPI           |
| Absolute-orientation                 | BNO055        | I2C/UART      |
| GPS                                  | MT3339        | I2C/SPI/UART  |
| Magnetic                             | HMC5883       | I2C           |
| Gyroscope                            | L3GD20        | I2C/SPI       |
| Magnetometer                         | LIS2MDL       | I2C/SPI       |
| Accelerometer/magnetometer           | LSM303        | I2C           |
| Accelerometer/gyroscope              | LSM6DS        | I2C/SPI       |
| Accelerometer/magnetometer/gyroscope | LSM9DS        | I2C/SPI       |
| 4-digit 7-segment display            | TM1637        | Digital       |


### Driver guide

This part guides you through adding a new driver to this library. Take SHT3x for example. 

To start with, let's have an overview of the main repository’s source tree. The `MadDrivers` is a Swift package. You'll find source code for all drivers, example projects, a manifest file, and other files.
* `Sources`: device driver code.
* `Examples`: simple demos for each device to get started.
* `Tests`: test for device drivers.
* `Package.swift`: package name and its content.
* `Package.mmp`: MadMachine project file.

```
├── MadDrivers
│   ├── Sources
│   │   ├── SHT3x
│   │   │   ├── SHT3x.swift
│   ├── Examples
│   │   ├── SHT3x
│   │   │   ├── ReadValues
│   ├── Tests
│   │   ├── SHT3xTests
│   ├── Package.swift
│   ├── Package.mmp
│   ├── ...
```
To add your driver, you will
1. create a new folder `SHT3x` in the folder `Sources`. Each folder in it matches a device.
2. create a swift file named `SHT3x.swift` in the folder `SHT3x`. This file stores the code to configure the sensor.
3. add the new target SHT3x to the file `Package.swift` as below.

```swift
import PackageDescription

let package = Package(
    name: "MadDrivers",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MadDrivers",
            targets: [
                "SGP30",
                "SHT3x",
                "ST7789"
                ]),
        .library(name: "SGP30", targets: ["SGP30"]),
        .library(name: "SHT3x", targets: ["SHT3x"]),
        .library(name: "ST7789", targets: ["ST7789"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SGP30",
            dependencies: ["SwiftIO",
                           .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "SHT3x",
            dependencies: ["SwiftIO"]),
        .target(
            name: "ST7789",
            dependencies: ["SwiftIO"]),
    ]
)
```

4. write code for the sensor according to its datasheet. At the same time, you can find many drivers created by manufacturers or others as a reference. 

5. in the folder `Examples`, create a new folder `SHT3x` to store demo project(s).

Info: BTW, we add tests for each sensor while writing code, which will prevent us from some typos and obvious errors. You could also skip it. 
If you want to have a try, one thing to note is that the `SwiftIO` library used for tests is from the branch `mock`. You need to change its version while working on tests. As for how to write tests, you could refer to [SHT3xTests](./Tests/SHT3xTests/SHT3xTests.swift). It lies in supposing the values from a sensor and calculating the 
result your methods should produce.
