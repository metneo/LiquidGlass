//
//  LiquidGlassV27.swift
//  LiquidGlass
//

import SwiftUI

/// The Platform 27 glass renderer — a dedicated style.
///
/// Internal. The inner body (material fill, tint wash, highlight, shadow) is
/// identical to ``LiquidGlassV26``; only the decorative border stroke differs:
/// the highlight runs along the top and bottom edges, including the rounded
/// corner arcs, and fades from the middle of each edge toward the corners. A
/// gray full-outline border frames the shape.
struct LiquidGlassV27: View {
    // MARK: - Stored properties

    /// Optional tint color. If not provided, `.clear` is used (the effect
    /// becomes a neutral wash tinted by the highlight/stroke colors).
    private let tintColor: Color?

    /// Underlying shape to style (rounded rect, capsule, or circle)
    private let shape: BackgroundShape

    /// The opacity level for the glass effect (default: 0.6).
    /// Higher values make the glass more opaque, lower values more transparent.
    private let opacity: CGFloat

    /// Accepted for the shared renderer signature but ignored by this renderer.
    private let lightAngle: LightAngle

    /// Fullness exponent of this instance's edge-highlight falloff; higher
    /// values make the highlight fatter. Defaults to ``StrokeFalloff/power``.
    private let falloffPower: Double

    /// Respect system color scheme for subtle color adjustments.
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(\.appearsActive) private var appearsActive

    // MARK: - Constants

    private static let strokeLineWidth: CGFloat = 1.2

    // MARK: - Initializer

    init(
        shape: BackgroundShape,
        tintColor: Color? = nil,
        opacity: CGFloat = LiquidGlass.defaultOpacity,
        lightAngle: LightAngle = LiquidGlass.defaultLightAngle,
        falloffPower: Double = StrokeFalloff.power
    ) {
        self.shape = shape
        self.tintColor = tintColor
        self.opacity = opacity
        self.lightAngle = lightAngle
        self.falloffPower = falloffPower
    }

    // MARK: - Computed colors (shared with v26)

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
        (colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
    }

    /// Subtle gray full-outline border color.
    private var grayBorder: Color {
        Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.2)
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

