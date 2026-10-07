import SwiftUI

@MainActor
private final class ModelChooserPresentation: ObservableObject {
    static let shared = ModelChooserPresentation()
    @Published var modelToRemove: SpeechModel?
}

/// Model selection presents one real decision at a time: quality, languages,
/// storage, and whether the weights are already available on this Mac.
/// Downloads stay explicit and removable models require confirmation.
struct ModelChooserView: View {
    var compact: Bool = false

    @ObservedObject private var store = ModelStore.shared
    @ObservedObject private var presentation = ModelChooserPresentation.shared
    private let device = Device.current()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            if !compact {
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text("Choose a speech model")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Start with the included model. Larger models can improve recognition, but use more storage and memory.")
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(SpeechModel.all.enumerated()), id: \.element.id) { index, model in
                    modelRow(model)
                    if index < SpeechModel.all.count - 1 {
                        Rectangle()
                            .fill(Line.hairline)
                            .frame(height: 1)
                            .padding(.leading, 34)
                    }
                }
            }

            Label("Dictation audio stays on this Mac. Utter uses the network only when you choose to download model weights.", systemImage: "lock.shield")
                .font(.system(size: 12))
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(
            "Remove \(presentation.modelToRemove?.displayName ?? "model")?",
            isPresented: Binding(
                get: { presentation.modelToRemove != nil },
                set: { if !$0 { presentation.modelToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let modelToRemove = presentation.modelToRemove {
                Button("Remove \(modelToRemove.displayName)", role: .destructive) {
                    store.remove(modelToRemove.tier)
                    presentation.modelToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) { presentation.modelToRemove = nil }
        } message: {
            if let modelToRemove = presentation.modelToRemove {
                Text("This removes about \(modelToRemove.sizeMB) MB from this Mac. Your saved transcripts and notes are unchanged.")
            }
        }
    }

    private func modelRow(_ model: SpeechModel) -> some View {
        let state = store.state(for: model.tier)
        let isActive = store.active == model.tier
        let isPending = store.pendingSelection == model.tier
        let isRecommended = model.tier == device.recommended.tier

        return VStack(alignment: .leading, spacing: Space.x2) {
            Button {
                store.select(model.tier)
            } label: {
                HStack(alignment: .center, spacing: Space.x2) {
                    Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isActive ? Color.accentColor : Ink.tertiary)
                        .frame(width: 18, height: 20)
                        .accessibilityHidden(true)

                    Text(model.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(model.displayName), \(model.summary)")
            .accessibilityAddTraits(isActive ? .isSelected : [])

            Text(model.summary)
                .font(.system(size: 12))
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 26)
            Text(metadata(for: model))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 26)

            HStack {
                Spacer(minLength: 0)
                stateAction(model, state: state, isActive: isActive, isPending: isPending)
            }

        }
        .padding(.vertical, Space.x3)
    }

    @ViewBuilder
    private func stateAction(
        _ model: SpeechModel,
        state: ModelStore.State,
        isActive: Bool,
        isPending: Bool
    ) -> some View {
        switch state {
        case .downloading(let progress):
            VStack(alignment: .trailing, spacing: Space.x1) {
                ProgressView(value: progress)
                    .frame(width: 88)
                HStack(spacing: Space.x1) {
                    Text("\(Int(progress * 100))%")
                        .monospacedDigit()
                    Button("Cancel") { store.cancelDownload(model.tier) }
                        .buttonStyle(.borderless)
                }
                .font(.system(size: 11))
                .foregroundStyle(Ink.secondary)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Downloading \(model.displayName)")
        case .failed(let message):
            VStack(alignment: .trailing, spacing: Space.x1) {
                Text("Download failed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tint.warningText)
                Button("Retry") { store.download(model.tier) }
                    .buttonStyle(.borderless)
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(2)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
        case .bundled:
            HStack(spacing: Space.x2) {
                statusLabel(isActive ? "In use" : "Included", symbol: isActive ? "checkmark.circle.fill" : "checkmark.circle")
                if store.canRemove(model.tier) && !isActive {
                    removeButton(for: model)
                }
            }
        case .installed:
            HStack(spacing: Space.x2) {
                if isActive {
                    statusLabel("In use", symbol: "checkmark.circle.fill")
                } else {
                    Button("Use") { store.select(model.tier) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                if store.canRemove(model.tier) && !isActive {
                    removeButton(for: model)
                }
            }
        case .notDownloaded:
            Button(isPending ? "Queued" : "Download") { store.select(model.tier) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isPending)
        }
    }

    private func statusLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(title == "In use" ? Color.accentColor : Ink.secondary)
            .fixedSize()
    }

    private func removeButton(for model: SpeechModel) -> some View {
        Button {
            presentation.modelToRemove = model
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Remove model from this Mac")
        .accessibilityLabel("Remove \(model.displayName)")
    }

    private func metadata(for model: SpeechModel) -> String {
        let language = model.isMultilingual ? "Multilingual" : "English"
        let memory = model.peakRAMMB >= 1024
            ? String(format: "%.1f GB peak memory", Double(model.peakRAMMB) / 1024)
            : "\(model.peakRAMMB) MB peak memory"
        let bundled = SpeechModel.isBundled(model.tier) ? " · Included" : ""
        return "\(language) · \(model.sizeMB) MB download · \(memory)\(bundled)"
    }
}
