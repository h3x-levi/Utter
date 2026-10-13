import SwiftUI
import UtterCore

/// One row per speech model: what it is, what it costs, and the one action its state allows.
/// Rows only, so a `PaneGroup` can hold them.
struct ModelChooserView: View {
    @ObservedObject private var models: ModelStore
    private let device: Device
    @State private var removing: SpeechModel?

    init(models: ModelStore? = nil, device: Device = .current()) {
        self.models = models ?? .shared
        self.device = device
    }

    var body: some View {
        ForEach(SpeechModel.all) { speech in
            row(speech)
        }
    }

    private func row(_ speech: SpeechModel) -> some View {
        let state = models.state(for: speech.tier)
        return PaneRow {
            HStack(spacing: 8) {
                Text(speech.displayName)
                if speech.tier == device.recommended.tier { PaneStatus(text: "Recommended") }
            }
            Text(speech.summary)
                .font(Pane.subtitle)
                .foregroundStyle(Pane.ink3)
                .fixedSize(horizontal: false, vertical: true)
            detail(speech, state: state)
        } trailing: {
            action(speech, state: state, isActive: models.active == speech.tier)
                // Wide enough for the widest state, so a download never shifts the text.
                .frame(minWidth: 176, alignment: .trailing)
        }
        .confirmationDialog(
            "Remove \(speech.displayName)?",
            isPresented: Binding(get: { removing == speech }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { models.remove(speech.tier) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees about \(speech.sizeMB) MB on this Mac. Your history and notes stay.")
        }
    }

    @ViewBuilder
    private func detail(_ speech: SpeechModel, state: ModelStore.State) -> some View {
        if case .failed(let message) = state {
            Text("Download failed. \(message)").font(Pane.subtitle).foregroundStyle(Color.red)
        } else {
            let memory = speech.peakRAMMB >= 1024
                ? String(format: "%.1f GB", Double(speech.peakRAMMB) / 1024)
                : "\(speech.peakRAMMB) MB"
            Text(verbatim: "\(speech.isMultilingual ? "Many languages" : "English")  \(speech.sizeMB) MB  \(memory) memory")
                .font(Pane.subtitle.monospacedDigit())
                .foregroundStyle(Pane.ink3)
        }
    }

    @ViewBuilder
    private func action(_ speech: SpeechModel, state: ModelStore.State, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            switch state {
            case .downloading(let progress):
                PaneMeter(value: progress, width: 64)
                    .accessibilityLabel("Downloading \(speech.displayName)")
                    .accessibilityValue("\(Int(progress * 100)) percent")
                Text(verbatim: "\(Int(progress * 100))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Pane.ink2)
                    .frame(width: 32, alignment: .trailing)
                Button("Cancel") { models.cancelDownload(speech.tier) }
                    .accessibilityLabel("Cancel downloading \(speech.displayName)")
            case .failed:
                Button("Retry") { models.download(speech.tier) }
                    .accessibilityLabel("Retry downloading \(speech.displayName)")
            case .notDownloaded:
                let queued = models.pendingSelection == speech.tier
                Button(queued ? "Queued" : "Download") { models.select(speech.tier) }
                    .disabled(queued)
                    .accessibilityLabel("Download \(speech.displayName)")
            case .bundled, .installed:
                if isActive {
                    PaneStatus(text: "In use", kind: .ok)
                } else {
                    if models.canRemove(speech.tier) {
                        Button {
                            removing = speech
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.pane(.plain))
                        .help("Remove from this Mac")
                        .accessibilityLabel("Remove \(speech.displayName)")
                    }
                    Button("Use") { models.select(speech.tier) }
                        .accessibilityLabel("Use \(speech.displayName)")
                }
            }
        }
        .buttonStyle(.pane())
    }
}
