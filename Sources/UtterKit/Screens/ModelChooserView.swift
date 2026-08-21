import SwiftUI

/// Lets the user pick a speech model, with the trade-offs stated in terms of
/// their own Mac rather than abstract model sizes.
///
/// Shown during first-run onboarding and again in Settings. The recommendation
/// comes from measured benchmarks scaled by this machine's chip and memory —
/// see `SpeechModelCatalog.swift`.
struct ModelChooserView: View {
    /// Compact form omits the explanatory header (used inside Settings).
    var compact: Bool = false

    @ObservedObject private var store = ModelStore.shared
    private let device = Device.current()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.stackGap) {
            if !compact {
                VStack(alignment: .leading, spacing: Space.x2) {
                    Text("Choose a speech model").typo(.heading)
                    Text(device.recommendationReason)
                        .typo(.lede)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, Space.x2)
            }

            ForEach(SpeechModel.all) { model in
                ModelRow(
                    model: model,
                    device: device,
                    isRecommended: model.tier == device.recommended.tier,
                    isActive: store.active == model.tier,
                    state: store.state(for: model.tier)
                )
            }

            Text("Small is included and works offline right away. Downloading a larger model is the only "
                 + "time Utter uses the network, and it only happens when you ask. You can remove any "
                 + "model you\u{2019}re not using \u{2014} including the included one \u{2014} as long as one remains.")
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.x1)
        }
    }
}

private struct ModelRow: View {
    let model: SpeechModel
    let device: Device
    let isRecommended: Bool
    let isActive: Bool
    let state: ModelStore.State

    @ObservedObject private var store = ModelStore.shared
    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// Estimated wall-clock to transcribe a minute of speech on this Mac.
    private var speedText: String {
        let seconds = model.secondsPerMinuteOfSpeech(scale: device.speedScale)
        if seconds < 1 { return "under a second per minute of speech" }
        if seconds < 60 { return String(format: "about %.0fs per minute of speech", seconds) }
        return String(format: "about %.1f× slower than real time", seconds / 60)
    }

    private var isAvailable: Bool {
        state == .bundled || state == .installed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? Tint.accent : Ink.tertiary)

                Text(model.displayName).typo(.subheading)

                if isRecommended {
                    // `Tint.accentText`, not `Tint.accent`. 12pt accent on
                    // `Tint.accentSoft` (the accent at 12% over the tile) computes to
                    // **2.58:1** on Paper against a 4.5:1 floor — Paper's amber is the
                    // accent tuned to read as a *fill*, which is the exact case
                    // `Tint.accentText` in DesignTokens.swift exists for. That token
                    // takes the same badge to 8.06:1, and clears the floor on all six
                    // themes (worst 8.06, best 13.04).
                    Text(isAvailable ? "Recommended" : "Recommended · download")
                        .typo(.caption, ink: Tint.accentText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Radius.rect(Radius.chip).fill(Tint.accentSoft))
                }
                if model.isMultilingual {
                    Text("90+ languages").typo(.caption)
                }

                Spacer()
                trailing
            }

            VStack(alignment: .leading, spacing: Space.x1) {
                Text(model.summary)
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.x3) {
                    Label("\(model.sizeMB) MB", systemImage: "internaldrive")
                    Label(speedText, systemImage: "speedometer")
                    Label("\(model.peakRAMMB) MB RAM", systemImage: "memorychip")
                }
                .typo(.caption)
                .labelStyle(.titleAndIcon)
            }
            .padding(.leading, 22)

            if !model.fitsComfortably(in: device) && !isAvailable {
                Label(
                    "Uses a large share of \(device.ramGB) GB — may slow other apps",
                    systemImage: "exclamationmark.triangle"
                )
                .typo(.caption, ink: Tint.warningText)
                .padding(.leading, 22)
            }
        }
        .padding(Space.x3)
        // The selection treatment now matches `GlassSelectableRow`
        // (`GlassSelectableRow.background`) exactly, which is the design system's answer
        // for "a list that *is* the picker" and what `DiagnosticsView` uses.
        //
        // It was `Tint.accentSoft.opacity(0.5)` — the accent at 6% — and
        // `Tint.accentRim` at 28%, so a selected model row was roughly half the
        // strength of a selected crash report two panes away, for the same idea. Same
        // radius and the same `Space.x3` padding as that row already; only the accent
        // strength was drifting.
        .background(
            Radius.rect(Radius.card)
                .fill(isActive ? Tint.accent.opacity(isDark ? 0.22 : 0.13)
                      : (hovering ? Surface.fillHover : Surface.fillSubtle))
        )
        .overlay(
            Radius.rect(Radius.card)
                .strokeBorder(isActive ? Tint.accent.opacity(0.45) : Line.hairline,
                              lineWidth: Line.width)
        )
        // The row's own shape, finishing the convergence the comment above claims.
        //
        // This row already matches `GlassSelectableRow` on radius, padding and selection
        // treatment — and that component uses `.contentShape(Radius.rect(Radius.card))`
        // (`GlassSelectableRow.body`), so a `Rectangle` here was the last place the two
        // still disagreed. It also made the whole row tappable 12pt into four corners
        // where the fill and the accent rim are not drawn, which on the one screen the
        // user meets during onboarding is a click that appears to hit nothing.
        .contentShape(Radius.rect(Radius.card))
        .onTapGesture { store.select(model.tier) }
        .onHover { h in withAnimation(h ? Motion.hoverIn : Motion.hoverOut) { hovering = h } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.displayName), \(model.sizeMB) megabytes"
                            + (isRecommended ? ", recommended" : "")
                            + (isActive ? ", selected" : ""))
    }

    /// The row's action surface. Every button here is a `GlassButton`.
    ///
    /// All four were bare system `Button`s, which made the model chooser the one
    /// screen in the app whose entire action surface was unstyled — and it is a screen
    /// the user meets during onboarding, before they have seen any other.
    ///
    /// `.bundled` and `.installed` were two byte-identical branches. Collapsed rather
    /// than edited twice: they are one state as far as this row is concerned (the model
    /// is on disk and usable), and the next person to change one would have changed one.
    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .bundled, .installed:
            HStack(spacing: Space.x2) {
                if isActive {
                    // `accentText`: 12pt accent on the active row's fill computes to
                    // **2.74:1** on Paper. The token takes it to 8.55:1.
                    Text("In use").typo(.caption, ink: Tint.accentText)
                } else {
                    GlassButton(title: "Use") { store.select(model.tier) }
                }
                if store.canRemove(model.tier) {
                    IconButton(
                        systemName: "trash",
                        label: "Remove \(model.displayName) and reclaim \(model.sizeMB) MB"
                    ) {
                        store.remove(model.tier)
                    }
                }
            }
        case .downloading(let progress):
            HStack(spacing: Space.x2) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 90)
                Text("\(Int(progress * 100))%").typo(.caption)
                IconButton(systemName: "xmark", label: "Cancel download") {
                    store.cancelDownload(model.tier)
                }
            }
        case .notDownloaded:
            // Not `prominent`. Every model in the list can be in this state at once,
            // and the HIG limits `.glassProminent` to one or two per view — a column
            // of prominent buttons is the emphasis meaning nothing.
            GlassButton(title: SpeechModel.isBundled(model.tier) ? "Restore" : "Download") {
                store.select(model.tier)
            }
        case .failed(let reason):
            HStack(spacing: Space.x2) {
                Text(reason)
                    .typo(.caption, ink: Tint.dangerText)
                    .lineLimit(1)
                GlassButton(title: "Retry") { store.download(model.tier) }
            }
        }
    }
}
