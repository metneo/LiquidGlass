//
//  LiquidGlassRenderer.swift
//  LiquidGlass
//
//  Quartz-only drawing for the Liquid Glass look, shared by the AppKit and
//  UIKit host views. No SwiftUI.
//

import CoreGraphics
import Foundation

#if canImport(CoreGraphics)

/// One color + location pair of an angular or linear gradient.
/// Mirrors SwiftUI's `Gradient.Stop` without importing SwiftUI.
struct GradientStop {
    /// The color at this stop.
    var color: CGColor
    /// Normalized location along the gradient (0…1).
    var location: CGFloat
}

/// Quartz-only renderer for the Liquid Glass effect.
///
/// Re-implements the drawing performed by the SwiftUI v26/v27 renderers —
/// tint wash, highlight fill, decorative outline strokes and full-outline border —
/// using nothing but Core Graphics. The frosted backdrop is *not* drawn here:
/// the host ``LiquidGlassView`` (AppKit or UIKit) owns a system material/blur
/// view clipped to the shape, and this renderer paints the accent layers on
/// top of it.
///
/// Coordinate convention: Core Graphics “y up” with the origin at the
/// bottom-left of the drawing rectangle. Both host views normalize their
/// context to that convention before calling ``draw(in:size:)``.
public struct LiquidGlassRenderer {
    /// Which decorative outline style to render.
    public enum Style: Equatable, Sendable {
        /// Platform 26 look: full angular-gradient outline.
        case v26
        /// Platform 27 look: horizontal lens highlight plus gray border.
        case v27
    }

    // MARK: - Configuration

    /// The glass backing shape.
    public var shape: LiquidGlassShape
    /// Optional tint color. When `nil` the highlight/wash stay neutral.
    public var tint: CGColor?
    /// Gloss intensity of the highlight (0…1).
    public var opacity: CGFloat
    /// Decorative outline style.
    public var style: Style
    /// Whether the dark appearance palette should be used.
    public var isDark: Bool

    // MARK: - Initializer

    public init(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: Style = .v26,
        isDark: Bool = false
    ) {
        self.shape = shape
        self.tint = tint
        self.opacity = opacity
        self.style = style
        self.isDark = isDark
    }

    // MARK: - Public API

    /// Draws the entire glass effect into `context`, covering `size`.
    ///
    /// The caller is responsible for a context whose user space uses the
    /// renderer's “y up” convention and already lets the shape's frosted
    /// backdrop show through beneath (typically an `NSVisualEffectView` on
    /// macOS or a `UIVisualEffectView` on iOS/tvOS).
    ///
    /// - Parameter shapeRect: The rectangle the glass shape occupies within
    ///   `context`, in points. Pass a rect inset from the drawable bounds to
    ///   leave a bleed margin around the shape, so centered strokes can render
    ///   their outer half (as SwiftUI's unclipped strokes do). Defaults to the
    ///   full `size`.
    public func draw(in context: CGContext, size: CGSize, shapeRect: CGRect? = nil) {
        let shapeBounds = shapeRect ?? CGRect(origin: .zero, size: size)
        guard shapeBounds.width.isFinite, shapeBounds.width > 0,
              shapeBounds.height.isFinite, shapeBounds.height > 0 else { return }
        let path = shape.path(in: shapeBounds)
        let strokeBase = baseStrokeColor()

        drawShapeFill(context, path: path, color: tintWashColor())
        drawShapeFill(context, path: path, color: highlightFillColor())

        switch style {
        case .v26:
            drawV26Stroke(context, bounds: shapeBounds, path: path, strokeBase: strokeBase)
        case .v27:
            drawV27Outline(context, bounds: shapeBounds, path: path, strokeBase: strokeBase)
        }
    }

    // MARK: - Base fills

    /// Soft tinted wash over the material (`tint.opacity(0.2)` in SwiftUI).
    private func tintWashColor() -> CGColor? {
        guard let tint = tint, tint.alpha > 0 else { return nil }
        return Self.withAlpha(tint, tint.alpha * 0.2)
    }

    /// The sheen that brightens the glass (`highlightColor.opacity(0.75)`).
    private func highlightFillColor() -> CGColor {
        let gloss = isDark ? 0.7 * 0.6 * opacity : 1.0 * opacity
        let alpha = gloss * 0.75
        return CGColor(gray: isDark ? 0 : 1, alpha: alpha)
    }

