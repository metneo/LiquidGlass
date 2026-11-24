//
//  AppKitLiquidGlassExample.swift
//  LiquidGlass
//
//  Xcode previews for the SwiftUI-free AppKit LiquidGlassView.
//

#if canImport(AppKit)

import AppKit
import SwiftUI

/// Hosts the AppKit ``LiquidGlassView`` inside SwiftUI so Xcode previews can
/// render the pure-AppKit glass implementation.
private struct AppKitGlass: NSViewRepresentable {
    var shape: LiquidGlassShape
    var tint: CGColor?
    var opacity: CGFloat = 0.6
    var style: LiquidGlassRenderer.Style = .v26
    var material: NSVisualEffectView.Material? = nil
    var hoverEffect: Bool = false

    func makeNSView(context: Context) -> LiquidGlassView {
        LiquidGlassView(
            shape: shape,
            tint: tint,
            opacity: opacity,
            style: style,
            material: material,
            hoverEffect: hoverEffect
        )
    }

    func updateNSView(_ view: LiquidGlassView, context: Context) {
        view.shape = shape
        view.tint = tint
        view.opacity = opacity
        view.style = style
        if let material { view.material = material }
        view.hoverEffect = hoverEffect
    }
}

#Preview("AppKit Liquid Glass") {
    AppKitGlassPreview()
}

/// Preview host that drives both the SwiftUI fallback and the pure-AppKit
/// ``LiquidGlassView`` from one version picker.
private struct AppKitGlassPreview: View {
    @State private var version: LiquidGlassVersion = .v26

    /// The AppKit renderer style matching the selected version.
    private var style: LiquidGlassRenderer.Style {
        version == .v27 ? .v27 : .v26
    }

    var body: some View {
        ZStack {
            GlassPreviewBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Picker("Liquid Version", selection: $version) {
                    Text("v26").tag(LiquidGlassVersion.v26)
                    Text("v27").tag(LiquidGlassVersion.v27)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                HStack(spacing: 24) {
                    LiquidGlass(shape: .capsule)
                        .frame(width: 200, height: 60)
                    LiquidGlass(shape: .roundedRect(cornerRadius: 16))
                        .frame(width: 140, height: 140)
                    LiquidGlass(
                        shape: .roundedRect(cornerRadius: 16)
                    )
                    .frame(width: 140, height: 140)
                }

                HStack(spacing: 24) {
                    AppKitGlass(shape: .capsule, style: style)
                        .frame(width: 200, height: 60)
                    AppKitGlass(shape: .roundedRect(cornerRadius: 16), style: style)
                        .frame(width: 140, height: 140)
                    AppKitGlass(
                        shape: .roundedRect(cornerRadius: 16),
                        tint: NSColor.systemBlue.cgColor,
                        style: style
                    )
                    .frame(width: 140, height: 140)
                }
            }
            .padding(40)
        }
        .liquidGlassVersion(version)
    }
}

#Preview("AppKit Glass Hover") {
    AppKitGlassHoverPreview()
}

/// Preview host for the AppKit-only pointer-hover fill.
private struct AppKitGlassHoverPreview: View {
    var body: some View {
        ZStack {
            GlassPreviewBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Hover the glass")
                    .font(.headline)

                HStack(spacing: 24) {
                    AppKitGlass(
                        shape: .roundedRect(cornerRadius: 16),
                        hoverEffect: true
                    )
                    .frame(width: 180, height: 90)

                    AppKitGlass(
                        shape: .circle,
                        tint: NSColor.systemBlue.cgColor,
                        hoverEffect: true
                    )
                    .frame(width: 90, height: 90)
                }
            }
            .padding(40)
        }
    }
}

#endif
