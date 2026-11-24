# Getting Started

Create a glass effect view or use a view modifier.

@Metadata {
    @PageImage(purpose: card, source: "LiquidGlass", alt: "The profile images for a LiquidGlass View.")
}

## Overview

LiquidGlass provides the frosted-glass background effect on older Apple platforms — before Platform 26, where the system's native `glassEffect(in:)` isn't available. It renders with a pure-SwiftUI implementation so your views get the glass look everywhere, and it automatically switches to the system's native effect on Platform 26+.

It supports built-in shapes such as rounded rectangles, circles, and capsules, and allows customization of color tints and opacity. Optional hover effects are available on macOS.

If your UI is built without SwiftUI, the same effect is available as a plain AppKit or UIKit view — see <doc:AppKitAndUIKit>.

### Create a liquid glass view

Create a glass effect view using ``LiquidGlass``:

```swift
import SwiftUI
import LiquidGlass

struct ContentView: View {
    var body: some View {
        LiquidGlass(
            shape: .roundedRect(cornerRadius: 12),
            tintColor: .blue,
            opacity: 0.6
        )
        .frame(width: 200, height: 100)
    }
}
```

> Note: Pass `tintColor` and `opacity` to the initializer — the SwiftUI `.tint(_:)` and `.opacity(_:)` modifiers affect the view's environment and rendering as a whole, not the glass tint or density.

``LiquidGlass`` always uses the custom renderer, on every OS version. The native `glassEffect(in:)` switch applies to the `.liquidGlass(shape:opacity:tint:hoverEffect:angle:)` modifier and the built-in component styles, which use the system effect on Platform 26+ unless you call `forceToCustomLiquidGlass()`.

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

Enable a shape-matched hover fill on macOS. When hovered, a subtle fill provides visual feedback — white in light appearance, `.quinary` in dark.

```swift
Text("Hover Over Me")
    .padding()
    .liquidGlass(shape: .capsule, hoverEffect: true)
```

#### Light angle

The modifier accepts a ``LightAngle`` through its `angle` parameter, but the built-in renderers currently use fixed highlight directions: `.v26` draws a 45° angular-gradient outline, and `.v27` a horizontal lens highlight. The parameter is accepted for API compatibility and does not change the custom fallback look.

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

### Force the custom renderer

On Platform 26+ the native effect is used by default. Call `forceToCustomLiquidGlass()` to always use the custom ``LiquidGlass`` renderer — useful for previewing the fallback look that older platforms get, or for keeping one consistent custom style everywhere:

```swift
ContentView()
    .forceToCustomLiquidGlass()

// Opt back into the native effect where available:
ContentView()
    .forceToCustomLiquidGlass(false)
```

The modifier also applies to glass controls, such as `Button.glassStyleButton(shape:prominent:tint:opacity:)`.

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

### AppKit & UIKit

Use ``LiquidGlassView`` when the UI is built without SwiftUI:

```swift
// macOS
let glass = LiquidGlassView(shape: .roundedRect(cornerRadius: 16))
glass.hoverEffect = true
container.addSubview(glass)

// iOS / tvOS
let glass = LiquidGlassView(shape: .capsule, tint: UIColor.systemBlue.cgColor)
view.addSubview(glass)
```

The platform views paint the same tint wash, highlight, outline, and shadow as the SwiftUI renderer, adapt to light/dark appearance, and expose `frostingOpacity` to tune the frosting's transparency. See <doc:AppKitAndUIKit> for materials, styles, and more.

### Platform behavior

- On **iOS 26+ / macOS 26+**, the SwiftUI glass modifiers render with the system's native `glassEffect(in:)`.
- On **earlier OS versions**, they automatically fall back to the custom SwiftUI implementation — same API, no extra work.
- **`forceToCustomLiquidGlass()`** opts out of the native API on Platform 26+ and always renders the custom ``LiquidGlass`` style.
- The **AppKit and UIKit** views always render the custom effect; they have no native counterpart to switch to. Choose their look with ``LiquidGlassRenderer/Style`` rather than `liquidGlassVersion(_:)`.
