//
//  LiquidGlassView.swift
//  LiquidGlass
//
//  AppKit version of the Liquid Glass effect — no SwiftUI.
//

#if canImport(AppKit)

import AppKit
import QuartzCore
import CoreGraphics

/// AppKit view that renders the Liquid Glass effect entirely with AppKit and
/// Core Graphics (no SwiftUI).
///
/// The view hosts a system ``NSVisualEffectView`` (the frosted backdrop,
/// clipped to a ``LiquidGlassShape`` through a layer mask) and paints the
/// accent layers — tint wash, highlight fill, decorative outline strokes and
/// gray border — with ``LiquidGlassRenderer``.
///
/// Example:
/// ```swift
/// let glass = LiquidGlassView(shape: .roundedRect(cornerRadius: 16))
/// glass.tint = NSColor.systemBlue.cgColor
/// glass.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
/// container.addSubview(glass)
/// ```
public final class LiquidGlassView: NSView {
    // MARK: - Public configuration

    /// The glass backing shape. Changes re-shape and redraw the effect.
    public var shape: LiquidGlassShape {
        didSet { shapeDidChange() }
    }

    /// Optional tint color. `nil` keeps the highlight neutral.
    public var tint: CGColor? {
        didSet { decoration.needsDisplay = true }
    }

    /// Gloss intensity of the highlight (0…1). Defaults to 0.6.
    public var opacity: CGFloat {
        didSet { decoration.needsDisplay = true }
    }

    /// Decorative outline style (`.v26` or `.v27`).
    public var style: LiquidGlassRenderer.Style {
        didSet { decoration.needsDisplay = true }
    }

    /// The system frosting material. Defaults to `.popover`.
    public var material: NSVisualEffectView.Material {
        didSet { effectView.material = material }
    }

    // MARK: - Private hierarchy

    private let maskContainer = NSView()
    private let effectView = NSVisualEffectView()
    private let decoration = DecorationView()

    // MARK: - Initializers

    /// Creates a glass view. Use `.frame` / constraints to size it.
    public init(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: LiquidGlassRenderer.Style = .v26,
        material: NSVisualEffectView.Material = .popover
    ) {
        self.shape = shape
        self.tint = tint
        self.opacity = opacity
        self.style = style
        self.material = material
        super.init(frame: .zero)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        shape = .capsule
        tint = nil
        opacity = 0.6
        style = .v26
        material = .popover
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        maskContainer.wantsLayer = true

        effectView.wantsLayer = true
        effectView.material = material
        effectView.blendingMode = .withinWindow
        effectView.state = .active

        addSubview(maskContainer)
        maskContainer.addSubview(effectView)
        addSubview(decoration)

        decoration.shape = shape
        decoration.tint = tint
        decoration.opacity = opacity
        decoration.style = style

        updateMask()
        updateShadow()
    }

    // MARK: - Layout

    public override var intrinsicContentSize: NSSize { NSSize(width: 100, height: 60) }

    public override func layout() {
        super.layout()
        maskContainer.frame = bounds
        effectView.frame = maskContainer.bounds
        decoration.frame = bounds
        updateMask()
        updateShadow()
    }

    private func shapeDidChange() {
        decoration.shape = shape
        needsLayout = true
        needsDisplay = true
    }

    // MARK: - Shape mask + shadow

    /// Clips the frosted backdrop to the glass shape.
    private func updateMask() {
        guard let layer = maskContainer.layer else { return }
        let mask = CAShapeLayer()
        mask.fillColor = CGColor(gray: 1, alpha: 1)
        mask.path = shape.path(in: maskContainer.bounds)
        layer.mask = mask
    }

    /// The soft drop shadow behind the glass composite. Drawn by the masked
    /// container's layer so it sits *behind* the frosted material, matching
    /// the SwiftUI `.shadow(...)` on the combined effect.
    private func updateShadow() {
        guard let layer = maskContainer.layer else { return }
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = Float(isDarkAppearance ? 0.1 : 0.05)
        layer.shadowRadius = 15
        layer.shadowOffset = CGSize(width: 0, height: -6)
        layer.shadowPath = shape.path(in: maskContainer.bounds)
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Re-renders when the system switches between light and dark appearance
    /// so the highlight / outline / shadow palettes stay in sync.
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        decoration.needsDisplay = true
        updateShadow()
    }
}

// MARK: - Decoration view

/// The sibling view that paints the accent layers on top of the material.
/// Coordinate system stays Core Graphics “y up” (AppKit's default), which is
/// what ``LiquidGlassRenderer`` expects.
private final class DecorationView: NSView {
    var shape: LiquidGlassShape = .capsule { didSet { needsDisplay = true } }
    var tint: CGColor? { didSet { needsDisplay = true } }
    var opacity: CGFloat = 0.6 { didSet { needsDisplay = true } }
    var style: LiquidGlassRenderer.Style = .v26 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        LiquidGlassRenderer(
            shape: shape,
            tint: tint,
            opacity: opacity,
            style: style,
            isDark: isDark
        ).draw(in: context, size: bounds.size)
    }
}

// MARK: - Convenience

public extension NSView {
    /// Inserts a `LiquidGlassView` behind all existing subviews as the
    /// view's glass background. Returns the glass view so it can be tuned.
    @discardableResult
    func addLiquidGlassBackground(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: LiquidGlassRenderer.Style = .v26
    ) -> LiquidGlassView {
        let glass = LiquidGlassView(shape: shape, tint: tint, opacity: opacity, style: style)
        glass.autoresizingMask = [.width, .height]
        glass.frame = bounds
        addSubview(glass, positioned: .below, relativeTo: subviews.first)
        return glass
    }
}

#endif