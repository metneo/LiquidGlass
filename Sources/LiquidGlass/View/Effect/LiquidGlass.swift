//
//  LiquidGlass.swift
//  LiquidGlass
//

import SwiftUI

/// A SwiftUI view that renders a frosted-glass background for a ``BackgroundShape``.
///
/// ```swift
/// LiquidGlass(shape: .capsule)
///     .tint(.blue)
///     .opacity(0.8)
/// ```
///
/// `LiquidGlass` is a lightweight **router**: it reads the target platform
/// version from the `\.liquidGlassVersion` environment value and routes to the
/// matching version-specific renderer (`LiquidGlassV26` or `LiquidGlassV27`).
/// The rendering implementation lives in those internal types.
public struct LiquidGlass: View {
    // MARK: - Constants
    public static let defaultOpacity: CGFloat = 0.6
    public static let defaultLightAngle: LightAngle = .topLeading

    // MARK: - Stored properties

    /// Optional tint color. If not provided, `.accentColor` is used.
    private let tintColor: Color?

    /// Underlying shape to style (rounded rect, capsule, or circle)
    private let shape: BackgroundShape

    /// The opacity level for the glass effect (default: 0.6).
    /// Higher values make the glass more opaque, lower values more transparent.
    private let opacity: CGFloat

    private let lightAngle: LightAngle

    /// The target platform version, read from the `\.liquidGlassVersion`
    /// environment value (defaults to `.v26`).
    @Environment(\.liquidGlassVersion) private var version

    // MARK: - Initializer

    public init(
        shape: BackgroundShape,
        tintColor: Color? = nil,
        opacity: CGFloat = Self.defaultOpacity,
        lightAngle: LightAngle = Self.defaultLightAngle
    ) {
        self.shape = shape
        self.tintColor = tintColor
        self.opacity = opacity
        self.lightAngle = lightAngle
    }

    // MARK: - Body (router)

    @ViewBuilder
    public var body: some View {
        switch version {
        case .v26:
            LiquidGlassV26(shape: shape, tintColor: tintColor, opacity: opacity, lightAngle: lightAngle)
        case .v27:
            LiquidGlassV27(shape: shape, tintColor: tintColor, opacity: opacity, lightAngle: lightAngle)
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
