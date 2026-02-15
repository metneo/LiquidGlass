//
//  LiquidGlassGlue.swift
//  LiquidGlass
//
//  "Glue" container that merges nearby glass shapes into a single blobby mask
//  (metaball-style). Implemented with blur + threshold, then filled with the
//  same refraction overlay. No system materials used.
//

import SwiftUI

public struct LiquidGlassGlueContainer<ID: Hashable, Content: View>: View {
    private let id: ID
    private let blur: CGFloat
    private let threshold: CGFloat
    private var config: LiquidGlassRefraction.Configuration
    private let content: Content

    init(id: ID,
                blur: CGFloat = 10,
                threshold: CGFloat = 0.5,
                config: LiquidGlassRefraction.Configuration,
                @ViewBuilder content: () -> Content) {
        self.id = id
        self.blur = blur
        self.threshold = threshold
        self.config = config
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
        }
        .background { glueFill.mask(glueMask) }
    }

    // MARK: - Glue Mask
    private var glueMask: some View {
        GeometryReader { proxy in
            ZStack {
                // Collect the registered shapes for this group from preferences
                Color.clear
                    .overlayPreferenceValue(GluePrefKey.self) { items in
                        Canvas { ctx, rect in
                            for item in items where item.groupAnyHashable == AnyHashable(id) {
                                let r = item.rect
                                let path: Path = pathFor(shape: item.shape, in: r)
                                ctx.fill(path, with: .color(.white))
                            }
                        }
                    }
            }
            .compositingGroup()
            .blur(radius: blur)
            .modifier(AlphaThresholdIfAvailable(threshold: threshold))
        }
    }

    // MARK: - Glue Fill (same refraction overlay clipped to mask)
    private var glueFill: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let s = min(1.0, max(0.0, config.opacity))
            let gradient = LinearGradient(
                gradient: Gradient(colors: [
                    (config.tint ?? Color.white).opacity(0.90 * s),
                    Color.white.opacity(0.60 * s)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(gradient)
                .compositingGroup()
                .modifier(RefractionIfAvailable(size: size,
                                               refract: config.refract,
                                               frequency: config.frequency,
                                               highlight: config.highlight))
                .shadow(color: Color.shadow.opacity(config.opacity),
                        radius: config.shadowRadius, x: 0, y: 0)
        }
    }
}

// MARK: - Registration
public extension View {
    func glueGlass<ID: Hashable>(id: ID, shape: BackgroundShape) -> some View {
        self.anchorPreference(key: GluePrefKey.self, value: .bounds) { anchor in
            [GlueItem(groupAnyHashable: AnyHashable(id), anchor: anchor, shape: shape)]
        }
    }
}

// MARK: - Prefs
fileprivate struct GlueItem: Equatable {
    var groupAnyHashable: AnyHashable
    var anchor: Anchor<CGRect>
    var shape: BackgroundShape
    var rect: CGRect = .zero

    static func == (lhs: GlueItem, rhs: GlueItem) -> Bool {
        lhs.groupAnyHashable == rhs.groupAnyHashable && lhs.anchor == rhs.anchor
    }
}

fileprivate struct GluePrefKey: PreferenceKey {
    static var defaultValue: [GlueItem] { [] }
    static func reduce(value: inout [GlueItem], nextValue: () -> [GlueItem]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Helpers
fileprivate func pathFor(shape: BackgroundShape, in rect: CGRect) -> Path {
    switch shape {
    case .roundedRect(let cornerRadius):
        return CustomShape(shape: shape, animatableCornerRadius: cornerRadius).path(in: rect)
    case .circle, .capsule:
        return CustomShape(shape: shape).path(in: rect)
    }
}

fileprivate struct AlphaThresholdIfAvailable: ViewModifier {
    var threshold: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            content.layerEffect(
                Shader(function: .init(library: .default, name: "alpha_threshold"), arguments: [
                    .float(Float(threshold))
                ]),
                maxSampleOffset: .zero
            )
        } else {
            content
        }
    }
}
fileprivate struct RefractionIfAvailable: ViewModifier {
    var size: CGSize
    var refract: CGFloat
    var frequency: CGFloat
    var highlight: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            content.layerEffect(
                Shader(function: .init(library: .default, name: "glass_refraction"), arguments: [
                    .float2(Float(size.width), Float(size.height)),
                    .float(Float(refract)),
                    .float(Float(frequency)),
                    .float(Float(highlight))
                ]),
                maxSampleOffset: CGSize(width: 6, height: 6)
            )
        } else {
            content
        }
    }
}

