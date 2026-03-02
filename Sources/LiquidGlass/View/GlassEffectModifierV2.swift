//
//  GlassEffectModifierV2.swift
//  LiquidGlass
//
//  A v2 ViewModifier that prefers the system glass effect when available
//  and falls back to the richer custom LiquidGlassV2 look otherwise.
//

import SwiftUI

public struct GlassEffectModifierV2: ViewModifier {
    private let shape: BackgroundShape
    private let config: LiquidGlassV2.Configuration
    private let hoverEffect: Bool

    @State private var onHover: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    public init(shape: BackgroundShape,
                config: LiquidGlassV2.Configuration = .init(),
                hoverEffect: Bool = false) {
        self.shape = shape
        self.config = config
        self.hoverEffect = hoverEffect
    }

    public func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                #if !os(visionOS)
                // Prefer native .glassEffect(in:) when present; apply extra tint via .tint
                Group {
                    switch shape {
                    case .roundedRect(let radius):
                        content.glassEffect(in: RoundedRectangle(cornerRadius: radius))
                    case .circle:
                        content.glassEffect(in: .circle)
                    case .capsule:
                        content.glassEffect(in: .capsule)
                    }
                }
                .tint(config.tint)
                .backgroundStyle(hoverEffect && onHover ? AnyShapeStyle(hoverBackground) : AnyShapeStyle(.clear))
                #else
                content.background { fallbackV2 }
                #endif
            } else {
                content.background { fallbackV2 }
            }
        }
        #if os(macOS)
        .onHover { hovering in
            if hoverEffect { withAnimation { onHover = hovering } }
        }
        #endif
    }

    private var fallbackV2: some View {
        LiquidGlassV2(shape: shape, config: config)
            .background { maskHover }
    }
    
    @ViewBuilder
    private var maskHover: some View {
        switch shape {
        case .roundedRect(let r):
            RoundedRectangle(cornerRadius: r)
                .fill(hoverEffect && onHover ? AnyShapeStyle(hoverBackground) : AnyShapeStyle(.clear))
        case .circle:
            Circle()
                .fill(hoverEffect && onHover ? AnyShapeStyle(hoverBackground) : AnyShapeStyle(.clear))
        case .capsule:
            Capsule()
                .fill(hoverEffect && onHover ? AnyShapeStyle(hoverBackground) : AnyShapeStyle(.clear))
        }
    }
    
    private var hoverBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.quinary) : AnyShapeStyle(.white)
    }
}


