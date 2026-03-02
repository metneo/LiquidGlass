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

    /// A rounded rectangle with customizable corner radius.
    /// - Parameter cornerRadius: The radius of the rounded corners in points.
    case roundedRect(cornerRadius: CGFloat)

    /// A perfect circle that fits within the available bounds.
    case circle

    /// A capsule (pill-shaped) that adapts to the container's aspect ratio.
    case capsule

//    /// Returns a `CustomShape` instance for use in SwiftUI view builders.
//    /// 
//    /// The returned shape supports animation and can be used with SwiftUI modifiers
//    /// like `.fill()`, `.stroke()`, and `.clipShape()`.
//    public var shape: CustomShape {
//        switch self {
//        case .roundedRect(let cornerRadius):
//            return CustomShape(shape: self, animatableCornerRadius: cornerRadius)
//        case .circle, .capsule:
//            return CustomShape(shape: self)
//        }
//    }
    
    public func gradient(proxy: GeometryProxy, highlighting: Color, tint: Color? = nil, angle: LightAngle) -> some ShapeStyle {
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

//    /// Creates a highlighted stroke view with gradient effects.
//    /// 
//    /// This method generates shape-specific gradient strokes that enhance the visual
//    /// depth and glass-like appearance of the shape.
//    /// 
//    /// - Parameters:
//    ///   - highlighting: The primary color used for the highlight effect.
//    ///   - tint: Optional tint color that modifies the highlight appearance.
//    ///           When provided, creates a more subtle, colored highlight.
//    /// 
//    /// - Returns: A view with the highlighted stroke applied to the shape.
//    /// 
//    /// ```swift
//    /// BackgroundShape.roundedRect(cornerRadius: 16)
//    ///     .highlight(highlighting: .white, tint: .blue)
//    /// ```
//    public func highlight(highlighting: Color, tint: Color? = nil) -> some View {
//        Group {
//            switch self {
//            case .roundedRect(let radius):
//                GeometryReader { proxy in
//                    shape.stroke(
//                        Self.calculatedGradient(
//                            highlightColor: highlighting,
//                            tint: tint,
//                            proxy: proxy,
//                            radius: radius
//                        )
//                    )
//                }
//            case .circle:
//                shape.stroke(
//                    Self.gradient(
//                        highlightColor: highlighting,
//                        tint: tint,
//                        startAngle: .pi + .pi / 4,
//                        mid1: 0.25,
//                        mid2: 0.75
//                    )
//                )
//            case .capsule:
//                GeometryReader { proxy in
//                    shape.stroke(
//                        Self.calculatedGradient(
//                            highlightColor: highlighting,
//                            tint: tint,
//                            proxy: proxy,
//                            radius: proxy.size.height / 2
//                        )
//                    )
//                }
//            }
//        }
//    }

    // MARK: - Private Gradient Helpers
    
    /// Creates an angular gradient for shape highlighting.
    /// 
    /// - Parameters:
    ///   - highlightColor: Base color for the gradient.
    ///   - tint: Optional tint that modifies the gradient colors.
    ///   - highOpacity: Opacity level for prominent gradient stops (default: 0.7).
    ///   - lowOpacity: Opacity level for subtle gradient stops (default: 0.1).
    ///   - startAngle: Starting angle for the gradient in radians.
    ///   - mid1: First midpoint location (0.0 to 1.0).
    ///   - mid2: Second midpoint location (0.0 to 1.0).
    /// 
    /// - Returns: An `AngularGradient` configured for the specified parameters.
    private static func gradient(
        highlightColor: Color,
        tint: Color? = nil,
        highOpacity: CGFloat = 1,
        lowOpacity: CGFloat = 0.3,
        startAngle: CGFloat,
        mid1: CGFloat,
        mid2: CGFloat,
        angle: LightAngle
    ) -> AngularGradient {
        
        if angle == .none {
            return AngularGradient.init(colors: [.clear], center: .center)
        }
        
        let topColor: Color
        let midColor: Color
        let bottomColor: Color
        
        if let tint = tint {
            topColor = tint.opacity(highOpacity * 0.15)
            midColor = tint.opacity(lowOpacity)
            bottomColor = tint.opacity(highOpacity * 0.3)
        } else {
            let high = highlightColor.opacity(highOpacity)
            let low = highlightColor.opacity(lowOpacity)
            topColor = high
            midColor = low
            bottomColor = high.opacity(0.7)
        }
        
        if angle == .all {
            return AngularGradient.init(colors: [topColor], center: .center)
        }
        
        var ss = startAngle
        
        if angle == .bottomTrailing {
            ss = ss + .pi
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
            angle: .radians(ss)
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

        switch shape {
        case .roundedRect:
            let maxRadius = min(insetRect.width, insetRect.height) / 2
            let radius = min(animatableCornerRadius, maxRadius)
            return RoundedRectangle(cornerRadius: radius).path(in: insetRect)

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
            return Capsule().path(in: insetRect)
        }
    }
}