    private func drawShapeFill(_ context: CGContext, path: CGPath, color: CGColor?) {
        guard let color = color else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setFillColor(color)
        context.fillPath()
        context.restoreGState()
    }

    /// Base outline color, matching each renderer's `strokeColor`.
    private func baseStrokeColor() -> CGColor {
        if let tint = tint {
            return Self.withAlpha(tint, tint.alpha * 0.3)
        }
        let grayAlpha = isDark ? (style == .v26 ? 0.3 : 0.2) : 1.0
        return CGColor(gray: isDark ? 0.5 : 1.0, alpha: grayAlpha)
    }

    // MARK: - V26 outline (angular gradient)

    private func drawV26Stroke(
        _ context: CGContext, bounds: CGRect, path: CGPath, strokeBase: CGColor
    ) {
        // Match SwiftUI's stop alphas exactly. The rim is clipped inside the
        // shape (SwiftUI's centered stroke leaves half outside), but the inner
        // band must keep the same color as SwiftUI's inner half.
        let high = Self.withAlpha(strokeBase, strokeBase.alpha * 0.7)
        let low = Self.withAlpha(strokeBase, strokeBase.alpha * 0.1)
        let (swiftUIStartAngle, mid1, mid2) = v26AngleParameters(bounds: bounds)

        let stops = [
            GradientStop(color: high, location: 0),
            GradientStop(color: low, location: mid1),
            GradientStop(color: high, location: 0.5),
            GradientStop(color: low, location: mid2),
            GradientStop(color: high, location: 1),
        ]
        let radius = sqrt(bounds.width * bounds.width + bounds.height * bounds.height)

        context.saveGState()
        // The host view clips drawing at its bounds, which would shave the
        // outer half off a centered stroke and leave a ragged sub-pixel line.
        // Clip to the shape and stroke at twice the width instead so a crisp,
        // full-width border remains inside the shape.
        context.addPath(path)
        context.clip()
        Self.clipStrokedPath(context, path: path, lineWidth: 2, blendMode: .plusLighter)
        // SwiftUI measures angular-gradient angles in its y-down coordinate
        // space; this renderer draws y-up. Mirror the start angle and the
        // sweep direction so the highlight lands in the same visual corner.
        Self.drawConicGradient(
            in: context,
            stops: stops,
            center: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -swiftUIStartAngle,
            sweep: -1
        )
        context.restoreGState()
    }

    /// Angle parameters for the angular outline, from the same geometry the
    /// SwiftUI renderer computes for each shape.
    private func v26AngleParameters(bounds: CGRect) -> (startAngle: CGFloat, mid1: CGFloat, mid2: CGFloat) {
        let radius: CGFloat
        switch shape {
        case .roundedRect(let cornerRadius):
            radius = min(max(cornerRadius, 0), min(bounds.width, bounds.height) / 2)
        case .capsule:
            radius = bounds.height / 2
        case .circle:
            return (.pi + .pi / 4, 0.25, 0.75)
        }

        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let horizontalGap = halfWidth - radius
        let verticalGap = halfHeight - radius
        let sqrt2: CGFloat = 1.4142135623730951

        let cornerDistance = sqrt2 * verticalGap + radius
        let gapDifference = horizontalGap - verticalGap
        let t1 = sqrt2 * cornerDistance
        let t2 = cornerDistance * cornerDistance + gapDifference * gapDifference
            + sqrt2 * cornerDistance * gapDifference
        guard t2 > 0 else { return (.pi, 0.25, 0.75) } // degenerate (square) bounds

        let t = t1 / (2 * sqrt(t2))
        let alpha = asin(min(max(t, -1), 1))
        let startAngle = .pi + alpha
        let mid1 = (.pi - 2 * alpha) / (2 * .pi)
        return (startAngle, mid1, 0.5 + mid1)
    }

    // MARK: - V27 outline (lens highlight + gray border)

