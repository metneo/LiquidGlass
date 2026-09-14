# LiquidGlass

Fallback support for the Liquid Glass effect on older Apple platforms.

Apple introduced the native `glassEffect(in:)` API on **Platform 26+** (iOS 26 / macOS 26). LiquidGlass gives your SwiftUI views the same frosted-glass look on **older platforms** — before Platform 26 — via a pure-SwiftUI implementation. On Platform 26+ it automatically switches to the system's native effect, so the same API works everywhere.

![Liquid Glass Preview](Sources/LiquidGlass/Documentation.docc/Resources/LiquidGlass.png)

## Features

- Frosted-glass backgrounds with highlights, shadows, and edge lighting
- Built-in shapes: rounded rectangle, circle, capsule
- Customizable color tints, opacity, and light angle
- Optional shape-matched hover effects (macOS)
- Ready-made glass button, toggle, and icon label styles
- Automatic use of the system `glassEffect(in:)` API on Platform 26+; pure-SwiftUI fallback on older platforms
- Minimal dependencies, dark mode support

## Requirements

- iOS 16.0+ / macOS 12.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 5.9+ (Xcode 15.0+)

## Installation

### Swift Package Manager

Add LiquidGlass to your project using Xcode:

1. File > Add Package Dependencies...
2. Enter the repository URL:

   ```text
   https://github.com/metneo/LiquidGlass.git
   ```

3. Select the version or branch you want to use
4. Click "Add Package"

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/metneo/LiquidGlass.git", from: "1.0.0")
]
```

Then add `LiquidGlass` to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["LiquidGlass"]
    )
]
```

## Quick Start

Import LiquidGlass and apply the glass effect to any SwiftUI view:

```swift
import SwiftUI
import LiquidGlass

struct ContentView: View {
    var body: some View {
        Text("Hello, Glass!")
            .padding()
            .liquidGlass(shape: .roundedRect(cornerRadius: 16))
    }
}
```

> **Tip:** glass needs something behind it to blur. Layer the glass over a gradient, image, or busy content, or the effect will look flat.

### Target a platform version

On Platform 26+ the effect is always the system's native `glassEffect(in:)`. Below Platform 26, the `liquidGlassVersion(_:)` modifier (default `.v26`) picks the **custom fallback look**:

```swift
// App-wide: use the v27 custom fallback look below Platform 26
ContentView()
    .liquidGlassVersion(.v27)

// Per-view: on a LiquidGlass view
LiquidGlass(shape: .roundedRect(cornerRadius: 14))
    .liquidGlassVersion(.v27)
```

`.v26` matches the original look (45° diagonal highlight); `.v27` is a dedicated style (darker border, 0° horizontal highlight).

### Shapes, tint, opacity, hover

```swift
.liquidGlass(shape: .roundedRect(cornerRadius: 16))
.liquidGlass(shape: .circle)
.liquidGlass(shape: .capsule)

.liquidGlass(
    shape: .capsule,
    opacity: 0.7,          // 0–1, density of the glass (default 0.6)
    tint: .blue,           // optional color cast
    hoverEffect: true,     // shape-matched hover fill (macOS only)
    angle: .topLeading     // LightAngle: .topLeading, .bottomTrailing, .none, .all
)
```

### Using the glass view directly

```swift
VStack {
    Text("Custom Glass")
        .padding()
}
.background(
    LiquidGlass(shape: .roundedRect(cornerRadius: 20))
        .tint(.purple)
)
```

## Component Styles

### Glass button

```swift
Button("Primary") { /* action */ }
    .glassStyleButton(shape: .capsule, prominent: true, tint: .blue)
```

Uses the system `.glass` / `.glassProminent` button styles on Platform 26+, and falls back to a custom `LiquidGlass`-backed button on older platforms.

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

## Platform Behavior

- On **Platform 26+** (iOS 26+ / macOS 26+), `.liquidGlass` renders with the system's native `glassEffect(in:)`.
- On **earlier OS versions**, it automatically falls back to the custom SwiftUI implementation, whose look is chosen by the `liquidGlassVersion(_:)` modifier (`.v26` default, `.v27` dedicated) — same API, no extra work on your side.

## Color Scheme Adaptation

LiquidGlass automatically adapts to light and dark color schemes:

![Light Mode](Sources/LiquidGlass/Documentation.docc/Resources/LiquidGlassShape.png) ![Dark Mode](Sources/LiquidGlass/Documentation.docc/Resources/LiquidGlassShape~dark.png)

## Documentation

Full API documentation is available via Swift DocC. See the [Getting Started](Sources/LiquidGlass/Documentation.docc/GettingStarted.md) for details and advanced usage.

## Architecture

- **`BackgroundShape`** – Enum defining available shapes (`roundedRect`, `circle`, `capsule`) with optimized path generation
- **`LiquidGlass`** – Core view that renders the glass effect with materials and gradients
- **`GlassEffectModifier`** – ViewModifier with Platform 26+ native support and custom fallback
- **`LiquidGlassVersion`** – Target platform selector, configurable via the `.liquidGlassVersion(_:)` view modifier
- **`View+LiquidGlass`** – Convenient view modifier extension (`.liquidGlass`)
- **`GlassToggleStyle` / `GlassIconLabel`** – Ready-made toggle and icon label styles

## Contributing

Contributions are welcome! Please submit a Pull Request or open an issue to discuss major changes.

## License

LiquidGlass is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
