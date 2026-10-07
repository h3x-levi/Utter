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
//      standard buttons" - reimplementing that by hand is how a control stops
//      feeling native.
//   3. Batch into a `GlassEffectContainer`. Each glass view outside a container
//      is its own render pass; AppKit's own docs say a container "reduc[es] the
//      number of passes required to render similar glass effect views."
//
// Two things Apple does NOT publish, so they are not invented here: there is no
// documented spring/duration for glass transitions (Apple's own samples use a
// bare `withAnimation { }`, so that is what these use), and there is no glass
// `ToggleStyle` in the SDK at all - the entire glass surface in SwiftUI is
// `glassEffect`, `.buttonStyle(.glass)`, and `.glassProminent`. A toggle's knob
// becomes glass transiently, but only the system can do that, so `GlassToggle`
// below wraps the real `Toggle` rather than faking a switch.
//
// **Everything here is a real system control.** That is the fourth rule, and it
// was the one being broken: a `Button`+`Capsule` segmented control, a `Circle`
// behind an icon, a `RoundedRectangle` well behind a `TextField`. Each of those
// reimplemented the pixels and silently dropped what only the OS supplies - the
// pointer-over highlight, the pressed state, the keyboard focus ring, and the
// accessibility role. The measurement that made this urgent: the hand-drawn
// light-mode hover wash came out at **1.142:1** against a light theme's card,
// i.e. a hover state the user cannot see (see `Surface.fillHover`). A system
// control's hover is drawn by AppKit against the appearance it is actually in,
// which is not a value this file can get wrong.

// MARK: - Segmented control

/// A segmented picker.
///
/// This replaces two pop-up menus (`Picker` with the default menu style). The
/// HIG's own test for a pop-up is whether the set is large: "If you need to
/// present more than about five options, consider using a component like a
/// pop-up button." Both of the choices this replaces - the settings pane and the
/// record hotkey - have three and four options, so hiding them behind a click
/// was costing a click and all of the affordance for nothing.
///
/// A real `Picker` with `.segmented`, which is `NSSegmentedControl`. What that
/// supplies and the `Button`-per-segment build it replaces did not: pointer-over
/// highlighting, the pressed state, a keyboard focus ring, arrow-key traversal
/// between segments, and VoiceOver announcing each segment with its position and
/// selected state. The sliding `matchedGeometryEffect` indicator, the recessed
/// track, and the `withAnimation` on selection are all gone with it - the system
/// animates its own selection, and honours Reduce Motion while doing it.
struct GlassSegmentedControl<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    /// Optional SF Symbol per option. No call site passes one today; a segmented
    /// `Picker` renders it through `Label`, so what shows is whatever
    /// `NSSegmentedControl` does with an image-and-text segment rather than
    /// something drawn here.
    var symbol: ((T) -> String?)? = nil
    @Binding var selection: T

    var body: some View {
        // The title is empty and hidden because this control has no title
        // parameter to pass one through: all three call sites put a `Text` above
        // the control instead. That leaves the *group* unnamed to VoiceOver - the
        // segments themselves are named - which is exactly as it was before, and
        // is fixed by giving the callers a label to pass, not by inventing one.
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { option in
                if let name = symbol?(option) {
                    Label(label(option), systemImage: name).tag(option)
                } else {
                    Text(label(option)).tag(option)
                }
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Buttons

/// The app's standard macOS button.
///
/// `role: .destructive` tints red; `prominent` is reserved for the primary action.
struct GlassButton: View {
    let title: String
    var systemImage: String? = nil
    var prominent: Bool = false
    var role: ButtonRole? = nil
    /// Native macOS sizing by default; screens opt into a larger primary control explicitly.
    var size: ControlSize = .regular
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
    let size: ControlSize

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent).controlSize(size)
        } else {
            content.buttonStyle(.bordered).controlSize(size)
        }
    }
}

/// A compact icon-only button, for row actions and toolbars.
///
/// The surface stays persistent: a control that is invisible
/// until hovered has no affordance. Rows that only want the button on hover fade
/// the whole button (`.opacity(isHovering ? 1 : 0)` at the row), which is a row
/// decision, not this control's.
///
/// `tint` still colours the *glyph* rather than being handed to `.tint()`. On a
/// bordered button `.tint` fills the bezel, so a destructive row action would
/// become a red-filled button rather than a red glyph - louder than the six call
/// sites intend, and the same collision `GlassChip` measured below.
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        glyphButton.buttonStyle(.bordered)
    }

    private var glyphButton: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint ?? Ink.secondary)
                // The HIG asks for a 44×44pt hit region, which a visually small
                // control can still honour by extending its hit test beyond its
                // artwork. Kept from the previous revision; whether a
                // `PrimitiveButtonStyle` that wraps the label in its own bezel
                // still reads an enlarged content shape from inside it is
                // **unverified** - it needs a pointer on a device, not a build.
                .contentShape(Rectangle().size(width: 44, height: 44))
        }
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Toggle

