//
//  LiquidGlassRefraction.swift
//  LiquidGlass
//
//  Shader-based "v3" style using SwiftUI layerEffect + Metal shader for
//  micro refraction and a diagonal sheen. Falls back to LiquidGlassV2
//  on older OS versions.
//

import SwiftUI

struct LiquidGlassRefraction: View {
    struct Configuration {
        public var opacity: CGFloat = 0.65     // base presence of the glass
        public var tint: Color? = nil          // optional color wash
        public var refract: CGFloat = 0.6      // 0…1, refraction strength
        public var frequency: CGFloat = 36.0   // wave frequency for micro undulation
        public var highlight: CGFloat = 0.35   // 0…1, diagonal sheen
        public var shadowRadius: CGFloat = 10
        public init() {}
        public init(opacity: CGFloat = 0.65,
                    tint: Color? = nil,
                    refract: CGFloat = 0.6,
                    frequency: CGFloat = 36.0,
                    highlight: CGFloat = 0.35,
                    shadowRadius: CGFloat = 10) {
            self.opacity = opacity
            self.tint = tint
            self.refract = refract
            self.frequency = frequency
            self.highlight = highlight
            self.shadowRadius = shadowRadius
        }
    }

    private let shape: BackgroundShape
    private var config: Configuration

    init(shape: BackgroundShape, config: Configuration = .init()) {
        self.shape = shape
        self.config = config
    }

    var body: some View {
        switch shape {
        case .roundedRect(let cornerRadius):
            effect(baseShape: RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            effect(baseShape: Circle())
        case .capsule:
            effect(baseShape: Capsule())
        }
    }

    @ViewBuilder
    func effect(baseShape: some InsettableShape) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            GeometryReader { proxy in
                let size = proxy.size
                baseShape
                    // Custom frosted base (keeps body)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(min(1.0, max(0.0, 0.95 * config.opacity))),
                                Color.white.opacity(min(1.0, max(0.0, 0.80 * config.opacity)))
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // Add true background blur (system material) clipped to shape
                    .overlay { baseShape.fill(Color.white.opacity(min(1.0, max(0.0, 0.35 * config.opacity)))).blur(radius: 8) }
                    // The refraction is applied only to a SwiftUI gradient overlay,
                    // so the shader layer contains no UIKit/AppKit-backed material.
                    .overlay {
                        let s = min(1.0, max(0.0, config.opacity))
                        let gradient = LinearGradient(
                            gradient: Gradient(colors: [
                                (config.tint ?? Color.white).opacity(0.90 * s),
                                Color.white.opacity(0.60 * s)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        gradient
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .mask(baseShape)
                            .compositingGroup()
                            .layerEffect(
                                makeShader(size: size,
                                           refract: config.refract,
                                           frequency: config.frequency,
                                           highlight: config.highlight),
                                maxSampleOffset: CGSize(width: 6, height: 6)
                            )
                    }
                    // Subtle inner highlight to sell thickness
                    .overlay {
                        baseShape
                            .inset(by: 0.5)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.05),
                                        .clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1
                            )
                            .blendMode(.screen)
                    }
                    .shadow(color: Color.shadow.opacity(config.opacity),
                            radius: config.shadowRadius, x: 0, y: 0)
            }
        } else {
            // Fallback to v2 custom composer on earlier OS versions
            LiquidGlassV2(shape: shape.asBackgroundShape, config: .init())
                .opacity(config.opacity)
                .tintColor(config.tint)
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
func makeShader(size: CGSize, refract: CGFloat, frequency: CGFloat, highlight: CGFloat) -> Shader {
    Shader(function: .init(library: .default, name: "glass_refraction"), arguments: [
        .float2(Float(size.width), Float(size.height)),
        .float(Float(refract)),
        .float(Float(frequency)),
        .float(Float(highlight))
    ])
}

private extension BackgroundShape {
    // Helper to reuse the enum value inside fallback branch
    var asBackgroundShape: BackgroundShape { self }
}

// High-contrast, detailed backdrop to better reveal refraction in Previews.
private struct RefractionPreviewBackdrop: View {
    var body: some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                center: .center
            )
            // Soft vertical banding to create additional edges to refract
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.18), .clear, Color.white.opacity(0.18)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)
            CheckerboardOverlay(tile: 18)
        }
        .ignoresSafeArea()
    }
}

private struct CheckerboardOverlay: View {
    var tile: CGFloat = 18
    var body: some View {
        GeometryReader { proxy in
            Canvas { ctx, rect in
                let cols = Int(rect.width / tile) + 2
                let rows = Int(rect.height / tile) + 2
                for row in 0..<rows {
                    for col in 0..<cols {
                        let r = CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                        let isLight = (row + col) % 2 == 0
                        let color = isLight ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
                        ctx.fill(Path(r), with: .color(color))
                    }
                }
            }
            .blendMode(.overlay)
            .opacity(0.9)
        }
    }
}

// MARK: - Preview
#Preview("LiquidGlass Refraction Examples") {
    VStack(spacing: 24) {
        Text("Liquid Glass")
            .padding()
            .liquidGlassRefraction(shape: .capsule, opacity: 0.7)
        
        Text("Liquid Glass")
            .padding()
            .glueGlass(id: "id", shape: .capsule)
        
        Text("Liquid Glass")
            .padding()
            .liquidGlass(shape: .capsule)
        
        if #available(macOS 26.0, *) {
            Text("Liquid Glass")
                .padding()
                .glassEffect()
        }
        
        LiquidGlassRefraction(shape: .roundedRect(cornerRadius: 16),
                              config: .init(opacity: 0.1, tint: Color.blue, refract: 0.65, frequency: 40, highlight: 0.40))
            .frame(width: 220, height: 100)

        LiquidGlassRefraction(shape: .circle,
                              config: .init(opacity: 0.3, tint: nil, refract: 0.55, frequency: 32, highlight: 0.35))
            .frame(width: 120, height: 120)

        LiquidGlassRefraction(shape: .capsule,
                              config: .init(opacity: 0.9, tint: Color.mint, refract: 0.6, frequency: 36, highlight: 0.4))
            .frame(width: 200, height: 56)
    }
    .padding(40)
    .background(RefractionPreviewBackdrop())
}
