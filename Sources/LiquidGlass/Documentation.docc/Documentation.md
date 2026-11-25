# ``LiquidGlass``

Fallback support for the Liquid Glass effect on older Apple platforms.

## Overview

LiquidGlass provides the frosted-glass background effect on platforms before Platform 26, where the system's native `glassEffect(in:)` isn't available. It renders with a pure-SwiftUI implementation. The `.liquidGlass` modifier and the built-in component styles automatically switch to the system's native effect on Platform 26+, while the ``LiquidGlass`` view renders the custom look on every version.

![A frosted-glass capsule labeled “Liquid Glass” over a purple-to-pink gradient](LiquidGlass)

The custom fallback look is selected with ``LiquidGlassVersion`` via the `liquidGlassVersion(_:)` modifier (default `.v26`). `.v26` matches the original look, with a diagonal angular-gradient outline. `.v27` uses a dedicated style: a horizontal lens highlight along the top and bottom edges, brightest at the middle of each straight edge and fading smoothly toward the corners before wrapping around them, plus a gray full-outline border. The same edge-highlight falloff drives the SwiftUI, AppKit, and UIKit renderers, so all three platforms fade identically. On Platform 26+ the native effect is used by default; call `forceToCustomLiquidGlass()` to keep the custom renderer everywhere.

While the SwiftUI window is inactive, the custom renderers replace the material treatment with a flat, opaque neutral fill and a hairline border — the treatment inactive system controls use, drawn without transparency so content stacked underneath does not show through.

The same effect is available without SwiftUI through ``LiquidGlassView`` on AppKit (macOS) and UIKit (iOS/tvOS), backed by ``LiquidGlassShape`` and ``LiquidGlassRenderer``. The platform views select the decorative outline with ``LiquidGlassRenderer/Style`` (`.v26` or `.v27`) and render the custom effect on every OS version.

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
    - <doc:AppKitAndUIKit>
}

## Topics

### Essentials

- <doc:GettingStarted>

### View

- ``LiquidGlass``
- ``BackgroundShape``
- ``CustomShape``
- ``LightAngle``
- ``SwiftUICore/View/liquidGlass(shape:opacity:tint:hoverEffect:angle:)``

### Versioning

- ``LiquidGlassVersion``
- ``SwiftUICore/View/liquidGlassVersion(_:)``
- ``SwiftUICore/View/forceToCustomLiquidGlass(_:)``

### Styles

- ``SwiftUI/Button/glassStyleButton(shape:prominent:tint:opacity:)``
- ``GlassToggleStyle``
- ``GlassIconLabel``

### AppKit & UIKit

- <doc:AppKitAndUIKit>
- ``LiquidGlassView``
- ``LiquidGlassShape``
- ``LiquidGlassRenderer``
- ``LiquidGlassRenderer/Style``
