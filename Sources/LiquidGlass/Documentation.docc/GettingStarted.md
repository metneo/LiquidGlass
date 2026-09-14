# Getting Started

Create a glass effect view or use a view modifier.

@Metadata {
    @PageImage(purpose: card, source: "LiquidGlass", alt: "The profile images for a LiquidGlass View.")
}

## Overview

LiquidGlass provides the frosted-glass background effect on older Apple platforms — before Platform 26, where the system's native `glassEffect(in:)` isn't available. It renders with a pure-SwiftUI implementation so your views get the glass look everywhere, and it automatically switches to the system's native effect on Platform 26+.

It supports built-in shapes such as rounded rectangles, circles, and capsules, and allows customization of color tints, opacity, and light angle. Optional hover effects are available on macOS.

### Create a liquid glass view

Create a glass effect view using ``LiquidGlass``:

```swift
import SwiftUI
import LiquidGlass

struct ContentView: View {
    var body: some View {
        LiquidGlass(shape: .roundedRect(cornerRadius: 12))
            .tint(Color.blue)
            .opacity(0.6)
            .frame(width: 200, height: 100)
    }
}
```

### Apply the glass effect

For convenience, add a glass effect to a SwiftUI view using the ``SwiftUICore/View/liquidGlass(shape:opacity:tint:hoverEffect:angle:)`` modifier:

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

#### Shape

```swift
Text("Rounded Rectangle")
    .padding(20)
    .liquidGlass(shape: .roundedRect(cornerRadius: 16))

Text("Circle")
    .padding(20)
    .liquidGlass(shape: .circle)

Text("Capsule")
    .padding(.horizontal, 30)
    .padding(.vertical, 15)
    .liquidGlass(shape: .capsule)
```

![Apply the glass effect to three different shapes: Rounded Rectangle, Circle and Capsule](LiquidGlassShape)

#### Opacity

```swift
Text("Colored Glass")
    .padding(20)
    .liquidGlass(shape: .capsule, opacity: 0.5)
```

#### Tint

```swift
Text("Tinted Glass")
    .padding(20)
    .liquidGlass(shape: .capsule, tint: .blue)
```

#### Hover Effect

Enable a shape-matched hover fill on macOS. When hovered, a subtle quaternary fill provides visual feedback.

```swift
Text("Hover Over Me")
    .padding()
    .liquidGlass(shape: .capsule, hoverEffect: true)
```

### Target a platform version

The glass effect targets an Apple platform version via the `liquidGlassVersion(_:)` modifier (default `.v26`):

```swift
// App-wide: native glass on iOS 26+ / macOS 26+, custom fallback below
ContentView()
    .liquidGlassVersion(.v26)

// Per-view
LiquidGlass(shape: .roundedRect(cornerRadius: 14))
    .liquidGlassVersion(.v27)
```

On **Platform 26+** the effect uses the system's native `glassEffect(in:)`. Below Platform 26 it falls back to the custom SwiftUI renderer, whose look depends on the target version: `.v26` (default) matches the original look, `.v27` uses a dedicated style.

### Component styles

Ready-made styles for common components:

```swift
Button("Primary") { /* action */ }
    .glassStyleButton(shape: .capsule, prominent: true, tint: .blue)

Toggle("Wi-Fi", systemImage: "wifi", isOn: $isOn)
    .toggleStyle(GlassToggleStyle().tint(.blue))

Label("Settings", systemImage: "gear")
    .labelStyle(GlassIconLabel(size: 32).tint(.blue).iconFont(.title2))
```

### Platform behavior

- On **iOS 26+ / macOS 26+**, the glass modifiers render with the system's native `glassEffect(in:)`.
- On **earlier OS versions**, they automatically fall back to the custom SwiftUI implementation — same API, no extra work.
