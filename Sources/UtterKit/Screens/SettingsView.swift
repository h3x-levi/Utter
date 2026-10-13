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
        PaneGroup("Look") {
            PaneRow("Appearance", "System follows the Light or Dark setting on your Mac.") {
                PaneSegmented(title: "Appearance", selection: model.appearance,
                              options: AppTheme.themes.map { ($0.id, $0.name) })
            }
        }
        PaneGroup("Pill") {
            toggle("Always show the pill", "Keep it on screen when you are not dictating.", \.alwaysShowPill)
        }
        PaneGroup("App") {
            PaneRow("Open at login") {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    .toggleStyle(.pane)
            }
            toggle("Show in Dock", nil, \.showInDock)
            toggle("Offer to transcribe calls", "When a Zoom, Teams, FaceTime, Webex, Slack or Discord call starts.",
                   \.offerToTranscribeCalls)
        }
        PaneGroup("Sound") {
            PaneRow("Dictation sounds", "A soft sound when listening starts and stops.") {
                Toggle("Dictation sounds", isOn: model.preference(\.soundsEnabled) { if $0 { SoundPlayer.playDone() } })
                    .toggleStyle(.pane)
            }
            toggle("Pause music while dictating", "So it does not get into the microphone.", \.muteMusicWhileDictating)
        }
        PaneGroup("Notes") {
            PaneRow("When you dictate into Utter") {
                PaneSegmented(title: "When you dictate into Utter", selection: model.preference(\.captureAppendsToOpenNote),
                              options: [(true, "Add to the open note"), (false, "Start a new note")])
            }
        }
        PaneGroup {
            PaneRow("Setup", "Walk through the permissions and a first dictation again.") {
                Button("Run setup again") { model.runSetupAgain() }
                    .buttonStyle(.pane())
            }
        }
        .onAppear { model.refreshLaunchAtLogin() }
    }

    private func toggle(_ title: String, _ detail: String?,
                        _ key: ReferenceWritableKeyPath<UserData, Bool>) -> some View {
        PaneRow(title, detail) {
            Toggle(title, isOn: model.preference(key)).toggleStyle(.pane)
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
        if WhistleEngine.isAvailable {
            PaneGroup("Engine") {
                engine(.whisper, "Accurate", "Best results. Uses the Whisper model, 190 MB.")
                engine(.whistle, "Fast", "Starts instantly. A smaller 17 MB model for Apple silicon. Makes a few more mistakes.")
            }
        }
        if SpeechEngine.active(userData) == .whisper {
            PaneGroup("Speech model",
                      note: "Your voice stays on this Mac. Utter goes online only to download a model you choose.") {
                ModelChooserView(models: model.models, device: model.device)
            }
        }
        PaneGroup("Writing") {
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
        PaneGroup("While you talk") {
            toggle("Show words as you speak", "A rough preview in the pill before the final text.",
                   \.livePreviewEnabled)
            toggle("Keep dictation history", "A private list of what you dictate, kept on this Mac.",
                   \.keepHistory)
        }
        PaneGroup {
            PaneRow("Language", "The included model understands English.") {
                Text("English").foregroundStyle(Pane.ink2)
            }
        }
    }

    private func toggle(_ title: String, _ detail: String,
                        _ key: ReferenceWritableKeyPath<UserData, Bool>) -> some View {
        PaneRow(title, detail) {
            Toggle(title, isOn: model.preference(key)).toggleStyle(.pane)
        }
    }

    private func engine(_ engine: SpeechEngine, _ title: String, _ detail: String) -> some View {
        let picked = userData.speechEngine == engine
        return Button { model.preference(\.speechEngine).wrappedValue = engine } label: {
            PaneRow(title, detail) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Look.Color.tint)
                    .opacity(picked ? 1 : 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
        }
        .buttonStyle(PanePressStyle(scale: 0.985, radius: 12))
        .padding(.horizontal, -8)
        .accessibilityAddTraits(picked ? .isSelected : [])
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
        PaneGroup("Dictation") {
            PaneRow("Hold to talk", HotkeyOption.find(stored: key).description) {
                Menu {
                    Picker("Hold to talk", selection: model.hotkey) {
                        ForEach(HotkeyOption.options) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    HStack(spacing: 6) {
                        Text(HotkeyOption.find(stored: key).name)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.pane())
                .fixedSize()
                .accessibilityLabel("Hold to talk key")
            }
            PaneRow("Double-tap for hands-free", "Press \(key) twice to keep listening without holding it.") {
                Toggle("Double-tap for hands-free", isOn: model.preference(\.doubleTapHotkeyForHandsFree))
                    .toggleStyle(.pane)
            }
        }
        PaneGroup("Other shortcuts") {
            shortcut("Hands-free", KeyChord.handsFree,
                     detail: (HoldTap.isAvailable ? "Or hold \(key) and tap Space while you talk. " : "")
                        + "Listens until you press it again or stop talking for 3 seconds.")
            shortcut("Take a note", KeyChord.noteCapture)
            shortcut("Remember", KeyChord.memoryCapture)
        }
    }

    private func shortcut(_ title: String, _ chord: KeyChord, detail: String? = nil) -> some View {
        PaneRow(title, detail) {
            HStack(spacing: 4) {
                ForEach(chord.keycaps, id: \.self) { Look.Keycap($0) }
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
        PaneRow(name, need.reason ?? purpose) {
            switch need {
            case .granted:
                PaneStatus(text: "Allowed", kind: .ok)
            case .required:
                Button("Grant", action: grant)
                    .buttonStyle(.pane(.prime))
                    .accessibilityLabel("Grant \(name)")
            case .optional:
                Button("Grant", action: grant)
                    .buttonStyle(.pane())
                    .accessibilityLabel("Grant \(name)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(need.spoken)
    }
}
