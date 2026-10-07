import SwiftUI
import AppKit

// MARK: - Liquid Glass
//
// macOS 26 introduces Liquid Glass: a material that refracts and reacts to what
// sits behind it. Apple is specific about where it belongs, and the constraint
// shapes this whole file (Human Interface Guidelines → Materials):
//
//   "Liquid Glass forms a distinct functional layer for controls and navigation
//    elements - like tab bars and sidebars - that floats above the content
//    layer… Don't use Liquid Glass in the content layer… including it in the
//    content layer can result in unnecessary complexity and a confusing visual
//    hierarchy. Instead, use Standard materials for elements in the content
//    layer, such as app backgrounds."
//
// So the app is glass in two different senses, deliberately:
//
//   `.chrome`  - real `glassEffect`. A surface that floats in its own window,
//                above whatever it acts on, carrying controls rather than prose.
//   `.content` - a standard translucent material with the same rim and
//                highlight treatment. In-window containers that hold text.
//
// Stated as a test rather than a list of screens, because the list has gone
// stale twice: does the surface float above the content it acts on, *and* is what
// sits on it a control rather than a paragraph? Both - `.chrome`. Either one
// missing - `.content`. `grep -rn 'glassSurface(' Sources` for today's answer.
//
// Both read as one glass family, but only the floating layer pays the
// refraction cost, and no paragraph of text is ever asked to sit on a surface
// that warps what's behind it. Apple names the exact case: use `.regular` glass
// "when background content might create legibility issues, or when components
// have a significant amount of text."
//
// Everything degrades in two directions - down to macOS 13.3, and sideways when
// Reduce Transparency is on. The HIG only promises automatic accessibility
// adaptation for *standard* components ("Ensure you test your app's custom
// elements"), so custom surfaces branch explicitly rather than assuming.

enum GlassRole {
    /// A surface that floats above the content it acts on and carries controls
    /// rather than prose. Gets true Liquid Glass where the OS provides it.
    case chrome
    /// Content-layer containers that hold text - bento tiles, cards. Standard
    /// translucent material, never `glassEffect`.
    case content
    /// A single emphasised control. Tinted glass, used sparingly: the HIG says
    /// to "reserve it for elements that truly benefit from emphasis" and to
    /// "refrain from adding color to the background of multiple controls."
    case accentControl
}

enum GlassSupport {
    /// True when the OS can render Liquid Glass at all.
    static var available: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// The one place that decides whether glass is drawn: supported *and* the
    /// user hasn't asked for reduced transparency.
    ///
    /// Every site that draws glass pairs this with a lexical
    /// `#available(macOS 26.0, *)`, and that pairing is not redundancy to tidy
    /// away: `glassEffect` and `GlassEffectContainer` do not exist below 26, so
    /// the compiler demands the `#available` *at the call site* before the symbol
    /// can be named at all. A runtime `Bool` cannot stand in for it. What this
    /// function owns is the other clause - the policy - and it is deliberately
    /// the only copy of it, because the policy is not settled: whether Increase
    /// Contrast should suppress glass as well is **unverified** (the SDK promises
    /// automatic adaptation only for *standard* components, and says nothing
    /// about custom surfaces). If it turns out it should, this is the single line
    /// that changes.
    static func active(reduceTransparency: Bool) -> Bool {
        available && !reduceTransparency
    }
}

// No `GlassMorphIdentity`.
//
// It bundled an id and a `Namespace.ID` for `glassEffectID(_:in:)`, on the theory that naming a glass
// body would stop `glassEffect` cross-fading it while its shape animated. Apple documents that
// identity as applying "during view hierarchy transitions" - it matches a shape that *appears or
// disappears* - so it had nothing to say about a body being resized, which is what the pill was
// asking of it. Its only caller stopped using it once the pill's size change was made instant, and an
// unreachable branch inside `ChromeGlass` is worse than no branch: it reads as a working mechanism.
// `glassEffectID` is still the right tool for the case it documents; that case is not here.

// MARK: - Surface modifier

