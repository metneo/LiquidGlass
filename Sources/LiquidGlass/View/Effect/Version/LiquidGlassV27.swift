//
//  LiquidGlassV27.swift
//  LiquidGlass
//

import SwiftUI

/// The Platform 27 glass renderer — a dedicated style.
///
/// Internal. Compared to v26:
/// 1. the border stroke is darker,
/// 2. the highlight runs horizontally (0°) instead of the 45° diagonal.
struct LiquidGlassV27: View {
    // MARK: - Constants
    private static let strokeLineWidth: CGFloat = 1.2
    private static let shadowRadius: CGFloat = 10
    private static let highlightOpacityMultiplier: CGFloat = 0.75
    /// Multiplies the border stroke opacity — lower values darken the border.
    private static let strokeOpacityMultiplier: CGFloat = 0.6

    // MARK: - Stored properties
    private let tintColor: Color?
    private let shape: BackgroundShape
    private let opacity: CGFloat
    private let lightAngle: LightAngle

    // MARK: - Initializer
    init(
        shape: BackgroundShape,
        tintColor: Color? = nil,
        opacity: CGFloat = LiquidGlass.defaultOpacity,
        lightAngle: LightAngle = LiquidGlass.defaultLightAngle
    ) {
        self.shape = shape
        self.tintColor = tintColor
        self.opacity = opacity
        self.lightAngle = lightAngle
    }

    // MARK: - Body
    var body: some View {
        applyEffect(baseShape: shape.shape)
    }

    @ViewBuilder
    private func applyEffect(baseShape: some InsettableShape) -> some View {
        baseShape
            .foregroundStyle(.ultraThinMaterial)
            .overlay {
                highlightOverlay(baseShape: baseShape)
            }
            .overlay {
                strokeOverlay(baseShape: baseShape)
            }
            .shadow(color: Color.shadow.opacity(opacity), radius: Self.shadowRadius, x: 0, y: 0)
            .compositingGroup()
    }

    @ViewBuilder
    private func highlightOverlay(baseShape: some InsettableShape) -> some View {
        let highlight =
            tintColor ?? Color.highlight.opacity(opacity * Self.highlightOpacityMultiplier)
        baseShape.fill(highlight)
    }

    @ViewBuilder
    private func strokeOverlay(baseShape: some InsettableShape) -> some View {
        switch lightAngle {
        case .topLeading, .bottomTrailing, .all:
            baseShape
                .strokeBorder(strokeGradient(), lineWidth: Self.strokeLineWidth)
                .blendMode(.plusLighter)
        case .none:
            EmptyView()
        }
    }

    /// The darker, horizontal (0°) border highlight.
    private func strokeGradient() -> LinearGradient {
        let stroke = Color.stroke.opacity(opacity * Self.strokeOpacityMultiplier)
        return LinearGradient(
            colors: [stroke, stroke.opacity(0.3), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
