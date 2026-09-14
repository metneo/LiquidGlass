//
//  GlassButtonStyle.swift
//  LiquidGlass
//
//

import SwiftUI

/// A button style that creates beautiful frosted glass effects with customizable shapes and tinting.
///
/// `GlassButtonStyle` provides a modern glass appearance for buttons with automatic platform adaptation.
/// On iOS 26+ and macOS 26+, it uses system glass button styles for optimal performance and consistency.
/// On earlier platforms, it falls back to custom glass rendering using the LiquidGlass framework.
///
/// ## Usage
///
/// Apply the glass style to any button:
///
/// ```swift
/// Button("Click Me") {
///     // Action
/// }
/// .buttonStyle(GlassButtonStyle())
/// ```
///
/// Customize the shape and prominence:
///
/// ```swift
/// Button("Primary Action") {
///     // Action
/// }
/// .buttonStyle(
///     GlassButtonStyle(
///         shape: .capsule,
///         prominent: true
///     )
///     .tint(.blue)
/// )
/// ```
///
/// ## Features
///
/// - **Shape Customization**: Supports rounded rectangles, circles, and capsules
/// - **Prominence Levels**: Regular and prominent styles for visual hierarchy
/// - **Custom Tinting**: Apply brand colors with the `.tint(_:)` modifier
/// - **Platform Adaptive**: Uses system styles on newer platforms, custom rendering on older ones
/// - **Hover Effects**: Automatic hover states and press feedback
/// - **Performance Optimized**: Minimal view hierarchy and efficient rendering
fileprivate struct GlassButtonStyle: ButtonStyle {
    // MARK: - Properties
    
    /// The background shape for the button.
    private let shape: BackgroundShape
    
    /// Whether to use the prominent glass style (more visible/emphasized).
    private let prominent: Bool
    
    /// Optional tint color for customizing the glass appearance.
    /// When `nil`, uses the system accent color for prominent styles.
    private let tint: Color?
    
    private let opacity: CGFloat
    
    // MARK: - Initializer
    
    /// Creates a glass button style with the specified shape and prominence level.
    ///
    /// - Parameters:
    ///   - shape: The background shape for the button. Defaults to a rounded rectangle with 12pt corners.
    ///            Available options: `.roundedRect(cornerRadius:)`, `.circle`, `.capsule`.
    ///   - prominent: Whether to use the prominent (emphasized) glass style. Defaults to `false`.
    ///                Prominent buttons have enhanced visual weight and are ideal for primary actions.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Default rounded rectangle button
    /// GlassButtonStyle()
    ///
    /// // Circular button
    /// GlassButtonStyle(shape: .circle)
    ///
    /// // Prominent capsule button for primary actions
    /// GlassButtonStyle(shape: .capsule, prominent: true)
    /// ```
    init(shape: BackgroundShape = .roundedRect(cornerRadius: 12), prominent: Bool = false, tint: Color? = nil, opacity: CGFloat = 0.8) {
        self.shape = shape
        self.prominent = prominent
        self.tint = tint
        self.opacity = opacity
    }
    
    /// Applies a custom tint color to the glass button style.
    ///
    /// The tint color affects the glass appearance, providing subtle color theming
    /// while maintaining the translucent glass effect. On prominent buttons,
    /// the tint is more visible and enhances the button's visual weight.
    ///
    /// - Parameter tint: The color to tint the glass effect, or `nil` to use
    ///                   the system accent color for prominent styles.
    /// - Returns: A new `GlassButtonStyle` instance with the specified tint applied.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Blue-tinted glass button
    /// GlassButtonStyle().tint(.blue)
    ///
    /// // Remove custom tinting (use system accent)
    /// GlassButtonStyle().tint(nil)
    ///
    /// // Brand color for prominent button
    /// GlassButtonStyle(prominent: true).tint(.orange)
    /// ```
    /// The effective color used for prominent button styling.
    /// Returns the custom tint if provided, otherwise falls back to the system accent color.
    private var prominentColor: Color {
        tint ?? .accentColor
    }
    
    // MARK: - ButtonStyle Protocol
    
    /// Creates the styled button content with platform-appropriate glass effects.
    ///
    /// Custom glass rendering using the `.liquidGlass()`
    /// modifier, providing consistent visual appearance across all supported platforms.
    ///
    /// The implementation automatically handles:
    /// - Press state feedback with color adjustments
    /// - Hover effects for supported platforms
    /// - Tint color application and prominence styling
    /// - Shape-specific rendering optimizations
    ///
    /// - Parameter configuration: The button configuration containing label and interaction state.
    /// - Returns: A view representing the styled button with glass effects applied.
    public func makeBody(configuration: Configuration) -> some View {
        let tintColor: Color? = configuration.isPressed ? nil : (prominent ? prominentColor : nil)
        // Use custom glass background for earlier platforms
        configuration.label
            .padding(5)
            .buttonStyle(.plain)
            .liquidGlass(shape: shape, opacity: opacity, tint: tintColor, hoverEffect: !configuration.isPressed)
    }
}

