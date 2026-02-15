//
//  GlassRefractionModifier.swift
//  LiquidGlass
//
//  Applies the refraction-based liquid glass as a background to any View.
//  Keeps behavior consistent with other modifiers in this package.
//

import SwiftUI

struct GlassRefractionModifier: ViewModifier {
    private let shape: BackgroundShape
    private var config: LiquidGlassRefraction.Configuration

    init(shape: BackgroundShape = .capsule,
                config: LiquidGlassRefraction.Configuration) {
        self.shape = shape
        self.config = config
    }

    func body(content: Content) -> some View {
        content.background {
            LiquidGlassRefraction(shape: shape, config: config)
        }
    }
}