    private func drawV27Outline(
        _ context: CGContext, bounds: CGRect, path: CGPath, strokeBase: CGColor
    ) {
        // SwiftUI draws this highlight with `strokeBorder`, i.e. fully inside
        // the shape. A centered stroke clipped to the shape reproduces that,
        // so double the width to leave the full 1.2 pt inside the bounds.
        let visibleWidth: CGFloat = 1.2
        let lineWidth = visibleWidth * 2

        context.saveGState()
        context.addPath(path)
        context.clip()
        switch shape {
        case .circle:
            let stops = [
                GradientStop(color: strokeBase, location: 0),
                GradientStop(color: Self.withAlpha(strokeBase, 0), location: 0.5),
                GradientStop(color: strokeBase, location: 1),
            ]
            Self.clipStrokedPath(context, path: path, lineWidth: lineWidth, blendMode: .plusLighter)
            Self.drawLinearGradient(
                in: context,
                stops: stops,
                start: CGPoint(x: bounds.midX, y: bounds.maxY),
                end: CGPoint(x: bounds.midX, y: bounds.minY)
            )
        case .roundedRect(let cornerRadius):
            let radius = min(max(cornerRadius, 0), min(bounds.width, bounds.height) / 2)
            drawLensHighlight(context, bounds: bounds, cornerRadius: radius,
                              strokeBase: strokeBase, lineWidth: lineWidth)
        case .capsule:
            drawLensHighlight(context, bounds: bounds, cornerRadius: bounds.height / 2,
                              strokeBase: strokeBase, lineWidth: lineWidth)
        }
        context.restoreGState()

        // Full-outline gray border, matching SwiftUI's centered 1 pt
        // `Color.gray` stroke. It is drawn *unclipped* so its outer 0.5 pt
        // renders in the host's bleed margin — a half-width clipped border is
        // barely visible. The inner 0.5 pt still overlaps only the outer edge
        // of the 1.2 pt lens, leaving the lens readable.
        let border = CGColor(gray: 0.5, alpha: isDark ? 0.1 : 0.2)
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(border)
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()
    }

    /// The top/bottom “lens” highlight: a linear gradient (100 → 0 → 100
    /// left-to-right) following the straight edges *and* the rounded corner
    /// arcs of a rounded-rect-style outline.
    private func drawLensHighlight(
        _ context: CGContext, bounds: CGRect, cornerRadius: CGFloat,
        strokeBase: CGColor, lineWidth: CGFloat
    ) {
        let edges = Self.horizontalEdgesPath(rect: bounds, cornerRadius: cornerRadius)
        let stops = [
            GradientStop(color: Self.withAlpha(strokeBase, strokeBase.alpha * 0.3), location: 0),
            GradientStop(color: Self.withAlpha(strokeBase, strokeBase.alpha * 0.9), location: 0.5),
            GradientStop(color: Self.withAlpha(strokeBase, strokeBase.alpha * 0.3), location: 1),
        ]
        Self.clipStrokedPath(context, path: edges, lineWidth: lineWidth, blendMode: .plusLighter)
        Self.drawLinearGradient(
            in: context,
            stops: stops,
            start: CGPoint(x: bounds.minX, y: bounds.midY),
            end: CGPoint(x: bounds.maxX, y: bounds.midY)
        )
    }

    // MARK: - Gradient helpers

    /// Clips the context to the stroked region of `path` and sets the blend
    /// mode, so a subsequent gradient fill only paints the outline.
    private static func clipStrokedPath(
        _ context: CGContext, path: CGPath, lineWidth: CGFloat, blendMode: CGBlendMode
    ) {
        context.addPath(path)
        context.setLineWidth(lineWidth)
        context.setBlendMode(blendMode)
        context.replacePathWithStrokedPath()
        context.clip()
    }

    /// The top + bottom edges of a rounded-rect outline, including the rounded
    /// corner arcs so the lens highlight extends around the corners. Mirrors
    /// SwiftUI's private `HorizontalEdges` shape in this file's y-up space.
    private static func horizontalEdgesPath(rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
        let x0 = rect.minX, y0 = rect.minY
        let width = rect.width, height = rect.height
        let topLeft = CGPoint(x: x0 + r, y: y0 + r)
        let topRight = CGPoint(x: x0 + width - r, y: y0 + r)
        let bottomRight = CGPoint(x: x0 + width - r, y: y0 + height - r)
        let bottomLeft = CGPoint(x: x0 + r, y: y0 + height - r)

        // Top outline, left → right. Each corner arc starts from its own
        // tangent point and sweeps onto the top edge. The arcs must run
        // through the *outer* quadrant of each corner circle (increasing
        // angle), matching SwiftUI's HorizontalEdges (180° → 270° → 0°).
        path.move(to: CGPoint(x: x0, y: y0 + r))
        path.addArc(center: topLeft, radius: r, startAngle: .pi, endAngle: 1.5 * .pi, clockwise: false)
        path.addLine(to: CGPoint(x: x0 + width - r, y: y0))
        path.addArc(center: topRight, radius: r, startAngle: 1.5 * .pi, endAngle: 2 * .pi,
                    clockwise: false)

        // Bottom outline, right → left, the mirror image of the top.
        path.move(to: CGPoint(x: x0 + width, y: y0 + height - r))
        path.addArc(center: bottomRight, radius: r, startAngle: 0, endAngle: .pi / 2,
                    clockwise: false)
        path.addLine(to: CGPoint(x: x0 + r, y: y0 + height))
        path.addArc(center: bottomLeft, radius: r, startAngle: .pi / 2, endAngle: .pi,
                    clockwise: false)

        return path
    }

