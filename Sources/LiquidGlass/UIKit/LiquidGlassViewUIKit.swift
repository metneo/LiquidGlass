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
/// clipped to a ``LiquidGlassShape`` with corner-radius clipping) and paints
/// the accent layers — tint wash, highlight fill, decorative outline strokes
/// and full-outline border — with ``LiquidGlassRenderer``.
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

    private let frostContainer = UIView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let decoration = DecorationView()

    /// The last path built for `shape` at a given size; the shadow uses it so the
    /// path is generated once per geometry change.
    private var cachedPath: CGPath?
    private var cachedPathShape: LiquidGlassShape?
    private var cachedPathSize: CGSize = .zero

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

        // Transparent hosting: an opaque custom-draw view would composite its
        // undrawn areas as black over the blur.
        isOpaque = false
        backgroundColor = .clear
        frostContainer.isOpaque = false
        frostContainer.backgroundColor = .clear

        for view in [frostContainer, effectView, decoration] {
            view.isUserInteractionEnabled = false
        }
        addSubview(frostContainer)
        frostContainer.addSubview(effectView)
        addSubview(decoration)

        decoration.shape = shape
        decoration.tint = tint
        decoration.opacity = opacity
        decoration.style = style
        applyFrostingOpacity()

        updateFrosting()
        updateShadow()
    }

    private func applyFrostingOpacity() {
        // Avoid touching the effect view's alpha unless an override was set:
        // UIVisualEffectView expects its alpha to stay at 1 by default.
        let alpha = frostingOpacity ?? 1
        if effectView.alpha != alpha {
            effectView.alpha = alpha
        }
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        frostContainer.frame = bounds
        decoration.frame = bounds.insetBy(
            dx: -DecorationView.bleed,
            dy: -DecorationView.bleed
        )
        updateFrosting()
        updateShadow()
    }

    private func shapeDidChange() {
        decoration.shape = shape
        setNeedsLayout()
    }

    // MARK: - Shape clipping + shadow

    /// Clips the frosted backdrop to the glass shape.
    ///
    /// Uses the effect view's own corner-radius clipping rather than a
    /// `CAShapeLayer` mask. Masking a `UIVisualEffectView` through an ancestor
    /// layer can render the backdrop black on recent iOS versions; corner
    /// radius clipping is supported for all three glass shapes.
    private func updateFrosting() {
        let containerBounds = frostContainer.bounds
        let clipRect: CGRect
        let radius: CGFloat
        switch shape {
        case .roundedRect(let cornerRadius):
            clipRect = containerBounds
            radius = min(
                max(cornerRadius, 0),
                min(containerBounds.width, containerBounds.height) / 2
            )
        case .capsule:
            clipRect = containerBounds
            radius = min(containerBounds.width, containerBounds.height) / 2
        case .circle:
            let side = min(containerBounds.width, containerBounds.height)
            clipRect = CGRect(
                x: containerBounds.midX - side / 2,
                y: containerBounds.midY - side / 2,
                width: side,
                height: side
            )
            radius = side / 2
        }

        withDisabledLayerActions {
            effectView.frame = clipRect
            effectView.layer.cornerRadius = radius
            effectView.clipsToBounds = true
        }
    }

    /// The soft drop shadow behind the glass composite, drawn by the container's
    /// layer so it sits *behind* the frosted material.
    private func updateShadow() {
        let layer = frostContainer.layer
        withDisabledLayerActions {
            layer.shadowColor = CGColor(gray: 0, alpha: 1)
            layer.shadowOpacity = Float(isDarkAppearance ? 0.1 : 0.05)
            layer.shadowRadius = 15
            layer.shadowOffset = CGSize(width: 0, height: -6)
            layer.shadowPath = glassPath(in: frostContainer.bounds)
        }
    }

    /// Returns the shape path for `rect`, reusing the previous result while the
    /// shape and size are unchanged.
    private func glassPath(in rect: CGRect) -> CGPath {
        if let cachedPath, cachedPathShape == shape, cachedPathSize == rect.size {
            return cachedPath
        }
        let path = shape.path(in: rect)
        cachedPath = path
        cachedPathShape = shape
        cachedPathSize = rect.size
        return path
    }

    /// Runs `body` with Core Animation's implicit animations disabled.
    private func withDisabledLayerActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// The renderer only paints the accent layers; the frosting must show
    /// through everywhere else. An opaque backing store would render those
    /// areas black.
    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

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