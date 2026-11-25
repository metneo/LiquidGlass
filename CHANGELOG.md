# Changelog

All notable changes to LiquidGlass will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **AppKit/UIKit `LiquidGlassView` no longer draws a drop shadow.** The shadow was painted outside the view's bounds, so when the glass was embedded edge-to-edge in a host container the container's clipping cut it off (on AppKit, a layer-backed parent clips by default). Elevation now belongs to the host container — see the AppKit & UIKit DocC guide for per-platform `layer.shadow…` setup. The SwiftUI renderer's shadow is unchanged.

## [2.2.0] - 2026-11-24

### Added

- **SwiftUI-free AppKit & UIKit renderers.** New `LiquidGlassView` for AppKit (macOS) and UIKit (iOS/tvOS) that render the Liquid Glass effect with AppKit/UIKit + Core Graphics only — no SwiftUI involved. The UIKit host (built as `Sources/LiquidGlass/UIKit/LiquidGlassViewUIKit.swift` to satisfy SwiftPM's unique-basename rule) and the AppKit host share the same drawing core.
- New `LiquidGlassShape` — a SwiftUI-free shape model (`roundedRect`, `circle`, `capsule`) producing `CGPath`s, mirroring `BackgroundShape` without importing SwiftUI.
- New `LiquidGlassRenderer` — Quartz-only renderer for the whole effect (tint wash, highlight fill, v26 angular outline, v27 lens outline + dark border), including a Core Graphics approximation of SwiftUI's `AngularGradient` (conic fan of wedge fills) and a port of the v27 `HorizontalEdges` outline.
- `addLiquidGlassBackground(shape:tint:opacity:style:)` convenience on `NSView`/`UIView` to drop a glass background behind existing content.
- New [UI Requirements](UIRequirements.md) document detailing the visual spec, parameter semantics, parity expectations, and acceptance criteria for the effect.
- README section covering AppKit/UIKit usage and per-platform material configuration.
- New `forceToCustomLiquidGlass(_:)` view modifier (defaults to `true`) to force the custom `LiquidGlass` renderer on Platform 26+. It also applies to `glassStyleButton(...)` controls.

### Deprecated

- `liquidGlassUsesSystemImplementation(_:)` is deprecated in favor of `forceToCustomLiquidGlass(_:)`.

### Fixed

- SwiftUI-free renderers now compile cleanly against the Platform 26 SDK surface: replaced `package`-restricted `CGRect.isFinite` with stdlib `CGFloat.isFinite`, and updated `CGColor` color-space conversion to `converted(to:intent:options:)`.
- Resolved a SwiftPM duplicate-filename error by renaming the UIKit host file to `LiquidGlassViewUIKit.swift`.

## [2.1.0] - 2026-11-04

### Added

- New `liquidGlassUsesSystemImplementation(_:)` view modifier to control which renderer is used on Platform 26+: the library still defaults to Apple's native `glassEffect(in:)`, but passing `false` forces the custom ``LiquidGlass`` renderer even where the native API is available — handy for previewing the fallback look older platforms get, or keeping one consistent custom style. Apply it app-wide at a root view or scope to a subtree.
- New `GlassPreviewBackground` example view, replacing the inline gradient background in the `LiquidGlass` gallery preview.

### Changed

- `glassStyleButton(shape:prominent:tint:)` now also accepts an `opacity` parameter for glass button customization.
- Example previews now pin the custom renderer (and the `.v27` style where relevant) so the fallback look is previewed consistently.
- Docs and README updated to cover the new implementation-selection modifier.

## [1.4.1] - 2025-12-03

### Changed

- **Performance**: Optimized `GlassToggleStyle` by removing intermediate variables and streamlining view hierarchy
- **Code Quality**: Cleaned up commented code and improved property naming consistency (`mHeight` → `toggleHeight`, `mPadding` → `horizontalPadding`)
- **Animation**: Enhanced toggle animations with explicit `.easeInOut(duration: 0.3)` timing and platform-aware transitions
- **API**: Improved fluent interface documentation with parameter descriptions and return value details

### Fixed

- **Critical Bug**: Fixed `height(_:)` and `padding(_:)` methods in `GlassToggleStyle` that were returning `self` instead of the modified copy
- **Transition Logic**: Simplified platform-specific transition handling with cleaner availability checking
- **Label Styling**: Optimized `ToggleLabelStyle` conditional logic for better performance

## [1.4.0] - 2025-12-03

### Added

- New `tint(_:)` modifier method for `GlassButtonStyle` to customize accent colors
- Enhanced color customization with dedicated `prominentColor` property

### Changed

- **Breaking**: Removed unused `id` and `namespace` parameters from `GlassButtonStyle` initializer
- Optimized `GlassButtonStyle` performance by eliminating intermediate variables
- Simplified API surface by removing unused matched geometry effect properties
- Improved memory efficiency with reduced property storage
- Enhanced tint color logic for better prominent button styling
- Streamlined view building for better SwiftUI performance
- Updated implementation to use `.liquidGlass()` modifier instead of direct `LiquidGlass` instantiation

### Fixed

- Improved code consistency and maintainability through SwiftLint optimizations


## [1.3.0] - 2025-12-02

### Added

- New `GlassIconLabel` `LabelStyle` for icon-first UI elements with glass backgrounds
- Additional DemoApp examples demonstrating label styles and component usage

### Changed

- Continued performance and readability refinements across core views
- Consolidated Color assets and clarified asset-based color usage
- Improved DocC pages with extra examples and a Getting Started walkthrough

### Fixed

- Minor API docs and example code fixes
- Cleaned up legacy helper functions and removed unused code

---

## [1.2.0] - 2025-11-28

### Added

- Published improved DocC site with a new "Getting Started" page
- Added more examples and updated the DemoApp sample views

### Changed

- Continued documentation improvements and README alignment with DocC
- Small API clarifications in doc comments and example usage
- Major performance optimizations across core components
- Simplified view hierarchy in GlassEffectModifier for better rendering performance
- Streamlined BackgroundShape path generation with reduced complexity
- Enhanced animation timing for hover effects with explicit duration controls

### Fixed

- Minor markdown formatting and link fixes
- Optimized gradient calculations with precomputed constants

---

## [1.1.1] - 2025-11-16

### Fixed

- Minor documentation corrections and formatting
- Updated README links and symbol references
- Small improvements to DocC and markdown consistency

## [1.1.0] - 2025-11-08

### Changed

- Major overhaul of DocC documentation for Swift best practices
- Improved module-level summary, symbol links, and organized topics
- Updated README for consistency with DocC and best practices
- Enhanced documentation clarity and completeness
- Minor formatting and structure improvements

## [1.0.3] - 2025-11-08

### Changed

- Improved documentation comments for opacity API
- Added missing API doc comments for fluent methods
- Minor code cleanup and comment consistency

---

## [1.0.2] - 2025-11-08

### Changed

- Maintenance release, workflow and documentation improvements
- Added MIT license headers to all source files
- Updated CI to use swiftlang action
- Minor markdown and DocC documentation fixes

---

## [1.0.0] - 2025-11-08

### Added

- Initial release of LiquidGlass
- `GlassStyle` view for creating frosted glass backgrounds
- `BackgroundShape` enum with support for rounded rectangles, circles, and capsules
- `.liquidGlass()` view modifier for easy integration
- Custom tint colors with `.tint()` modifier
- Hover effect support for macOS and iPadOS
- Platform 26+ integration with system `glassEffect` API
- Automatic dark mode adaptation
- Multi-colored gradient strokes for enhanced visual depth
- Comprehensive test suite with 18+ tests
- Full API documentation
- Swift Package Manager support

### Features

- ✨ Beautiful frosted glass effects with realistic materials
- 🎨 Customizable color tints
- 🔷 Three built-in shapes (rounded rect, circle, capsule)
- 🖱️ Optional hover interactions
- 🌓 Automatic light/dark mode support
- ⚡ Performance-optimized path generation
- 📦 Lightweight, zero dependencies

---

## Future Releases

### [Unreleased]

- Additional shape support (polygons, custom paths)
- Animation presets for glass transitions
- Accessibility improvements
- More customization options
- Enhanced performance optimizations

---

[1.0.0]: https://github.com/metneo/LiquidGlass/releases/tag/1.0.0
