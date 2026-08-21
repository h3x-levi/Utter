import SwiftUI

// MARK: - Liquid Glass control kit
//
// Controls are the one place Apple *wants* Liquid Glass, so this is where the
// material earns its keep. Everything here follows three rules from the HIG:
//
//   1. Glass belongs to the control/navigation layer, never behind body text.
//      (Materials → "Don't use Liquid Glass in the content layer.")
//   2. `.interactive()` rather than hand-rolled press states. Apple: it applies
//      "the same responsive and fluid reactions that `.glass` provides to
//      standard buttons" — reimplementing that by hand is how a control stops
//      feeling native.
//   3. Batch into a `GlassEffectContainer`. Each glass view outside a container
//      is its own render pass; AppKit's own docs say a container "reduc[es] the
//      number of passes required to render similar glass effect views."
//
// Two things Apple does NOT publish, so they are not invented here: there is no
// documented spring/duration for glass transitions (Apple's own samples use a
// bare `withAnimation { }`, so that is what these use), and there is no glass
// `ToggleStyle` in the SDK at all — the entire glass surface in SwiftUI is
// `glassEffect`, `.buttonStyle(.glass)`, and `.glassProminent`. A toggle's knob
// becomes glass transiently, but only the system can do that, so `GlassToggle`
// below wraps the real `Toggle` rather than faking a switch.

// MARK: - Segmented control

/// A segmented picker with a glass selection indicator that slides.
///
/// This replaces two pop-up menus (`Picker` with the default menu style). The
/// HIG's own test for a pop-up is whether the set is large: "If you need to
/// present more than about five options, consider using a component like a
/// pop-up button." Both of the choices this replaces — the settings pane and the
/// record hotkey — have three and four options, so hiding them behind a click
/// was costing a click and all of the affordance for nothing.
///
/// The indicator is a single glass capsule moved with `matchedGeometryEffect`,
/// so selection *slides* between segments rather than blinking.
struct GlassSegmentedControl<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    /// Optional SF Symbol per option.
    var symbol: ((T) -> String?)? = nil
    @Binding var selection: T

    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(track)
    }

    private func segment(_ option: T) -> some View {
        let isSelected = selection == option
        return Button {
            // `withAnimation(nil)` does not mean "use the default" — it clears the
            // transaction's animation outright. So the branches were inverted: with Reduce
            // Motion OFF (the default) the `matchedGeometryEffect` indicator had nothing to
            // move under and teleported between segments, and it only slid for the users who
            // had asked for *less* motion. `Motion.listChange` matches `GlassTabBar` below,
            // which drives the identical indicator.
            withAnimation(motion.reduceMotion ? Motion.reduced : Motion.listChange) {
                selection = option
            }
        } label: {
            HStack(spacing: Space.x1 + 2) {
                if let name = symbol?(option) {
                    Image(systemName: name).font(.system(size: 12, weight: .medium))
                }
                Text(label(option)).typo(.callout, ink: isSelected ? Ink.primary : Ink.secondary)
            }
            .padding(.horizontal, Space.x3)
            .frame(height: 26)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    // One indicator, moved between segments — not one per
                    // segment fading in and out.
                    selectionIndicator
                        .matchedGeometryEffect(id: "glassSegmentIndicator", in: indicator)
                }
            }
            // `Rectangle`, not `Capsule` — the shape of the *target*, not of the art.
            //
            // A `Capsule` here matched `selectionIndicator`, which reads as the tidy choice and
            // is wrong: the segments tile edge to edge, so a capsule on each one leaves four
            // dead wedges per segment, and they meet at the segment *boundaries* — the place a
            // pointer most often lands when moving between two options. On a 26pt-tall segment
            // the capsule's ends are radius 13, so each end forfeits `13×26 − π·13²/2` ≈ 72pt²;
            // for three segments across ~300pt that is ~5.6% of each segment, all of it on the
            // edges. `NSSegmentedControl` has no dead zones, and neither should this.
            //
            // The indicator stays a capsule. What the user clicks and what they see are allowed
            // to differ, and here they have to: a rectangle tiles without gaps, a capsule does
            // not, and only one of those two jobs is about pixels.
            //
            // `GlassTabBar` below already did this, and it drives the identical indicator — so
            // this was two spellings of one control, not two decisions.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if #available(macOS 26.0, *),
           GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            Capsule().fill(.clear).glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule().fill(Surface.raised)
                .overlay(Capsule().strokeBorder(Line.hairline, lineWidth: Line.width))
        }
    }

    /// The recessed track the indicator rides in. Content-layer, so a plain fill
    /// rather than a second sheet of glass — the HIG warns against "layering
    /// Liquid Glass elements on top of each other."
    private var track: some View {
        Capsule().fill(Surface.fillSubtle)
            .overlay(Capsule().strokeBorder(Line.hairline.opacity(0.6), lineWidth: Line.width))
    }
}

