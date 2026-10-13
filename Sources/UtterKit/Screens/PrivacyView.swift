import SwiftUI
import UtterCore

struct PrivacySettingsContent: View {
    @Bindable var model: SettingsModel
    @ObservedObject private var readiness: ReadinessMonitor
    @ObservedObject private var userData: UserData
    @ObservedObject private var meeting: MeetingSession

    init(model: SettingsModel) {
        self.model = model
        readiness = model.readiness
        userData = model.userData
        meeting = model.meeting
    }

    var body: some View {
        PaneNote(title: "Everything stays on this Mac.",
                 text: "Utter turns your voice into text here. Your audio and your words are not sent anywhere. There is no account and no usage tracking. Utter goes online only to download a speech model you choose, and for app updates.")

        PaneGroup("Permissions") {
            PermissionRow(name: "Microphone", purpose: "So Utter can hear you.",
                          need: .core(granted: readiness.micGranted)) {
                model.openSystemSettings("Privacy_Microphone")
            }
            PermissionRow(name: "Accessibility", purpose: "So Utter can type into other apps.",
                          need: .core(granted: readiness.axGranted)) {
                model.openSystemSettings("Privacy_Accessibility")
            }
            PermissionRow(name: "Screen Recording", purpose: "To hear the other side of a call.",
                          need: .screenRecording(granted: readiness.screenRecordingGranted,
                                                 offersToTranscribeCalls: userData.offerToTranscribeCalls,
                                                 meetingCaptureUnderway: meeting.state != .idle)) {
                model.openSystemSettings("Privacy_ScreenCapture")
            }
        }

        PaneGroup("Apple Intelligence") {
            PaneRow("Writing fixes and commands", readiness.aiState.message) {
                HStack(spacing: 10) {
                    aiStatus
                    if readiness.aiState == .appleIntelligenceOff {
                        Button("Open Settings") { model.openSystemSettings("AppleIntelligence") }
                            .buttonStyle(.pane())
                            .accessibilityLabel("Open Apple Intelligence settings")
                    }
                }
            }
        }

        PaneNote(title: "Only the words are kept.",
                 text: "While you dictate, the audio is held in memory and thrown away once the words are typed. Meeting recordings save the words to your note, not the audio. The microphone is on only while you dictate or record a meeting.")

        PaneGroup {
            PaneRow("Erase everything", model.resetDone
                    ? "Everything was erased."
                    : "History, notes, installed characters, dictionary words, snippets, custom commands and settings.") {
                Button("Reset Utter\u{2026}", role: .destructive) { model.confirmingReset = true }
                    .buttonStyle(.pane())
            }
        }
        .alert("Reset Utter?", isPresented: $model.confirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Erase Everything", role: .destructive) { model.reset() }
        } message: {
            Text("This deletes your dictation history, every note, the characters you installed, your dictionary words, snippets, custom commands and all settings. It cannot be undone.")
        }
        .onAppear { readiness.startPolling() }
        .onDisappear { readiness.stopPolling() }
    }

    private var aiStatus: some View {
        switch readiness.aiState {
        case .ready: PaneStatus(text: "Ready", kind: .ok)
        case .appleIntelligenceOff: PaneStatus(text: "Off", kind: .warn)
        case .modelNotReady: PaneStatus(text: "Not ready", kind: .warn)
        case .unsupportedOS: PaneStatus(text: "Not supported")
        }
    }
}