extension View {
    /// Apply the app's glass treatment for a given role.
    ///
    /// `tint` is only honoured for `.accentControl`; for other roles the glass
    /// stays monochromatic, which is what the HIG asks for when the background
    /// is arbitrary: "prefer a monochromatic appearance for toolbars and tab
    /// bars" over colourful content.
    ///
    @ViewBuilder
    func glassSurface<S: InsettableShape>(
        _ role: GlassRole,
        in shape: S,
        reduceTransparency: Bool,
        isDark: Bool,
        tint: Color? = nil
    ) -> some View {
        switch role {
        case .chrome, .accentControl:
            self.modifier(ChromeGlass(
                shape: shape,
                reduceTransparency: reduceTransparency,
                isDark: isDark,
                tint: role == .accentControl ? tint : nil
            ))
        case .content:
            self.modifier(ContentGlass(
                shape: shape,
                reduceTransparency: reduceTransparency,
                isDark: isDark
            ))
        }
    }
}

// `flushChromeGlass` lived here: Liquid Glass for a chrome band running flush to a
// window's own edges - `glassEffect(.regular, in: Rectangle())` behind the
// `GlassSupport.active` gate, with a passthrough on the two non-glass paths.
//
// **Deleted because AppKit took the job.** Its two call sites were the main window's
// sidebar and the Settings navigation column, and both are now
// `NSSplitViewItem.sidebar` - AppKit supplies an `NSContainerConcentricGlassEffectView`
// that is concentric with the window's corner radius, which a `Rectangle()` shape
// argument structurally cannot be, and it supplies the `.sidebar` material below 26
// where this modifier was a passthrough. Zero callers remained.
//
// Three findings worth keeping, for whoever adds the next chrome band:
//   * It was deliberately **not** `glassSurface(.chrome, in:)` and deliberately not a
//     new `GlassRole`. `ChromeGlass` builds a *floating panel*: its non-26 branches add
//     a four-sided `strokeBorder` and a `Surface.raised` fill, both wrong on a band
//     whose edges are the window's - the border traces a rectangle just inside the
//     window frame and the fill replaces the shell that should show through. The role
//     was identical; the fallback *geometry* differed.
//   * **Untinted, and not `.interactive()`.** `ChromeGlass`'s theme tint (accent at
//     0.22) across a whole band is a large colour commitment, and the HIG asks for "a
//     monochromatic appearance for toolbars and tab bars". The theme still reads
//     through, because the glass samples the themed plane behind it. A band is not a
//     control; what sits on it is.
//   * The shape was the *argument*, never a carrier view. The modifier has to be
//     applied to something with an already-resolved frame, or a carrier publishes an
//     intrinsic size up through `NSHostingView` - the ~133pt window collapse this
//     file's other comments record.
//
// If a real control bar appears (`WhatsNewView` names a version filter or a floating
// "back to top" bar as the candidate), prefer a real `NSToolbar` first: that is what
// replaced the hand-drawn 30pt band in both windows. Reach for a SwiftUI surface only
// for something AppKit has no chrome structure for.

