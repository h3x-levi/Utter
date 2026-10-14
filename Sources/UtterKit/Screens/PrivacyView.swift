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
        SettingsProse(title: "Everything stays on this Mac.",
                      text: "Utter turns your voice into text here. Your audio and your words are not sent anywhere. There is no account and no usage tracking. Utter goes online only to download a speech model you choose, and for app updates.")

        SettingsSection("Permissions", detail: "System Settings") {
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
                                                 meetingCaptureUnderway: meeting.isCapturing)) {
                model.openSystemSettings("Privacy_ScreenCapture")
            }
        }

        SettingsSection("Apple Intelligence", detail: "on device") {
            SettingsRow("Writing fixes and commands", readiness.aiState.message) {
                HStack(spacing: 10) {
                    aiStatus
                    if readiness.aiState == .appleIntelligenceOff {
                        Button("Open Settings") { model.openSystemSettings("AppleIntelligence") }
                            .buttonStyle(.pen(.outline, .small))
                            .accessibilityLabel("Open Apple Intelligence settings")
                    }
                }
            }
        }

        SettingsProse(title: "Only the words are kept.",
                      text: "While you dictate, the audio is held in memory and thrown away once the words are typed. Meeting recordings save the words to your note, not the audio. The microphone is on only while you dictate or record a meeting.")

        SettingsSection("Erase") {
            SettingsRow("Erase everything", model.resetDone
                        ? "Everything was erased."
                        : "History, notes, installed characters, dictionary words, snippets, custom commands and settings.") {
                Button(role: .destructive) { model.confirmingReset = true } label: {
                    Text("Reset Utter\u{2026}").foregroundStyle(Mixtape.red)
                }
                .buttonStyle(.pen(.ghost, .small))
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
        case .ready: SettingsStatus(text: "Ready", kind: .ok)
        case .appleIntelligenceOff: SettingsStatus(text: "Off", kind: .warn)
        case .modelNotReady: SettingsStatus(text: "Not ready", kind: .warn)
        case .unsupportedOS: SettingsStatus(text: "Not supported")
        }
    }
}
