# LiquidGlass — UI Requirements

| | |
|---|---|
| **Document** | LiquidGlass UI Requirements |
| **Version** | 1.2 |
| **Date** | 2026-11-25 |
| **Status** | Proposed |
| **Author** | LiquidGlass maintainers |
| **Applies to** | v2.2.0+ (SwiftUI renderers, AppKit & UIKit renderers) |

This document specifies the **visual design requirements**, **parameter semantics**, **platform behavior**, and **acceptance criteria** for the LiquidGlass frosted-glass effect. It is the reference for both the SwiftUI implementation and the SwiftUI-free AppKit/UIKit implementation, which must render to the same visual spec apart from the documented drop-shadow difference.

> **Revision 1.1** aligns the specification with the current SwiftUI renderers (`LiquidGlassV26` / `LiquidGlassV27`, `GlassEffectModifier`, and the component styles). Values that previously diverged from the code — the v26 stroke alignment, the v27 lens/border colors, the hover fill, the `lightAngle` semantics, and the conic-fan segment count — have been corrected to match what the library actually draws.
>
> **Revision 1.2** removes the drop shadow from the AppKit/UIKit host views. They are embedded edge-to-edge in host containers, whose clipping cut any shadow drawn outside the view's bounds; elevation now belongs to the host container. The SwiftUI renderer keeps its shadow unchanged.

Every requirement has an identifier (`REQ-*`) and an acceptance test so it can be verified during development and review.

---

## 1. Introduction

### 1.1 Purpose

LiquidGlass provides a frosted-glass ("Liquid Glass") background effect on Apple platforms before **Platform 26** (iOS 26 / macOS 26), where the native `glassEffect(in:)` API is unavailable. On Platform 26+ it automatically uses the system-native effect. The custom implementation must:

- Render a realistic frosted-glass surface using **system materials, gradients, and shadows only** — no Metal, shaders, or external dependencies.
- Adapt to **light and dark** system appearances.
- Provide the effect through **three interchangeable renderer stacks** that must all produce a visually equivalent result:
  1. **SwiftUI fallback** (`.liquidGlass(...)`, `LiquidGlass` router → `LiquidGlassV26`/`LiquidGlassV27`),
  2. **AppKit** (`LiquidGlassView` for macOS),
  3. **UIKit** (`LiquidGlassView` for iOS/tvOS).

### 1.2 Audience

UI/UX reviewers, maintainers, and implementers of the renderer stacks. It also serves as a test plan for visual regressions.

### 1.3 Related documents

- `README.md` — usage.
- `CHANGELOG.md` — release history.
- `Package.swift` — supported platforms.

---

## 2. Scope

### 2.1 In scope

- The glass **background effect**: frosted material, tint wash, highlight, decorative outline strokes, and drop shadow (the drop shadow is SwiftUI-only — see §5.4).
- The three **shape** types: rounded rectangle, circle, capsule.
- **Customization parameters**: tint, opacity, target platform version (v26/v27). (`lightAngle` remains in the API for compatibility but does not affect the current renderers.)
- **Platform-adaptive behavior** (native vs. custom renderer) and **light/dark adaptation**.
- **AppKit/UIKit parity** with the SwiftUI renderer.
- The **v26** and **v27** outline styles (see §5.5, §5.6).

### 2.2 Out of scope (non-goals)

- Pixel-for-pixel equality with Apple's native Liquid Glass hardware effect.
- Match-finding a real background photo (no motion parallax, no lens distortion).
- New shape types beyond `roundedRect`, `circle`, `capsule` (future work).
- Recreating the AppKit/UIKit views as drop-in replacements for SwiftUI `Material`/`ShapeStyle` compositing.

---

## 3. Terminology

