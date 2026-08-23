import SwiftUI

/// Lets the user pick a speech model, with the trade-offs stated in terms of
/// their own Mac rather than abstract model sizes.
///
/// Shown during first-run onboarding and again in Settings. The recommendation
/// comes from measured benchmarks scaled by this machine's chip and memory —
/// see `SpeechModelCatalog.swift`.
///
/// # This is a real radio group now
///
/// The model list **is** a `Picker` with `.pickerStyle(.radioGroup)` — the AppKit
/// radio group, hosted by SwiftUI, verified `@available(macOS 10.15, *)` in
/// `SwiftUI.swiftinterface`, so no availability branch. It replaces a hand-drawn
/// imitation: an `Image(systemName: "largecircle.fill.circle")` glyph, a `@State
/// hovering` flag, an `.onHover` animation, a `.fill()` selection wash and a
/// composed `accessibilityLabel`. Every one of those is now the system's:
///
///   * **Hover and pressed feedback** — the reason this was rewritten. The hand-drawn
///     wash was `Surface.fillHover` over the tile, which measures ~1.14:1 against the
///     unhovered row in light themes. Invisible. AppKit draws the real thing.
///   * **Keyboard traversal** — arrow keys move between options and the focus ring is
///     drawn for free. The tap-gesture version had neither.
///   * **VoiceOver** — "radio button, selected" with the group's own semantics, rather
///     than a hand-assembled string that had to be kept in sync with the row's content.
///
/// `List(selection:)` was the other candidate and is ruled out by where this view is
/// embedded: `OnboardingView.modelStep` and `SettingsView.SpeechSettingsContent` both
/// place it inside an enclosing `ScrollView`. A `List` scrolls itself, so it would put
/// two competing scrollers over one gesture in two places — the defect
/// `OnboardingView` documents at its own step container. A radio group does not scroll,
/// so it survives both embeddings unchanged.
///
/// No glass here. This is content inside `SettingsCard`/the onboarding step, and the
/// radio group's own control layer is the system's to draw.
struct ModelChooserView: View {
    /// Compact form omits the explanatory header (used inside Settings).
    var compact: Bool = false

    @ObservedObject private var store = ModelStore.shared
    private let device = Device.current()

    /// The radio's selection is `store.active` — the model that actually transcribes.
    ///
    /// Deliberately **not** `pendingSelection ?? active`. Picking a model that is not on
    /// disk starts its download and only activates it when the bytes land
    /// (`ModelStore.select` → `download` → `select`), so binding to the pending value
    /// would move the dot to a model that is not in use. The radio tells the truth about
    /// which model is running; the option's own status line explains that a download is
    /// in flight and that it will switch when it finishes.
    private var selection: Binding<SpeechModel.Tier> {
        Binding(
            get: { store.active },
            set: { store.select($0) }
        )
    }

    /// Downloads in flight, in catalogue order.
    ///
    /// A transfer is not a choice, so it does not belong inside the radio group: a radio
    /// label cannot host a working `Button`, and the progress of a download is a
    /// different fact from which model is selected. These are rows of their own,
    /// present only while something is downloading — the Safari-downloads arrangement.
    private var downloads: [(model: SpeechModel, progress: Double)] {
        SpeechModel.all.compactMap { model in
            guard case .downloading(let progress) = store.state(for: model.tier) else { return nil }
            return (model, progress)
        }
    }

    /// Models that can be deleted — `ModelStore.canRemove` requires one to remain.
    private var removable: [SpeechModel] {
        SpeechModel.all.filter { store.canRemove($0.tier) }
    }

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

