import SwiftUI
import AppKit

/// StudioWorkspaceView: The primary present-tense voice studio.
///
/// Combines local speech readiness, live voice scratchpad, active meeting
/// detection/recording, and the companion mascot co-pilot into a single, cohesive
/// native workspace surface.
@MainActor
final class StudioViewModel: ObservableObject {
    @Published var scratchpadText: String = ""
    @Published var isPolishing: Bool = false
    @Published var statusFeedback: String? = nil

    func copyToClipboard() {
        guard !scratchpadText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(scratchpadText, forType: .string)
        showFeedback("Copied to clipboard")
    }

    func saveAsNote(store: NoteStore) {
        let text = scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = store.create(body: text)
        store.selectedNoteID = note.id
        store.writeToDisk()
        showFeedback("Saved to Memory as Note")
    }

    func polishWithAI() {
        let text = scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isPolishing = true
        Task {
            let polished = await SentencePolish.polish(text)
            await MainActor.run {
                self.scratchpadText = polished
                self.isPolishing = false
                self.showFeedback("Polished with on-device AI")
            }
        }
    }

    func clear() {
        scratchpadText = ""
    }

    func showFeedback(_ message: String) {
        statusFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusFeedback == message {
                self?.statusFeedback = nil
            }
        }
    }
}

struct StudioWorkspaceView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var readiness = ReadinessMonitor.shared
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var noteStore = NoteStore.shared
    @ObservedObject private var meeting = AppDelegate.current?.meetingSession ?? MeetingSession()
    @StateObject private var model = StudioViewModel()

    private var activeModelName: String {
        SpeechModel.model(for: ModelStore.shared.active).displayName
    }

    private var allReady: Bool {
        readiness.micGranted && readiness.axGranted && readiness.modelPresent && readiness.modelLoad == .ready
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            // 1. Engine & Hardware Readiness Bar
            engineStatusBar

            // 2. Meeting Detection / Active Recording Banner
            meetingBanner

            // 3. Central Live Voice Scratchpad
            scratchpadSection

            // 4. Mascot Co-Pilot & Activity Footer
            mascotFooterSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Engine Status Bar

    private var engineStatusBar: some View {
        HStack(alignment: .center, spacing: Space.x3) {
            HStack(spacing: Space.x2) {
                Image(systemName: allReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(allReady ? Tint.success : Tint.warning)

                VStack(alignment: .leading, spacing: 1) {
                    Text(allReady ? "Whisper Metal Local Engine Ready" : "Preparing Local Speech Engine")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text("\(activeModelName) · 0ms cloud latency · 100% offline")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
            }

            Spacer()

            HStack(spacing: Space.x1) {
                Text("Hold")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
                Keycap(key: userData.hotkeyName)
                Text("in any app")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.horizontal, Space.x2)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor.opacity(0.08)))
        }
        .padding(Space.x3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Line.hairline, lineWidth: 1)
        )
    }

    // MARK: - Meeting Banner

    @ViewBuilder
    private var meetingBanner: some View {
        if meeting.state == .recording {
            let m = meeting.elapsed / 60
            let s = meeting.elapsed % 60
            let formatted = String(format: "%d:%02d", m, s)
            HStack(spacing: Space.x3) {
                Circle()
                    .fill(Tint.danger)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording Meeting Live")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text("\(formatted) elapsed · System audio & microphone active")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button("Finish & Save Meeting") {
                    Task { await meeting.stop() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(Space.x3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Tint.danger.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Tint.danger.opacity(0.3), lineWidth: 1)
            )
        } else if let source = AppDelegate.current?.callDetector.currentCall {
            HStack(spacing: Space.x3) {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(source.appName ?? "Live") Meeting Detected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text("Record with system audio + microphone and dual-stream speaker diarization.")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button("Transcribe Meeting") {
                    startMeetingCapture()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(Space.x3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Live Scratchpad

    private var scratchpadSection: some View {
        ContentSection(
            title: "Voice Scratchpad",
            systemImage: "square.and.pencil",
            accessory: AnyView(
                HStack(spacing: Space.x2) {
                    if let feedback = model.statusFeedback {
                        Text(feedback)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Tint.success)
                            .transition(.opacity)
                    }

                    if model.isPolishing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button(action: { model.copyToClipboard() }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.scratchpadText.isEmpty)

                    Button(action: { model.saveAsNote(store: noteStore) }) {
                        Label("Save as Note", systemImage: "note.text.badge.plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.scratchpadText.isEmpty)

                    Menu {
                        Button("Polish Punctuation") { model.polishWithAI() }
                        Button("Clear Canvas", role: .destructive) { model.clear() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 13))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderless)
                    .disabled(model.scratchpadText.isEmpty)
                }
            )
        ) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.scratchpadText)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(Space.x3)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Line.hairline, lineWidth: 1)
                    )
                    .frame(minHeight: 180, maxHeight: .infinity)

                if model.scratchpadText.isEmpty {
                    Text("Speak freely or type here. What you dictate using \(userData.hotkeyName) or straight into this canvas is never sent to the cloud.")
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.tertiary)
                        .padding(Space.x4)
                        .allowsHitTesting(false)
                }
            }

            // Word and character count strip
            HStack {
                let words = model.scratchpadText.split { $0.isWhitespace }.count
                let chars = model.scratchpadText.count
                Text("\(words) words · \(chars) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                Spacer()
                Text("Press ⌃⌥N to dictate into a new note anywhere in macOS")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, Space.x1)
        }
    }

    // MARK: - Mascot Footer

    private var mascotFooterSection: some View {
        HStack(alignment: .center, spacing: Space.x4) {
            if let style = CodePixelCatStyle(rawValue: userData.companionCharacter) {
                CodePixelCatView(
                    style: style,
                    mood: userData.companionEnabled ? .resting : .loaf,
                    pose: .neutral,
                    size: 38,
                    elapsed: 1.0
                )
                .frame(width: 38, height: 38)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.x2) {
                    Text("AI Companion Co-Pilot")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text(userData.companionEnabled ? "Active" : "Quiet")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(userData.companionEnabled ? Tint.success.opacity(0.12) : Color.gray.opacity(0.12)))
                        .foregroundStyle(userData.companionEnabled ? Tint.success : Ink.secondary)
                }
                Text("\(history.totalWords) lifetime words dictated · \(history.streakDays) day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
            }

            Spacer()

            Button(action: {
                userData.companionEnabled.toggle()
                userData.save()
            }) {
                Text(userData.companionEnabled ? "Mute" : "Enable")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Space.x3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Line.hairline, lineWidth: 1)
        )
    }

    private func startMeetingCapture() {
        guard let delegate = AppDelegate.current else { return }
        if let why = MeetingSession.prepare() {
            model.statusFeedback = why
            return
        }
        let source = delegate.callDetector.currentCall
        Task { @MainActor in
            let id = await meeting.start(
                recorder: delegate.audioRecorder,
                transcriber: delegate.transcriptionService,
                store: noteStore,
                source: source
            )
            if id != nil {
                model.showFeedback("Meeting recording started")
            }
        }
    }
}
