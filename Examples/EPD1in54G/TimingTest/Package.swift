// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimingTest",
    dependencies: [
        .package(url: "https://github.com/madmachineio/SwiftIO.git", branch: "main"),
        .package(url: "https://github.com/madmachineio/MadBoards.git", branch: "main"),
        .package(path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "TimingTest",
            dependencies: [
                "SwiftIO",
                "MadBoards",
                .product(name: "EPD1in54G", package: "MadDrivers")
            ])
    ]
)
