//
//  LiquidGlassView.swift
//  LiquidGlass
//
//  UIKit version of the Liquid Glass effect — no SwiftUI.
//

#if canImport(UIKit) && !os(watchOS)

import UIKit
import QuartzCore
import CoreGraphics

/// UIKit view that renders the Liquid Glass effect entirely with UIKit and
/// Core Graphics (no SwiftUI).
///
/// The view hosts a system ``UIVisualEffectView`` (the frosted backdrop,
/// clipped to a ``LiquidGlassShape`` through a layer mask) and paints the
/// accent layers — tint wash, highlight fill, decorative outline strokes and
/// full-outline border — with ``LiquidGlassRenderer``.
///
/// Example:
/// ```swift
/// let glass = LiquidGlassView(shape: .roundedRect(cornerRadius: 16))
/// glass.tint = UIColor.systemBlue.cgColor
/// glass.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
/// container.addSubview(glass)
/// ```
public final class LiquidGlassView: UIView {
    // MARK: - Public configuration

    /// The glass backing shape. Changes re-shape and redraw the effect.
    public var shape: LiquidGlassShape {
        didSet { shapeDidChange() }
    }

    /// Optional tint color. `nil` keeps the highlight neutral.
    public var tint: CGColor? {
        didSet { decoration.setNeedsDisplay() }
    }

    /// Gloss intensity of the highlight (0…1). Defaults to 0.6.
    public var opacity: CGFloat {
        didSet { decoration.setNeedsDisplay() }
    }

    /// Decorative outline style (`.v26` or `.v27`).
    public var style: LiquidGlassRenderer.Style {
        didSet { decoration.setNeedsDisplay() }
    }

    /// The system frosted-material style. Defaults to `.systemUltraThinMaterial`.
    public var blurStyle: UIBlurEffect.Style {
        didSet { effectView.effect = UIBlurEffect(style: blurStyle) }
    }

    /// Opacity of the frosting material view (`0…1`).
    ///
    /// Lower values let more of the backdrop through, reading as a more
    /// transparent glass. `nil` (the default) keeps the material at full
    /// opacity: UIKit's `.systemUltraThinMaterial` already matches SwiftUI's
    /// `.ultraThinMaterial`, so no easing is needed. Mirrors the AppKit
    /// ``LiquidGlassView/frostingOpacity`` control.
    public var frostingOpacity: CGFloat? {
        didSet { applyFrostingOpacity() }
    }

    // MARK: - Private hierarchy

    private let maskContainer = UIView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let decoration = DecorationView()

    // MARK: - Initializers

    public override init(frame: CGRect) {
        shape = .capsule
        tint = nil
        opacity = 0.6
        style = .v26
        blurStyle = .systemUltraThinMaterial
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a glass view. Use `.frame` / Auto Layout to size it.
    public convenience init(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: LiquidGlassRenderer.Style = .v26,
        blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial,
        frostingOpacity: CGFloat? = nil
    ) {
        self.init(frame: .zero)
        self.shape = shape
        self.tint = tint
        self.opacity = opacity
        self.style = style
        self.blurStyle = blurStyle
        self.frostingOpacity = frostingOpacity
    }

    public required init?(coder: NSCoder) {
        shape = .capsule
        tint = nil
        opacity = 0.6
        style = .v26
        blurStyle = .systemUltraThinMaterial
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Decorative: never intercept touches, so the view can sit behind (or
        // inside) interactive content without swallowing its events.
        isUserInteractionEnabled = false
        for view in [maskContainer, effectView, decoration] {
            view.isUserInteractionEnabled = false
        }
        addSubview(maskContainer)
        maskContainer.addSubview(effectView)
        addSubview(decoration)

        decoration.shape = shape
        decoration.tint = tint
        decoration.opacity = opacity
        decoration.style = style
        applyFrostingOpacity()

        updateMask()
        updateShadow()
    }

    private func applyFrostingOpacity() {
        effectView.alpha = frostingOpacity ?? 1
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        maskContainer.frame = bounds
        effectView.frame = maskContainer.bounds
        decoration.frame = bounds.insetBy(
            dx: -DecorationView.bleed,
            dy: -DecorationView.bleed
        )
        updateMask()
        updateShadow()
    }

    private func shapeDidChange() {
        decoration.shape = shape
        setNeedsLayout()
    }

    // MARK: - Shape mask + shadow

    /// Clips the frosted backdrop to the glass shape.
    private func updateMask() {
        let mask = CAShapeLayer()
        mask.fillColor = CGColor(gray: 1, alpha: 1)
        mask.path = shape.path(in: maskContainer.bounds)
        maskContainer.layer.mask = mask
    }

    /// The soft drop shadow behind the glass composite, drawn by the masked
    /// container's layer so it sits *behind* the frosted material.
    private func updateShadow() {
        let layer = maskContainer.layer
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = Float(isDarkAppearance ? 0.1 : 0.05)
        layer.shadowRadius = 15
        layer.shadowOffset = CGSize(width: 0, height: -6)
        layer.shadowPath = shape.path(in: maskContainer.bounds)
    }

    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    /// Re-renders when the system switches between light and dark appearance.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            decoration.setNeedsDisplay()
            updateShadow()
        }
    }
}

// MARK: - Decoration view

/// The sibling view that paints the accent layers on top of the material.
/// Flips the UIKit context to Core Graphics “y up” so the shared renderer sees
/// the same coordinate convention as on AppKit.
private final class DecorationView: UIView {
    /// Margin drawn around the glass shape so centered strokes (notably the
    /// v27 gray border) can render their outer half, matching SwiftUI's
    /// unclipped strokes.
    static let bleed: CGFloat = 2

    var shape: LiquidGlassShape = .capsule { didSet { setNeedsDisplay() } }
    var tint: CGColor? { didSet { setNeedsDisplay() } }
    var opacity: CGFloat = 0.6 { didSet { setNeedsDisplay() } }
    var style: LiquidGlassRenderer.Style = .v26 { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let isDark = traitCollection.userInterfaceStyle == .dark

        context.saveGState()
        // Normalize UIKit's flipped context to the renderer's y-up space.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        LiquidGlassRenderer(
            shape: shape,
            tint: tint,
            opacity: opacity,
            style: style,
            isDark: isDark
        ).draw(
            in: context,
            size: bounds.size,
            shapeRect: bounds.insetBy(dx: Self.bleed, dy: Self.bleed)
        )
        context.restoreGState()
    }
}

// MARK: - Convenience

public extension UIView {
    /// Inserts a `LiquidGlassView` at the back of the view's subview stack as
    /// its glass background. Returns the glass view so it can be tuned.
    @discardableResult
    func addLiquidGlassBackground(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: LiquidGlassRenderer.Style = .v26,
        frostingOpacity: CGFloat? = nil
    ) -> LiquidGlassView {
        let glass = LiquidGlassView(
            shape: shape,
            tint: tint,
            opacity: opacity,
            style: style,
            frostingOpacity: frostingOpacity
        )
        glass.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(glass, at: 0)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        return glass
    }
}

#endif