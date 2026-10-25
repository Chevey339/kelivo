// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "liquid_glass_widgets",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "liquid-glass-widgets", targets: ["liquid_glass_widgets"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "liquid_glass_widgets",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
