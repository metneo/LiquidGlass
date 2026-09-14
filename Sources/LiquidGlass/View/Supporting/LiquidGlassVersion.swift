//
//  LiquidGlassVersion.swift
//  LiquidGlass
//
//  The target platform version for the glass effect, configurable through the
//  SwiftUI environment.
//

import SwiftUI

/// Selects the target Apple platform version for the glass effect.
///
/// On the version's platform and newer, the system's native `glassEffect(in:)`
/// is used. On older platforms it falls back to the custom renderer.
public enum LiquidGlassVersion: Sendable {
    /// Use the native glass effect on Platform 26+ (iOS 26 / macOS 26).
    /// Below that, fall back to the custom renderer.
    case v26

    /// Use the native glass effect on Platform 27+ (future). Until it ships,
    /// falls back to the custom renderer.
    case v27

    // Additional platform cases are added as Apple ships new versions.
}

// MARK: - Environment

private struct LiquidGlassVersionKey: EnvironmentKey {
    static let defaultValue: LiquidGlassVersion = .v26
}

extension EnvironmentValues {
    /// The target Apple platform version for Liquid Glass effects (internal).
    ///
    /// Set through the public ``SwiftUICore/View/liquidGlassVersion(_:)``
    /// modifier. Defaults to `.v26`.
    var liquidGlassVersion: LiquidGlassVersion {
        get { self[LiquidGlassVersionKey.self] }
        set { self[LiquidGlassVersionKey.self] = newValue }
    }
}

public extension View {
    /// Sets the target Apple platform version for the glass effect.
    ///
    /// The effect renders the look associated with the given version, using
    /// the system's native `glassEffect(in:)` on the version's platform and
    /// newer, and a matching custom style on older platforms.
    ///
    /// Apply it app-wide at a root view to set a default for the whole
    /// hierarchy, or on an individual view to scope it to a subtree.
    ///
    /// Example usage:
    /// ```swift
    /// LiquidGlass(shape: .capsule)
    ///     .liquidGlassVersion(.v27)
    /// ```
    ///
    /// - Parameter version: The ``LiquidGlassVersion`` to target. Defaults to
    ///   `.v26` when unset.
    /// - Returns: A view that renders its glass effect for the given version.
    func liquidGlassVersion(_ version: LiquidGlassVersion) -> some View {
        environment(\.liquidGlassVersion, version)
    }
}
