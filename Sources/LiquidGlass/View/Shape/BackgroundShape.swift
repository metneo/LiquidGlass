//
//  BackgroundShape.swift
//  LiquidGlass

import SwiftUI

/// BackgroundShape describes simple shapes used by the glass background renderer.
///
/// Use `.shape` to obtain a `Shape` that can be placed into SwiftUI view builders.
///
/// ```swift
/// // Rounded rectangle with 12pt corners
/// let roundedShape = BackgroundShape.roundedRect(cornerRadius: 12)
/// 
/// // Perfect circle
/// let circleShape = BackgroundShape.circle
/// 
/// // Capsule (pill shape)
/// let capsuleShape = BackgroundShape.capsule
/// ```
public enum BackgroundShape: Sendable, Shape {

    public func path(in rect: CGRect) -> Path {
        switch self {
        case .roundedRect(let cornerRadius):
            CustomShape(shape: self, animatableCornerRadius: cornerRadius).path(in: rect)
        default:
            CustomShape(shape: self).path(in: rect)
        }
    }

    /// Returns a `Shape` instance for use in SwiftUI view builders.
    ///
    /// This is the single place that maps `BackgroundShape` cases to their
    /// concrete shapes, so callers can build the glass effect directly without
    /// re-implementing the `roundedRect`/`circle`/`capsule` switch:
    ///
    /// ```swift
    /// shape.shape.fill(.ultraThinMaterial)
    /// ```
    public var shape: CustomShape {
        switch self {
        case .roundedRect(let cornerRadius):
            return CustomShape(shape: self, animatableCornerRadius: cornerRadius)
        default:
            return CustomShape(shape: self)
        }
    }

    /// A rounded rectangle with customizable corner radius.
    /// - Parameter cornerRadius: The radius of the rounded corners in points.
    case roundedRect(cornerRadius: CGFloat)

    /// A perfect circle that fits within the available bounds.
    case circle

    /// A capsule (pill-shaped) that adapts to the container's aspect ratio.
    case capsule
    
    public func gradient(proxy: GeometryProxy, highlighting: Color, tint: Color? = nil, angle: LightAngle) -> AngularGradient {
        switch self {
        case .roundedRect(let radius):
            Self.calculatedGradient(
                highlightColor: highlighting,
                tint: tint,
                proxy: proxy,
                radius: radius,
                angle: angle
            )
        case .circle:
            Self.gradient(
                highlightColor: highlighting,
                tint: tint,
                startAngle: .pi + .pi / 4,
                mid1: 0.25,
                mid2: 0.75,
                angle: angle
            )
        case .capsule:
            Self.calculatedGradient(
                highlightColor: highlighting,
                tint: tint,
                proxy: proxy,
                radius: proxy.size.height / 2,
                angle: angle
            )
        }
    }

    // MARK: - Private Gradient Helpers

    // MARK: - Gradient Constants
    /// Opacity applied to top gradient stop when using tint (default: 0.15).
    private static let tintTopOpacityMultiplier: CGFloat = 0.15
    /// Opacity applied to bottom gradient stop when using tint (default: 0.3).
    private static let tintBottomOpacityMultiplier: CGFloat = 0.3
    /// Opacity for bottom gradient stop when not using tint (default: 0.7).
    private static let highlightBottomOpacityMultiplier: CGFloat = 0.7

    /// Creates an angular gradient for shape highlighting.
    ///
    /// - Parameters:
    ///   - highlightColor: Base color for the gradient.
    ///   - tint: Optional tint that modifies the gradient colors.
    ///   - startAngle: Starting angle for the gradient in radians.
    ///   - mid1: First midpoint location (0.0 to 1.0).
    ///   - mid2: Second midpoint location (0.0 to 1.0).
    ///   - angle: LightAngle determining gradient direction and behavior.
    ///
    /// - Returns: An `AngularGradient` configured for the specified parameters.
    private static func gradient(
        highlightColor: Color,
        tint: Color? = nil,
        startAngle: CGFloat,
        mid1: CGFloat,
        mid2: CGFloat,
        angle: LightAngle
    ) -> AngularGradient {

        if angle == .none {
            return AngularGradient(colors: [.clear], center: .center)
        }

        let topColor: Color
        let midColor: Color
        let bottomColor: Color

        // Consistent opacity multipliers for both tint and highlight paths
        if let tint = tint {
            topColor = tint.opacity(tintTopOpacityMultiplier)
            midColor = tint.opacity(0.3)
            bottomColor = tint.opacity(tintBottomOpacityMultiplier)
        } else {
            topColor = highlightColor
            midColor = highlightColor.opacity(0.3)
            bottomColor = highlightColor.opacity(highlightBottomOpacityMultiplier)
        }

        if angle == .all {
            return AngularGradient(colors: [topColor], center: .center)
        }

        var adjustedStartAngle = startAngle

        if angle == .bottomTrailing {
            adjustedStartAngle = startAngle + .pi
        }

        return AngularGradient(
            stops: [
                .init(color: topColor, location: 0),
                .init(color: midColor, location: mid1),
                .init(color: bottomColor, location: 0.5),
                .init(color: midColor, location: mid2),
                .init(color: topColor, location: 1)
            ],
            center: .center,
            angle: .radians(adjustedStartAngle)
        )
    }
    
