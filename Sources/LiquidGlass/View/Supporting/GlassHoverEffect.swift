//
//  GlassHoverEffect.swift
//  LiquidGlass
//
//  Shared shape-matched hover highlight for glass modifiers.
//  Replaces the duplicated hover state + shape mask previously kept in
//  GlassEffectModifier.
//

import SwiftUI

/// A view modifier that draws a subtle, shape-matched fill while the pointer
/// hovers the content (macOS). The fill adapts to the current color scheme.
///
/// This is an internal implementation detail shared by all glass modifiers.
struct GlassHoverEffect: ViewModifier {
    /// The background shape used to match the hover highlight.
    private let shape: BackgroundShape

    /// Whether hover highlighting is enabled.
    private let enabled: Bool

    @Environment(\.colorScheme) private var colorScheme

    @State private var onHover: Bool = false

    init(shape: BackgroundShape, enabled: Bool) {
        self.shape = shape
        self.enabled = enabled
    }

    func body(content: Content) -> some View {
        content
            .background {
                // `shape.shape` maps each case to the matching shape, so no
                // per-case switch is needed for the hover fill.
                shape.shape.fill(hoverStyle)
            }
            #if os(macOS)
                .onHover { hovering in
                    if enabled {
                        withAnimation { onHover = hovering }
                    }
                }
            #endif
    }

    /// The hover fill style — a quinary fill in dark mode, white in light mode.
    private var hoverStyle: AnyShapeStyle {
        guard enabled && onHover else { return AnyShapeStyle(.clear) }
        return colorScheme == .dark ? AnyShapeStyle(.quinary) : AnyShapeStyle(.white)
    }
}

extension View {
    /// Applies the shared shape-matched hover highlight.
    func glassHoverEffect(shape: BackgroundShape, enabled: Bool) -> some View {
        modifier(GlassHoverEffect(shape: shape, enabled: enabled))
    }
}
