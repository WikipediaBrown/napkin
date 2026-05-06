// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "napkin",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "napkin",
            targets: ["napkin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "napkin",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("RegionBasedIsolation")
            ]
        ),
        .testTarget(
            name: "napkinTests",
            dependencies: ["napkin"]),
    ]
)
