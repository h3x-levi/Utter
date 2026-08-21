import SwiftUI

// MARK: - Empty state

/// The one empty-state treatment. No card, no border, no coloured icon —
/// an empty list should look intentional, not broken.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
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

/// A single keycap chip. Used by both the pill and the Ready panel — one
/// component, not two divergent copies.
// MARK: - Section header

/// Sentence-case group header. Space above is larger than space below, so the
/// header binds visually to the content it labels.
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

/// 22×22 hit target with both a tooltip and a VoiceOver label. macOS minimum is
/// 22–28pt; 44 is a touch metric and would look oversized here.
struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(tint ?? Ink.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Radius.rect(Radius.control)
                        .fill(hovering ? Surface.fillHover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(h ? Motion.hoverIn : Motion.hoverOut) { hovering = h } }
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Status row

/// Label + value with a state dot. Colour never carries meaning alone — the
/// value text always states the status too.
struct StatusRow: View {
    enum State { case ok, attention, neutral

        var color: Color {
            switch self {
            case .ok: return Tint.success
            case .attention: return Tint.warning
            case .neutral: return Ink.quaternary
            }
        }
    }

    let label: String
    let value: String
    let state: State
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Space.x2) {
            Circle()
                .fill(state.color)
                .frame(width: 7, height: 7)
            Text(label).typo(.body)
            Spacer(minLength: Space.x4)
            Text(value).typo(.caption)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.plain)
                    .typo(.caption, ink: Tint.accentText)
            }
        }
        .frame(minHeight: 26)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
