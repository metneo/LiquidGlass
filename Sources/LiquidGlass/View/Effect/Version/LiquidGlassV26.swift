//
//  LiquidGlassV26.swift
//  LiquidGlass
//

import SwiftUI

/// The Platform 26 glass renderer — the current `LiquidGlass` look.
///
/// Internal. Owns the shared rendering implementation (material fill, gradient
/// highlight, border stroke, soft shadow) used below Platform 26 for `.v26`
/// targets. Tune the v26 visuals here.
struct LiquidGlassV26: View {
    // MARK: - Constants
    private static let strokeLineWidth: CGFloat = 1.2
    private static let shadowRadius: CGFloat = 10
    private static let highlightOpacityMultiplier: CGFloat = 0.75

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
            GeometryReader { proxy in
                baseShape
                    .strokeBorder(
                        shape.gradient(
                            proxy: proxy,
                            highlighting: Color.stroke.opacity(opacity),
                            tint: tintColor,
                            angle: lightAngle
                        ),
                        lineWidth: Self.strokeLineWidth
                    )
                    .blendMode(.plusLighter)
            }
        case .none:
            EmptyView()
        }
    }
}
