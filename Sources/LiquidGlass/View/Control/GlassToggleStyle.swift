//
//  GlassToggleStyle.swift
//  LiquidGlass
//
//

import SwiftUI

/// A toggle style that switches between expanded and collapsed states with glass effects.
///
/// `GlassToggleStyle` creates an animated toggle that shows the full label when on
/// and only the icon when off, both with glass backgrounds that adapt their shapes.
///
/// ```swift
/// Toggle("Settings", systemImage: "gear", isOn: $isEnabled)
///     .toggleStyle(GlassToggleStyle().tint(.blue))
/// ```
public struct GlassToggleStyle: ToggleStyle {

    // MARK: - Properties
    
    /// Optional tint color for the icon when enabled.
    private var tint: Color?
    
    /// The height of the toggle in both collapsed and expanded states.
    private var toggleHeight: CGFloat = 25
    
    /// Horizontal padding applied to the expanded state content.
    private var horizontalPadding: CGFloat = 8
    
    private var opacity: CGFloat = 0.6
    
    // MARK: - Initializer
    
    /// Creates a glass toggle style with default dimensions.
    public init() {
    }
    
    /// Sets the height for both collapsed and expanded toggle states.
    /// - Parameter height: The desired height in points.
    /// - Returns: A new `GlassToggleStyle` with the specified height.
    public func height(_ height: CGFloat) -> Self {
        var copy = self
        copy.toggleHeight = height
        return copy
    }
    
    /// Sets the horizontal padding for the expanded state content.
    /// - Parameter horizontal: The horizontal padding in points.
    /// - Returns: A new `GlassToggleStyle` with the specified padding.
    public func padding(_ horizontal: CGFloat) -> Self {
        var copy = self
        copy.horizontalPadding = horizontal
        return copy
    }

    // MARK: - Fluent API
    
    /// Returns a modified toggle style with the specified tint color.
    /// - Parameter color: The color to apply to the icon when the toggle is enabled.
    /// - Returns: A new `GlassToggleStyle` with the specified tint.
    public func tint(_ color: Color?) -> Self {
        var copy = self
        copy.tint = color
        return copy
    }
    
    public func glassOpacity(_ opacity: CGFloat) -> Self {
        var copy = self
        copy.opacity = opacity
        return copy
    }

    // MARK: - ToggleStyle Protocol
    
    public func makeBody(configuration: Configuration) -> some View {
        Group {
            if configuration.isOn {
                // Expanded state: show full label with capsule background
                configuration.label
                    .labelStyle(ToggleLabelStyle(tint: tint))
                    .padding(.horizontal, horizontalPadding)
                    .frame(height: toggleHeight)
                    .liquidGlass(shape: .capsule, hoverEffect: true)
            } else {
                // Collapsed state: show only icon with circular background
                configuration.label
                    .labelStyle(.iconOnly)
                    .frame(width: toggleHeight, height: toggleHeight)
                    .liquidGlass(shape: .circle, opacity: opacity, hoverEffect: true)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: configuration.isOn)
        .transition(availableTransition)
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
    
    /// Returns the appropriate transition based on platform availability.
    private var availableTransition: AnyTransition {
        if #available(macOS 14.0, iOS 17.0, *) {
            AnyTransition(.opacity.combined(with: .symbolEffect))
        } else {
            AnyTransition.opacity
        }
    }
}

// MARK: - Private Label Style

/// Internal label style that applies optional tinting to the icon.
/// 
/// This style enhances the standard `.titleAndIcon` style by adding
/// custom color theming and filled symbol variants for better visual consistency.
private struct ToggleLabelStyle: LabelStyle {
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            if let tint = tint {
                configuration.icon
                    .foregroundStyle(tint)
            } else {
                configuration.icon
            }
        }
        .labelStyle(.titleAndIcon)
        .symbolVariant(.fill)
    }
}
