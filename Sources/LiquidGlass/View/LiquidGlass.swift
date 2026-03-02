//
//  LiquidGlass.swift
//  LiquidGlass
//

import SwiftUI

public enum LightAngle {
    case topLeading, bottomTrailing, none, all
}

/// A SwiftUI view that renders a frosted-glass background for a ``BackgroundShape``.
///
/// ```swift
/// LiquidGlass(shape: .capsule)
///     .tint(.blue)
///     .opacity(0.8)
/// ```
///
/// This view composes multiple translucent fills, subtle multi-stop strokes, and a soft shadow
/// to create a glass-like visual. It is lightweight and keeps the public API minimal:
/// - `init(shape:)` to create the style for a given ``BackgroundShape``.
/// - `tint(_:)` to customize the accent/tint color used by subtle gradients.
/// - `opacity(_:)` to customize the highlight color opacity.
public struct LiquidGlass: View {
    // MARK: - Constants
    private static let defaultOpacity: CGFloat = 0.6
    private static let defaultLightAngle: LightAngle = .topLeading
    private static let strokeLineWidth: CGFloat = 1.2
    private static let strokeBlurRadius: CGFloat = 1.2
    private static let shadowRadius: CGFloat = 10
    private static let highlightOpacityMultiplier: CGFloat = 0.75
    private static let overlayBlendBlurRadius: CGFloat = 0.6
    
    // MARK: - Stored properties

    /// Optional tint color. If not provided, `.accentColor` is used.
    private var tintColor: Color?

    /// Respect system color scheme for subtle color adjustments.
    @Environment(\.colorScheme) private var colorScheme

    /// Underlying shape to style (rounded rect, capsule, or circle)
    private let shape: BackgroundShape
    
    /// The opacity level for the glass effect (default: 0.6).
    /// Higher values make the glass more opaque, lower values more transparent.
    private var opacity: CGFloat = Self.defaultOpacity
    
    private let hovering: Bool
    
    private var lightAngle: LightAngle = Self.defaultLightAngle

    // MARK: - Initializer

    /// Create a glass style for the provided `BackgroundShape`.
    /// - Parameters:
    ///   - shape: the target `BackgroundShape` to render.
    public init(shape: BackgroundShape, hovering: Bool = false) {
        self.shape = shape
        self.hovering = hovering
    }
            
    internal init(shape: BackgroundShape, hovering: Bool = false, tintColor: Color? = nil, opacity: CGFloat = Self.defaultOpacity, lightAngle: LightAngle = Self.defaultLightAngle) {
        self.shape = shape
        self.hovering = hovering
        self.tintColor = tintColor
        self.opacity = opacity
        self.lightAngle = lightAngle
    }
    
    public func lightAngle(_ angle: LightAngle) -> Self {
        var copy = self
        copy.lightAngle = angle
        return copy
    }

    // MARK: - Fluent API
    
    /// Return a modified view with the specified opacity value.
    /// - Parameter opacity: The opacity level for the glass effect (default: 0.6).
    ///   Higher values make the glass more opaque, lower values more transparent.
    /// - Returns: A new `LiquidGlass` with the specified opacity.
    public func opacity(_ opacity: CGFloat) -> LiquidGlass {
        var copy = self
        copy.opacity = opacity
        return copy
    }

    /// Return a modified view using the provided `tint` color.
    /// - Parameter tint: A `Color` used to tint the subtle overlay gradient, or `nil` to remove tinting.
    /// - Returns: A new `LiquidGlass` with the specified tint color.
    ///
    /// The opacity of the glass effect is preserved.
    public func tintColor(_ tint: Color?) -> LiquidGlass {
        if let tint = tint {
            var copy = self
            copy.tintColor = tint
            return copy
        } else {
            return self
        }
    }
    
    @ViewBuilder
    private func applyEffect(baseShape: some InsettableShape) -> some View {
        baseShape
            .foregroundStyle(.ultraThinMaterial)
            .overlay {
                highlightOverlay(baseShape: baseShape)
            }
            .overlay {
                strokeOverlay(baseShape: baseShape)
            }
            .shadow(color: Color.shadow.opacity(opacity), radius: Self.shadowRadius, x: 0, y: 0)
            .compositingGroup()
    }
    
    @ViewBuilder
    private func highlightOverlay(baseShape: some InsettableShape) -> some View {
        let highlight = tintColor ?? Color.highlight
        baseShape.fill(highlight.opacity(opacity * Self.highlightOpacityMultiplier))
    }
    
    @ViewBuilder
    private func strokeOverlay(baseShape: some InsettableShape) -> some View {
        switch lightAngle {
        case .topLeading, .bottomTrailing, .all:
            GeometryReader { proxy in
                baseShape
                    .stroke(
                        shape.gradient(
                            proxy: proxy,
                            highlighting: Color.stroke.opacity(opacity),
                            tint: tintColor,
                            angle: lightAngle
                        ),
                        lineWidth: Self.strokeLineWidth
                    )
                    .blendMode(.plusLighter)
            }
        case .none:
            EmptyView()
        }
    }

    public var body: some View {
        buildShapeView()
    }
    
    @ViewBuilder
    private func buildShapeView() -> some View {
        switch shape {
        case .roundedRect(let cornerRadius):
            applyEffect(baseShape: RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            applyEffect(baseShape: Circle())
        case .capsule:
            applyEffect(baseShape: Capsule())
        }
    }
}

// MARK: - Preview

#Preview("LiquidGlass Examples") {
    let group = VStack(spacing: 30) {
        LiquidGlass(shape: .roundedRect(cornerRadius: 16))
            .frame(width: 200, height: 100)
        
        LiquidGlass(shape: .circle)
            .frame(width: 120, height: 120)
        
        LiquidGlass(shape: .capsule)
            .frame(width: 180, height: 60)
    }
    
    HStack {
        group
    }
    .padding(40)
    .background(
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