// MARK: - Buttons

/// The app's standard button. Glass on macOS 26, bordered below it.
///
/// `role: .destructive` tints red; `prominent` uses `.glassProminent`, which the
/// HIG limits to "one or two per view" — it is the call to action, not a style.
struct GlassButton: View {
    let title: String
    var systemImage: String? = nil
    var prominent: Bool = false
    var role: ButtonRole? = nil
    /// The control size, because the style used to pin it and silently win.
    ///
    /// `GlassButtonLook` applies `.controlSize(.large)` to the button itself, which is *closer* to
    /// it than anything a caller writes outside — `controlSize` is an environment value and the
    /// innermost application is the one the control reads. So
    /// `GlassButton(...).controlSize(.small)` compiled, read as intent, and did nothing: two call
    /// sites in this app were inert. An API that discards a caller's instruction without a word is
    /// worse than one that cannot express it, so the size is a parameter now and the outer
    /// modifier is no longer the way to ask.
    var size: ControlSize = .large
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .modifier(GlassButtonLook(prominent: prominent, size: size))
    }
}

private struct GlassButtonLook: ViewModifier {
    let prominent: Bool
    /// Applied here rather than left to the caller — see `GlassButton.size` for why an outer
    /// `.controlSize` could never have worked.
    let size: ControlSize
    @ObservedObject private var motion = MotionPreference.shared

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *),
           GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            if prominent {
                content.buttonStyle(.glassProminent).controlSize(size)
            } else {
                content.buttonStyle(.glass).controlSize(size)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent).controlSize(size)
            } else {
                content.buttonStyle(.bordered).controlSize(size)
            }
        }
    }
}

/// A compact icon-only glass button, for row actions and toolbars.
///
/// Note the 28pt frame with a larger `contentShape`: the HIG asks for a 44×44pt
/// hit region, which a visually small control can still honour by extending its
/// hit test beyond its artwork.
///
/// The surface is **persistent**, and that is the fix for what this was before: a
/// glass circle inserted only `if isHovering`, asking for `.regular.interactive()`.
/// `Glass.interactive(_:)` *is* the system's own hover and press response — Apple
/// describes it as applying "the same responsive and fluid reactions that `.glass`
/// provides to standard buttons" — so a view that does not exist until the pointer
/// arrives has already missed the event it was asking to handle. What actually
/// happened was a hand-rolled `Motion.hoverIn` fade in front of a material that
/// was never given the chance to do its own. One persistent surface, and the
/// pointer response comes from the OS, which is also the only way to get the
/// press-in and the specular reaction that make it read as native.
///
/// The pre-26 and Reduce Transparency branch is persistent too, for the same
/// reason it is persistent above: a control that is invisible until hovered has no
/// affordance. Rows that only want the button on hover fade the whole button
/// (`.opacity(isHovering ? 1 : 0)` at the row), which is a row decision, not this
/// control's.
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint ?? Ink.secondary)
                .frame(width: 28, height: 28)
                .modifier(IconButtonSurface())
                .contentShape(Rectangle().size(width: 44, height: 44))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The icon button's material. A `ViewModifier` because `@ObservedObject` needs a
/// view type to live in, and because `glassEffect` has to be applied *to* the
/// glyph rather than composited behind it in a `.background`: a shape carrier in a
/// `.background` with the effect on it is what collapsed the main window to ~133pt
/// once already (see `UsageCard.cardBackground` in `FlowMainView.swift`).
private struct IconButtonSurface: ViewModifier {
    @ObservedObject private var motion = MotionPreference.shared

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *),
           GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.background(Circle().fill(Surface.fillMuted))
        }
    }
}

// MARK: - Toggle

