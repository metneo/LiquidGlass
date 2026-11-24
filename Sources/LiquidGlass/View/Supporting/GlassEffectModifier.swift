//
//  GlassEffectModifier.swift
//  LiquidGlass
//
//  A ViewModifier that applies a glass effect to any SwiftUI view.
//

import SwiftUI

// MARK: - Environment

private struct LiquidGlassForcesCustomKey: EnvironmentKey {
    /// Default to the system's native `glassEffect(in:)` on Platform 26+.
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether to force the custom Liquid Glass renderer even on platforms
    /// that support the native `glassEffect(in:)` API.
    ///
    /// Set through the public `forceToCustomLiquidGlass(_:)` modifier. Defaults to
    /// `false` (use the native API when available).
    var liquidGlassForcesCustom: Bool {
        get { self[LiquidGlassForcesCustomKey.self] }
        set { self[LiquidGlassForcesCustomKey.self] = newValue }
    }
}

public extension View {
    /// Forces the custom Liquid Glass renderer instead of the system's native
    /// `glassEffect(in:)` on Platform 26+.
    ///
    /// The library defaults to Apple's native Liquid Glass on Platform 26+
    /// (iOS 26 / macOS 26). Call this with `true` (the default) to always use
    /// the custom ``LiquidGlass`` renderer — useful for previewing the fallback
    /// look that older platforms get, or for keeping a consistent custom style
    /// everywhere. Pass `false` to let the native API be used where available.
    ///
    /// This also applies to glass controls, such as
    /// `Button.glassStyleButton(shape:prominent:tint:opacity:)`.
    ///
    /// Apply it app-wide at a root view, or on an individual view to scope it to
    /// a subtree.
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello, World!")
    ///     .padding()
    ///     .liquidGlass(shape: .roundedRect(cornerRadius: 16))
    ///     .forceToCustomLiquidGlass()  // always use the custom renderer
    /// ```
    ///
    /// - Parameter force: Pass `true` (the default) to force the custom
    ///   renderer, or `false` to allow the native implementation on Platform 26+.
    /// - Returns: A view with the glass implementation preference applied.
    func forceToCustomLiquidGlass(_ force: Bool = true) -> some View {
        environment(\.liquidGlassForcesCustom, force)
    }

    /// Controls whether the system's native `glassEffect(in:)` is used on
    /// Platform 26+, or the custom ``LiquidGlass`` implementation.
    ///
    /// - Parameter usesSystemImplementation: Pass `false` to always use the
    ///   custom renderer. Defaults to `true` (use the native API when available).
    /// - Returns: A view with the glass implementation preference applied.
    @available(*, deprecated, message: "Use .forceToCustomLiquidGlass() instead.")
    func liquidGlassUsesSystemImplementation(_ usesSystemImplementation: Bool) -> some View {
        environment(\.liquidGlassForcesCustom, !usesSystemImplementation)
    }
}

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

    /// When `true`, always use the custom renderer regardless of OS version.
    @Environment(\.liquidGlassForcesCustom) private var forcesCustom

    func body(content: Content) -> some View {
        renderGlassEffect(content: content)
            .glassHoverEffect(shape: shape, enabled: hoverEffect)
            .compositingGroup()
    }

    // MARK: - Private Helpers

    @ViewBuilder
    private func renderGlassEffect(content: Content) -> some View {
        if !forcesCustom, #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
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
