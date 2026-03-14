// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "napkin",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "napkin",
            targets: ["napkin"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "napkin",
            dependencies: []),
        .testTarget(
            name: "napkinTests",
            dependencies: ["napkin"]),
    ]
)
