// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SHT3xRead",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
	.package(url: "https://github.com/madmachineio/SwiftIO.git", .branch("release/v0.2")),
	.package(url: "https://github.com/madmachineio/Board.git", .branch("main")),
	.package(url: "https://github.com/madmachineio/MadDriver.git", .branch("main"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SHT3xRead",
            dependencies: ["SwiftIO",
                          "Board",
			              "SHT3x"]),
        .testTarget(
            name: "SHT3xReadTests",
            dependencies: ["SHT3xRead"]),
    ]
)
