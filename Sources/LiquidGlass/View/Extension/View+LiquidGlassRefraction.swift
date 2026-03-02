//
//  View+LiquidGlassRefraction.swift
//  LiquidGlass
//
//  Convenience modifier for the refraction-based glass.
//

import SwiftUI

extension View {
    // Convenience overload: pass common knobs directly without constructing Configuration.
    public func liquidGlassWithRefraction(
        shape: BackgroundShape = .capsule,
        opacity: CGFloat = 0.65,
        tint: Color? = nil,
        refract: CGFloat = 0.6,
        frequency: CGFloat = 36.0,
        highlight: CGFloat = 0.35,
        shadowRadius: CGFloat = 10
    ) -> some View {
        let cfg = LiquidGlassRefraction.Configuration(
            opacity: opacity,
            tint: tint,
            refract: refract,
            frequency: frequency,
            highlight: highlight,
            shadowRadius: shadowRadius
        )
        return self.modifier(GlassRefractionModifier(shape: shape, config: cfg))
    }
}
