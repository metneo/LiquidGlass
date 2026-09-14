---
name: liquidglass
description: Fallback support for the Liquid Glass effect on older Apple platforms (before Platform 26) — when the system's native glassEffect(in:) is unavailable, apply frosted-glass backgrounds with .liquidGlass(), pick shapes, tint, opacity, light angle, and macOS hover, and target an Apple platform version via the liquidGlassVersion(_:) modifier. Use when writing SwiftUI code that needs glass effects.
---

# Using LiquidGlass in Your App

LiquidGlass provides the frosted-glass background effect on older Apple platforms — before Platform 26, where the system's native `glassEffect(in:)` isn't available. It renders with a pure-SwiftUI implementation so your views get the glass look everywhere, and it automatically switches to the system's native effect on Platform 26+.

The library provides version-targeted glass looks (v26 / v27) and several ready-made component styles.

## Add the dependency

In Xcode: **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/metneo/LiquidGlass.git
```

Or add it to a `Package.swift`:

```swift
.package(url: "https://github.com/metneo/LiquidGlass.git", from: "1.0.0")
```

Then import it wherever you use it:

```swift
import LiquidGlass
```

Supported platforms: **iOS 16+**, **macOS 12+**, **tvOS 16+**, **watchOS 9+**.

## Quick start

The main entry point is the `.liquidGlass(shape:)` modifier — attach it to any view and it renders a frosted-glass background behind your content:

```swift
import SwiftUI
import LiquidGlass

struct PurchaseButton: View {
    var body: some View {
        Button("Buy Now") { /* action */ }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .liquidGlass(shape: .capsule)
    }
}
```

> **Tip:** glass needs something behind it to blur. Put a colorful gradient or image underneath the glass (e.g. a `ZStack` with a `LinearGradient`), otherwise the effect will look flat.

## Choose a shape

`BackgroundShape` controls the shape of the glass:

```swift
.liquidGlass(shape: .roundedRect(cornerRadius: 16))
.liquidGlass(shape: .circle)
.liquidGlass(shape: .capsule)
```

## Target a platform version

On Platform 26+ the effect is always the system's native `glassEffect(in:)`. Below Platform 26, the `liquidGlassVersion(_:)` modifier (default `.v26`) picks the **custom fallback look**:

```swift
// App-wide: use the v27 custom fallback look below Platform 26
ContentView()
    .liquidGlassVersion(.v27)

// Per-view
LiquidGlass(shape: .roundedRect(cornerRadius: 14))
    .liquidGlassVersion(.v27)
```

`.v26` matches the original look (45° diagonal highlight); `.v27` is a dedicated style (darker border, 0° horizontal highlight).

## Customize the effect

```swift
.liquidGlass(
    shape: .capsule,
    opacity: 0.7,          // 0–1, how opaque/dense the glass is
    tint: .blue,           // optional accent color wash
    hoverEffect: true,     // subtle fill on pointer hover (macOS only)
    angle: .topLeading     // direction of the highlight
)
```

- **`opacity`** — density of the glass (default `0.6`). Higher = more opaque.
- **`tint`** — optional color cast; `nil` uses the library's built-in highlight color.
- **`hoverEffect`** — macOS only; adds a shape-matched fill while the pointer hovers.
- **`angle`** — a `LightAngle`: `.topLeading` (default), `.bottomTrailing`, `.none`, `.all`.

You can also build a glass view directly when you need it as a background or inside a `ZStack`:

```swift
LiquidGlass(shape: .circle)
    .tint(.orange)
    .opacity(0.8)
    .frame(width: 80, height: 80)
```

## Ready-made component styles

### Glass button

```swift
Button("Primary") { /* action */ }
    .glassStyleButton(shape: .capsule, prominent: true, tint: .blue)
```

On iOS 26+ / macOS 26+ this uses the system `.glass` / `.glassProminent` button styles; on older OS versions it falls back to a custom `LiquidGlass`-backed button.

### Glass toggle

```swift
Toggle("Wi-Fi", systemImage: "wifi", isOn: $isOn)
    .toggleStyle(GlassToggleStyle().tint(.blue))
```

### Glass icon label

```swift
Label("Settings", systemImage: "gear")
    .labelStyle(GlassIconLabel(size: 32).tint(.blue).iconFont(.title2))
```

## Platform behavior

- On **Platform 26+** (iOS 26+ / macOS 26+), `.liquidGlass` renders with the system's native `glassEffect(in:)`.
- On **earlier OS versions** it automatically falls back to the custom SwiftUI implementation, whose look is chosen by the `liquidGlassVersion(_:)` modifier (`.v26` default, `.v27` dedicated) — same API, no extra work on your side.

## Troubleshooting

- **The glass looks invisible / flat** — there's nothing behind it to blur. Layer it over a gradient, image, or busy content.
- **Hover effect does nothing** — `hoverEffect` is macOS-only; it's ignored on iOS/tvOS/watchOS.
- **Native or custom?** Native `glassEffect(in:)` is always used on Platform 26+. Below that, the `liquidGlassVersion(_:)` modifier (default `.v26`) picks the custom fallback look (`.v27` for the dedicated style).
