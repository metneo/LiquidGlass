//
//  GlassPreviewBackground.swift
//  LiquidGlass
//

import SwiftUI

/// The shared gradient backdrop used by LiquidGlass previews.
///
/// Renders every demo sample against the same colorful surface so the glass
/// effect stays comparable across versions and shapes. Add it as a view
/// background, e.g. `.background { GlassPreviewBackground() }`.
struct GlassPreviewBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
