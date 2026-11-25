# AppKit & UIKit

Render the Liquid Glass effect without SwiftUI.

## Overview

`LiquidGlassView` brings the same frosted-glass design to apps built directly with AppKit (macOS) and UIKit (iOS/tvOS). The view hosts a system material clipped to a ``LiquidGlassShape`` and paints the accent layers — tint wash, highlight, and outline — with ``LiquidGlassRenderer``. No SwiftUI dependency is required.

The platform views always render the custom effect; there is no native `glassEffect(in:)` counterpart to switch to. Both adapt to light and dark appearance automatically, and both are decorative: they never intercept pointer or touch events.

## AppKit

```swift
import AppKit
import LiquidGlass

let glass = LiquidGlassView(shape: .roundedRect(cornerRadius: 16))
glass.tint = NSColor.systemBlue.cgColor
glass.style = .v27          // or .v26
glass.hoverEffect = true    // shape-matched pointer hover
glass.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
container.addSubview(glass)
```

Use the AppKit view as a background behind existing content:

```swift
let glass = container.addLiquidGlassBackground(shape: .capsule)
glass.tint = NSColor.systemIndigo.cgColor
```

### Material and transparency

The AppKit frosting follows an appearance-matched default chosen to match SwiftUI's `.ultraThinMaterial`:

- **Light appearance:** `.headerView`, composited at 65% opacity so the glass stays translucent.
- **Dark appearance:** `.popover`, at full opacity.

Assigning `material` pins a specific `NSVisualEffectView.Material` and restores the automatic opacity. Use `frostingOpacity` to fine-tune the material view's transparency; lower values let more of the backdrop through. Pass `nil` (the default) to follow the appearance-matched value.

```swift
glass.material = .popover       // pins the material
glass.frostingOpacity = 0.6     // optional: lower = more transparent
```

### Hover

Set `hoverEffect` to show a shape-matched fill while the pointer is over the glass. The fill sits behind the frosting: opaque white in light appearance, a faint white wash in dark. Hover is macOS-only, matching the SwiftUI `hoverEffect` option.

## UIKit

```swift
import UIKit
import LiquidGlass

let glass = LiquidGlassView(shape: .capsule, tint: UIColor.systemBlue.cgColor)
glass.style = .v27
glass.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(glass)
// pin the edges with constraints as usual…
```

Or insert it as a background:

```swift
view.addLiquidGlassBackground(shape: .roundedRect(cornerRadius: 16))
```

### Material and transparency

The UIKit view uses `UIBlurEffect.Style.systemUltraThinMaterial` by default, which already matches SwiftUI's `.ultraThinMaterial`. Set `blurStyle` to use a different system material. `frostingOpacity` mirrors the AppKit control: `nil` keeps the material at full opacity, and lower values make the glass more transparent.

```swift
glass.blurStyle = .systemMaterial
glass.frostingOpacity = 0.8
```

## Shapes

``LiquidGlassShape`` mirrors ``BackgroundShape`` with the same three cases:

```swift
LiquidGlassShape.roundedRect(cornerRadius: 16)
LiquidGlassShape.circle
LiquidGlassShape.capsule
```

## Convenience backgrounds

Both platforms provide `addLiquidGlassBackground(shape:tint:opacity:style:...)`, which inserts a `LiquidGlassView` at the back of the receiver's subview stack and returns it for further tuning. The AppKit variant also takes `hoverEffect:`; the UIKit variant takes `frostingOpacity:`.

## Styles

``LiquidGlassRenderer/Style`` selects the decorative outline, matching the SwiftUI target version:

- `.v26` (default) — the original look: a full angular-gradient outline.
- `.v27` — a horizontal lens highlight along the top and bottom edges plus a full-outline gray border.

Set `style` directly on the view; the platform views do not read the SwiftUI `liquidGlassVersion(_:)` environment.

The v27 border is a centered stroke, so its outer half renders just outside the shape; the 2 pt bleed margin around the decoration lets it stay visible without covering the lens highlight.

## Layer model

The platform views share one fixed layer stack with the SwiftUI renderer:

1. System material, clipped to the shape
2. Tint wash (`tint` × 0.2 alpha)
3. Highlight fill (white in light appearance, black in dark)
4. Outline (`.v26` or `.v27`)

The SwiftUI renderer adds a fifth layer — a soft drop shadow behind the composite. The platform views deliberately omit it: they are normally embedded edge-to-edge in a host container, and the container's clipping would cut a shadow drawn outside the view's bounds. Apply elevation on the host container instead:

```swift
let shape = LiquidGlassShape.roundedRect(cornerRadius: 16)

// AppKit (y-up layer coordinates: negative height = shadow below)
container.layer?.shadowColor = NSColor.black.cgColor
container.layer?.shadowRadius = 15
container.layer?.shadowOffset = CGSize(width: 0, height: -6)
container.layer?.shadowOpacity = 0.05
container.layer?.shadowPath = shape.path(in: container.bounds)

// UIKit (y-down layer coordinates: positive height = shadow below)
container.layer.shadowColor = UIColor.black.cgColor
container.layer.shadowRadius = 15
container.layer.shadowOffset = CGSize(width: 0, height: 6)
container.layer.shadowOpacity = 0.05
container.layer.shadowPath = shape.path(in: container.bounds)
```