| Term | Meaning |
|---|---|
| **Platform 26** | iOS 26 / macOS 26 (also tvOS/watchOS 26), where the native `glassEffect(in:)` exists. |
| **Custom renderer** | The `LiquidGlass`-based implementation used below Platform 26 (or forced via `forceToCustomLiquidGlass()`; deprecated alias `liquidGlassUsesSystemImplementation(false)`). |
| **Backdrop** | The system material or blur that produces the frosting. |
| **Tint wash** | A soft, low-alpha color overlay giving the glass a color cast. |
| **Highlight fill** | A white (light mode) or black (dark mode) sheen over the glass that makes it read as glossy. |
| **Outline / stroke** | The decorative edge lighting around the shape (`v26` angular gradient or `v27` lens highlight + gray border). |
| **LightAngle** | `topLeading`, `bottomTrailing`, `none`, `all` — retained for API compatibility. The current v26/v27 renderers accept it but derive their highlight geometry from the shape, so it does not change the rendered look. |
| **Version** | `.v26` (original look) or `.v27` (dedicated look), selected via `liquidGlassVersion(_:)` (default `.v26`). It selects the **custom fallback** look; Platform 26+ still prefers the native effect unless the custom renderer is forced. |

---

## 4. Functional Requirements

### 4.1 Effect primitives

The glass effect is produced by a fixed layer stack. The stack MUST be rendered in this order so the appearance is deterministic:

```
1. Backdrop      — system material (frost), clipped to the shape
2. Tint wash     — tint × 0.2 alpha, clipped to the shape
3. Highlight     — white/black fill, clipped to the shape
4. Outline       — v26: angular-gradient stroke
                   v27: horizontal lens stroke, then a full-outline gray border
5. Shadow        — soft black drop shadow behind the whole composite
                   (SwiftUI renderer only; the AppKit/UIKit hosts omit it — §5.4)
```

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-001 | The effect MUST be drawn with system materials, gradients, and shadows; no Metal/shader code is permitted. | Source review: no `MTKView`, `MTL*`, or `.layer` `CALayer` shader source in the render stack. |
| REQ-UI-002 | The layer stack in §4.1 MUST be composited in the listed order. | Visual test: a tinted, highlighted shape shows the tint beneath the highlight. |
| REQ-UI-003 | Each renderer stack (SwiftUI, AppKit, UIKit) MUST implement the same stack, except that the platform hosts omit the drop shadow (§5.4). | Side-by-side screenshots of all three renderers at the same size/params differ only by implementation tolerance (see §11.2) and the platform views' missing shadow. |

### 4.2 Shapes

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-004 | `roundedRect(cornerRadius:)` draws a rounded rectangle with the given corner radius, clamped to half the smaller dimension. | Corner radius renders at the requested value; a radius larger than half the smaller side caps gracefully. |
| REQ-UI-005 | `circle` draws a circle centered in the available bounds, sized to the smaller dimension. | Non-square frames center the circle without distortion. |
| REQ-UI-006 | `capsule` draws a pill whose corner radius equals half the smaller dimension. | Any aspect ratio produces a stadium with fully rounded ends. |
| REQ-UI-007 | Empty or zero/negative bounds MUST render nothing (no crash, no artifacts). | Unit test: zero-size and negative-size frames return empty geometry. |
| REQ-UI-066 | SwiftUI rounded rectangles use **continuous** corner curves (`Path(roundedRect:cornerRadius:style:.continuous)`). The AppKit/UIKit shape model approximates them with circular arcs (`addRoundedRect`). | Side-by-side shapes read equivalently at outline widths ≤ 1.5 pt (see §11.2 tolerance). |

### 4.3 Customization parameters

