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
/// full-outline border — with ``LiquidGlassRenderer``.
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

    /// The system frosting material.
    ///
    /// Unless set explicitly, it follows the appearance-matched default that
    /// most closely matches SwiftUI's `.ultraThinMaterial`: `.headerView` in
    /// light appearance and `.popover` in dark appearance. Assigning a material
    /// pins it (restoring the automatic frosting opacity unless
    /// ``frostingOpacity`` is set), stopping the automatic appearance switching.
    public var material: NSVisualEffectView.Material {
        didSet {
            if !isApplyingAutomaticMaterial {
                isUsingAutomaticMaterial = false
                applyFrostingOpacity()
            }
            guard material != oldValue else { return }
            effectView.material = material
        }
    }

    /// Opacity of the frosting material view (`0…1`).
    ///
    /// Lower values let more of the backdrop through, reading as a more
    /// transparent glass. `nil` (the default) follows the appearance-matched
    /// value — currently `0.65` in light appearance and `1` in dark. Assigning
    /// a value pins it.
    public var frostingOpacity: CGFloat? {
        didSet { applyFrostingOpacity() }
    }

    /// Whether `material` still follows the appearance-matched default.
    private var isUsingAutomaticMaterial = true

    /// Guards the internal material assignment so it does not count as an
    /// explicit user choice.
    private var isApplyingAutomaticMaterial = false

    /// The material that best matches `.ultraThinMaterial` for the current
    /// appearance (measured against the SwiftUI renderer).
    private var automaticMaterial: NSVisualEffectView.Material {
        isDarkAppearance ? .popover : .headerView
    }

    /// Opacity of the frosting view for the automatic material.
    ///
    /// `.headerView` in light appearance is brighter and more opaque than
    /// SwiftUI's `.ultraThinMaterial`, so the material view is eased back to
    /// let more of the backdrop through. Dark appearance keeps the material
    /// fully opaque.
    private var automaticMaterialAlpha: CGFloat {
        isDarkAppearance ? 1 : 0.65
    }

    /// Resolves the frosting opacity from the explicit override or the
    /// appearance-matched default, then applies it to the material view.
    private func applyFrostingOpacity() {
        let base = isUsingAutomaticMaterial ? automaticMaterialAlpha : 1
        effectView.alphaValue = frostingOpacity ?? base
    }

    /// Whether to show the shape-matched pointer-hover fill, mirroring the
    /// SwiftUI `hoverEffect` option. Defaults to `false`.
    ///
    /// The fill sits *behind* the frosting (like SwiftUI's `GlassHoverEffect`):
    /// opaque white in light appearance, a faint white wash in dark appearance.
    public var hoverEffect: Bool {
        didSet {
            guard hoverEffect != oldValue else { return }
            updateTrackingAreas()
            if !hoverEffect {
                // Disabling while hovered must also clear the visible fill.
                isHovered = false
                withDisabledLayerActions {
                    hoverView.alphaValue = 0
                }
            }
        }
    }

    // MARK: - Private hierarchy

    private let maskContainer = NSView()
    private let effectView = NSVisualEffectView()
    private let decoration = DecorationView()

    /// Shape-clipped hover fill, composited below the frosting.
    private let hoverView = NSView()

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false

    /// Reused as the frosted backdrop's mask. Allocating and swapping a fresh
    /// `CAShapeLayer` on every layout pass would churn layers while resizing.
    private let maskLayer = CAShapeLayer()

    /// The last path built for `shape` at a given size. The mask and the
    /// shadow share it so the path is generated once per geometry change.
    private var cachedPath: CGPath?
    private var cachedPathShape: LiquidGlassShape?
    private var cachedPathSize: CGSize = .zero

    // MARK: - Initializers

    /// Creates a glass view. Use `.frame` / constraints to size it.
    ///
    /// - Parameter material: The system frosting material. Pass `nil` (the
    ///   default) to follow the appearance-matched default that best matches
    ///   SwiftUI's `.ultraThinMaterial` — `.headerView` in light appearance,
    ///   `.popover` in dark appearance. Pass a material to pin it.
    public init(
        shape: LiquidGlassShape,
        tint: CGColor? = nil,
        opacity: CGFloat = 0.6,
        style: LiquidGlassRenderer.Style = .v26,
        material: NSVisualEffectView.Material? = nil,
        hoverEffect: Bool = false
    ) {
        self.shape = shape
        self.tint = tint
        self.opacity = opacity
        self.style = style
        self.material = material ?? .headerView
        self.isUsingAutomaticMaterial = material == nil
        self.hoverEffect = hoverEffect
        super.init(frame: .zero)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        shape = .capsule
        tint = nil
        opacity = 0.6
        style = .v26
        material = .headerView
        isUsingAutomaticMaterial = true
        hoverEffect = false
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true

        // Layer-backed NSViews default to `masksToBounds = true`, which clips
        // the root layer's shadow to the view's frame. The frosted backdrop is
        // already masked to the shape by `maskContainer`, so the root layer
        // must let the shadow render outside its bounds.
        layer?.masksToBounds = false

        maskContainer.wantsLayer = true

        // The hover fill is a sibling *below* the material, so it shows through
        // the frosting exactly like SwiftUI's hover background behind the glass.
        hoverView.wantsLayer = true
        hoverView.alphaValue = 0
        hoverTrackingArea = nil

        effectView.wantsLayer = true
        effectView.material = material
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        applyAutomaticMaterialIfNeeded()

        // The shadow lives on the view's own (unmasked) layer. A mask on the
        // same layer as the shadow clips the shadow away, so the shape mask
        // stays on `maskContainer` and the root layer casts the shape-matched
        // shadow behind the whole composite — matching SwiftUI's `.shadow(...)`
        // on the effect. Only the shadow's opacity and path vary at runtime;
        // everything else is fixed, so it is applied once here.
        if let rootLayer = layer {
            rootLayer.shadowColor = CGColor(gray: 0, alpha: 1)
            rootLayer.shadowRadius = 15
            rootLayer.shadowOffset = CGSize(width: 0, height: -6)
        }

        addSubview(maskContainer)
        maskContainer.addSubview(hoverView)
        maskContainer.addSubview(effectView)
        addSubview(decoration)

        decoration.shape = shape
        decoration.tint = tint
        decoration.opacity = opacity
        decoration.style = style

        updateGlassLayers()
    }

    // MARK: - Layout

    public override var intrinsicContentSize: NSSize { NSSize(width: 100, height: 60) }

    public override func layout() {
        super.layout()
        maskContainer.frame = bounds
        hoverView.frame = maskContainer.bounds
        effectView.frame = maskContainer.bounds
        decoration.frame = bounds.insetBy(
            dx: -DecorationView.bleed,
            dy: -DecorationView.bleed
        )
        updateGlassLayers()
    }

    private func shapeDidChange() {
        decoration.shape = shape
        // Keep the material mask/shadow in lock-step with the stroke shape.
        updateGlassLayers()
        needsLayout = true
    }

    /// Applies the appearance-matched material and frosting opacity while the
    /// caller has not pinned a material explicitly.
    private func applyAutomaticMaterialIfNeeded() {
        applyFrostingOpacity()

        guard isUsingAutomaticMaterial else { return }
        let target = automaticMaterial
        guard material != target else { return }
        isApplyingAutomaticMaterial = true
        material = target
        isApplyingAutomaticMaterial = false
    }

    // MARK: - Hover

    /// The glass view is decorative: it never participates in hit testing, so
    /// it can sit behind (or inside) interactive content without swallowing
    /// clicks. Tracking areas still deliver `mouseEntered`/`mouseExited`.
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        hoverTrackingArea = nil

        guard hoverEffect else { return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    public override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    /// Cross-fades the hover fill. Matches SwiftUI's `withAnimation` hover:
    /// the fill only exists while `hoverEffect` is enabled.
    private func setHovered(_ hovering: Bool, animated: Bool = true) {
        guard hoverEffect else {
            isHovered = false
            return
        }
        guard hovering != isHovered else { return }
        isHovered = hovering
        updateHoverColor()

        let target: CGFloat = hovering ? 1 : 0
        guard animated else {
            withDisabledLayerActions {
                hoverView.alphaValue = target
            }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            hoverView.animator().alphaValue = target
        }
    }

    /// Hover fill palette: opaque white in light appearance, a faint white wash
    /// in dark appearance (the platform stand-in for SwiftUI's `.quinary`).
    private func updateHoverColor() {
        let color: NSColor = isDarkAppearance ? .white.withAlphaComponent(0.08) : .white
        withDisabledLayerActions {
            hoverView.layer?.backgroundColor = color.cgColor
        }
    }

    // MARK: - Shape mask + shadow

    /// Rebuilds the cached shape path when the geometry changed, then applies
    /// it to both the backdrop mask and the drop shadow.
    private func updateGlassLayers() {
        let path = glassPath(in: CGRect(origin: .zero, size: bounds.size))
        withDisabledLayerActions {
            updateMask(path: path)
            updateShadow(path: path)
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

    /// Clips the frosted backdrop to the glass shape.
    private func updateMask(path: CGPath) {
        guard let containerLayer = maskContainer.layer else { return }
        if containerLayer.mask !== maskLayer {
            maskLayer.fillColor = CGColor(gray: 1, alpha: 1)
            containerLayer.mask = maskLayer
        }
        maskLayer.frame = containerLayer.bounds
        maskLayer.path = path
    }

    /// The soft drop shadow behind the glass composite. Drawn by the view's
    /// unmasked root layer so it sits *behind* the frosted material (and is
    /// not clipped by the material's shape mask), matching the SwiftUI
    /// `.shadow(...)` on the combined effect.
    private func updateShadow(path: CGPath) {
        guard let rootLayer = layer else { return }
        let opacity = Float(isDarkAppearance ? 0.1 : 0.05)
        if rootLayer.shadowOpacity != opacity {
            rootLayer.shadowOpacity = opacity
        }
        rootLayer.shadowPath = path
    }

    /// Runs `body` with Core Animation's implicit animations disabled, so the
    /// mask and shadow snap to the current geometry during live resizing
    /// rather than animating every intermediate size.
    private func withDisabledLayerActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Re-renders when the system switches between light and dark appearance
    /// so the highlight / outline / shadow palettes stay in sync.
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAutomaticMaterialIfNeeded()
        decoration.needsDisplay = true
        updateHoverColor()
        withDisabledLayerActions {
            updateShadow(path: glassPath(in: CGRect(origin: .zero, size: bounds.size)))
        }
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
}

// MARK: - Decoration view

/// The sibling view that paints the accent layers on top of the material.
/// Coordinate system stays Core Graphics “y up” (AppKit's default), which is
/// what ``LiquidGlassRenderer`` expects.
private final class DecorationView: NSView {
    /// Margin drawn around the glass shape so centered strokes (notably the
    /// v27 gray border) can render their outer half, matching SwiftUI's
    /// unclipped strokes.
    static let bleed: CGFloat = 2

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
        ).draw(
            in: context,
            size: bounds.size,
            shapeRect: bounds.insetBy(dx: Self.bleed, dy: Self.bleed)
        )
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
        style: LiquidGlassRenderer.Style = .v26,
        hoverEffect: Bool = false
    ) -> LiquidGlassView {
        let glass = LiquidGlassView(
            shape: shape,
            tint: tint,
            opacity: opacity,
            style: style,
            hoverEffect: hoverEffect
        )
        glass.autoresizingMask = [.width, .height]
        glass.frame = bounds
        addSubview(glass, positioned: .below, relativeTo: subviews.first)
        return glass
    }
}

#endif