/// A labelled switch on a glass-consistent row.
///
/// Deliberately a real `Toggle`: macOS 26 turns the *knob* into Liquid Glass
/// while the user is dragging it, and that transient treatment is internal to
/// the system - there is no `.glass` ToggleStyle to ask for, and hand-drawing a
/// switch would lose the behaviour rather than gain it. What this adds is the
/// surrounding row: a title and a description on the leading side.
///
/// The `HStack` + `labelsHidden()` is not a hand-built substitute for the
/// `Toggle`'s own label, it is what pins the *order*. Outside a `Form`, a macOS
/// `.switch` Toggle draws the switch **leading** of its label; inside a grouped
/// `Form` it draws label-leading, switch-trailing. All 16 call sites sit in
/// `SettingsCard`/`VStack`, so relying on the Toggle's own label would put the
/// switch on the left at every one of them. If a screen moves to
/// `Form`/`.formStyle(.grouped)`, this row should be replaced there by a plain
/// `Toggle(title, isOn:)` and let the Form do the layout.
///
/// Not `LabeledContent`, which is the system component this row's shape otherwise
/// matches: it restyles its label with `secondaryLabelColor`, and that colour
/// measured **4.01:1** on this app's translucent tiles - under the 4.5:1 floor  - 
/// which is the whole reason `Ink.secondary` exists (see `DesignTokens`). Keeping
/// the row means keeping the measured ink.
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
            // so VoiceOver keeps it as the control's accessible name - an empty string left
            // every switch in the app announced as an unnamed "off, switch", with the
            // visible text a separate element the user had to correlate by position. Same
            // pixels, 16 call sites fixed at once.
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // No `.contentShape(Rectangle())`. It was here under a doc comment
        // claiming "a tappable area covering the whole width", and it never did
        // that: `contentShape` sets a hit *shape*, and with no gesture attached to
        // the row there was nothing to consume the hit. Only the switch was ever
        // clickable. Click-anywhere-on-the-row is what a grouped `Form` gives a
        // `Toggle` for free, which is the reason to move a screen to one rather
        // than to add a tap gesture to a view that does not look like a button.
    }
}

// MARK: - Chip

/// A small chip: placeholder tokens, badges.
///
/// **Not a `Toggle(...).toggleStyle(.button)` and not a `Button`, because it is
/// neither.** It has no action and no binding, and none of its six call sites is a
/// filter or a selection: "dictated", "dynamic", "replaces"/"appends", "English",
/// "Latest" are all read-only badges. The one call site that is clickable
/// (`FeatureViews`, the placeholder tokens) supplies its own `Button` *around* the
/// chip, so the interactivity - and the missing hover with it - lives in that
/// file, not this one.
///
/// SwiftUI's badge component is `.badge(_:)`, which only renders inside a `List`
/// row or a `TabView` item, so there is no system control to wrap here. This stays
/// hand-drawn, and being hand-drawn is safe *because* it is not interactive: there
/// is no hover, press or focus state for the system to have supplied.
struct GlassChip: View {
    let text: String
    var systemImage: String? = nil
    /// Accent for the *rim and glyph*, never the label - see below.
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
            // floor - the accent set the text *and* the surface it sat on, so the
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
    /// here sits directly behind 11pt type - and text composited onto Liquid
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

/// A text field.
///
/// `.textFieldStyle(.roundedBorder)` - `NSTextField` in its rounded bezel. The
/// well, the 30pt frame, the `@FocusState` and the hand-drawn focus ring
/// (`Tint.accent.opacity(0.7)` at 1.5pt, animated on `Motion.hoverIn`) are all
/// gone: the system bezel *is* the well, and it draws the real
/// `keyboardFocusIndicatorColor` ring - which, unlike the accent imitation,
/// follows the user's Increase Contrast and Full Keyboard Access settings and is
/// the ring every other field on the machine draws. It also gets the text
/// insertion cursor, the secondary-click services menu and the standard
/// field-editor behaviours that a `.plain` field in a custom shape does not.
///
/// The height is now the control's own (~22pt at the default control size) rather
/// than a fixed 30pt, and the bezel replaces `Surface.sunken`. Both are visible
/// changes, and both are the point: a themed rectangle cannot hover, focus, or
/// respond to Increase Contrast, and the bezel samples the themed window behind it.
///
/// `systemImage` renders *outside* the bezel. A rounded-border `NSTextField` has no
/// leading-accessory slot, and reaching for one with an `.overlay` would put a
/// glyph on top of the field's own text area. Two call sites pass one.
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var mono: Bool = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Space.x2) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.tertiary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(mono ? .system(size: 13, design: .monospaced) : Typo.body.font)
                .onSubmit { onSubmit?() }
        }
    }
}

