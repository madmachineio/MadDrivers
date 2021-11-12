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
                "BH1750",
                "DHTxx",
                "DS3231",
                "HCSR04",
                "IS31FL3731",
                "LCD1602",
                "LIS3DH",
                "MCP4725",
                "SHT3x",
                "ST7789",
                "VEML6040"]),
        .library(name: "BH1750", targets: ["BH1750"]),
        .library(name: "DHTxx", targets: ["DHTxx"]),
        .library(name: "DS3231", targets: ["DS3231"]),
        .library(name: "HCSR04", targets: ["HCSR04"]),
        .library(name: "IS31FL3731", targets: ["IS31FL3731"]),
        .library(name: "LCD1602", targets: ["LCD1602"]),
        .library(name: "LIS3DH", targets: ["LIS3DH"]),
        .library(name: "MCP4725", targets: ["MCP4725"]),
        .library(name: "SHT3x", targets: ["SHT3x"]),
        .library(name: "ST7789", targets: ["ST7789"]),
        .library(name: "VEML6040", targets: ["VEML6040"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/madmachineio/SwiftIO.git", .upToNextMajor(from: "0.0.5")),
        .package(url: "https://github.com/madmachineio/MadDisplay.git", .upToNextMajor(from: "0.0.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BH1750",
            dependencies: ["SwiftIO"]),
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
            name: "MCP4725",
            dependencies: ["SwiftIO"]),
        .target(
            name: "SHT3x",
            dependencies: ["SwiftIO"]),
        .target(
            name: "ST7789",
            dependencies: ["SwiftIO", "MadDisplay"]),
        .target(
            name: "VEML6040",
            dependencies: ["SwiftIO"]),
    ]
)