fileprivate struct GlassButtonMidifier: ViewModifier {
    
    // MARK: - Properties
    
    /// The background shape for the button.
    private let shape: BackgroundShape
    
    /// Whether to use the prominent glass style (more visible/emphasized).
    private let prominent: Bool
    
    /// Optional tint color for customizing the glass appearance.
    /// When `nil`, uses the system accent color for prominent styles.
    private let tint: Color?
    
    private let opacity: CGFloat
    
    /// The effective color used for prominent button styling.
    /// Returns the custom tint if provided, otherwise falls back to the system accent color.
    private var prominentColor: Color {
        tint ?? .accentColor
    }
    
    init(shape: BackgroundShape, prominent: Bool, tint: Color? = nil, opacity: CGFloat) {
        self.shape = shape
        self.prominent = prominent
        self.tint = tint
        self.opacity = opacity
    }
    
    // MARK: - Private Helpers
    
    /// Applies the appropriate system glass button style for Platform 26+.
    ///
    /// Uses the native `.glass` and `.glassProminent` button styles introduced in Platform 26,
    /// providing optimal performance and platform consistency. Automatically applies
    /// the configured tint color when available.
    ///
    /// - Parameter label: The button's label content to style.
    /// - Returns: A view with the appropriate system glass button style applied.
    ///
    @ViewBuilder
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, visionOS 26.0, tvOS 26.0, *)
    private func systemGlassButton(content: Content) -> some View {
#if !os(visionOS)
        if prominent {
            content
                .buttonStyle(.glassProminent)
                .tint(prominentColor)
        } else {
            content.buttonStyle(.glass)
        }
#else
        if prominent {
            content
                .buttonStyle(.borderedProminent)
                .tint(prominentColor)
        } else {
            content
        }
#endif
    }
    
    /// Applies system button border shapes for Platform 14+.
    ///
    /// Maps the custom `BackgroundShape` values to system `ButtonBorderShape` equivalents
    /// for consistent appearance with platform design guidelines.
    ///
    /// - Parameter content: The view content to apply the button shape to.
    /// - Returns: The content view with the appropriate button border shape applied.
    @ViewBuilder
    @available(macOS 14.0, iOS 17.0, watchOS 9.0, tvOS 16.0, *)
    private func applySystemButtonShape<T: View>(to content: T) -> some View {
        switch shape {
        case .roundedRect(let cornerRadius):
            content.buttonBorderShape(.roundedRectangle(radius: cornerRadius))
        case .circle:
            content
                .buttonBorderShape(.circle)
        case .capsule:
            content.buttonBorderShape(.capsule)
        }
    }
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, visionOS 26.0, tvOS 26.0, *) {
            // Use system glass button styles on Platform 26+
            applySystemButtonShape(to: systemGlassButton(content: content))
        } else {
            content
                .buttonStyle(GlassButtonStyle(shape: shape, prominent: prominent, tint: tint, opacity: opacity))
        }
    }
}

public extension Button {
    @MainActor func glassStyleButton(shape: BackgroundShape = .roundedRect(cornerRadius: 12), prominent: Bool = false, tint: Color? = nil, opacity: CGFloat = 0.8) -> some View {
        self.modifier(GlassButtonMidifier(shape: shape, prominent: prominent, tint: tint, opacity: opacity))
    }
}


#Preview("Glass Button Styles") {
    VStack(spacing: 20) {
        // Basic glass button
        Button("Tap Me!") {
            //
        }
        .padding(12)
        .buttonStyle(GlassButtonStyle(shape: .capsule))
        
        // Prominent tinted button
        Button("Primary Action") {
            //
        }
        .padding(12)
        .buttonStyle(
            GlassButtonStyle(
                shape: .roundedRect(cornerRadius: 16),
                prominent: true,
                tint: .blue
            )
        )
        
        // Circular button
        Button {
            //
        } label: {
            Image(systemName: "heart.fill")
                .font(.title2)
                .padding()
        }
        .buttonStyle(GlassButtonStyle(shape: .circle))
    }
    .padding()
}
