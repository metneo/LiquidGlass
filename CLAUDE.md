# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

LiquidGlass is a SwiftUI library that provides **fallback support for the Liquid Glass effect on older Apple platforms** (before Platform 26). It renders frosted-glass backgrounds with a pure-SwiftUI implementation (materials, gradients, shadows — **no Metal/shaders**) and automatically switches to the system's native `glassEffect(in:)` on Platform 26+.

## Build & Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a specific test file
swift test --filter LiquidGlassTests

# Run tests with verbose output
swift test -v
```

> **Note:** A full `swift build`/`swift test` requires Xcode — the asset catalog (`Sources/LiquidGlass/Resources/Asset.xcassets`) is processed by `actool`, and the `@State`/`#Preview` macros need Xcode's macro plugins (neither ships with CommandLineTools alone). For a quick check without Xcode, type-check with `swiftc -typecheck -parse-as-library -module-name LiquidGlass $(find Sources/LiquidGlass -name '*.swift' -not -path '*Examples*')` plus a temp stub defining `extension Bundle { static let module = Bundle.main }`. Expect zero diagnostics; `#Preview` macro-plugin errors are environmental, not code problems.

## Architecture

LiquidGlass is a SwiftUI library for frosted glass effects. The architecture has several key layers:

### Core Components

- **`LiquidGlass`** - Public view that acts as a **router** — reads the `\.liquidGlassVersion` environment value and delegates to the version-specific renderer (`LiquidGlassV26`/`LiquidGlassV27`)
- **`GlassEffectModifier`** - ViewModifier that applies glass backgrounds. On Platform 26+, uses native `glassEffect(in:)` API; on earlier versions, falls back to the `LiquidGlass` router
- **`BackgroundShape`** - Enum with `roundedRect`, `circle`, and `capsule` cases. Provides path generation and gradient calculations for stroke overlays
- **`CustomShape`** - Animatable, insettable shape conforming to `InsettableShape` and `Animatable`, used internally by `BackgroundShape`
- **`BackgroundShape.shape`** - The single mapping from `BackgroundShape` to its concrete shape; glass views build their effect directly from `shape.shape` instead of repeating a per-case switch
- **`GlassHoverEffect`** - Shared shape-matched macOS hover highlight used by all glass modifiers

### Extension Layer

- **`View+LiquidGlass`** - Provides the `.liquidGlass(shape:opacity:tint:hoverEffect:angle:)` view modifier convenience API
- **`Color`** - Defines module-scoped colors: `highlight`, `shadow`, `stroke` (loaded from asset catalog)

### Version Selection

- **`LiquidGlassVersion`** (`View/Supporting/LiquidGlassVersion.swift`) selects the target Apple platform: `.v26` (default), `.v27` (future). The `\.liquidGlassVersion` environment value is **internal**; the public way to set it is the ``SwiftUICore/View/liquidGlassVersion(_:)`` modifier (on any `View`).
- Set the version with `.liquidGlassVersion(.v27)` on any view — app-wide at a root view, or per-view. The `LiquidGlass` router and `GlassEffectModifier` read it from the environment.
- **`LiquidGlass`** (`View/Effect/LiquidGlass.swift`) is a **router**: it reads the `\.liquidGlassVersion` environment value and routes to the version-specific renderer. It carries `shape`/`tintColor`/`opacity`/`lightAngle`.
- **`LiquidGlassV26`** / **`LiquidGlassV27`** (`View/Effect/`) are the internal per-version **renderers** — they own the actual rendering (`applyEffect`: material fill, highlight, border stroke, shadow). v26 = the current look (45° diagonal highlight); v27 = a dedicated style (darker border, 0° horizontal highlight). Keep per-version tuning inside each.
- `GlassEffectModifier` renders the native `glassEffect(in:)` on Platform 26+ and falls back to the custom `LiquidGlass` router below it (the router picks `LiquidGlassV26`/`LiquidGlassV27` from the environment version). There is no shader/Metal code — all effects are built from materials, gradients, and shadows.

### Styles (`View/Control/`)

- **`GlassButtonStyle`** / **`GlassButtonMidifier`** - Custom glass button rendering, exposed via `Button.glassStyleButton(shape:prominent:tint:opacity:)` (system `.glass`/`.glassProminent` on Platform 26+, `LiquidGlass`-backed fallback on older platforms)
- **`GlassToggleStyle`** - Animated glass toggle style with `.height/.padding/.tint/.glassOpacity` customization
- **`GlassIconLabel`** - Glass circular icon label style with `.tint/.iconFont/.iconTint/.iconOnly` customization

### Color Assets

Three color sets in `Sources/LiquidGlass/Resources/Asset.xcassets/`:
- `highlightColor` - Brightness effects
- `shadowColor` - Depth/elevation effects  
- `strokeColor` - Edge highlighting

These adapt automatically to light/dark appearance via asset catalog configuration.

### Platform Handling

```swift
@ViewBuilder
private func renderGlassEffect(content: Content) -> some View {
    if #available(anyAppleOS 26.0, *) {          // the single modifier
        content.glassEffect(in: shape).tint(tint)  // native glassEffect(in:) API
    } else {
        content.background { LiquidGlass(shape: shape, tintColor: tint, lightAngle: lightAngle) }
    }
}
```

- Platform 26 = iOS 26 / macOS 26. `GlassEffectModifier` gates on `anyAppleOS 26.0` and always prefers the native API on 26+; below that it falls back to the `LiquidGlass` router (which picks V26/V27 from the `\.liquidGlassVersion` environment).
- Keep the native-`glassEffect`/custom-fallback pattern when adding new modifiers.
