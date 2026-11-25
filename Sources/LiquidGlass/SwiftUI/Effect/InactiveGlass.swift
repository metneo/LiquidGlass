//
//  InactiveGlass.swift
//  LiquidGlass
//

import SwiftUI

/// The flat stand-in both version renderers use while the view's window is
/// inactive.
///
/// A material over a deactivated window loses the contrast that makes the
/// glass read as glass, so the renderers swap the whole effect for the
/// treatment inactive system controls use. Unlike `.quinary`/`.quaternary`,
/// whose translucency lets content stacked underneath show through, this
/// stand-in paints an opaque neutral fill under a hairline border.
///
/// Internal.
struct InactiveGlass: View {
    /// The shape to draw (rounded rect, circle, or capsule).
    let shape: BackgroundShape

    /// Appearance used to pick the neutral fill and border.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape.shape
            .fill(fillColor)
            .overlay {
                shape.shape.stroke(borderColor, lineWidth: 1)
            }
    }

    /// Opaque neutral fill matching the background an inactive window gives
    /// its bordered controls (text fields, the add button): a near-white gray
    /// in light appearance, a slightly lifted dark gray in dark appearance.
    ///
    /// Solid colors — not a material or `.quaternary`/`.quinary` — so the fill
    /// stays opaque and whatever is stacked underneath cannot show through.
    private var fillColor: Color {
        // Light ≈ systemGray6 (#F2F2F2) on a window background; dark ≈
        // systemGray5 (#2C2C2E), which sits just above a dark window.
        colorScheme == .dark ? Color(white: 0.21) : Color(white: 0.94)
    }

    /// Hairline bezel border, just darker (light) or lighter (dark) than the
    /// fill so the shape still reads against the window background.
    private var borderColor: Color {
        // Light ≈ #D1D1D1, dark ≈ systemGray3 (#48484A).
        colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.78)
    }
}

#Preview("InactiveGlass · Light") {
    InactiveGlassPreview()
}

#Preview("InactiveGlass · Dark") {
    InactiveGlassPreview()
        .preferredColorScheme(.dark)
}

/// The three shapes in one stack, for both appearance previews.
private struct InactiveGlassPreview: View {
    var body: some View {
        VStack(spacing: 30) {
            // Rounded rectangle
            InactiveGlass(shape: .roundedRect(cornerRadius: 16))
                .frame(width: 200, height: 100)

            // Circle
            InactiveGlass(shape: .circle)
                .frame(width: 120, height: 120)

            // Capsule
            InactiveGlass(shape: .capsule)
                .frame(width: 180, height: 60)
        }
        .padding(40)
        .background(GlassPreviewBackground())
    }
}