/// A labelled switch on a glass-consistent row.
///
/// Deliberately a real `Toggle`: macOS 26 turns the *knob* into Liquid Glass
/// while the user is dragging it, and that transient treatment is internal to
/// the system — there is no `.glass` ToggleStyle to ask for, and hand-drawing a
/// switch would lose the behaviour rather than gain it. What this adds is the
/// surrounding row: a description, and a tappable area covering the whole width.
struct GlassToggle: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.x4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).typo(.body)
                if let description {
                    Text(description).typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.x4)
            // The real title, not "". `labelsHidden()` suppresses only the *visual* label,
            // so VoiceOver keeps it as the control's accessible name — an empty string left
            // every switch in the app announced as an unnamed "off, switch", with the
            // visible text a separate element the user had to correlate by position. Same
            // pixels, 16 call sites fixed at once.
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Chip

/// A small glass chip: keycaps, placeholder tokens, badges.
///
/// `interactive` is opt-in because a chip is sometimes a label (a keycap showing
/// which key to hold) and sometimes a button (a placeholder you insert). Only the
/// latter should respond to the pointer.
struct GlassChip: View {
    let text: String
    var systemImage: String? = nil
    /// Accent for the *rim and glyph*, never the label — see below.
    var tint: Color? = nil
    var mono: Bool = false

    var body: some View {
        HStack(spacing: Space.x1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tint ?? Ink.secondary)
            }
            // The label is always label-coloured, never the tint.
            //
            // Tinted text on a tinted-glass chip measured 1.18:1 against a 4.5:1
            // floor — the accent set the text *and* the surface it sat on, so the
            // two converged and the chip became unreadable. The tint now shows in
            // the rim and the glyph, where it can't collide with the label.
            Text(text)
                .font(mono ? .system(size: 11, weight: .medium, design: .monospaced)
                           : .system(size: 12, weight: .medium))
                .foregroundStyle(Ink.primary)
        }
        .padding(.horizontal, Space.x2)
        .padding(.vertical, 3)
        .background(chipBackground)
        .overlay(
            Capsule().strokeBorder(
                tint.map { $0.opacity(0.45) } ?? Line.hairline,
                lineWidth: Line.width
            )
        )
    }

    /// A standard material, deliberately *not* `glassEffect`.
    ///
    /// A chip is a label in a capsule barely taller than its own text, so glass
    /// here sits directly behind 11pt type — and text composited onto Liquid
    /// Glass loses subpixel antialiasing, which measured roughly 3x softer glyph
    /// edges. On the monospaced placeholder tokens ([date], [clipboard]) the
    /// stems are thin enough that the loss reads plainly as blur.
    ///
    /// This is also what the HIG asks for: glass belongs to the chrome layer,
    /// and content should "use standard materials" instead. The chip keeps its
    /// tinted rim and glyph, so it still reads as part of the same design.
    private var chipBackground: some View {
        Capsule().fill(Surface.fillMuted)
    }
}

// MARK: - Text input

/// A text field in a recessed well.
///
/// The well is a *content-layer* surface, so it is a plain fill and not glass:
/// text needs a stable, opaque-enough backdrop, and glass behind an editable
/// field is exactly the "significant amount of text" case the HIG steers away
/// from. The glass in this control is the focus ring.
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var mono: Bool = false
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Space.x2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.tertiary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(mono ? .system(size: 13, design: .monospaced) : Typo.body.font)
                .focused($isFocused)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, Space.x3)
        .frame(height: 30)
        .background(Radius.rect(Radius.field).fill(Surface.sunken))
        .overlay(
            Radius.rect(Radius.field).strokeBorder(
                isFocused ? Tint.accent.opacity(0.7) : Line.hairline,
                lineWidth: isFocused ? 1.5 : Line.width
            )
        )
        .animation(Motion.hoverIn, value: isFocused)
    }
}

/// A multi-line editor in the same well as `GlassTextField`.
struct GlassTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 90
    var mono: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(mono ? .system(size: 13, design: .monospaced) : Typo.body.font)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(Space.x2)
            .frame(minHeight: minHeight)
            .background(Radius.rect(Radius.field).fill(Surface.sunken))
            .overlay(
                Radius.rect(Radius.field).strokeBorder(
                    isFocused ? Tint.accent.opacity(0.7) : Line.hairline,
                    lineWidth: isFocused ? 1.5 : Line.width
                )
            )
            .animation(Motion.hoverIn, value: isFocused)
    }
}

// MARK: - Selectable row