            // `.labelsHidden()` suppresses the *visual* label only, so the group keeps its
            // accessible name. Both call sites already title this list — the header above
            // in the full form, `SettingsCard(title: "Model")` in the compact one — and a
            // third "Speech model" heading between them would be the same word twice.
            //
            // `.tint` is the whole theming bridge: it colours the selected radio's fill,
            // which is the one place the seven themes need to reach a system control here.
            // Nothing is drawn behind the group; the themed window shows through it.
            Picker(selection: selection) {
                ForEach(SpeechModel.all) { model in
                    ModelOption(
                        model: model,
                        device: device,
                        isRecommended: model.tier == device.recommended.tier,
                        state: store.state(for: model.tier)
                    )
                    .tag(model.tier)
                }
            } label: {
                Text("Speech model")
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            ForEach(downloads, id: \.model.tier) { download in
                LabeledContent("Downloading \(download.model.displayName)") {
                    HStack(spacing: Space.x2) {
                        ProgressView(value: download.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 90)
                        Text("\(Int(download.progress * 100))%")
                            .typo(.caption)
                            .monospacedDigit()
                        GlassButton(title: "Cancel", size: .small) {
                            store.cancelDownload(download.model.tier)
                        }
                    }
                }
                .typo(.caption)
            }

            // Removal is disk management, not model choice, and it is the one action here
            // that cannot be undone — so it is a `Menu` (a real macOS pop-up button, with
            // the system's own hover and pressed states) rather than a trash glyph on every
            // row. Two clicks for a destructive, occasional action is the right trade, and
            // it keeps the radio labels free of controls a radio label cannot host.
            //
            // Absent entirely when nothing is removable, which is the state of a fresh
            // install: only `small` ships in the bundle, so there is nothing to reclaim
            // until the user has downloaded a second model.
            if !removable.isEmpty {
                Menu {
                    ForEach(removable) { model in
                        Button("\(model.displayName) \u{2014} frees \(model.sizeMB) MB") {
                            store.remove(model.tier)
                        }
                    }
                } label: {
                    Label("Remove a model", systemImage: "trash")
                }
                .menuStyle(.button)
                .fixedSize()
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

/// One radio option: the model, its cost on this Mac, and what picking it will do.
///
/// Contains no controls. A `.radioGroup` option's label is the radio's own hit area, so
/// anything tappable inside it would be competing with the radio for the same click —
/// and it does not need to compete, because every button this row used to carry was a
/// different spelling of "pick this model":
///
///   * **Use** (installed, not active) → select it.
///   * **Download** / **Restore** (not on disk) → `ModelStore.select` downloads it and
///     activates it when the bytes land, so picking it *is* the download.
///   * **Retry** (failed) → the same call again, which is exactly what re-picking does.
///
/// Cancel and Remove are the two that genuinely are not "pick this model", and they live
/// outside the group in `ModelChooserView`.
private struct ModelOption: View {
    let model: SpeechModel
    let device: Device
    let isRecommended: Bool
    let state: ModelStore.State

    private var isAvailable: Bool {
        state == .bundled || state == .installed
    }

    /// Estimated wall-clock to transcribe a minute of speech on this Mac.
    private var speedText: String {
        let seconds = model.secondsPerMinuteOfSpeech(scale: device.speedScale)
        if seconds < 1 { return "under a second per minute of speech" }
        if seconds < 60 { return String(format: "about %.0fs per minute of speech", seconds) }
        return String(format: "about %.1f× slower than real time", seconds / 60)
    }

    /// Where the model is, and what picking it will do.
    ///
    /// This line carries what the row's four buttons used to say, and it has to: with the
    /// buttons gone, "Download" is no longer visible as a word anywhere, so the option
    /// must state that picking it starts a download. `Tint.dangerText`/`Ink.secondary`
    /// rather than `Tint.danger`/`Ink.tertiary` — this is text the user must read.
    private var status: (text: String, ink: Color) {
        switch state {
        case .bundled:
            return ("Included with Utter \u{2014} ready now", Ink.secondary)
        case .installed:
            return ("Downloaded \u{2014} ready now", Ink.secondary)
        case .downloading:
            return ("Downloading \u{2014} switches over when it finishes", Ink.secondary)
        case .notDownloaded:
            let verb = SpeechModel.isBundled(model.tier) ? "downloads it again" : "downloads"
            return ("Not on this Mac \u{2014} picking it \(verb) (\(model.sizeMB) MB)", Ink.secondary)
        case .failed(let reason):
            return ("Download failed: \(reason). Pick it again to retry.", Tint.dangerText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                Text(model.displayName).typo(.subheading)
                if isRecommended {
                    // `GlassChip`, not a hand-rolled `Text` on `Tint.accentSoft`. That
                    // badge was 12pt `Tint.accentText` over the accent at 12% — a measured
                    // fix for a 2.58:1 failure on Paper, whose theme accent is an amber
                    // tuned to read as a fill. `GlassChip` already resolves that case the
                    // same way for every chip in the app: `Ink.primary` for the label, the
                    // tint on the rim and glyph only. One fewer place to re-measure.
                    GlassChip(text: "Recommended", tint: Tint.accent)
                }
                if model.isMultilingual {
                    Text("90+ languages").typo(.caption)
                }
            }

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

            Text(status.text)
                .typo(.caption, ink: status.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !model.fitsComfortably(in: device) && !isAvailable {
                Label(
                    "Uses a large share of \(device.ramGB) GB \u{2014} may slow other apps",
                    systemImage: "exclamationmark.triangle"
                )
                .typo(.caption, ink: Tint.warningText)
            }
        }
        // The radio group supplies the indent, the row's hit area and the gap between
        // options; the former `Space.x3` padding, `Radius.card` fill, hairline rim and
        // `.contentShape` are all gone with it. This is the only geometry left, and it is
        // just breathing room between one multi-line option and the next.
        .padding(.vertical, Space.x1)
    }
}
