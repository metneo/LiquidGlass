//
//  UIKitLiquidGlassExample.swift
//  LiquidGlass
//
//  Xcode previews for the SwiftUI-free UIKit LiquidGlassView.
//

#if canImport(UIKit) && !os(watchOS)

import SwiftUI
import UIKit

// MARK: - Wrappers

/// Hosts the UIKit ``LiquidGlassView`` inside SwiftUI so Xcode previews can
/// render the pure-UIKit glass implementation.
private struct UIKitGlass: UIViewRepresentable {
    var shape: LiquidGlassShape
    var tint: Color?
    var opacity: CGFloat = 0.6
    var style: LiquidGlassRenderer.Style = .v26

    func makeUIView(context: Context) -> LiquidGlassView {
        LiquidGlassView(
            shape: shape,
            tint: tint?.uiColor.cgColor,
            opacity: opacity,
            style: style
        )
    }

    func updateUIView(_ view: LiquidGlassView, context: Context) {
        view.shape = shape
        view.tint = tint?.uiColor.cgColor
        view.opacity = opacity
        view.style = style
    }
}

// MARK: - Previews

#Preview("UIKit Liquid Glass") {
    UIKitGlassPreview()
}

/// Preview host that drives both the SwiftUI fallback and the pure-UIKit
/// ``LiquidGlassView`` from one version picker.
private struct UIKitGlassPreview: View {
    @State private var version: LiquidGlassVersion = .v26

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
                }

                HStack(spacing: 24) {
                    UIKitGlass(shape: .capsule, style: style)
                        .frame(width: 200, height: 60)
                    UIKitGlass(
                        shape: .roundedRect(cornerRadius: 16),
                        tint: .blue,
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

// MARK: - Helpers

private extension Color {
    /// Maps a SwiftUI color onto UIKit's color model for the wrappers.
    var uiColor: UIColor { UIColor(self) }
}

#endif