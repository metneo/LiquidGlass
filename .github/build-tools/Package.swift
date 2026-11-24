// swift-tools-version: 6.3
//
// DocC builder for the Docs workflow (.github/workflows/docs.yml).
//
// LiquidGlass deliberately declares NO package dependencies, so the
// swift-docc-plugin it uses at doc-build time can't live in its manifest.
// This throwaway package hosts the plugin instead: the workflow copies the
// library's sources into Sources/LiquidGlass and runs `swift package
// generate-documentation` against this package.
import PackageDescription

let package = Package(
    name: "LiquidGlassBuildTools",
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "LiquidGlass",
            path: "Sources/LiquidGlass",
            resources: [.process("Resources")]
        )
    ]
)