| Param | Default | Semantics |
|---|---|---|
| `opacity` | `0.6` | Gloss density. Range `0…1`. Scales the highlight fill (see REQ-UI-010). |
| `tint` | `nil` | Optional color cast. When `nil` the glass stays neutral. Also colors the outline base when set (§5.5). |
| `lightAngle` | `.topLeading` | Accepted for API compatibility. The current v26/v27 renderers ignore it; their highlight geometry is derived from the shape. |
| `version` | `.v26` | Selects the custom fallback look: `.v26` angular outline, `.v27` lens + gray border. On Platform 26+ the native `glassEffect(in:)` is used unless the custom renderer is forced. |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-008 | All rendering parameters (`shape`, `tint`, `opacity`, `version`) MUST be adjustable per instance and reflected on redraw. `lightAngle` is API-compatibility only and does not alter the current renderers' output. | Change each rendering parameter at runtime; the effect updates without recreating the view. |
| REQ-UI-009 | A `tint == nil` MUST render a neutral glass with no color cast. | White background sample: neutral glass has no hue offset (gray-scale samples). |
| REQ-UI-010 | Increasing `opacity` MUST increase highlight strength monotonically. | Compare `opacity = 0.2` vs `0.8` on a fixed background: `0.8` shows a stronger sheen. |
| REQ-UI-011 | Invalid parameter values (`opacity` outside `0…1`, negative corner radius) MUST be clamped, not crash. | Unit tests pass with `opacity = 2.0`, `opacity = -1`, `cornerRadius = -5`. |

### 4.4 Platform-adaptive behavior

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-012 | On Platform 26+, `.liquidGlass(...)` MUST prefer the native `glassEffect(in:)`. | Run on iOS/macOS 26+: rendering uses the native API (verified via implementation-selection flag). |
| REQ-UI-013 | Below Platform 26, `.liquidGlass(...)` MUST fall back to the custom renderer. | Run on an OS older than 26: custom look renders without crashing. |
| REQ-UI-014 | `forceToCustomLiquidGlass()` (deprecated alias: `liquidGlassUsesSystemImplementation(false)`) MUST force the custom renderer even on Platform 26+. It applies to `.liquidGlass(...)` and to the glass controls. | With the flag set on Platform 26+, the custom look renders. |
| REQ-UI-015 | The AppKit/UIKit `LiquidGlassView` MUST render the custom look unconditionally (there is no native equivalents there). | It renders the same visuals on any supported OS version. |
| REQ-UI-067 | Below Platform 26, the `\.liquidGlassVersion` environment value MUST select `LiquidGlassV26` or `LiquidGlassV27`. On Platform 26+ it only applies when the custom renderer is forced. | `.v27` shows the V27 outline below 26, and the V27 look under `forceToCustomLiquidGlass()` on 26+. |

### 4.5 Light/dark adaptation

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-016 | The effect MUST switch palettes automatically with the system light/dark appearance. | Toggle system appearance; the highlight and outline palettes update (values per §5), as does the SwiftUI renderer's shadow palette. |
| REQ-UI-017 | The AppKit/UIKit views MUST repaint on appearance change. | `viewDidChangeEffectiveAppearance` (AppKit) and `traitCollectionDidChange` (UIKit) trigger redraws (verified by hook instrumentation or visual test). |
| REQ-UI-018 | In dark mode the glass reads lighter than its surroundings; in light mode it reads like a thin bright surface (original v26-style behavior). | Visual review against §5 reference values. |

### 4.6 AppKit/UIKit parity

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-019 | The AppKit view (`NSView`) and UIKit view (`UIView`) MUST expose the same shape/tint/opacity/style parameters with the same defaults as the SwiftUI renderer. | API comparison: `shape`, `tint`, `opacity` (default `0.6`), `style` (`v26`/`v27`). |
| REQ-UI-020 | Both platform views MUST render the same geometry for the same shape/parameters. | Same-size screenshot at 1× and 2× scale: shapes align within 1 pt. |
| REQ-UI-021 | The platform views MUST provide a shape-conforming hit surface (interaction not required through the glass itself). | Glass views are non-interactive; they do not block interaction when configured as backgrounds. |
| REQ-UI-022 | The v26 angular-gradient outline MAY be approximated by a finite conic fan (Core Graphics has no native conic gradient); it MUST read as smooth at typical outline widths (≤1.5 pt). | No visible banding/seams on a 200×100 sample at 2× scale. |

