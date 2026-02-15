//
//  View+LiquidGlassV2.swift
//  LiquidGlass
//
//  Public API surface for v2 effect.
//

import SwiftUI

public extension View {
    /// Apply the second‑generation Liquid Glass background.
    /// - Parameters:
    ///   - shape: Background shape (roundedRect/circle/capsule), default `.capsule`.
    ///   - config: Advanced configuration (opacity, tint, lighting, glows).
    ///   - hoverEffect: Optional macOS hover fill.
    func liquidGlassV2(
        shape: BackgroundShape = .capsule,
        config: LiquidGlassV2.Configuration = .init(),
        hoverEffect: Bool = false
    ) -> some View {
        self.modifier(GlassEffectModifierV2(shape: shape, config: config, hoverEffect: hoverEffect))
    }
}