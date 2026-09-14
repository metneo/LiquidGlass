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
            .glassHoverEffect(shape: shape, enabled: hoverEffect)
            .compositingGroup()
    }

    // MARK: - Private Helpers

    @ViewBuilder
    private func renderGlassEffect(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            nativeGlass(content)
        } else {
            fallbackGlass(content)
        }
    }

    @ViewBuilder
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *)
    private func nativeGlass(_ content: Content) -> some View {
        content
            .glassEffect(in: shape)
            .tint(tint)
    }

    @ViewBuilder
    private func fallbackGlass(_ content: Content) -> some View {
        content
            .background {
                // `LiquidGlass` is the router: it reads the `\.liquidGlassVersion`
                // environment value and renders the matching V26/V27 style.
                LiquidGlass(shape: shape, tintColor: tint, opacity: opacity, lightAngle: lightAngle)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Apply a frosted-glass background effect to SwiftUI view.
    ///
    /// This modifier creates a frosted glass appearance behind the view content.
    /// On Platform 26+, it uses the system `.glassEffect(in:)` API.
    /// On earlier OS versions, it falls back to a custom glass implementation.
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello, World!")
    ///     .padding()
    ///     .liquidGlass(shape: .roundedRect(cornerRadius: 16), hoverEffect: true)
    /// ```
    ///
    /// - Parameters:
    ///   - shape: The ``BackgroundShape`` to use (roundedRect, circle, or capsule).
    ///   - opacity: The opacity level for the glass effect (default: 0.6).
    ///     Higher values make the glass more opaque, lower values more transparent.
    ///   - tint: Tint color for the glass effect.
    ///   - hoverEffect: If `true`, shows a subtle fill on pointer hover. Default is `false`.
    ///   - angle: The ``LightAngle`` direction for the highlight gradient. Defaults to `.topLeading`.
    ///
    /// The target platform version defaults to `.v26`; set it with the
    /// `.liquidGlassVersion(_:)` view modifier (app-wide at a root view, or
    /// per-view).
    /// - Returns: A view with a glass background effect applied.
    public func liquidGlass(
        shape: BackgroundShape = .capsule,
        opacity: CGFloat = 0.6,
        tint: Color? = nil,
        hoverEffect: Bool = false,
        angle: LightAngle = .topLeading
    ) -> some View {
        self.modifier(
            GlassEffectModifier(
                shape: shape,
                opacity: opacity,
                tint: tint,
                hoverEffect: hoverEffect,
                angle: angle
            )
        )
    }
}