---

## 5. Visual Design Specification

All values below are authoritative for both the SwiftUI and AppKit/UIKit implementations.

### 5.1 Frosted backdrop

| Mode | SwiftUI | AppKit | UIKit |
|---|---|---|---|
| Backdrop | `.ultraThinMaterial` | Appearance-matched `NSVisualEffectView` default: `.headerView` (light) / `.popover` (dark) — the closest SwiftUI match | `UIVisualEffectView` `.systemUltraThinMaterial` (default) |
| Clipping | Shape's `fill` | `CAShapeLayer` mask on the material's container | Effect view corner-radius clipping (`clipsToBounds`) |
| Blending | In-stack | `.withinWindow` | In-stack (system) |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-023 | The frosting MUST be confined to the shape — nothing renders outside the shape boundary. | Screenshot: no blur rectangle visible beyond shape edges. |
| REQ-UI-024 | The backdrop MUST remain a system material (live blur of the content behind). | Place a moving background behind a large glass view: the region in front of it stays blurred. |
| REQ-UI-025 | AppKit/UIKit material choices MUST be configurable (`.material`/`.blurStyle` properties). Assigning an AppKit material pins it; the default follows the appearance-matched mapping above. | Changing the property updates the backdrop without recreating the view. |

> **Known caveat:** masked visual-effect views are slightly version-fragile on some macOS releases; the container-view + mask technique is the mitigation. If a specific macOS version ignores the mask, the frosting may appear rectangular — tracked as risk R-1 (§13).
>
> **UIKit clipping note:** masking a `UIVisualEffectView` through an ancestor `CAShapeLayer` can render the backdrop black on recent iOS versions. The UIKit view therefore clips the effect view with its own corner radius (`clipsToBounds`), which is exact for rounded rectangles, capsules, and circles. The host, container, and decoration views are also explicitly non-opaque so the blur never samples a black backing store.
>
> **Material parity note:** no public `NSVisualEffectView.Material` reproduces SwiftUI's `.ultraThinMaterial` exactly. The AppKit default is chosen by measurement — `.headerView` in light appearance, `.popover` in dark — and the light-appearance frosting is composited at 65% opacity, which restores SwiftUI's translucency (the material alone reads too bright/opaque). `frostingOpacity` overrides this per view. The result stays within a few percent of the SwiftUI material. Assigning a material explicitly pins it and restores the automatic frosting opacity. UIKit's `.systemUltraThinMaterial` already matches SwiftUI, so its default is full opacity; both platform views expose `frostingOpacity` for override. The residual difference is a slight desaturation of the AppKit backdrop; exact parity would require the private SwiftUI material recipe.

### 5.2 Tint wash

| Step | Value |
|---|---|
| Fill | `tint` at alpha `tint.alpha × 0.2` |
| Composition | direct (source-over) |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-026 | With a tint set, the shape shows a subtle color cast at 20% of the tint's alpha. | Color-pick the interior over a neutral background; hue matches the tint at ≈20% alpha. |
| REQ-UI-027 | The wash MUST be independent of `opacity` (per the SwiftUI implementation). | Changing `opacity` alone does not alter the wash. |

### 5.3 Highlight fill

