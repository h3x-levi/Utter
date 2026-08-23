import SwiftUI

// MARK: - Empty state

/// The one empty-state treatment. No card, no border, no coloured icon —
/// an empty list should look intentional, not broken.
///
/// `ContentUnavailableView` is macOS's own component for this, and it is what the
/// system uses in Mail, Notes and Spotlight — so an empty Utter list now reads the
/// way an empty list reads everywhere else on the machine, including the icon size,
/// the title/description hierarchy and the vertical centring this view used to
/// approximate with `Space.x12` of hand-set padding.
///
/// It arrived in macOS 14.0 and this app's floor is 13.3 (`Package.swift`, set by
/// the prebuilt whisper.cpp xcframework), so it is gated and the previous
/// hand-built body is kept verbatim as the fallback rather than deleted — on 13.3
/// it is still the only implementation there is.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text(message)
            } actions: {
                if let actionLabel, let action {
                    // Same `GlassButton` at the same `.regular` size as the
                    // fallback below, for the same reason: an empty state's action
                    // is an offer, not the screen's main event.
                    GlassButton(title: actionLabel, size: .regular, action: action)
                }
            }
            // No `.accessibilityElement(children: .combine)` on this branch, unlike
            // the fallback. Combining here would fold the action button into the
            // description and take it out of VoiceOver's control order — the system
            // component already pairs its own label and description, so the manual
            // grouping is both unnecessary and harmful.
            .frame(maxWidth: .infinity)
        } else {
            legacyBody
        }
    }

    /// The pre-14 body, unchanged. Retained rather than deleted: it is what runs on
    /// the 13.3 floor, and it is the only place the icon size, the 380pt message
    /// measure and the `Space.x12` vertical rhythm are expressed.
    private var legacyBody: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Ink.tertiary)
                .symbolRenderingMode(.monochrome)

            Text(title)
                .typo(.subheading)
                .padding(.top, Space.x3)

            Text(message)
                .typo(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, Space.x2)

            if let actionLabel, let action {
                // `GlassButton`, not a bare `Button`. This is used at eight sites and was the
                // last system-default button left in the app, which made an empty state the one
                // place a primary action looked like a different app's — the same drift already
                // corrected in onboarding, the model chooser and Settings. `.regular` rather than
                // the default `.large`: an empty state's action is an offer, not the screen's
                // main event.
                GlassButton(title: actionLabel, size: .regular, action: action)
                    .padding(.top, Space.x4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.x12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section header

/// Sentence-case group header. Space above is larger than space below, so the
/// header binds visually to the content it labels.
///
/// Kept as a view rather than replaced, because what it needs to become is a
/// *position*, not a component: both call sites now pass it as the `header:` of a
/// real `Section` (`HomeView`'s per-day history groups, `SnippetsView`'s
/// placeholder group), which is what gives the group its grouping semantics. This
/// still supplies the two things `Section`'s plain `Text` header does not outside a
/// `List`: the measured `Typo.sectionHeader` ink and the `.isHeader` trait
/// VoiceOver's rotor navigates by.
///
/// (The doc comment that used to sit here described a keycap chip. `Keycap` lives
/// in `GlassControls`; the comment was left behind by a move.)
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).typo(.sectionHeader)
            if let trailing {
                Spacer()
                Text(trailing).typo(.caption)
            }
        }
        .padding(.bottom, Space.headerToContent)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Icon-only button

/// An icon-only button with both a tooltip and a VoiceOver label.
///
/// This was the app's second implementation of that, and the hand-drawn one: a
/// `.buttonStyle(.plain)` `Button` with `@State hovering`, an `.onHover` that ran
/// `withAnimation` on every pointer crossing, and a `Surface.fillHover` rectangle
/// behind the glyph. That fill *is* the user's report — 10% white on a near-white
/// tile measures **1.253:1**, and the 6% it replaced measured **1.142:1**
/// (`Surface.fillHover`'s own note). Neither is a hover state anyone can see in a
/// light theme, and no amount of tuning a hand-painted wash fixes that, because the
/// system's hover response is not a wash: `.bordered` has a resting bezel that
/// *changes*, and on macOS 26 `.glass.interactive()` reacts to the pointer.
///
/// So this now forwards to `GlassIconButton`, which is a real `Button` with an
/// `Image` label, `#available(macOS 26.0, *)`-gated `.glass` over a `.bordered`
/// fallback, `.help(label)` and `.accessibilityLabel(label)` — that is, everything
/// this type was hand-rolling, already reviewed, already type-checked, and already
/// the thing used for the identical job in `WordRow`, `SnippetRow` and
/// `CustomCommandRow`. Keeping two divergent icon buttons was the actual defect;
/// this deletes one rather than tuning it.
///
/// The name and the `(systemName:label:tint:action:)` signature are unchanged, so
/// the seven call sites in `HomeView`, `ModelChooserView` and `NotesView` are
/// untouched. Two visible consequences, both improvements and both worth knowing:
/// the glyph slot goes from 26×26 to `GlassIconButton`'s 28pt with a 44×44 hit
/// region (the HIG target this type's old comment explicitly declined), and the
/// button now has a resting bezel instead of being invisible until hovered.
struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        GlassIconButton(systemName: systemName, label: label, tint: tint, action: action)
    }
}

