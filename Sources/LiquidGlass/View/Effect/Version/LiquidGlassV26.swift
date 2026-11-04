//
//  LiquidGlassV26.swift
//  LiquidGlass
//

import SwiftUI

/// The Platform 26 glass renderer — the original `LiquidGlass` look.
///
/// Internal. Owns the shared rendering implementation (material fill, gradient
/// highlight, border stroke, soft shadow) used below Platform 26 for `.v26`
/// targets. Tune the v26 visuals here.
///
/// Note: `lightAngle` is accepted (to match the shared renderer signature) but
/// ignored by this renderer, which uses its own angular-gradient strokes.
struct LiquidGlassV26: View {
    // MARK: - Stored properties

    /// Optional tint color. If not provided, `.clear` is used (the effect
    /// becomes a neutral wash tinted by the highlight/stroke colors).
    private let tintColor: Color?

    /// Underlying shape to style (rounded rect, capsule, or circle)
    private let shape: BackgroundShape

    /// The opacity level for the glass effect (default: 0.6).
    /// Higher values make the glass more opaque, lower values more transparent.
    private let opacity: CGFloat

    /// Accepted for the shared renderer signature but ignored by v26's look.
    private let lightAngle: LightAngle

    /// Respect system color scheme for subtle color adjustments.
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initializer

    init(
        shape: BackgroundShape,
        tintColor: Color? = nil,
        opacity: CGFloat = LiquidGlass.defaultOpacity,
        lightAngle: LightAngle = LiquidGlass.defaultLightAngle
    ) {
        self.shape = shape
        self.tintColor = tintColor
        self.opacity = opacity
        self.lightAngle = lightAngle
    }

    // MARK: - Computed colors

    /// Effective base color (tint or accent)
    private var color: Color {
        tintColor ?? .clear
    }

    /// Slight bright/dark highlight depending on environment
    private var highlightColor: Color {
        colorScheme == .dark ? .black.opacity(0.7 * 0.6 * opacity) : .white.opacity(1.0 * opacity)
    }

    /// Shadow color tuned for light/dark modes
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.1) : .black.opacity(0.05)
    }

    /// Stroke base color (thin white-ish strokes in either mode)
    private var strokeColor: Color {
        tintColor?.opacity(0.3) ??
        (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
    }

    // MARK: - Gradients and styles

    /// Very subtle tint overlay to give the glass a hint of color.
    private var tintGradient: some ShapeStyle {
        color.opacity(0.2)
    }

    /// A simple highlight color (keeps the shape bright at the top area).
    private var highlightGradient: some ShapeStyle {
        highlightColor.opacity(0.75)
    }

    /// Slight multi-stop gradient used for some stroke decorations.
    private var strokeGradient1: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                strokeColor.opacity(0.5),
                strokeColor.opacity(0.2),
                strokeColor.opacity(0.4)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Opacity constants used across stroke gradients (consistent Double type)
    private let highOpacity: Double = 0.7
    private let lowOpacity: Double = 0.1

    // MARK: - Body

    private func gradient(startAngle: CGFloat, mid1: CGFloat, mid2: CGFloat) -> AngularGradient {
        let highStroke = strokeColor.opacity(highOpacity)
        let lowStroke = strokeColor.opacity(lowOpacity)

        return AngularGradient(
            stops: [
                .init(color: highStroke, location: 0),
                .init(color: lowStroke, location: mid1),
                .init(color: highStroke, location: 0.5),
                .init(color: lowStroke, location: mid2),
                .init(color: highStroke, location: 1)
            ],
            center: .center,
            angle: .radians(startAngle)
        )
    }

    public var body: some View {
        // Base fill: use a system material to provide the frosted effect, then layer other accents on top.
        shape
            .shape
            .fill(.ultraThinMaterial)
            // Tint overlay: soft colored wash
            .overlay {
                shape.shape.fill(tintGradient)
            }
            // Highlight: adds a faint brightening to the shape
            .overlay {
                shape.shape.fill(highlightGradient)
            }
            // Decorative strokes: vary by shape to match edges
            .overlay {
                Group {
                    switch shape {
                    case .roundedRect(let cornerRadius):
                        GeometryReader { proxy in
                            shape
                                .shape
                                .stroke(
                                    calculatedGradient(proxy: proxy, radius: cornerRadius)
                                )
                        }
                    case .circle:
                        // Single stroke gradient for circle
                        shape.shape
                            .stroke(
                                gradient(startAngle: .pi + .pi / 4, mid1: 0.25, mid2: 0.75)
                            )
                    case .capsule:
                        GeometryReader { proxy in
                            let radius = proxy.size.height / 2
                            shape
                                .shape
                                .stroke(
                                    calculatedGradient(proxy: proxy, radius: radius)
                                )
                        }
                    }
                }
                .blendMode(.plusLighter)
            }
            .shadow(color: shadowColor, radius: 15, x: 0, y: 6)
    }

    private func calculatedGradient(proxy: GeometryProxy, radius: CGFloat) -> AngularGradient {
        let halfWidth = proxy.size.width / 2
        let halfHeight = proxy.size.height / 2
        let horizontalGap = halfWidth - radius
        let verticalGap = halfHeight - radius
        let sqrt2 = sqrt(2)

        let cornerDistance = sqrt2 * verticalGap + radius
        let gapDifference = horizontalGap - verticalGap
        let t1 = sqrt2 * cornerDistance
        let t2 = cornerDistance * cornerDistance + gapDifference * gapDifference + sqrt2 * cornerDistance * gapDifference
        let alpha = asin(t1 / (2 * sqrt(t2)))

        let startAngle = CGFloat.pi + alpha
        let mid = (CGFloat.pi - 2 * alpha) / (2 * CGFloat.pi)
        let mid2 = 0.5 + mid // Symmetric

        return gradient(startAngle: startAngle, mid1: mid, mid2: mid2)
    }
}

// MARK: - Preview

#Preview("LiquidGlass V26") {
    VStack(spacing: 30) {
        // Rounded rectangle with blue tint
        LiquidGlassV26(shape: .roundedRect(cornerRadius: 16))
            .frame(width: 200, height: 100)

        // Circle with pink tint
        LiquidGlassV26(shape: .circle)
            .frame(width: 120, height: 120)

        // Capsule with green tint
        LiquidGlassV26(shape: .capsule)
            .frame(width: 180, height: 60)
    }
    .padding(40)
    .background(GlassPreviewBackground())
}
