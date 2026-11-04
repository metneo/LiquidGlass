//
//  LiquidGlassV27.swift
//  LiquidGlass
//

import SwiftUI

/// The Platform 27 glass renderer — a dedicated style.
///
/// Internal. The inner body (material fill, tint wash, highlight, shadow) is
/// identical to ``LiquidGlassV26``; only the decorative border stroke differs:
/// the highlight runs along the straight top/bottom edges only, and the rounded
/// corners are left unstroked, symmetric about the center axis.
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

    /// Respect system color scheme for subtle color adjustments.
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Constants

    private static let strokeLineWidth: CGFloat = 1.2

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

    /// Edge highlight for the straight top and bottom segments: bright (100) at
    /// the middle of the shape, fading to transparent (0) at both corners.
    ///
    /// The outline is split into a left and a right half across the center
    /// vertical axis, each running **100 → 0** from the top-center outward.
    private var lensGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: strokeColor.opacity(0), location: 0),
                .init(color: strokeColor.opacity(0.6), location: 0.2),
                .init(color: strokeColor, location: 0.5),
                .init(color: strokeColor.opacity(0.6), location: 0.8),
                .init(color: strokeColor.opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    var body: some View {
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
            // Decorative stroke: only the straight top and bottom segments get the
            // highlight (bright at the middle, fading to the corners); the rounded
            // corners are left unstroked. A circle keeps a full outline highlight.
            .overlay {
                Group {
                    switch shape {
                    case .roundedRect(let cornerRadius):
                        GeometryReader { _ in
                            HorizontalEdges(cornerRadius: cornerRadius)
                                .strokeBorder(lensGradient, lineWidth: Self.strokeLineWidth)
                        }
                    case .circle:
                        shape
                            .shape
                            .strokeBorder(circleStrokeGradient, lineWidth: Self.strokeLineWidth)
                    case .capsule:
                        GeometryReader { proxy in
                            HorizontalEdges(cornerRadius: proxy.size.height / 2)
                                .strokeBorder(lensGradient, lineWidth: Self.strokeLineWidth)
                        }
                    }
                }
                .blendMode(.plusLighter)
            }
            // Extra gray border: a subtle full-outline rim around the shape
            .overlay {
                shape
                    .shape
                    .stroke(grayBorder, lineWidth: 1)
            }
            .shadow(color: shadowColor, radius: 15, x: 0, y: 6)
    }
}

// MARK: - HorizontalEdges

/// A shape that traces only the straight top and bottom edges of a rounded-rect
/// style outline, skipping the rounded corner arcs.
private struct HorizontalEdges: InsettableShape, Animatable {
    /// Corner radius of the source shape; the straight segments start/end past
    /// this inset so the corners are excluded.
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
        let edgeInset = min(cornerRadius, min(insetRect.width, insetRect.height) / 2)
        let left = insetRect.minX + edgeInset
        let right = insetRect.maxX - edgeInset

        var path = Path()
        // Top edge
        path.move(to: CGPoint(x: left, y: insetRect.minY))
        path.addLine(to: CGPoint(x: right, y: insetRect.minY))
        // Bottom edge
        path.move(to: CGPoint(x: left, y: insetRect.maxY))
        path.addLine(to: CGPoint(x: right, y: insetRect.maxY))
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