    /// Edge highlight for the straight top and bottom segments: bright at the
    /// middle of the shape, fading toward both corners.
    ///
    /// The curve itself lives in ``StrokeFalloff``, so the SwiftUI, AppKit, and
    /// UIKit renderers all fade identically. The rounded corner arcs hold the
    /// opacity they have where they leave the straight edge, so the stroke
    /// wraps the corner instead of fading out inside it.
    private func lensGradient(cornerRadius: CGFloat, size: CGSize) -> LinearGradient {
        let radius = min(cornerRadius, min(size.width, size.height) / 2)
        let stops = StrokeFalloff.sampledAlphas(
            power: falloffPower,
            cornerFraction: size.width > 0 ? Double(radius / size.width) : 0
        ).map { sample in
            Gradient.Stop(color: strokeColor.opacity(sample.alpha), location: sample.location)
        }

        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    /// Full-outline highlight for circles (no straight edges): bright at the top
    /// and bottom, transparent at the sides.
    private var circleStrokeGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: strokeColor, location: 0),
                .init(color: strokeColor.opacity(0), location: 0.5),
                .init(color: strokeColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Body

    /// Switches between the glass treatment and a flat inactive stand-in based
    /// on whether the view's window is active.
    @ViewBuilder
    var body: some View {
        if appearsActive {
            activeGlass
        } else {
            InactiveGlass(shape: shape)
        }
    }

    /// The full glass treatment, shown while the view's window is active.
    private var activeGlass: some View {
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
            // Decorative stroke: the top and bottom edges get the highlight
            // (bright at the middle, fading around the rounded corners). A circle
            // keeps a full outline highlight.
            .overlay {
                Group {
                    switch shape {
                    case .roundedRect(let cornerRadius):
                        GeometryReader { proxy in
                            HorizontalEdges(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    lensGradient(cornerRadius: cornerRadius, size: proxy.size),
                                    lineWidth: Self.strokeLineWidth
                                )
                        }
                    case .circle:
                        shape
                            .shape
                            .strokeBorder(circleStrokeGradient, lineWidth: Self.strokeLineWidth)
                    case .capsule:
                        GeometryReader { proxy in
                            HorizontalEdges(cornerRadius: proxy.size.height / 2)
                                .strokeBorder(
                                    lensGradient(
                                        cornerRadius: proxy.size.height / 2,
                                        size: proxy.size
                                    ),
                                    lineWidth: Self.strokeLineWidth
                                )
                        }
                    }
                }
                .blendMode(.plusLighter)
            }
            .overlay {
                shape
                    .shape
                    .stroke(grayBorder, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: 15, x: 0, y: 6)
    }
}

// MARK: - HorizontalEdges

/// A shape that traces the top and bottom edges of a rounded-rect style
/// outline, including the rounded corner arcs so the highlight extends to the
/// corners and fades around them.
private struct HorizontalEdges: InsettableShape, Animatable {
    /// Corner radius of the source shape; the straight segments start/end past
    /// this inset so the corners are rounded.
    var cornerRadius: CGFloat
    private var insetAmount: CGFloat = 0

    /// Explicit initializer: the `private` stored property above would otherwise
    /// pull the synthesized memberwise init down to `private`, making it
    /// inaccessible from the glass renderer in this file (a Swift-version-sensitive
    /// rule). Declaring the init keeps it accessible across toolchains.
    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let r = min(cornerRadius, min(insetRect.width, insetRect.height) / 2)
        let x0 = insetRect.minX
        let y0 = insetRect.minY
        let width = insetRect.width
        let height = insetRect.height

        // Corner arc centers.
        let topLeft = CGPoint(x: x0 + r, y: y0 + r)
        let topRight = CGPoint(x: x0 + width - r, y: y0 + r)
        let bottomLeft = CGPoint(x: x0 + r, y: y0 + height - r)
        let bottomRight = CGPoint(x: x0 + width - r, y: y0 + height - r)

        var path = Path()

        // Top outline, traced left → right. Each corner arc starts from its own
        // corner start point (the tangent where the arc leaves the adjacent
        // vertical side) and sweeps 90° up onto the top edge.
        path.move(to: CGPoint(x: x0, y: y0 + r))                    // top-left corner start point
        path.addArc(center: topLeft, radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(270),
                    clockwise: false)
        path.addLine(to: CGPoint(x: x0 + width - r, y: y0))         // top edge
        path.addArc(center: topRight, radius: r,
                    startAngle: .degrees(270), endAngle: .degrees(0),
                    clockwise: false)

        // Bottom outline, the mirror image of the top, traced right → left so
        // each corner arc likewise starts from its own corner start point.
        path.move(to: CGPoint(x: x0 + width, y: y0 + height - r))   // bottom-right corner start point
        path.addArc(center: bottomRight, radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: x0 + r, y: y0 + height))        // bottom edge
        path.addArc(center: bottomLeft, radius: r,
                    startAngle: .degrees(90), endAngle: .degrees(180),
                    clockwise: false)

        return path
    }
}

// MARK: - Preview

#Preview("LiquidGlass V27") {
    VStack(spacing: 30) {
        // Rounded rectangle with blue tint
        LiquidGlassV27(shape: .roundedRect(cornerRadius: 16))
            .frame(width: 200, height: 100)

        // Circle with pink tint
        LiquidGlassV27(shape: .circle)
            .frame(width: 120, height: 120)

        // Capsule with green tint
        LiquidGlassV27(shape: .capsule)
            .frame(width: 180, height: 60)
    }
    .padding(40)
    .background(GlassPreviewBackground())
}


/// The curve above the glass samples that use it, so the two can be compared.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
private struct StrokeFalloffPreview: View {
    /// Fullness exponent being previewed; starts at the renderer's default.
    @State private var power = StrokeFalloff.power

    private let glassWidth: CGFloat = 340
    private let cornerRadius: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LiquidGlassV27(shape: .roundedRect(cornerRadius: cornerRadius), falloffPower: power)
                .frame(width: glassWidth, height: 88)

            LiquidGlassV27(shape: .capsule, falloffPower: power)
                .frame(width: glassWidth, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("Edge highlight falloff")
                    .font(.headline)
                Text("opacity(t) = b·(1 − |2t − 1|^p)   ·   b = \(StrokeFalloff.peak, specifier: "%.2f")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                Text("p")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Slider(value: $power, in: 1.0...8.0)
                Text("\(power, specifier: "%.1f")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .trailing)
            }

            StrokeFalloffChart(
                power: power,
                cornerFraction: Double(cornerRadius / glassWidth)
            )

            Text("Curve is pinned to 0 at the edges; the corner arcs (dots at the ends) hold the tangent opacity.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 388)
        .background(GlassPreviewBackground())
    }
}

#Preview("LiquidGlass V27 · Edge Highlight Falloff") {
    // Swift Charts needs macOS 13 / iOS 16; the package deploys below that.
    if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
        StrokeFalloffPreview()
    } else {
        Text("Requires macOS 13 / iOS 16")
    }
}
