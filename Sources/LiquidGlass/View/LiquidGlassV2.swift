//
//  LiquidGlassV2.swift
//  LiquidGlass
//
//  A refreshed “v2” look that keeps the original API spirit but adds
//  richer depth: adaptive tinting, inner/outer glow, dual-edge lighting,
//  and a subtle sparkle highlight. No Combine; SwiftUI-only.
//

import SwiftUI

/// A second‑generation Liquid Glass style.
///
/// Goals:
/// - Preserve the simple shape‑first API.
/// - Compose a few lightweight layers (materials, strokes, glows) for a deeper glass look.
/// - Keep platform coverage (iOS 15+/macOS 12+).
public struct LiquidGlassV2: View {
    // MARK: - Configuration
    public struct Configuration {
        public let opacity: CGFloat
        public let tint: Color?
        public let lightAngle: LightAngle
        public let edgeGlow: CGFloat
        public let innerGlow: CGFloat
        public let sparkle: CGFloat
        public let shadowRadius: CGFloat

        public init(
            opacity: CGFloat = 0.6,
            tint: Color? = nil,
            lightAngle: LightAngle = .topLeading,
            edgeGlow: CGFloat = 0.8,
            innerGlow: CGFloat = 0.6,
            sparkle: CGFloat = 0.35,
            shadowRadius: CGFloat = 10
        ) {
            self.opacity = opacity
            self.tint = tint
            self.lightAngle = lightAngle
            self.edgeGlow = edgeGlow
            self.innerGlow = innerGlow
            self.sparkle = sparkle
            self.shadowRadius = shadowRadius
        }
    }

    // MARK: - Stored
    private let shape: BackgroundShape
    private let config: Configuration

    // MARK: - Init
    public init(shape: BackgroundShape, config: Configuration = .init()) {
        self.shape = shape
        self.config = config
    }

    // MARK: - Body
    public var body: some View {
        switch shape {
        case .roundedRect(let cornerRadius):
            effect(baseShape: RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            effect(baseShape: Circle())
        case .capsule:
            effect(baseShape: Capsule())
        }
    }

    // MARK: - Layers
    @ViewBuilder
    private func effect(baseShape: some InsettableShape) -> some View {
        let opacity = max(0, min(1, config.opacity))
        let highlightOpacity = opacity * 0.75
        let edgeGlow = max(0, min(1, config.edgeGlow))
        let innerGlow = max(0, min(1, config.innerGlow))
        let sparkle = max(0, min(1, config.sparkle))

        baseShape
            // 1) Frosted base using material
            .fill(.ultraThinMaterial)
            // Optional color wash or neutral highlight
            .overlay {
                if let tint = config.tint {
                    baseShape.fill(tint.opacity(opacity * 0.35))
                } else {
                    baseShape.fill(Color.highlight.opacity(highlightOpacity * 0.6))
                }
            }
            // 2) Dual edge lighting depending on lightAngle
            .overlay(alignment: .topLeading) {
                if config.lightAngle == .topLeading || config.lightAngle == .all {
                    baseShape.inset(by: 0.5)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55 * edgeGlow),
                                    Color.white.opacity(0.15 * edgeGlow),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.0
                        )
                        .blendMode(.plusLighter)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if config.lightAngle == .bottomTrailing || config.lightAngle == .all {
                    baseShape.inset(by: 0.5)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.20 * edgeGlow),
                                    Color.black.opacity(0.05 * edgeGlow),
                                    .clear
                                ],
                                startPoint: .bottomTrailing,
                                endPoint: .topLeading
                            ), lineWidth: 1.0
                        )
                        .blendMode(.softLight)
                }
            }
            // 3) Subtle inner glow to simulate thickness
            .overlay {
                baseShape
                    .inset(by: 1)
                    .stroke(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.20 * innerGlow),
                                Color.white.opacity(0.05 * innerGlow),
                                .clear
                            ],
                            center: .center, startRadius: 2, endRadius: 60
                        ), lineWidth: 1
                    )
                    .blendMode(.screen)
            }
            // 4) Sparkle highlight streak masked to shape
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let minSide = min(w, h)
                    let thickness = max(1, minSide * 0.06)

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.25 * sparkle),
                            Color.white.opacity(0.55 * sparkle),
                            Color.white.opacity(0.18 * sparkle),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: w * 1.2, height: thickness)
                    .offset(x: -w * 0.1, y: h * 0.18)
                    .rotationEffect(.degrees(12))
                    .mask(baseShape)
                    .allowsHitTesting(false)
                }
            }
            // 5) Soft drop shadow for lift
            .shadow(color: Color.shadow.opacity(opacity), radius: config.shadowRadius, x: 0, y: 0)
            .compositingGroup()
    }
}

// MARK: - Preview
#Preview("LiquidGlassV2 Examples") {
    VStack(spacing: 24) {
        LiquidGlassV2(shape: .roundedRect(cornerRadius: 16))
            .frame(width: 220, height: 100)
        LiquidGlassV2(shape: .circle)
            .frame(width: 120, height: 120)
        LiquidGlassV2(shape: .capsule)
            .frame(width: 200, height: 56)
    }
    .padding(40)
    .background(
        LinearGradient(colors: [.purple.opacity(0.35), .blue.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    )
}