// MARK: - Status row

/// Label + value with a state glyph. Colour never carries meaning alone — the
/// value text always states the status too.
///
/// `LabeledContent`, macOS's own label/value pairing, replaces the hand-built
/// `HStack` + `Spacer(minLength:)` this used to be. The system now owns the column
/// split, the baseline alignment and the label→value relationship VoiceOver reads,
/// which is the part a `Spacer` could never express: two `Text`s in a stack are two
/// unrelated strings that happen to sit on one line.
///
/// Available macOS 13.0, under the 13.3 floor — no availability branch.
///
/// **Why the 4.01:1 objection to `LabeledContent` recorded in `GlassControls`
/// (`GlassToggle`) does not apply here.** That note is correct: the default style
/// restyles one side with `secondaryLabelColor`, which measured 4.01:1 on this app's
/// translucent tiles against a 4.5:1 floor. It bites when the text inherits its
/// colour. Every string in this row goes through `typo(_:ink:)`, and that helper
/// applies `.foregroundStyle(ink ?? style.ink)` unconditionally
/// (`DesignTokens.swift:511`) — an explicit colour on every call, which wins over
/// the style's restyle. So the measured inks survive. Any future row that puts bare
/// `Text` inside a `LabeledContent` on a tile *would* hit 4.01:1.
struct StatusRow: View {
    enum State { case ok, attention, neutral

        var color: Color {
            switch self {
            case .ok: return Tint.success
            case .attention: return Tint.warning
            case .neutral: return Ink.quaternary
            }
        }

        /// A distinct glyph per state, not one `Circle` recoloured.
        ///
        /// The row's promise is that colour never carries meaning alone, and it kept
        /// that promise only through the value text. Three different shapes mean the
        /// glyph itself stops depending on hue — which matters most for `.neutral`,
        /// whose `Ink.quaternary` is the dimmest ink in the app and was never going
        /// to clear the 3:1 floor a non-text indicator is held to.
        var symbol: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .attention: return "exclamationmark.triangle.fill"
            case .neutral: return "circle"
            }
        }
    }

    let label: String
    let value: String
    let state: State
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        // The combined announcement is kept only where it is still correct.
        //
        // `.accessibilityElement(children: .combine)` used to be applied to the
        // whole row unconditionally, including the two rows that carry a "Grant"
        // button — which folded that button into the combined element and took it
        // out of VoiceOver's control order. On the Home screen those are the only
        // two controls that lead a blocked user to the permission they are missing.
        // Rows without an action keep the "Microphone: Allowed" phrasing; rows with
        // one let `LabeledContent` pair the label and value and leave the button
        // reachable.
        if actionLabel != nil, action != nil {
            row
        } else {
            row
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label): \(value)")
        }
    }

    private var row: some View {
        LabeledContent {
            HStack(spacing: Space.x2) {
                Text(value).typo(.caption)
                if let actionLabel, let action {
                    // A real button, not text styled to look like one. This was a
                    // `.buttonStyle(.plain)` `Button` wearing `Tint.accentText`,
                    // which gave it no bezel, no hover and no pressed state — the
                    // "Grant" affordance on the app's landing screen was
                    // indistinguishable from the label beside it. `GlassButton`
                    // resolves to `.glass` on macOS 26 and `.bordered` below, both
                    // of which the system draws hover and press feedback for.
                    GlassButton(title: actionLabel, size: .small, action: action)
                }
            }
        } label: {
            Label {
                Text(label).typo(.body)
            } icon: {
                Image(systemName: state.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(state.color)
            }
        }
        .frame(minHeight: 26)
    }
}
