import SwiftUI
import AppKit
import UtterCore

// MARK: - General

struct GeneralSettingsContent: View {
    let model: SettingsModel
    @ObservedObject private var userData: UserData
    @ObservedObject private var theme: ThemeManager

    init(model: SettingsModel) {
        self.model = model
        userData = model.userData
        theme = model.theme
    }

    var body: some View {
        AccountSettingsSection()
        SettingsSection("Look", detail: "light or dark") {
            SettingsRow("Appearance", "System follows the Light or Dark setting on your Mac.") {
                SettingsChoice(title: "Appearance", selection: model.appearance,
                               options: AppTheme.themes.map { ($0.id, $0.name) })
            }
            toggle("Always show the pill", "Keep it on screen when you are not dictating.", \.alwaysShowPill)
        }
        SettingsSection("App", detail: "on this Mac") {
            SettingsRow("Open at login") {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .toggleStyle(.settingsSwitch)
            }
            toggle("Show in Dock", nil, \.showInDock)
            toggle("Offer to transcribe calls", "When a Zoom, Teams, FaceTime, Webex, Slack or Discord call starts.",
                   \.offerToTranscribeCalls)
        }
        SettingsSection("Sound") {
            SettingsRow("Dictation sounds", "A soft sound when listening starts and stops.") {
                Toggle("Dictation sounds", isOn: model.preference(\.soundsEnabled) { if $0 { SoundPlayer.playDone() } })
                    .toggleStyle(.settingsSwitch)
            }
            toggle("Pause music while dictating", "So it does not get into the microphone.", \.muteMusicWhileDictating)
        }
        SettingsSection("Notes") {
            SettingsRow("When you dictate into Utter") {
                SettingsChoice(title: "When you dictate into Utter", selection: model.preference(\.captureAppendsToOpenNote),
                               options: [(true, "Add to open note"), (false, "New note")])
            }
        }
        HelpSettingsContent(model: model)
            .onAppear { model.refreshLaunchAtLogin() }
    }

    private func toggle(_ title: String, _ detail: String?,
                        _ key: ReferenceWritableKeyPath<UserData, Bool>) -> some View {
        SettingsRow(title, detail) {
            Toggle(title, isOn: model.preference(key)).toggleStyle(.settingsSwitch)
        }
    }
}

/// Who is signed in. Signing out of a required sign-in quits, so the next launch asks again.
private struct AccountSettingsSection: View {
    @ObservedObject private var session = AccountSession.shared

    var body: some View {
        SettingsSection("Account", detail: "your Google account") {
            if let account = session.account {
                SettingsRow(account.name, account.email) {
                    Button(session.isRequired ? "Sign out and quit" : "Sign out") {
                        let quit = session.isRequired
                        session.signOut()
                        if quit { NSApp.terminate(nil) }
                    }
                    .buttonStyle(.pen(.outline, .small))
                }
            } else {
                SettingsRow("Not signed in", session.isRequired
                            ? "Sign in with Google to use Utter."
                            : "Google sign-in isn\u{2019}t connected yet.") {
                    Button("Sign in") { AppDelegate.current?.showSignIn() }
                        .buttonStyle(.pen(.outline, .small))
                }
            }
        }
    }
}

// MARK: - Speech

struct SpeechSettingsContent: View {
    let model: SettingsModel
    @ObservedObject private var userData: UserData

    init(model: SettingsModel) {
        self.model = model
        userData = model.userData
    }