/// The floating layer: real Liquid Glass on macOS 26, a hand-built translucent
/// stack below it.
private struct ChromeGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let reduceTransparency: Bool
    let isDark: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        if reduceTransparency {
            // Opaque, themed, no translucency at all - the point of the setting.
            content
                .background(shape.fill(Surface.raised))
                .overlay(shape.strokeBorder(Line.strong, lineWidth: Line.width))
        } else if #available(macOS 26.0, *) {
            // NOTHING behind the glass. That is the whole point.
            //
            // This used to composite a themed fill at 0.55-0.78 opacity under the
            // effect, on the reasoning that glass "has no inherent colour" so a
            // theme needed something to tint it. That was backwards, and it is
            // the specific mistake Apple calls out - "Reduce your use of custom
            // backgrounds… custom backgrounds might overlay or interfere with
            // Liquid Glass", and on solid fills: "it is completely opaque and
            // breaks the visual character of Liquid Glass."
            //
            // Liquid Glass defines itself by *lensing* - it "dynamically bends,
            // shapes, and concentrates light", sampling an area larger than
            // itself. A fill underneath removes the backdrop there is to bend, so
            // all that survives is the blur. Hence "looks translucent, not like
            // glass". Colour now goes through `Glass.tint`, which tone-maps a hue
            // against the brightness behind it - the documented way to keep an
            // identity without going opaque.
            //
            // `.regular`, not `.clear`: these surfaces carry text and sit over
            // arbitrary wallpaper. `.clear` is permanently more transparent, has
            // no adaptive behaviour, and needs its own 35% dim layer.
            //
            content
                .glassEffect(glass, in: shape)
        } else {
            // Pre-26 there is no lensing to preserve, so this is an honest
            // frosted approximation rather than a pretence at glass.
            content
                .background(shape.fill(.regularMaterial))
                .background(shape.fill(Surface.canvas.opacity(0.22)))
                .overlay(shape.strokeBorder(rimGradient, lineWidth: 0.8))
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        // Tint is how a glass element keeps its own colour. Apple: "Selecting a
        // color generates a range of tones that are mapped to content brightness
        // underneath the tinted element… changing its hue, brightness and
        // saturation depending on what's behind without deviating too much from
        // the intended color."
        //
        // A theme with its own surfaces supplies that hue, so Ember still reads
        // as Ember on any wallpaper. System/Light/Dark pass `nil` and get plain,
        // uncoloured glass, which is the default the HIG expects.
        //
        // No rim overlay here either: the material draws its own highlight layer,
        // whose lights "move in space, causing light to travel around the
        // material, defining its silhouette". A static stroke on top fights that.
        let hue = tint ?? ThemeManager.shared.current.accent
        guard let hue else { return .regular.interactive() }
        return .regular.tint(hue.opacity(0.22)).interactive()
    }

    /// Top-lit rim for the pre-26 fallback only. Real glass supplies its own
    /// highlights, so this is not applied on macOS 26.
    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [.white.opacity(0.20), .white.opacity(0.04)]
                : [.white.opacity(0.55), .white.opacity(0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The content layer: standard material, per the HIG's explicit instruction not
/// to put Liquid Glass behind content. Visually part of the same family - same
/// rim, same softness - without refracting the text sitting on it.
private struct ContentGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let reduceTransparency: Bool
    let isDark: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(shape.fill(Surface.raised))
                .overlay(shape.strokeBorder(Line.strong, lineWidth: Line.width))
        } else {
            content
                // **An opaque themed fill, NOT a live `.regularMaterial`, and that is a bug fix.**
                //
                // A material tile re-samples the window's `.behindWindow` backdrop every frame.
                // When a scrollbar-thumb drag exposes a large region of the history at once, the
                // material cannot re-sample in time and paints SwiftUI Material's blank near-white
                // state - the "page goes white on the side scroller" the user reported. The mouse
                // wheel exposes a thin strip per tick, so the same cost degrades to *lag* rather
                // than white - which is exactly the two-way split they described. The content plane
                // behind these tiles is itself an `NSVisualEffectView`, and this file already quotes
                // the HIG remedy (line ~180): do not put a material over a material.
                //
                // Nearly no visual change, measured: `Veil.nestedSurface` was already 0.86 opaque
                // in light, so the material showed through ~14% and the tile rendered ≈ this same
                // `Surface.raised`. Dark loses a little translucency (nested was 0.62) and reads as
                // a more solidly themed card, which sits better in the hierarchy anyway. What it
                // costs is a per-frame backdrop sample and the white blank; what it keeps is the
                // themed colour and the rim.
                .background(shape.fill(Surface.raised))
                .overlay(shape.strokeBorder(rim, lineWidth: Line.width))
                // Light mode gets a cast shadow; dark mode does not.
                //
                // In dark mode a raised card separates by being *lighter* than the canvas, and a
                // shadow under it adds nothing a darker surround can show. In light mode there is
                // no headroom to be lighter with - `Surface.raised` for the Paper theme is already
                // (1.0, 0.988, 0.965), so the card cannot out-brighten its own canvas, which is
                // exactly why it measured 1.117:1 against it and read as flat. Depth in light mode
                // therefore has to come from the two cues a physical raised object actually gives:
                // a defined edge (`rim`, below) and a shadow. This is the shadow.
                .shadow(
                    color: isDark ? .clear : .black.opacity(0.10),
                    radius: 3, x: 0, y: 1
                )
        }
    }

    /// The card's edge, and the direction it runs is **per appearance** - not one gradient with
    /// two opacities.
    ///
    /// This was a white gradient in both appearances, and in light mode that is a white line on a
    /// near-white card: measured against `Surface.raised`, white at 60% comes out at **1.015:1** for
    /// Paper and **1.022:1** for Linen. 1.015:1 is not a subtle edge, it is no edge - which is the
    /// "so much whitewashed, no depth" report. The same gradient measures ~1.55:1 in all four dark
    /// themes, so it was tuned in dark mode and never checked in light.
    ///
    /// A raised object in light surroundings does not outline itself in white; it is bounded by the
    /// shadow it occludes. So light mode strokes the warm dark hairline the rest of the app already
    /// uses, and runs it *stronger at the bottom* where a raised edge sits in its own shadow:
    /// **1.40:1 top → 1.71:1 bottom** against the card. Dark mode keeps the top-lit white rim it
    /// always had, because there the card is the bright thing.
    private var rim: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [.white.opacity(0.14), .white.opacity(0.03)]
                : [Line.hairlineInk.opacity(0.17), Line.hairlineInk.opacity(0.26)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Container

/// Groups sibling glass surfaces into a single render pass.
///
/// Apple: "Creating too many Liquid Glass effect containers and applying too
/// many effects to views outside of containers can degrade performance." One
/// container per cluster of glass siblings, not one per surface.
///
/// The corollary, which is easy to miss: a container around content that calls no
/// `glassEffect` does nothing at all. It has no appearance of its own, so the
/// render is byte-identical with and without it, and all it buys is a reader
/// believing there is glass in there. Before wrapping something in this, check
/// that what is inside actually reaches `glassEffect` - `GlassChip`,
/// `GlassSelectableRow`, `ContentSection` and the theme/character swatches are all
/// deliberately standard materials and fills, so a container around them is a
/// no-op. The theme grid had one and it was deleted rather than kept.
struct GlassCluster<Content: View>: View {
    var spacing: CGFloat = Space.x3
    @ObservedObject private var motion = MotionPreference.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        // `#available` is the compile-time gate; `GlassSupport.active` is the
        // decision. See `GlassSupport.active` for why both clauses are here.
        if #available(macOS 26.0, *),
           GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

// MARK: - Window backing

/// An `NSVisualEffectView` for the window's content layer.
///
/// This is *not* the glass API - `NSVisualEffectView` is what the HIG calls a
/// standard material, used "to convey a sense of structure in the content
/// beneath Liquid Glass." It gives the window a live translucent backing so the
/// glass chrome above it has something real to refract, and `.behindWindow`
/// blending is what samples the desktop rather than the window's own content.
struct WindowBacking: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        // `.followsWindowActiveState` would drain the colour out of the whole
        // window whenever focus moved elsewhere, which reads as the app
        // greying out rather than as a background.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Liquid grouping
//
// `LiquidGlassGroup` (a `GlassEffectContainer` wrapper) and `GlassIdentity` (a `glassEffectID`
// wrapper) lived here, for the pill's hands-free bead and nothing else. They are deleted rather
// than kept unused, because the approach they implemented was replaced rather than supplemented.
//
// The container's proximity blend is real and it is Apple's - but its merged silhouette is not
// something you can obtain a `Path` for, so nothing can stroke it, and the pill's outer contrast
// ring is load-bearing (see `PillContent`). That left one stroke per body, i.e. two fully outlined
// objects sliding through each other. It is also a plain passthrough before macOS 26 *and* under
// Reduce Transparency, so it produced the liquid read on one of four render configurations and two
// separate objects on the other three. `PillShellShape` makes the bead a lobe of the pill's own
// silhouette instead: one `Path`, one glass body, one outline, on all four.
//
// `GlassCluster` above is a different thing and still used widely - it groups genuinely
// independent glass siblings into one render pass, which is a performance measure the HIG asks for,
// not a merge anybody depends on the shape of.