/// A multi-line editor in a recessed well.
///
/// **The one input that stays hand-drawn, and the SDK is the reason.** There is no
/// macOS `TextEditorStyle`: `.roundedBorder` is declared
/// `@available(macOS, unavailable)` and `.plain` is macOS 14.0+ (verified in
/// `SwiftUI.swiftinterface`), so a `TextEditor` on this app's 13.3 floor draws no
/// bezel and no focus ring of its own. Deleting the well would leave a transparent
/// scroll view with no edge, and deleting the ring would leave the only multi-line
/// input in the app with **no visible keyboard focus at all** - which is an
/// accessibility regression, not a simplification.
///
/// The well is a *content-layer* surface, so it is a plain fill and not glass:
/// text needs a stable, opaque-enough backdrop, and glass behind an editable field
/// is exactly the "significant amount of text" case the HIG steers away from.
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

/// A row that can be picked, used where a list *is* the picker - speech models,
/// theme swatches. Selection is an accent wash plus a rim, not tinted glass:
/// tinted glass behind a label measured 1.17:1 contrast (4.5:1 is the floor),
/// because the material applies its own vibrancy to whatever it composites.
///
/// The hand-rolled `isHovering` below looks like the mistake `GlassIconButton`
/// above had, and is not. `Glass.interactive(_:)` is a property *of the glass
/// material* - it can only supply a pointer response to a view that has a
/// `glassEffect` for it to modulate. This row deliberately has none (see the
/// contrast measurement), so there is no system response to defer to and a fill
/// that changes on hover is the whole mechanism, not a reimplementation of one.
///
/// **This type should not survive.** The system component for "a row you can pick"
/// is `List` with a selection binding: it draws the hover wash, the selection fill
/// in the correct appearance, the focus ring, arrow-key and type-select navigation,
/// and the accessibility table role - none of which the code below has. It cannot
/// be reached from here, though, because macOS has no row-selection style outside a
/// `List` and both call sites are `VStack` + `ForEach`: `DiagnosticsView` (crash
/// logs) and `NotesView.NoteRow`. Converting those two to
/// `List(selection:)`/`.listStyle(.inset)` retires this whole type; until then it
/// is what keeps the two of them consistent, so it stays as it is.
///
/// The hover wash is at least now *visible*: `Surface.fillHover` moved 0.06 → 0.10
/// after 6% measured **1.142:1** on a light theme's card, which is the report this
/// refactor came from. 10% measures 1.253:1, roughly AppKit's own list-row step.
@MainActor
private final class GlassRowHoverModel: ObservableObject {
    @Published var isHovering = false
}

struct GlassSelectableRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @StateObject private var model = GlassRowHoverModel()
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
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { model.isHovering = hovering }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var background: some View {
        let shape = Radius.rect(Radius.card)
        shape
            .fill(isSelected
                  ? Tint.accent.opacity(isDark ? 0.22 : 0.13)
                  : (model.isHovering ? Surface.fillHover : Surface.fillSubtle))
            .overlay(shape.strokeBorder(
                isSelected ? Tint.accent.opacity(0.45) : Line.hairline,
                lineWidth: Line.width
            ))
    }
}

// MARK: - Flow layout

/// Lays children out left to right, wrapping to a new line when they run out of
/// width - what CSS calls flex-wrap.
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
// "the reference design uses these everywhere a screen has sub-views" - which
// described the reference, not this app. Every screen here navigates through the
// sidebar or a `GlassSegmentedControl`, and no screen has ever had sub-tabs. A
// component that nothing calls cannot be wrong on screen, so what it actually
// cost was a reader believing the app has two navigation idioms when it has one.
// Deleted; `GlassSegmentedControl` above is the only in-page switch.

// MARK: - Keycap

/// A single key, rendered as its own chip.
///
/// The reference splits a shortcut into one chip per key - `⌥ Opt` in one and `1`
/// in the next - rather than running them together in a single box. Two chips read
/// as two keys, which is what the user has to press.
///
/// A standard material, not `glassEffect` - the same call `GlassChip` makes above,
/// for the same measured reason, and this is the view that needed it most. An 18pt
/// chip drawing `Typo.keycap` (11pt medium) is glass sitting *directly* behind
/// small type, and text composited onto Liquid Glass loses subpixel antialiasing:
/// roughly 3× softer glyph edges. It also draws the string the app repeats more
/// than any other - the user's own hotkey name, in the ready panel and in three
/// shortcut hints in Settings - so a soft-edged keycap is soft in the one place
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
    /// characters - "⌃⌥N" is announced as their Unicode names or skipped - so a
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