    private static func drawLinearGradient(
        in context: CGContext, stops: [GradientStop], start: CGPoint, end: CGPoint
    ) {
        guard stops.count >= 2 else { return }
        let colors = stops.map(\.color) as CFArray
        let locations = stops.map(\.location)
        guard let gradient: CGGradient = locations.withUnsafeBufferPointer({ buffer in
            CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: buffer.baseAddress
            )
        }) else { return }
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
    }

    /// Draws a conic (angular) gradient by filling many thin wedges sampled
    /// around `center`. CG has no native conic gradient, so SwiftUI's
    /// `AngularGradient` is reproduced the way Core Graphics can express it:
    /// for a thin outline the segment fan reads as smooth.
    ///
    /// Wedges abut exactly with no overlap: they are composited with
    /// `.plusLighter`, so any overlap would add alpha twice and show up as
    /// bright seams along the border.
    /// - Parameters:
    ///   - startAngle: Starting angle in this renderer's y-up space.
    ///   - sweep: `1` sweeps toward increasing angles, `-1` toward decreasing
    ///     angles (used to mirror SwiftUI's y-down angular direction).
    private static func drawConicGradient(
        in context: CGContext,
        stops: [GradientStop],
        center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        sweep: CGFloat = 1
    ) {
        guard radius > 0, !stops.isEmpty else { return }
        let segmentCount = 240
        let step = sweep * 2 * .pi / CGFloat(segmentCount)
        for i in 0..<segmentCount {
            let a0 = startAngle + CGFloat(i) * step
            let a1 = a0 + step
            let t = (CGFloat(i) + 0.5) / CGFloat(segmentCount)
            context.setFillColor(Self.interpolate(stops: stops, at: t))
            context.move(to: center)
            context.addLine(to: CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0)))
            context.addLine(to: CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1)))
            context.closePath()
            context.fillPath()
        }
    }

    private static func interpolate(stops: [GradientStop], at t: CGFloat) -> CGColor {
        let t = min(max(t, 0), 1)
        guard stops.count > 1 else { return stops.first?.color ?? CGColor(gray: 0, alpha: 1) }
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) {
            let a = stops[i], b = stops[i + 1]
            if t >= a.location, t <= b.location { lower = a; upper = b; break }
        }
        let span = upper.location - lower.location
        let f = span > 0 ? (t - lower.location) / span : 0
        return lerp(lower.color, upper.color, f)
    }

    private static func lerp(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
        guard t > 0 else { return a }
        guard t < 1 else { return b }

        let space = CGColorSpaceCreateDeviceRGB()
        guard let ca = a.converted(to: space, intent: .defaultIntent, options: nil),
              let cb = b.converted(to: space, intent: .defaultIntent, options: nil),
              let ac = ca.components, ac.count >= 4,
              let bc = cb.components, bc.count >= 4
        else { return a }

        let r = ac[0] + (bc[0] - ac[0]) * t
        let g = ac[1] + (bc[1] - ac[1]) * t
        let bl = ac[2] + (bc[2] - ac[2]) * t
        let al = ac[3] + (bc[3] - ac[3]) * t
        var components: [CGFloat] = [r, g, bl, al]
        return CGColor(colorSpace: space, components: &components) ?? a
    }

    private static func withAlpha(_ color: CGColor, _ alpha: CGFloat) -> CGColor {
        color.copy(alpha: min(max(alpha, 0), 1)) ?? color
    }
}

#endif