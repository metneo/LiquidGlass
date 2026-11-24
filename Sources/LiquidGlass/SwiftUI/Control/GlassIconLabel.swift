//
//  GlassIconLabel.swift
//  LiquidGlass
//
//  Created by Oren on 11/30/25.
//

import SwiftUI

/// A custom label style that displays icons within a glass-effect circular background.
///
/// `GlassIconLabel` creates visually appealing labels with frosted glass circular backgrounds
/// for icons, perfect for modern UI designs that require depth and visual hierarchy.
///
/// ```swift
/// Label("Settings", systemImage: "gear")
///     .labelStyle(GlassIconLabel(size: 32)
///         .tint(.blue)
///         .iconFont(.title2))
/// ```
///
/// ## Customization Options
///
/// - **Size**: Controls the diameter of the circular glass background
/// - **Tint**: Applies color tinting to the glass effect
/// - **Icon Font**: Customizes the icon's font style and size
/// - **Icon Tint**: Separate color control for the icon itself
/// - **Icon Only**: Option to hide the text and show only the icon
public struct GlassIconLabel: LabelStyle {
    // MARK: - Properties
    
    /// The diameter of the circular glass background in points.
    private let size: CGFloat
    
    /// Optional tint color applied to the glass effect background.
    private var tint: Color?
    
    /// Optional font style for the icon.
    private var iconFont: Font?
    
    /// Whether to display only the icon without the text label.
    private var showIconOnly: Bool
    
    /// Optional separate tint color for the icon itself.
    private var iconTint: Color?

    // MARK: - Initializer
    
    /// Creates a glass icon label style.
    ///
    /// - Parameters:
    ///   - size: The diameter of the circular glass background in points.
    ///   - tint: Optional tint color for the glass effect.
    ///   - iconFont: Optional font style for the icon.
    ///   - iconOnly: Whether to show only the icon without text.
    ///   - iconTint: Optional separate color for the icon.
    public init(
        size: CGFloat,
        tint: Color? = nil,
        iconFont: Font? = nil,
        iconOnly: Bool = false,
        iconTint: Color? = nil
    ) {
        self.size = size
        self.tint = tint
        self.iconFont = iconFont
        self.showIconOnly = iconOnly
        self.iconTint = iconTint
    }

    // MARK: - Fluent API
    
    /// Returns a modified label style with the specified tint color.
    /// - Parameter tint: The color to apply to the glass background.
    /// - Returns: A new `GlassIconLabel` with the specified tint.
    public func tint(_ tint: Color) -> GlassIconLabel {
        var copy = self
        copy.tint = tint
        return copy
    }

    /// Returns a modified label style with the specified icon font.
    /// - Parameter font: The font to apply to the icon.
    /// - Returns: A new `GlassIconLabel` with the specified font.
    public func iconFont(_ font: Font) -> GlassIconLabel {
        var copy = self
        copy.iconFont = font
        return copy
    }

    /// Returns a modified label style with the specified icon tint color.
    /// - Parameter tint: The color to apply to the icon.
    /// - Returns: A new `GlassIconLabel` with the specified icon tint.
    public func iconTint(_ tint: Color) -> GlassIconLabel {
        var copy = self
        copy.iconTint = tint
        return copy
    }

    /// Returns a modified label style that shows only the icon.
    /// - Returns: A new `GlassIconLabel` configured to show only the icon.
    public func iconOnly() -> GlassIconLabel {
        var copy = self
        copy.showIconOnly = true
        return copy
    }

    // MARK: - LabelStyle Protocol
    
    public func makeBody(configuration: Configuration) -> some View {
        let effectiveTint = tint ?? .accentColor
        let effectiveIconTint = iconTint ?? tint ?? .primary
        
        let label = Label {
            configuration.title
        } icon: {
            configuration.icon
                .font(iconFont)
                .foregroundColor(effectiveIconTint)
                .frame(width: size, height: size)
                .background(
                    LiquidGlass(shape: .circle)
                        .tint(effectiveTint)
                        .opacity(0.2)
                )
        }
        
        if showIconOnly {
            label.labelStyle(.iconOnly)
        } else {
            label
        }
    }
}