/// A row that can be picked, used where a list *is* the picker — speech models,
/// theme swatches. Selection is an accent wash plus a rim, not tinted glass:
/// tinted glass behind a label measured 1.17:1 contrast (4.5:1 is the floor),
/// because the material applies its own vibrancy to whatever it composites.
///
/// The hand-rolled `isHovering` below looks like the mistake `GlassIconButton`
/// above had, and is not. `Glass.interactive(_:)` is a property *of the glass
/// material* — it can only supply a pointer response to a view that has a
/// `glassEffect` for it to modulate. This row deliberately has none (see the
/// contrast measurement), so there is no system response to defer to and a fill
/// that changes on hover is the whole mechanism, not a reimplementation of one.
struct GlassSelectableRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: action) {
            content()
                .padding(Space.x3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background)
                .contentShape(Radius.rect(Radius.card))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var background: some View {
        let shape = Radius.rect(Radius.card)
        shape
            .fill(isSelected
                  ? Tint.accent.opacity(isDark ? 0.22 : 0.13)
                  : (isHovering ? Surface.fillHover : Surface.fillSubtle))
            .overlay(shape.strokeBorder(
                isSelected ? Tint.accent.opacity(0.45) : Line.hairline,
                lineWidth: Line.width
            ))
    }
}

// MARK: - Flow layout

/// Lays children out left to right, wrapping to a new line when they run out of
/// width — what CSS calls flex-wrap.
///
/// SwiftUI has no built-in wrapping stack. The chip rows this replaces were plain
/// `HStack`s, which don't wrap: they either clipped or forced the whole pane
/// wider than the window.
///
/// Note `SwiftUI.Layout` spelled in full: this project's design tokens include an
/// enum called `Layout`, which shadows the protocol and makes the associated
/// types (`Subviews`) unresolvable if written bare.
struct FlowLayout: SwiftUI.Layout {
    var spacing: CGFloat = Space.x2
    var lineSpacing: CGFloat = Space.x2

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: LayoutSubviews,
                      cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                widest = max(widest, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        widest = max(widest, x - spacing)
        return CGSize(width: min(widest, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: LayoutSubviews,
                       cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Underline tabs
//
// `UnderlineTabs` lived here with zero call sites, above a doc comment claiming
// "the reference design uses these everywhere a screen has sub-views" — which
// described the reference, not this app. Every screen here navigates through the
// sidebar or a `GlassSegmentedControl`, and no screen has ever had sub-tabs. A
// component that nothing calls cannot be wrong on screen, so what it actually
// cost was a reader believing the app has two navigation idioms when it has one.
// Deleted; `GlassSegmentedControl` above is the only in-page switch.

// MARK: - Keycap

/// A single key, rendered as its own chip.
///
/// The reference splits a shortcut into one chip per key — `⌥ Opt` in one and `1`
/// in the next — rather than running them together in a single box. Two chips read
/// as two keys, which is what the user has to press.
///
/// A standard material, not `glassEffect` — the same call `GlassChip` makes above,
/// for the same measured reason, and this is the view that needed it most. An 18pt
/// chip drawing `Typo.keycap` (11pt medium) is glass sitting *directly* behind
/// small type, and text composited onto Liquid Glass loses subpixel antialiasing:
/// roughly 3× softer glyph edges. It also draws the string the app repeats more
/// than any other — the user's own hotkey name, in the ready panel and in three
/// shortcut hints in Settings — so a soft-edged keycap is soft in the one place
/// the user has to read a key and go press it.
///
/// This is what the HIG asks for as well: glass belongs to the chrome layer, and
/// content should "use standard materials" instead. The keycap's own hairline and
/// muted fill are what make it read as a key.
struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .typo(.keycap, ink: Ink.secondary)
            .padding(.horizontal, Space.x2 - 2)
            .frame(height: 18)
            .background(background)
    }

    private var background: some View {
        let shape = Radius.rect(Radius.chip)
        return shape.fill(Surface.fillMuted)
            .overlay(shape.strokeBorder(Line.hairline, lineWidth: 0.5))
    }
}

/// A shortcut as a row of individual keycaps, optionally followed by a caption.
struct ShortcutHint: View {
    let keys: [String]
    var caption: String? = nil
    /// What VoiceOver says in place of the keycaps. The modifier glyphs are symbol
    /// characters — "⌃⌥N" is announced as their Unicode names or skipped — so a
    /// chord passes `KeyChord.spelled` here and the shortcut is actually spoken.
    var spokenKeys: String? = nil

    var body: some View {
        HStack(spacing: Space.x1) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Keycap(key: key)
            }
            if let caption {
                Text(caption)
                    .typo(.caption, ink: Ink.tertiary)
                    .padding(.leading, Space.x1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            (spokenKeys ?? keys.joined(separator: " "))
                + (caption.map { ", \($0)" } ?? "")
        )
    }
}
