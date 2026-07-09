// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BasicTest",
    dependencies: [
        .package(url: "https://github.com/madmachineio/SwiftIO.git", branch: "main"),
        .package(url: "https://github.com/madmachineio/MadBoards.git", branch: "main"),
        .package(path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "BasicTest",
            dependencies: [
                "SwiftIO",
                "MadBoards",
                .product(name: "EPD1in54G", package: "MadDrivers")
            ])
    ]
)