| Mode | Alpha formula |
|---|---|
| Light | `highlightAlpha = (1.0 × opacity) × 0.75` → white fill |
| Dark | `highlightAlpha = (0.7 × 0.6 × opacity) × 0.75` → black fill |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-028 | At default `opacity = 0.6`, the light-mode highlight renders white at ~0.45 alpha. | Sample matches within ±0.05 alpha. |
| REQ-UI-029 | The highlight MUST be clipped to the shape (no sheen beyond the shape's edges). | Screenshot review. |

### 5.4 Soft shadow

**SwiftUI renderer only.** The values below apply to `LiquidGlassV26` / `LiquidGlassV27`.

| Property | Value |
|---|---|
| Color | Black |
| Radius | 15 pt |
| Offset | (0, –6) in the renderers' y-up space (i.e., shadow falls below the shape on screen) |
| Alpha | light `0.05`, dark `0.1` |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-030 | In the SwiftUI renderer, a soft drop shadow of radius 15 pt and 6 pt downward offset MUST render behind the composite (below the material, per §4.1 order). | Screenshot over a plain background: a subtle dark plane lifts the glass off the background. |
| REQ-UI-031 | The shadow MUST follow the shape outline. | Shadow path mirrors the shape for all three shapes. |
| REQ-UI-032 | The shadow's darkness MUST scale with appearance (darker in dark mode). | Light vs. dark screenshots differ by the alpha above. |
| REQ-UI-072 | The AppKit/UIKit host views MUST NOT draw a drop shadow. | Source review: no `shadow…` layer properties set by either host view. |
| REQ-UI-073 | Test fixtures that compare the SwiftUI renderer against the platform hosts MUST account for the missing platform shadow. | The visual comparison in §11.2 excludes the shadow region. |

> **Why the platform hosts omit the shadow:** a platform glass view is normally embedded edge-to-edge in a host container (for example via `addLiquidGlassBackground` or Auto Layout edge constraints). Any shadow drawn outside the view's bounds is clipped by that container — on AppKit a layer-backed parent clips by default — so the shadow would render as a hard-edged sliver or not at all. Elevation therefore belongs to the host container, which can also expand its bounds to make room for it. See the [AppKit & UIKit guide](Sources/LiquidGlass/Documentation.docc/AppKitAndUIKit.md) for per-platform `layer.shadow…` snippets.

### 5.5 v26 outline (default, `style = .v26`)

The v26 outline is the **original look**: a 5-stop angular gradient stroked around the full shape.

| Property | Value |
|---|---|
| Stroke | Full shape path, **centered** `.stroke(...)` (half of the 1 pt line falls outside the shape), blend mode `plusLighter`, not clipped by SwiftUI |
| Base color `strokeBase` | `tint` set: `tint` at alpha `0.3`; else light: white; dark: gray(0.5) at alpha `0.3` |
| High stop | `strokeBase` at alpha `× 0.7` |
| Low stop | `strokeBase` at alpha `× 0.1` |
| Cross-stack parity | SwiftUI keeps its centered stroke unclipped. AppKit/UIKit draw the same centered stroke at `2 ×` width and clip it to the shape, so the visible 1 pt sits fully inside. Stop alphas are identical across stacks (no scaling). |
| Stop layout | `high@0`, `low@mid1`, `high@0.5`, `low@mid2`, `high@1` |
| Angles | Circle: `startAngle = π+π/4`, `mid1 = 0.25`, `mid2 = 0.75`. Rounded rect / capsule: geometry-derived (`v26AngleParameters`) |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-033 | The full outline MUST follow the shape edge with gradient stops exactly as specified. | Visual/regression test against the reference implementation. |
| REQ-UI-034 | The highlight of the outline MUST be brighter top-leading and fade through the geometry-derived angles (45° diagonal character). | Screenshot shows a bright diagonal emphasis on the upper-left of rounded rect/capsule shapes. |
| REQ-UI-035 | The `plusLighter` (additive) blend MUST be used for the outline. | On a bright background the outline brightens rather than darkens. |

### 5.6 v27 outline (`style = .v27`)

The v27 outline is a **dedicated look**: a horizontal "lens" highlight on the straight top/bottom edges plus a full-outline gray border.

| Property | Value |
|---|---|
| Lens stroke | Line width `1.2` pt, blend mode `plusLighter` |
| Lens gradient (rounded rect / capsule) | Left→right: `strokeBase×0.3 @ 0`, `strokeBase×0.9 @ 0.5`, `strokeBase×0.3 @ 1` |
| Lens geometry | Only the top and bottom outline segments, including the rounded corner arcs (`HorizontalEdges` path) |
| Circle outline | Full circle, line width `1.2` pt: top→bottom `strokeBase`, transparent `@ 0.5`, `strokeBase` |
| Dark border | Full outline, **centered** `.stroke(...)`, line width `1` pt, `Color.gray` (50% gray); alpha light `0.2`, dark `0.1`. Drawn outside the `plusLighter` group |
| Platform-view note | AppKit/UIKit draw the lens at `2 ×` width clipped to the shape, so the full 1.2 pt sits inside. The gray border is a centered `1 pt` stroke rendered in a `2 pt` bleed margin around the shape, so both halves are visible exactly as in SwiftUI (clipping the border to the shape left only a 0.5 pt inner line that was barely visible, and a `2 pt` clipped border hid most of the lens). Border and lens colors match SwiftUI exactly (gray border `0.2`/`0.1`; lens ends `×0.3`). |
| Base color `strokeBase` | Same as v26 except dark mode gray alpha `0.2` (instead of `0.3`) |

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-036 | The lens highlight MUST appear only along the straight top and bottom edges and around the corner arcs — NOT along the vertical sides. | Screenshot: vertical sides show only the faint gray border. |
| REQ-UI-037 | The lens gradient MUST brighten toward the horizontal center and fade at the corners. | The center stop alpha (0.9) is 3× the end stop alpha (0.3). |
| REQ-UI-038 | Circles use the full-outline highlight (no straight edges). | Circle in v27 shows a full bright top/bottom ring. |
| REQ-UI-039 | The full-outline gray border MUST be present around the entire shape in v27 only. | v26 shapes have no full border; v27 shapes do. |

### 5.7 Coordinate conventions

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-040 | All three stacks MUST use a shared coordinate origin/top meaning so the highlight orientation is identical (top of the shape = screen top). | The AppKit/UIKit renderer normalizes to a y-up context and mirrors the conic start angle and sweep; the SwiftUI renderer uses its native flipped coordinates. Screenshots align. |

---

## 6. Layout & Sizing

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-041 | The effect MUST scale to any non-empty frame; strokes keep their point thickness regardless of size. | Same code at 50×25 and 400×200: strokes remain 1 pt, geometry recalculates. |
| REQ-UI-042 | The glass must not impose layout on surrounding content (AppKit view exposes a sane intrinsic size of 100×60 points). | No constraint ambiguity when embedding. |
| REQ-UI-043 | The glass background MUST sit behind content without capturing pointer/touch events (background usage). | Interaction targets behind the glass remain hittable (backgrounds are non-interactive). |

---

## 7. Component Styles

The library also provides ready-made **SwiftUI** styles that reuse the glass look. The AppKit/UIKit stacks currently expose only the `LiquidGlassView` primitive; control counterparts are future work.

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-044 | `Button.glassStyleButton(shape:prominent:tint:opacity:)` renders a glass button. Defaults: `shape = .roundedRect(cornerRadius: 12)`, `prominent = false`, `tint = nil`, `opacity = 0.8`. The label receives 5 pt padding over the glass, using `.buttonStyle(.plain)`. | Button looks glassy on both paths; parameters take effect. |
| REQ-UI-045 | `GlassToggleStyle` renders an animated glass toggle. Defaults: `height = 25`, horizontal `padding = 8`, glass `opacity = 0.6`, all customizable via `.height/.padding/.tint/.glassOpacity`. | Toggle animates and honors customization. |
| REQ-UI-046 | `GlassIconLabel` renders a circular glass platter behind its icon. The platter uses `tint ?? .accentColor` at glass opacity `0.2`, sized `size × size`; the icon uses `iconFont` and `iconTint ?? tint ?? .primary`. `.iconOnly()` hides the title. | Label renders with the glass platter. |
| REQ-UI-047 | Component styles MUST not crash or distort at minimum content sizes. | Run each at zero/one-char content. |
| REQ-UI-068 | On Platform 26+ the glass button MUST use the native `.glass` / `.glassProminent` styles (`.borderedProminent` on visionOS) unless the custom renderer is forced, mapping the `BackgroundShape` to `buttonBorderShape` on macOS 14+ / iOS 17+. | Native path selected on 26+; shape mapping visible. |
| REQ-UI-069 | In the custom glass button, the tint MUST be `nil` while pressed and `prominent ? (tint ?? .accentColor) : nil` otherwise; hover feedback MUST be enabled only while not pressed. | Pressed state clears the tint; prominent buttons show the accent/tint color. |
| REQ-UI-070 | `GlassToggleStyle` MUST show the full label when on — title plus a filled symbol (icon tinted when `tint` is set) in a capsule with horizontal padding and the configured height — and only the symbol in a `height × height` circle when off. It animates `0.3 s` ease-in-out with an opacity (+ symbol-effect where available) transition; tapping toggles the state. | Toggle expands/collapses smoothly and matches the capsule/circle shapes. |

---

## 8. Interaction & Feedback

The hover highlight is the shared `GlassHoverEffect` modifier. It draws a shape-matched fill **behind** the glass background (the modifier is applied after the glass background), gated to macOS `onHover`. Light mode uses an opaque white fill; dark mode uses `.quinary` (on OS versions without hierarchical styles it falls back to `gray × 0.3`). The fill animates in and out with an explicit animation, and is off entirely when `hoverEffect` is `false`.

The AppKit ``LiquidGlassView`` exposes the same behavior through its `hoverEffect` property, drawing a shape-clipped fill *below* the frosting (opaque white in light appearance, a faint white wash in dark). UIKit has no hover, matching SwiftUI's macOS-only behavior.

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-048 | `.liquidGlass(..., hoverEffect: true)` — and `LiquidGlassView.hoverEffect` on AppKit — MUST show a subtle shape-matched fill on pointer hover (macOS only): white in light mode, `.quinary` in dark mode. | Hover shows the fill; leaving clears it, animated with an explicit duration. |
| REQ-UI-049 | Hover feedback MUST NOT be active on non-hover-capable platforms or when `hoverEffect` is off. | Check iOS (no hover) and macOS with the flag off. |
| REQ-UI-050 | The hover fill MUST match the shape (rounded rect/circle/capsule), not a rectangle. | Screenshot during hover. |
| REQ-UI-071 | Hover highlighting MUST be non-destructive: it adds a separate background fill and MUST NOT alter the glass renderer's tint, highlight, or outline. | Toggling hover changes only the fill behind the glass; the glass layers render identically. |

---

## 9. Accessibility

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-051 | The glass MUST NOT be presented as an accessibility element on its own; it is decorative. | VoiceOver does not announce the glass views/elements. |
| REQ-UI-052 | Foreground content over glass MUST remain legible at the default contrast ratio with `opacity = 0.6` over a mid-tone background. | Measure contrast of sample text over glass ≈ over the raw background (degradation < 10%). |
| REQ-UI-053 | Concise titles/captions MUST not be duplicated; ephemeral status changes SHOULD use existing system announcements only. | No duplicate accessibility labels added. |

---

## 10. Performance & Rendering

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-054 | The SwiftUI renderer MUST reuse path geometry across frames (no per-frame shape allocation during animation). | `CustomShape.path` builds paths directly; no throwaway system-shape allocations (source review + instruments). |
| REQ-UI-055 | The AppKit/UIKit renderers MUST redraw only when parameters, bounds, or appearance change — not continuously. | CPU is idle when the view is static (Instruments: no continuous display cycle). |
| REQ-UI-056 | A static glass view MUST not animate or re-render unless animated explicitly by the caller. | Screen capture over 2 s shows identical composited frames. |
| REQ-UI-057 | The conic-fan approximation MUST use a fixed segment count adequate for the stroke thickness (`240` wedges in the platform renderer). | No performance regression on mid-rate devices at typical sizes. |

---

## 11. Testing & Acceptance Criteria

### 11.1 Unit tests

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-058 | Shape geometry MUST be covered by unit tests (all three shapes, corner-radius clamping, degenerate bounds). | Test suite passes. |
| REQ-UI-059 | Parameter clamping MUST be covered (opacity/radius ranges). | Tests pass for out-of-range inputs (REQ-UI-011). |
| REQ-UI-060 | Defaults MUST match the specification (§4.3). | Tests assert `opacity == 0.6`, version `.v26`. |

### 11.2 Visual regression

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-061 | Each renderer stack MUST have a golden sample per mode (light/dark), shape, and style. | Diff of a fresh render vs. golden ≤ small tolerance (anti-aliased pixels allowed ±1). |
| REQ-UI-062 | SwiftUI vs. AppKit vs. UIKit MUST agree at 1× within tolerance, excluding the SwiftUI-only shadow region (§5.4). | Pixel diff passes inside the shape and its outline; the v26 fan approximation reads equivalent (REQ-UI-022). |

### 11.3 Manual QA checklist

- [ ] Frosting clips exactly to the shape (REQ-UI-023). 
- [ ] Tint wash present only with tint set (REQ-UI-026).
- [ ] Highlight brightens with opacity (REQ-UI-010).
- [ ] SwiftUI shadow sits below and follows the shape (REQ-UI-030/031); platform hosts draw no shadow (REQ-UI-072).
- [ ] v26 diagonal outline; v27 lens top/bottom + gray border (REQ-UI-033/036/039).
- [ ] Hover fill is white (light) / `.quinary` (dark), shape-matched, and animated (REQ-UI-048/050).
- [ ] Light/dark switch repaints all stacks (REQ-UI-016).
- [ ] Native vs. custom selection works (REQ-UI-012→014).
- [ ] AppKit/UIKit sample apps render all three shapes in both styles.

---

## 12. Constraints & Dependencies

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-UI-063 | Zero runtime dependencies; the effect is built from platform primitives. | `Package.swift` lists no runtime `dependencies` (only dev-only DocC/SwiftLint plugins). |
| REQ-UI-064 | The implementation MUST support the package's deployment floors: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+. | The package builds at each floor (CI matrix). |
| REQ-UI-065 | Where a newer SDK API is unavailable at the deployment floor, an equivalent older API MUST be used. | e.g., `CGColor` conversion uses the API available at the floor (see change notes in CHANGELOG). |

---

## 13. Risks & Open Questions

| ID | Risk / Question | Mitigation / Status |
|---|---|---|
| R-1 | Masked `NSVisualEffectView` can ignore its mask on some macOS releases, showing a rectangular blur. | Container-view + layer-mask technique is the mitigation. Verify on target OS matrix; fallback: internal content clipping. |
| R-2 | Conic-fan approximation is not pixel-identical to SwiftUI `AngularGradient`. | Acceptance tolerance defined (REQ-UI-022/062); no functional impact. |
| R-3 | The two outline styles (v26/v27) intentionally differ; adding more styles is future work. | `LiquidGlassRenderer.Style` is an enum — extensible without breaking callers. |
| R-4 | ~~The platform v27 lens used `×0.1` end stops and a black 0.10 border.~~ | Resolved: the renderer now uses SwiftUI's `×0.3` lens stops and gray `0.2`/`0.1` border. |
| Q-1 | Should AppKit/UIKit `LiquidGlassView` gain hover/pointer feedback and control counterparts matching the SwiftUI `glassHoverEffect` and component styles? | Resolved for the effect view: AppKit `LiquidGlassView.hoverEffect` matches §8; UIKit has no hover. Control counterparts remain out of scope and SwiftUI-only (§7). |
| Q-2 | Should the UI requirement doc live in DocC for discoverability? | Currently a repo-root markdown; can be re-homed if desired. |
