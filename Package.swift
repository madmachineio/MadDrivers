// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MadDrivers",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MadDrivers",
            targets: [
                "ADT7410",
                "ADXL345",
                "AHTx0",
                "AMG88xx",
                "APDS9960",
                "AS7341",
                "BH1750",
                "BME680",
                "BMI160",
                "BMP280",
                "DHTxx",
                "DS3231",
                "HCSR04",
                "IS31FL3731",
                "LCD1602",
                "LIS3DH",
                "LTR390",
                "MAG3110",
                "MCP4725",
                "MCP9808",
                "MLX90393",
                "MPL3115A2",
                "MPU6050",
                "PCF8523",
                "PCF8563",
                "SGP30",
                "SHT3x",
                "ST7789",
                "TCS34725",
                "TSL2591",
                "VEML6040",
                "VEML6070",
                "VEML7700",
                "VL53L0x"]),
        .library(name: "ADT7410", targets: ["ADT7410"]),
        .library(name: "ADXL345", targets: ["ADXL345"]),
        .library(name: "AHTx0", targets: ["AHTx0"]),
        .library(name: "AMG88xx", targets: ["AMG88xx"]),
        .library(name: "APDS9960", targets: ["APDS9960"]),
        .library(name: "AS7341", targets: ["AS7341"]),
        .library(name: "BH1750", targets: ["BH1750"]),
        .library(name: "BME680", targets: ["BME680"]),
        .library(name: "BMI160", targets: ["BMI160"]),
        .library(name: "BMP280", targets: ["BMP280"]),
        .library(name: "DHTxx", targets: ["DHTxx"]),
        .library(name: "DS3231", targets: ["DS3231"]),
        .library(name: "HCSR04", targets: ["HCSR04"]),
        .library(name: "IS31FL3731", targets: ["IS31FL3731"]),
        .library(name: "LCD1602", targets: ["LCD1602"]),
        .library(name: "LIS3DH", targets: ["LIS3DH"]),
        .library(name: "LTR390", targets: ["LTR390"]),
        .library(name: "MAG3110", targets: ["MAG3110"]),
        .library(name: "MCP4725", targets: ["MCP4725"]),
        .library(name: "MCP9808", targets: ["MCP9808"]),
        .library(name: "MLX90393", targets: ["MLX90393"]),
        .library(name: "MPL3115A2", targets: ["MPL3115A2"]),
        .library(name: "MPU6050", targets: ["MPU6050"]),
        .library(name: "PCF8523", targets: ["PCF8523"]),
        .library(name: "PCF8563", targets: ["PCF8563"]),
        .library(name: "SGP30", targets: ["SGP30"]),
        .library(name: "SHT3x", targets: ["SHT3x"]),
        .library(name: "ST7789", targets: ["ST7789"]),
        .library(name: "TCS34725", targets: ["TCS34725"]),
        .library(name: "TSL2591", targets: ["TSL2591"]),
        .library(name: "VEML6040", targets: ["VEML6040"]),
        .library(name: "VEML6070", targets: ["VEML6070"]),
        .library(name: "VEML7700", targets: ["VEML7700"]),
        .library(name: "VL53L0x", targets: ["VL53L0x"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ADT7410",
            dependencies: ["SwiftIO"]),
        .target(
            name: "ADXL345",
            dependencies: ["SwiftIO"]),
        .target(
            name: "AHTx0",
            dependencies: ["SwiftIO"]),
        .target(
            name: "AMG88xx",
            dependencies: ["SwiftIO"]),
        .target(
            name: "APDS9960",
            dependencies: ["SwiftIO"]),
        .target(
            name: "AS7341",
            dependencies: ["SwiftIO"]),
        .target(
            name: "BH1750",
            dependencies: ["SwiftIO"]),
        .target(
            name: "BME680",
            dependencies: ["SwiftIO",
                            .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "BMI160",
            dependencies: ["SwiftIO"]),
        .target(
            name: "BMP280",
            dependencies: ["SwiftIO",
                            .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "DHTxx",
            dependencies: ["SwiftIO"]),
        .target(
            name: "DS3231",
            dependencies: ["SwiftIO"]),
        .target(
            name: "HCSR04",
            dependencies: ["SwiftIO"]),
        .target(
            name: "IS31FL3731",
            dependencies: ["SwiftIO"]),
        .target(
            name: "LCD1602",
            dependencies: ["SwiftIO"]),
        .target(
            name: "LIS3DH",
            dependencies: ["SwiftIO"]),
        .target(
            name: "LTR390",
            dependencies: ["SwiftIO",
                           .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "MAG3110",
            dependencies: ["SwiftIO",
                           .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "MCP4725",
            dependencies: ["SwiftIO"]),
        .target(
            name: "MCP9808",
            dependencies: ["SwiftIO"]),
        .target(
            name: "MLX90393",
            dependencies: ["SwiftIO"]),
        .target(
            name: "MPL3115A2",
            dependencies: ["SwiftIO"]),
        .target(
            name: "MPU6050",
            dependencies: ["SwiftIO"]),
        .target(
            name: "PCF8523",
            dependencies: ["SwiftIO"]),
        .target(
            name: "PCF8563",
            dependencies: ["SwiftIO"]),
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
        .target(
            name: "TCS34725",
            dependencies: ["SwiftIO",
                           .product(name: "RealModule", package: "swift-numerics")]),
        .target(
            name: "TSL2591",
            dependencies: ["SwiftIO"]),
        .target(
            name: "VEML6040",
            dependencies: ["SwiftIO"]),
        .target(
            name: "VEML6070",
            dependencies: ["SwiftIO"]),
        .target(
            name: "VEML7700",
            dependencies: ["SwiftIO"]),
        .target(
            name: "VL53L0x",
            dependencies: ["SwiftIO"]),
        .testTarget(
            name: "ADT7410Tests",
            dependencies: ["ADT7410", "SwiftIO"]),
        .testTarget(
            name: "ADXL345Tests",
            dependencies: ["ADXL345", "SwiftIO"]),
        .testTarget(
            name: "AHTx0Tests",
            dependencies: ["AHTx0", "SwiftIO"]),
        .testTarget(
            name: "AMG88xxTests",
            dependencies: ["AMG88xx", "SwiftIO"]),
        .testTarget(
            name: "APDS9960Tests",
            dependencies: ["APDS9960", "SwiftIO"]),
        .testTarget(
            name: "AS7341Tests",
            dependencies: ["AS7341", "SwiftIO"]),
        .testTarget(
            name: "BMI160Tests",
            dependencies: ["BMI160", "SwiftIO"]),
        .testTarget(
            name: "LTR390Tests",
            dependencies: ["LTR390", "SwiftIO"]),
        .testTarget(
            name: "MAG3110Tests",
            dependencies: ["MAG3110", "SwiftIO"]),
        .testTarget(
            name: "MCP9808Tests",
            dependencies: ["MCP9808", "SwiftIO"]),
        .testTarget(
            name: "MLX90393Tests",
            dependencies: ["MLX90393", "SwiftIO"]),
        .testTarget(
            name: "MPL3115A2Tests",
            dependencies: ["MPL3115A2", "SwiftIO"]),
        .testTarget(
            name: "SGP30Tests",
            dependencies: ["SGP30", "SwiftIO"]),
        .testTarget(
            name: "SHT3xTests",
            dependencies: ["SHT3x", "SwiftIO"]),
        .testTarget(
            name: "TCS34725Tests",
            dependencies: ["TCS34725", "SwiftIO"]),
        .testTarget(
            name: "TSL2591Tests",
            dependencies: ["TSL2591", "SwiftIO"]),
        .testTarget(
            name: "VEML6070Tests",
            dependencies: ["VEML6070", "SwiftIO"]),
        .testTarget(
            name: "VEML7700Tests",
            dependencies: ["VEML7700", "SwiftIO"]),
        .testTarget(
            name: "VL53L0xTests",
            dependencies: ["VL53L0x", "SwiftIO"]),
    ]
)
