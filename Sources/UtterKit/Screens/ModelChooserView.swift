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
    var compact: Bool = false

    @ObservedObject private var store = ModelStore.shared
    private let device = Device.current()

    private var downloads: [(model: SpeechModel, progress: Double)] {
        SpeechModel.all.compactMap { model in
            guard case .downloading(let progress) = store.state(for: model.tier) else { return nil }
            return (model, progress)
        }
    }

    private var removable: [SpeechModel] {
        SpeechModel.all.filter { store.canRemove($0.tier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.stackGap) {
            if !compact {
                VStack(alignment: .leading, spacing: Space.x2) {
                    HStack {
                        Text("Speech Models").typo(.heading)
                        Spacer()
                        GlassChip(text: "\(device.ramGB)GB Unified Memory", systemImage: "memorychip")
                    }
                    Text(device.recommendationReason)
                        .typo(.lede)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, Space.x1)
            }

            // Bento Model Cards
            VStack(spacing: Space.x3) {
                ForEach(SpeechModel.all) { model in
                    BentoModelCard(
                        model: model,
                        device: device,
                        isActive: store.active == model.tier,
                        isRecommended: model.tier == device.recommended.tier,
                        state: store.state(for: model.tier),
                        onSelect: {
                            store.select(model.tier)
                        },
                        onDelete: store.canRemove(model.tier) ? {
                            store.remove(model.tier)
                        } : nil
                    )
                }
            }

            // In-Flight Downloads Bar
            ForEach(downloads, id: \.model.tier) { download in
                BentoTile(title: "Downloading \(download.model.displayName)", systemImage: "arrow.down.circle.fill", tint: Tint.accent) {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        HStack {
                            ProgressView(value: download.progress)
                                .progressViewStyle(.linear)
                            Text("\(Int(download.progress * 100))%")
                                .typo(.caption)
                                .monospacedDigit()
                            GlassButton(title: "Cancel", size: .small) {
                                store.cancelDownload(download.model.tier)
                            }
                        }
                        Text("Transcribing will automatically switch to \(download.model.displayName) once finished.")
                            .font(.caption2)
                            .foregroundStyle(Ink.secondary)
                    }
                }
            }

            // Storage Management Note
            HStack(spacing: Space.x2) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(Tint.accent)
                Text("All speech recognition runs 100% on-device. Downloading models is the only time Utter uses the network.")
                    .typo(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Space.x1)
        }
    }
}

// MARK: - Bento Model Card

private struct BentoModelCard: View {
    let model: SpeechModel
    let device: Device
    let isActive: Bool
    let isRecommended: Bool
    let state: ModelStore.State
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    private var isAvailable: Bool {
        state == .bundled || state == .installed
    }

    private var speedBadgeText: String {
        let seconds = model.secondsPerMinuteOfSpeech(scale: device.speedScale)
        if seconds < 1 { return "<1s per min (Ultra Fast)" }
        if seconds < 60 { return String(format: "%.0fs per min", seconds) }
        return String(format: "%.1f× real-time", seconds / 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack(alignment: .center) {
                // Radio / Active Indicator
                Button(action: onSelect) {
                    HStack(spacing: Space.x3) {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isActive ? Tint.accent : Ink.secondary.opacity(0.6))

                        HStack(spacing: Space.x2) {
                            Text(model.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Ink.primary)

                            if isActive {
                                GlassChip(text: "Active & Ready", tint: Tint.accent)
                            }

                            if isRecommended {
                                GlassChip(text: "Recommended", tint: Color.purple)
                            }

                            if model.isMultilingual {
                                Text("90+ languages")
                                    .font(.caption2)
                                    .foregroundStyle(Ink.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Actions (Delete if downloaded & not active)
                if let deleteAction = onDelete, isAvailable && !isActive {
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete to free \(model.sizeMB) MB")
                }
            }

            Text(model.summary)
                .font(.caption)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)

            // Metric Badges Row
            HStack(spacing: Space.x3) {
                MetricChip(icon: "internaldrive", text: "\(model.sizeMB) MB")
                MetricChip(icon: "speedometer", text: speedBadgeText)
                MetricChip(icon: "memorychip", text: "\(model.peakRAMMB) MB RAM")

                Spacer()

                if !isAvailable && !isActive {
                    Button(action: onSelect) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Download")
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(Space.x3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? Tint.accent.opacity(0.08) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? Tint.accent.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct MetricChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Tint.accent)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Ink.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
