// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiquidGlass",
    platforms: [
        .macOS(.v12),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LiquidGlass",
            targets: ["LiquidGlass"]
        )
    ],
    dependencies: [
        // Dev-only: enables `swift package generate-documentation` for the Docs
        // workflow. A build-time plugin, not a runtime dependency.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LiquidGlass",
            resources: [.process("Resources/")]
        ),
        .testTarget(
            name: "LiquidGlassTests",
            dependencies: ["LiquidGlass"]
        ),
    ]
)