    var body: some View {
        let mics = AudioInputs.all()
        SettingsSection("Microphone", detail: "what Utter listens to") {
            SettingsRow("Record from", "Meetings use the call app\u{2019}s microphone when Utter can tell which one it is.") {
                SettingsPick("Microphone", value: mics.first { $0.id == userData.microphoneUID }?.name ?? "System default") {
                    Picker("Microphone", selection: model.preference(\.microphoneUID)) {
                        Text("System default").tag("")
                        ForEach(mics) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
        if WhistleEngine.isAvailable {
            SettingsSection("Engine", detail: "how Utter hears you") {
                SettingsRow("Engine", userData.speechEngine == .whistle
                            ? "Starts instantly. A smaller 17 MB model for Apple silicon. Makes a few more mistakes."
                            : "Best results. Uses the Whisper model, 190 MB.") {
                    SettingsChoice(title: "Engine", selection: model.preference(\.speechEngine),
                                   options: [(.whisper, "Accurate"), (.whistle, "Fast")])
                }
            }
        }
        if SpeechEngine.active(userData) == .whisper {
            SettingsSection("Speech model", detail: "on this Mac",
                            note: "Your voice stays on this Mac. Utter goes online only to download a model you choose.") {
                ModelChooserView(models: model.models, device: model.device)
            }
        }
        SettingsSection("Writing", detail: "your words stay yours") {
            toggle("Fix sentence structure", "Fixes punctuation and capitals. Your words stay the same.",
                   \.sentencePolishEnabled)
            toggle("Spoken punctuation", "Say \u{201C}period\u{201D} or \u{201C}comma\u{201D} to type the mark.",
                   \.spokenPunctuationEnabled)
            toggle("Voice commands", "Say a command\u{2019}s name to run it instead of typing it.",
                   \.voiceCommandsEnabled)
            toggle("Prefer your dictionary words", "Helps Utter hear the names and terms in your dictionary.",
                   \.speechBiasEnabled)
            toggle("Match the app", "Short in chat, full sentences in email. Your words stay the same.",
                   \.perAppToneEnabled)
            toggle("Read text around the cursor", "Uses nearby words, on this Mac, so new text fits in.",
                   \.useSurroundingContext)
        }
        SettingsSection("While you talk") {
            toggle("Show words as you speak", "A rough preview in the pill before the final text.",
                   \.livePreviewEnabled)
            toggle("Keep dictation history", "A private list of what you dictate, kept on this Mac.",
                   \.keepHistory)
            SettingsRow("Language", "The included model understands English.") {
                Text("English").font(Mixtape.mono(12, .semibold)).foregroundStyle(Mixtape.ink2)
            }
        }
    }

    private func toggle(_ title: String, _ detail: String,
                        _ key: ReferenceWritableKeyPath<UserData, Bool>) -> some View {
        SettingsRow(title, detail) {
            Toggle(title, isOn: model.preference(key)).toggleStyle(.settingsSwitch)
        }
    }
}

// MARK: - Shortcuts

struct ShortcutSettingsContent: View {
    let model: SettingsModel
    @ObservedObject private var userData: UserData

    init(model: SettingsModel) {
        self.model = model
        userData = model.userData
    }

    var body: some View {
        let key = userData.hotkeyName
        SettingsSection("Dictation", detail: "hold to talk") {
            SettingsRow("Hold to talk", HotkeyOption.find(stored: key).description) {
                SettingsPick("Hold to talk key", value: HotkeyOption.find(stored: key).name) {
                    Picker("Hold to talk", selection: model.hotkey) {
                        ForEach(HotkeyOption.options) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            SettingsRow("Double-tap for hands-free", "Press \(key) twice to keep listening without holding it.") {
                Toggle("Double-tap for hands-free", isOn: model.preference(\.doubleTapHotkeyForHandsFree))
                    .toggleStyle(.settingsSwitch)
            }
        }
        SettingsSection("Other shortcuts", detail: "anywhere on your Mac") {
            shortcut("Hands-free", KeyChord.handsFree,
                     detail: (HoldTap.isAvailable ? "Or hold \(key) and tap Space while you talk. " : "")
                        + "Listens until you press it again or stop talking for 3 seconds.")
            shortcut("Take a note", KeyChord.noteCapture)
            shortcut("Remember", KeyChord.memoryCapture)
        }
    }

    private func shortcut(_ title: String, _ chord: KeyChord, detail: String? = nil) -> some View {
        SettingsRow(title, detail) {
            HStack(spacing: 4) {
                ForEach(chord.keycaps, id: \.self) { SettingsKeycap($0) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chord.spelled)
        }
    }
}

// MARK: - Permissions

/// How a permission row should read. Screen Recording is optional until meeting capture is in play:
/// the user has turned on call offers, or a capture is recording, finishing or has just failed.
enum PermissionNeed: Equatable {
    case granted
    case required
    case optional(reason: String)

    static func core(granted: Bool) -> PermissionNeed {
        granted ? .granted : .required
    }

    static let meetingsOnly = "Only needed to record a meeting."

    static func screenRecording(granted: Bool,
                                offersToTranscribeCalls: Bool,
                                meetingCaptureUnderway: Bool) -> PermissionNeed {
        if granted { return .granted }
        return offersToTranscribeCalls || meetingCaptureUnderway
            ? .required
            : .optional(reason: meetingsOnly)
    }

    var spoken: String {
        switch self {
        case .granted: "granted"
        case .required: "not granted"
        case .optional(let why): "optional, not granted. \(why)"
        }
    }

    var reason: String? {
        if case .optional(let why) = self { return why }
        return nil
    }
}

struct PermissionRow: View {
    let name: String
    let purpose: String
    let need: PermissionNeed
    let grant: () -> Void

    var body: some View {
        SettingsRow(name, need.reason ?? purpose) {
            switch need {
            case .granted:
                SettingsStatus(text: "Allowed", kind: .ok)
            case .required:
                Button("Grant", action: grant)
                    .buttonStyle(.pen(.fill, .small))
                    .accessibilityLabel("Grant \(name)")
            case .optional:
                Button("Grant", action: grant)
                    .buttonStyle(.pen(.outline, .small))
                    .accessibilityLabel("Grant \(name)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(need.spoken)
    }
}
