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
/// The view draws no drop shadow: it is typically embedded edge-to-edge in a
/// host container, whose clipping would cut a shadow that extends past the
/// view's bounds. Apply elevation (a `shadow…` layer property or the
/// container's own shadow) on the container instead.
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
        didSet {
            guard shape != oldValue else { return }
            shapeDidChange()
        }
    }

    /// Optional tint color. `nil` keeps the highlight neutral.
    public var tint: CGColor? {
        didSet {
            guard !Self.colorsEqual(tint, oldValue) else { return }
            decoration.tint = tint
        }
    }

    /// Gloss intensity of the highlight (0…1). Defaults to 0.6.
    public var opacity: CGFloat {
        didSet {
            guard opacity != oldValue else { return }
            decoration.opacity = opacity
        }
    }

    /// Decorative outline style (`.v26` or `.v27`).
    public var style: LiquidGlassRenderer.Style {
        didSet {
            guard style != oldValue else { return }
            decoration.style = style
        }
    }

    /// The system frosted-material style. Defaults to `.systemUltraThinMaterial`.
    public var blurStyle: UIBlurEffect.Style {
        didSet {
            guard blurStyle != oldValue else { return }
            effectView.effect = UIBlurEffect(style: blurStyle)
        }
    }

    /// Opacity of the frosting material view (`0…1`).
    ///
    /// Lower values let more of the backdrop through, reading as a more
    /// transparent glass. `nil` (the default) keeps the material at full
    /// opacity: UIKit's `.systemUltraThinMaterial` already matches SwiftUI's
    /// `.ultraThinMaterial`, so no easing is needed. Mirrors the AppKit
    /// ``LiquidGlassView/frostingOpacity`` control.
    public var frostingOpacity: CGFloat? {
        didSet {
            guard frostingOpacity != oldValue else { return }
            applyFrostingOpacity()
        }
    }

    // MARK: - Private hierarchy

    private let frostContainer = UIView()
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
        // `commonInit()` seeded the decoration with the defaults held before
        // these assignments. Push the requested configuration explicitly so
        // initialization does not depend on property observers having run —
        // otherwise a stale decoration shape draws a capsule rim around a
        // rounded-rect material.
        applyConfiguration()
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

        applyConfiguration()
    }

    /// Pushes the stored configuration into the decoration view and the
    /// material layer.
    ///
    /// The decoration view holds its own copy of the configuration, so every
    /// path that changes several settings at once (the convenience initializer
    /// in particular) must push them through here rather than relying on the
    /// individual property observers.
    private func applyConfiguration() {
        decoration.shape = shape
        decoration.tint = tint
        decoration.opacity = opacity
        decoration.style = style
        effectView.effect = UIBlurEffect(style: blurStyle)
        applyFrostingOpacity()
        updateFrosting()
        setNeedsLayout()
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
    }

    private func shapeDidChange() {
        decoration.shape = shape
        // Keep the material clip in lock-step with the stroke shape; layout may
        // be deferred, and a stale frost clip would show a capsule/rounded-rect
        // mismatch against the drawn outline.
        updateFrosting()
        setNeedsLayout()
    }

    // MARK: - Shape clipping

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

    /// Runs `body` with Core Animation's implicit animations disabled.
    private func withDisabledLayerActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    /// `CGColor` is not `Equatable`, so compare through Core Foundation.
    private static func colorsEqual(_ lhs: CGColor?, _ rhs: CGColor?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return CFEqual(lhs, rhs)
        default:
            return false
        }
    }

    /// Re-renders when the system switches between light and dark appearance.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            decoration.setNeedsDisplay()
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