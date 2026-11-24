// swift-tools-version: 6.3
//
// Dev command-plugin host for the CI workflows (.github/workflows/*.yml).
//
// LiquidGlass deliberately declares NO package dependencies. The command
// plugins it uses at build time — swift-docc-plugin (Docs) and
// SwiftLintPlugins (CI lint) — are hosted here instead. Each workflow copies
// the library's sources into Sources/LiquidGlass and invokes
// `swift package --package-path .github/build-tools ...` against this package.
import PackageDescription

let package = Package(
    name: "LiquidGlassBuildTools",
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.65.1")
    ],
    targets: [
        .target(
            name: "LiquidGlass",
            path: "Sources/LiquidGlass",
            resources: [.process("Resources")]
        )
    ]
)