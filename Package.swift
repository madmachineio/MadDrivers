// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MadDrivers",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MadDrivers",
            targets: [
                "ADXL345",
                "AHTx0",
                "APDS9960",
                "BH1750",
                "BME680",
                "BMP280",
                "DHTxx",
                "DS3231",
                "HCSR04",
                "IS31FL3731",
                "LCD1602",
                "LIS3DH",
                "MAG3110",
                "MCP9808",
                "MCP4725",
                "MPU6050",
                "PCF8523",
                "PCF8563",
                "SGP30",
                "SHT3x",
                "ST7789",
                "TCS34725",
                "VEML6040",
                "VEML6070",
                "VL53L0x"]),
        .library(name: "ADXL345", targets: ["ADXL345"]),
        .library(name: "AHTx0", targets: ["AHTx0"]),
        .library(name: "APDS9960", targets: ["APDS9960"]),
        .library(name: "BH1750", targets: ["BH1750"]),
        .library(name: "BME680", targets: ["BME680"]),
        .library(name: "BMP280", targets: ["BMP280"]),
        .library(name: "DHTxx", targets: ["DHTxx"]),
        .library(name: "DS3231", targets: ["DS3231"]),
        .library(name: "HCSR04", targets: ["HCSR04"]),
        .library(name: "IS31FL3731", targets: ["IS31FL3731"]),
        .library(name: "LCD1602", targets: ["LCD1602"]),
        .library(name: "LIS3DH", targets: ["LIS3DH"]),
        .library(name: "MAG3110", targets: ["MAG3110"]),
        .library(name: "MCP4725", targets: ["MCP4725"]),
        .library(name: "MCP9808", targets: ["MCP9808"]),
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
        .library(name: "VL53L0x", targets: ["VL53L0x"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .branch("main")),
        .package(url: "https://github.com/madmachineio/MadDisplay.git", .branch("main")),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ADXL345",
            dependencies: ["SwiftIO"]),
        .target(
            name: "AHTx0",
            dependencies: ["SwiftIO"]),
        .target(
            name: "APDS9960",
            dependencies: ["SwiftIO"]),
        .target(
            name: "BH1750",
            dependencies: ["SwiftIO"]),
        .target(
            name: "BME680",
            dependencies: ["SwiftIO",
                            .product(name: "RealModule", package: "swift-numerics")]),
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
            dependencies: ["SwiftIO", "MadDisplay"]),
        .target(
            name: "LCD1602",
            dependencies: ["SwiftIO"]),
        .target(
            name: "LIS3DH",
            dependencies: ["SwiftIO"]),
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
            dependencies: ["SwiftIO", "MadDisplay"]),
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
            name: "VL53L0x",
            dependencies: ["SwiftIO"]),

        .testTarget(
            name: "ADXL345Tests",
            dependencies: ["ADXL345", "SwiftIO"]),
        .testTarget(
            name: "AHTx0Tests",
            dependencies: ["AHTx0", "SwiftIO"]),
        .testTarget(
            name: "APDS9960Tests",
            dependencies: ["APDS9960", "SwiftIO"]),
        .testTarget(
            name: "MAG3110Tests",
            dependencies: ["MAG3110", "SwiftIO"]),
        .testTarget(
            name: "MCP9808Tests",
            dependencies: ["MCP9808", "SwiftIO"]),
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
            name: "VL53L0xTests",
            dependencies: ["VL53L0x", "SwiftIO"]),
    ]
)