    /// Calculates an angular gradient based on shape geometry.
    /// 
    /// This method performs mathematical calculations to determine optimal gradient
    /// angles and positions based on the shape's dimensions and corner radius.
    /// 
    /// - Parameters:
    ///   - highlightColor: Base color for the gradient.
    ///   - tint: Optional tint color for gradient modification.
    ///   - proxy: Geometry proxy providing the shape's dimensions.
    ///   - radius: Corner radius or characteristic radius of the shape.
    /// 
    /// - Returns: An optimized `AngularGradient` for the shape's geometry.
    private static func calculatedGradient(
        highlightColor: Color,
        tint: Color? = nil,
        proxy: GeometryProxy,
        radius: CGFloat,
        angle: LightAngle
    ) -> AngularGradient {
        let halfWidth = proxy.size.width / 2
        let halfHeight = proxy.size.height / 2
        let d = halfWidth - radius
        let l = halfHeight - radius
        
        // Precomputed constant for better performance
        let sqrt2: CGFloat = 1.414213562373095
        
        let a = sqrt2 * l + radius
        let b = d - l
        let t1 = sqrt2 * a
        let t2 = a * a + b * b + sqrt2 * a * b
        let alpha = asin(t1 / (2 * sqrt(t2)))
        
        let startAngle = CGFloat.pi + alpha
        let mid = (CGFloat.pi - 2 * alpha) / (2 * CGFloat.pi)
        let mid2 = 0.5 + mid
        
        return gradient(
            highlightColor: highlightColor,
            tint: tint,
            startAngle: startAngle,
            mid1: mid,
            mid2: mid2,
            angle: angle
        )
    }
}

// MARK: - CustomShape

/// An animatable, insettable shape that works with `BackgroundShape` enum values.
/// 
/// `CustomShape` provides SwiftUI-compatible shape functionality with support for:
/// - **Animation**: Corner radius and inset changes animate smoothly
/// - **Insetting**: Shape can be inset for stroke and other effects
/// - **Sendable**: Thread-safe for use in concurrent contexts
/// 
/// ```swift
/// let shape = BackgroundShape.roundedRect(cornerRadius: 12).shape
/// shape
///     .fill(.blue)
///     .frame(width: 100, height: 100)
/// ```
public struct CustomShape: InsettableShape, Animatable, Sendable {
    // MARK: - Properties
    
    /// Internal inset amount applied to the shape bounds.
    /// This value is animatable and affects the final shape size.
    private var insetAmount: CGFloat = 0.0
    
    /// The corner radius for rounded rectangle shapes.
    /// This property is animatable, allowing smooth transitions between radius values.
    public var animatableCornerRadius: CGFloat
    
    /// The underlying shape type from the `BackgroundShape` enum.
    /// This determines which geometric path will be generated.
    public let shape: BackgroundShape
    
    // MARK: - Animatable Data
    
    /// Combined animatable data for inset amount and corner radius.
    /// 
    /// SwiftUI uses this property to interpolate between different shape states
    /// during animations, ensuring smooth transitions for both inset and radius changes.
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(insetAmount, animatableCornerRadius) }
        set {
            insetAmount = newValue.first
            animatableCornerRadius = newValue.second
        }
    }
    
    // MARK: - Initializer
    
    /// Creates a `CustomShape` from a `BackgroundShape` enum value.
    /// 
    /// - Parameters:
    ///   - shape: The `BackgroundShape` that defines the geometric type.
    ///   - animatableCornerRadius: Initial corner radius for rounded rectangles.
    ///                            Ignored for circle and capsule shapes.
    public init(shape: BackgroundShape, animatableCornerRadius: CGFloat = 0) {
        self.shape = shape
        self.animatableCornerRadius = animatableCornerRadius
    }
    
    // MARK: - InsettableShape Protocol
    
    /// Returns a copy of the shape inset by the specified amount.
    /// 
    /// Insetting reduces the shape's size on all sides, commonly used for
    /// stroke effects or creating bordered shapes.
    /// 
    /// - Parameter amount: The inset distance in points. Negative values are clamped to 0.
    /// - Returns: A new `CustomShape` with the additional inset applied.
    public func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount = max(0, insetAmount + amount)
        return copy
    }

    // MARK: - Shape Protocol
    
    /// Generates the geometric path for the shape within the given rectangle.
    /// 
    /// This method creates the actual `Path` that SwiftUI uses for rendering,
    /// hit testing, and clipping operations. The path accounts for any applied insets
    /// and shape-specific geometry requirements.
    /// 
    /// - Parameter rect: The rectangle in which to generate the path.
    /// - Returns: A `Path` representing the shape's geometry, or an empty path
    ///           if the inset rectangle has no positive area.
    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard insetRect.width > 0, insetRect.height > 0 else { return Path() }

        // Build paths directly instead of instantiating throwaway system shapes
        // (`RoundedRectangle`, `Capsule`) and asking for their paths — this avoids
        // per-frame shape allocation during animations.
        switch shape {
        case .roundedRect:
            let maxRadius = min(insetRect.width, insetRect.height) / 2
            let radius = min(animatableCornerRadius, maxRadius)
            return Path(roundedRect: insetRect, cornerRadius: radius, style: .continuous)

        case .circle:
            let size = min(insetRect.width, insetRect.height)
            let circleRect = CGRect(
                x: insetRect.midX - size / 2,
                y: insetRect.midY - size / 2,
                width: size,
                height: size
            )
            return Path(ellipseIn: circleRect)

        case .capsule:
            // A capsule is a stadium: a rounded rect whose corner radius equals
            // half the smaller dimension. Geometrically identical to `Capsule()`.
            let radius = min(insetRect.width, insetRect.height) / 2
            return Path(roundedRect: insetRect, cornerRadius: radius, style: .continuous)
        }
    }
}
