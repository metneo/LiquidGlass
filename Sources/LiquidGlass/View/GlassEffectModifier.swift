//
//  GlassEffectModifier.swift
//  LiquidGlass
//
//  A ViewModifier that applies a glass effect to any SwiftUI view.
//

import SwiftUI

// MARK: - GlassEffectModifier

/// A `ViewModifier` that applies a frosted-glass background to the modified view.
///
/// On OS Platform 26+, this modifier uses the system's native `.glassEffect(in:)` API.
/// On earlier OS versions, it falls back to the custom ``LiquidGlass`` implementation.
///
/// Optional features:
/// - **Hover effect**: When enabled, shows a subtle quaternary fill on pointer hover.
struct GlassEffectModifier: ViewModifier {
    // MARK: - Constants
    private static let defaultOpacity: CGFloat = 0.6
    private static let defaultAngle: LightAngle = .topLeading
    
    // MARK: - Properties
    
    /// The underlying background shape (roundedRect, circle, capsule)
    private let shape: BackgroundShape
    
    /// Whether to show a subtle hover effect on pointer hover
    private let hoverEffect: Bool

    /// The opacity level for the glass effect (default: 0.6).
    /// Higher values make the glass more opaque, lower values more transparent.
    private let opacity: CGFloat
    
    private let tint: Color?
    
    private let lightAngle: LightAngle
    
    /// Tracks current hover state (used when hoverEffect is true)
    @State private var onHover: Bool = false
    
    /// Respect system color scheme for subtle color adjustments.
    @Environment(\.colorScheme) private var colorScheme
    
    /// Computed property for current hover fill style
    private var hoverFillStyle: AnyShapeStyle {
        let hoverBackground = colorScheme == .dark ? AnyShapeStyle(.quinary) : AnyShapeStyle(.white)
        return hoverEffect && onHover ? AnyShapeStyle(hoverBackground) : AnyShapeStyle(.clear)
    }

    // MARK: - Initializer
    
    /// Create a glass effect modifier.
    /// - Parameters:
    ///   - shape: The `BackgroundShape` to use for the glass background.
    ///   - opacity: The opacity level for the glass effect (default: 0.6).
    ///     Higher values make the glass more opaque, lower values more transparent.
    ///   - hoverEffect: If `true`, displays a subtle fill on pointer hover. Default is `false`.
    ///   - angle: Glass effect light angle
    init(
        shape: BackgroundShape,
        opacity: CGFloat = Self.defaultOpacity,
        tint: Color? = nil,
        hoverEffect: Bool = false,
        angle: LightAngle = Self.defaultAngle
    ) {
        self.shape = shape
        self.hoverEffect = hoverEffect
        self.opacity = opacity
        self.tint = tint
        self.lightAngle = angle
    }

    func body(content: Content) -> some View {
        renderGlassEffect(content: content)
        #if os(macOS)
        .onHover { hovering in
            if hoverEffect {
                withAnimation {
                    self.onHover = hovering
                }
            }
        }
        #endif
        .compositingGroup()
    }
    
    // MARK: - Private Helpers
    
    @ViewBuilder
    private func renderGlassEffect(content: Content) -> some View {
        content
            .background {
                renderHoverBackground()
            }
            .background {
                LiquidGlass(
                    shape: shape,
                    hovering: hoverEffect && onHover,
                    tintColor: tint,
                    lightAngle: lightAngle
                )
            }
    }
    
    @ViewBuilder
    private func renderHoverBackground() -> some View {
        switch shape {
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(hoverFillStyle)
        case .circle:
            Circle()
                .fill(hoverFillStyle)
        case .capsule:
            Capsule()
                .fill(hoverFillStyle)
        }
    }
}
