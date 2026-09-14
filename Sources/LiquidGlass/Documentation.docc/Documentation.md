# ``LiquidGlass``

Fallback support for the Liquid Glass effect on older Apple platforms.

## Overview

LiquidGlass provides the frosted-glass background effect on platforms before Platform 26, where the system's native `glassEffect(in:)` isn't available. It renders with a pure-SwiftUI implementation and automatically switches to the system's native effect on Platform 26+.

The custom fallback look is selected with ``LiquidGlassVersion`` via the ``liquidGlassVersion(_:)`` modifier (default `.v26`): `.v26` matches the original look, `.v27` a dedicated style (darker border, horizontal highlight).

@Links(visualStyle: detailedGrid) {
    - <doc:GettingStarted>
}

## Topics

### Essentials

- <doc:GettingStarted>

### View

- ``LiquidGlass``
- ``BackgroundShape``
- ``CustomShape``
- ``LightAngle``
- ``SwiftUICore/View/liquidGlassVersion(_:)``
- ``SwiftUICore/View/liquidGlass(shape:opacity:tint:hoverEffect:angle:)``

### Styles

- ``GlassToggleStyle``
- ``GlassIconLabel``
