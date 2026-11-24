//
//  LiquidGlassShape.swift
//  LiquidGlass
//
//  A SwiftUI-free shape model shared by the AppKit/UIKit renderers.
//

import CoreGraphics
import Foundation

/// A lightweight shape model used by the AppKit/UIKit glass renderers.
///
/// Mirrors ``BackgroundShape`` (iOS-style rounded rect / circle / capsule) but
/// is expressed purely in Quartz terms, so the platform glass views never need
/// to import SwiftUI. Use ``path(in:)`` to get the `CGPath` for a rectangle.
public enum LiquidGlassShape: Equatable, Sendable {
    /// A rounded rectangle with a customizable corner radius (in points).
    case roundedRect(cornerRadius: CGFloat)
    /// A perfect circle centered within the available bounds.
    case circle
    /// A capsule (pill shape) that rounds to half the smaller dimension.
    case capsule

    /// The Quartz path of the shape filling `rect`.
    ///
    /// The path is invariant under a vertical flip (every corner shares the
    /// same radius), so it works unchanged in both AppKit and UIKit layer
    /// coordinate conventions.
    public func path(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard rect.width.isFinite, rect.width > 0,
              rect.height.isFinite, rect.height > 0 else { return path }
        switch self {
        case .roundedRect(let cornerRadius):
            let radius = min(max(cornerRadius, 0), min(rect.width, rect.height) / 2)
            // Continuous corners from SwiftUI's RoundedRectangle are
            // approximated by CG's plain rounded rect — visually equivalent
            // for thin glass outlines.
            path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)

        case .circle:
            let diameter = min(rect.width, rect.height)
            path.addEllipse(in: CGRect(
                x: rect.midX - diameter / 2,
                y: rect.midY - diameter / 2,
                width: diameter,
                height: diameter
            ))

        case .capsule:
            let radius = min(rect.width, rect.height) / 2
            path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
        }
        return path
    }
}