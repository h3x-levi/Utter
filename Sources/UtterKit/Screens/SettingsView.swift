import SwiftUI
import AppKit
import ServiceManagement
import AVFoundation
import ApplicationServices

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}

// MARK: - Settings panes
//
// These are the individual panes. The window that hosts them, and its group list,
// live in SettingsWindowView.swift.
//
// Removed here: `InlineSettingsView` (the in-sidebar settings page) and a
// `SettingsView` TabView that rendered the same three panes with different
// chrome. Settings is one window now, so two extra hosts for the same content
// were just two more things to keep in sync.

// MARK: - General Settings

struct GeneralSettingsContent: View {
    @ObservedObject private var readiness = ReadinessMonitor.shared

    private var micGranted: Bool { readiness.micGranted }
    private var axGranted: Bool { readiness.axGranted }
    private var screenGranted: Bool { readiness.screenRecordingGranted }
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    @ObservedObject private var meeting = AppDelegate.current?.meetingSession ?? MeetingSession()

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                if #available(macOS 13.0, *) {
                    return SMAppService.mainApp.status == .enabled
                }
                return false
            },
            set: { val in
                if #available(macOS 13.0, *) {
                    try? val ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            // Utter does not currently provide accounts or cloud sync.
            AppleSettingsSection(title: "LOCAL DATA") {
                HStack(spacing: Space.x4) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 38, height: 38)
                        Image(systemName: "lock.shield")
                            .font(.system(size: 20))
                            .foregroundStyle(Ink.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stored on this Mac")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Ink.primary)
                        Text("Preferences, notes, and transcripts stay in your local Utter data folder.")
                            .font(.system(size: 11))
                            .foregroundStyle(Ink.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            // Dictation Shortcut Section (Matches Apple System Settings Dictation)
            let currentOpt = HotkeyOption.options.first { $0.name == userData.hotkeyName } ?? HotkeyOption.options[0]
            AppleSettingsSection(
                title: "DICTATION SHORTCUT",
                footer: "Hold \(userData.hotkeyName) to record and release to transcribe. \(currentOpt.description) \(currentOpt.impact)"
            ) {
                AppleSettingsRow(title: "Shortcut Key", subtitle: "Press and hold key to dictate") {
                    Picker("", selection: $userData.hotkeyName) {
                        ForEach(HotkeyOption.options) { option in
                            Text(option.name).tag(option.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                    .onChange(of: userData.hotkeyName) { _ in
                        userData.save()
                        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                    }
                }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Press \(userData.hotkeyName) Key Twice",
                    subtitle: "Double-tap to start or stop hands-free dictation without holding",
                    isOn: $userData.doubleTapHotkeyForHandsFree
                )
                .onChange(of: userData.doubleTapHotkeyForHandsFree) { _ in
                    userData.save()
                }
            }

            // App Settings
            AppleSettingsSection(title: "APP") {
                AppleSettingsToggle(
                    title: "Launch at login",
                    subtitle: "Start Utter automatically when you log in",
                    isOn: launchAtLoginBinding
                )
                AppleSettingsDivider()
                AppleSettingsToggle(
                    title: "Always show the pill",
                    subtitle: "Keep floating pill visible on screen when idle",
                    isOn: $userData.alwaysShowPill
                )
                .onChange(of: userData.alwaysShowPill) { _ in userData.save() }
                AppleSettingsDivider()
                AppleSettingsToggle(
                    title: "Show in Dock",
                    subtitle: "Display an application icon in the macOS Dock",
                    isOn: $userData.showInDock
                )
                .onChange(of: userData.showInDock) { _ in userData.save() }
                AppleSettingsDivider()
                AppleSettingsToggle(
                    title: "Offer to transcribe calls",
                    subtitle: "Detect Zoom, Teams, FaceTime, Webex, Slack, and Discord calls",
                    isOn: $userData.offerToTranscribeCalls
                )
                .onChange(of: userData.offerToTranscribeCalls) { _ in userData.save() }
            }

            // Sound
            AppleSettingsSection(title: "SOUND") {
                AppleSettingsToggle(
                    title: "Dictation sounds",
                    subtitle: "Play soft cues when recording starts, stops, and completes",
                    isOn: $userData.soundsEnabled
                )
                .onChange(of: userData.soundsEnabled) { _ in
                    userData.save()
                    if userData.soundsEnabled { SoundPlayer.playDone() }
                }
                AppleSettingsDivider()
                AppleSettingsToggle(
                    title: "Pause music while dictating",
                    subtitle: "Pauses media playback so audio does not bleed into the microphone",
                    isOn: $userData.muteMusicWhileDictating
                )
                .onChange(of: userData.muteMusicWhileDictating) { _ in userData.save() }
            }

            // Notes target
            AppleSettingsSection(title: "NOTES") {
                AppleSettingsRow(title: "When dictating into Utter", subtitle: "Choose default note capture destination") {
                    Picker("", selection: $userData.captureAppendsToOpenNote) {
                        Text("Add to open note").tag(true)
                        Text("Always start a new note").tag(false)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190)
                    .onChange(of: userData.captureAppendsToOpenNote) { _ in userData.save() }
                }
            }

            // Keyboard Shortcuts
            AppleSettingsSection(
                title: "OTHER SHORTCUTS",
                footer: "Hands-free records continuously until toggled off or 3 seconds of silence."
            ) {
                AppleSettingsRow(title: "Hands-Free Dictation", subtitle: "Toggle hands-free recording on/off") {
                    HStack(spacing: 4) {
                        Keycap(key: "⌃")
                        Keycap(key: "⌥")
                        Keycap(key: "Space")
                    }
                }
                AppleSettingsDivider()
                AppleSettingsRow(title: "Take a Note", subtitle: "Dictate directly into Utter notes") {
                    HStack(spacing: 4) {
                        Keycap(key: "⌃")
                        Keycap(key: "⌥")
                        Keycap(key: "N")
                    }
                }
                AppleSettingsDivider()
                AppleSettingsRow(title: "Remember", subtitle: "Capture a private thought or memory") {
                    HStack(spacing: 4) {
                        Keycap(key: "⌃")
                        Keycap(key: "⌥")
                        Keycap(key: "R")
                    }
                }
            }

            // Permissions
            AppleSettingsSection(title: "PERMISSIONS") {
                PermRow(need: .core(granted: axGranted), label: "Accessibility",
                        url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                AppleSettingsDivider()
                PermRow(need: .core(granted: micGranted), label: "Microphone",
                        url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                AppleSettingsDivider()
                PermRow(need: .screenRecording(granted: screenGranted,
                                               offersToTranscribeCalls: userData.offerToTranscribeCalls,
                                               meetingCaptureUnderway: meeting.state != .idle),
                        label: "Screen Recording",
                        url: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .onAppear { readiness.startPolling() }
        .onDisappear { readiness.stopPolling() }
    }
}

// MARK: - Settings form style

extension View {
    /// The one place a Settings pane's `Form` is configured, applied by all four panes.
    ///
    /// `.formStyle(.grouped)` is the whole point of the pass: it is the macOS settings group  - 
    /// the system's inset rounded container, its own separators between rows, its own row
    /// insets, and one shared label/control alignment down the group. It is macOS 13.0
    /// (`GroupedFormStyle` in the SDK swiftinterface), so it needs no availability gate at this
    /// package's 13.3 floor.
    ///
    /// The two modifiers after it exist because these forms are **not** the pane's scroll view.
    /// `SettingsDetail` in SettingsWindowView.swift already wraps every pane in a `ScrollView`,
    /// which is what carries the window's measured 66pt top content inset and the macOS 26
    /// scroll-edge pocket. A grouped `Form` brings its own scroll view, so without
    /// `.scrollDisabled(true)` there are two nested scrollers: the inner one wins the wheel and
    /// the outer one never moves, which strands the bottom of a long pane. `.fixedSize(vertical:)`
    /// is the other half - a disabled scroll view still takes the height it is offered, so
    /// without it the Form would clip its own content at the viewport instead of growing and
    /// letting the outer `ScrollView` scroll it.
    ///
    /// `.scrollContentBackground(.hidden)` (also 13.0) is for the same reason it is on the
    /// sidebar `List`: the pane sits on a themed `windowBackground`, and a form's default
    /// content background would paint an opaque sheet over it and lose the theme.
    ///
    /// The grouped style's own margins do stack with the page column's `Space.pageInset`, so a
    /// group sits further in than the heading above it - and **that is not a bug to fix here.**
    /// Dropping the page inset is the wrong fix and would make three things worse: a grouped
    /// `Form` *outdents* its section headers relative to its own group background (System
    /// Settings does the same), so the element nearest the window's leading edge would become a
    /// header pressed against the sidebar glass; Companion and Diagnostics are still bare
    /// `VStack`s of `SettingsCard` and would go flush; and the page heading would lose its
    /// margin. The inset is uniform, so it cannot change the gap it is blamed for. See the note
    /// on `Space.pageInset`.
    func settingsForm() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
    }
}

/// An anti-collision settings toggle row with native macOS ergonomics.
///
/// Decouples the multi-line text container from the native switch control, ensuring
/// that SwiftUI's Form layout engine calculates the true height of multi-line descriptions
/// without overlapping adjacent rows.
struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .typo(.body, ink: Ink.primary)
                Text(description)
                    .typo(.caption, ink: Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 2)
        .accessibilityLabel("\(title), \(description)")
    }
}

/// A genuine AppKit radio button whose parent controls the vertical layout.
///
/// SwiftUI's macOS `RadioGroupPickerStyle` is free to lay a short group out
/// horizontally, even when its content is inside a vertical stack. Settings
/// needs one predictable row per option, so the system radio control is bridged
/// directly instead of redrawing it with an SF Symbol.
private struct SettingsRadioButton<Value: Hashable>: NSViewRepresentable {
    let title: String
    let value: Value
    @Binding var selection: Value

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            radioButtonWithTitle: title,
            target: context.coordinator,
            action: #selector(Coordinator.selectValue(_:))
        )
        button.controlSize = .regular
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.title = title
        button.state = selection == value ? .on : .off
    }

    final class Coordinator: NSObject {
        var parent: SettingsRadioButton

        init(parent: SettingsRadioButton) {
            self.parent = parent
        }

        @objc func selectValue(_ sender: NSButton) {
            parent.selection = parent.value
        }
    }
}

// MARK: - Rules and cards

/// A horizontal rule between rows, in the app's own neutral ramp.
///
/// Not `Divider()`. `Divider` draws `NSColor.separatorColor`, and `Line.hairline`
/// exists precisely because that colour is wrong here - see `Line` in
/// DesignTokens.swift: "macOS's `separatorColor` is cool blue-gray. Mixing the two is
/// the single fastest way to make a warm layout look wrong."
///
/// This replaces 22 `Divider().opacity(0.5)` call sites. The `0.5` was the tell: an
/// opacity tuned to mute the wrong hue rather than to set a weight, repeated as a
/// magic number at every one of them. The shape is the one `SettingsWindowView`
/// already uses for the rule between its two panes - a `Rectangle` filled with the
/// token, sized on `Line.width`.
///
/// One exception was left alone deliberately: `HomeView`'s `.contextMenu` still calls
/// `Divider()`, because inside a menu that is the API for a *menu separator* - AppKit
/// draws it, it is not a line in this layout, and a `Rectangle` there would be a 1pt
/// item in the menu rather than a divider between items.
///
/// Lives in `Screens/` rather than `DesignSystem/` only because that folder is owned
/// by another change in flight; it belongs beside `Line` in DesignTokens.swift.
///
/// **No Settings pane calls this any more** - a grouped `Form` draws its own separators
/// between rows, which deleted twelve calls from this file. It stays because `HomeView`,
/// `DiagnosticsView` and `CompanionSettingsView` still use it, and it is still right
/// there: a rule inside a hand-built stack has no system component to defer to.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Line.hairline)
            .frame(height: Line.width)
            // A rule carries no information VoiceOver needs - the rows either side
            // of it are already separate elements.
            .accessibilityHidden(true)
    }
}

/// Settings group, rendered as a bento tile so Settings matches the rest of
/// the app. The uppercase header is gone - sentence case is the macOS convention.
///
/// Kept as a compatibility wrapper for feature panes while those panes migrate to
/// native Lists and Forms. The wrapper now adds semantic grouping and spacing only;
/// it deliberately does not draw a rounded dashboard card.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ContentSection(title: title) {
            VStack(alignment: .leading, spacing: Space.x3) {
                content()
            }
        }
    }
}

/// How a permission row should read, and the rule for picking one.
///
/// Three states, not two. `PermRow` took a bare `ok: Bool` - granted, or a warning
/// dot and a "Grant" button - which is correct for Accessibility and the microphone
/// and wrong for Screen Recording. Meeting capture is off by default
/// (`UserData.offerToTranscribeCalls` starts `false`, and the Notes screen's Record
/// button is a deliberate press), so the *default* state of a fresh install was a
/// warning indicator and a call to action for a permission the user may never need.
/// That reads as "something in this app is broken" when nothing is.
///
/// A pure enum with the rule as a static function, following `PillHoverControl`: the
/// view cannot be tested on this machine, the decision can - and this is a decision
/// that is wrong quietly in both directions. Nagged for when it is not needed is a
/// support question; presented as optional at the moment it is actually required is a
/// feature that silently half-works, which for meeting capture means a transcript
/// with one side of the conversation in it.
enum PermissionNeed: Equatable {
    case granted
    /// Not granted, and something the user has switched on needs it now - the
    /// existing warning-plus-Grant treatment, which is right here.
    case required
    /// Not granted, and nothing needs it yet. Neutral and informational.
    /// `reason` is the supporting line that says so, shown and spoken.
    case optional(reason: String)

    /// A permission the app cannot do its core job without. Missing means required
    /// immediately - there is no "later" for dictation.
    static func core(granted: Bool) -> PermissionNeed {
        granted ? .granted : .required
    }

    /// Why Screen Recording is on the list at all, given it is optional.
    ///
    /// A constant so the test can pin the case without pinning the copy, and so the
    /// spoken and the visible line cannot drift from each other.
    static let meetingsOnly = "Only needed to record a meeting."

    /// Screen Recording: optional until meeting capture is actually in play.
    ///
    /// Two signals, OR'd, and the reasoning for each - this is the judgement call:
    ///
    ///   * `offersToTranscribeCalls` is the user's own declaration that they want
    ///     meeting capture. With it on, `CallDetector` runs and will put an offer
    ///     card on screen during the next call, and accepting that card without this
    ///     permission records only the user. So from the moment the switch is on the
    ///     permission is genuinely needed and the warning is honest - this is the
    ///     primary signal, because it is durable and it is the user's intent rather
    ///     than an inference about it.
    ///   * `meetingCaptureUnderway` covers the other route in, which the preference
    ///     does not: the Notes screen's Record button starts a capture with the
    ///     preference off. `MeetingSession.state` is non-`.idle` while a capture is
    ///     recording, finishing, or has **failed and not been retried** - and the
    ///     failed case is the one that earns this input. It persists until the next
    ///     `start()`, so a user whose capture just failed and who opens Settings to
    ///     find out why sees the warning treatment, which is exactly right.
    ///     Deliberately *not* narrowed to failures whose message names Screen
    ///     Recording: that reason string can equally be "microphone busy", and either
    ///     way the user has just tried to record a meeting, which is the fact that
    ///     makes the permission needed. Attributing the failure would be a guess;
    ///     noticing the attempt is not.
    ///
    /// Not keyed off "has ever recorded a meeting". The only durable evidence for
    /// that is scanning `NoteStore` for a `.meeting` note, which is filesystem-shaped
    /// work in a view body - the exact thing `ReadinessMonitor` exists to keep out of
    /// the render path - and it would pin the row to required forever after a single
    /// meeting, including for a user who tried it once and stopped.
    static func screenRecording(granted: Bool,
                                offersToTranscribeCalls: Bool,
                                meetingCaptureUnderway: Bool) -> PermissionNeed {
        if granted { return .granted }
        return offersToTranscribeCalls || meetingCaptureUnderway
            ? .required
            : .optional(reason: meetingsOnly)
    }

    /// What VoiceOver says after the permission's name.
    ///
    /// The state cannot be left to the dot's colour: amber going neutral is nothing
    /// to a colourblind user, and VoiceOver never sees a `Circle` at all. Same reason
    /// `GlassToggle` hands its real title to the `Toggle` it visually hides.
    var spoken: String {
        switch self {
        case .granted: return "granted"
        case .required: return "not granted"
        case .optional(let why): return "optional, not granted. \(why)"
        }
    }

    /// The supporting line under the label, when the state has one.
    var reason: String? {
        if case .optional(let why) = self { return why }
        return nil
    }
}

struct PermRow: View {
    let need: PermissionNeed
    let label: String
    let url: String

    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        // The dot/label/action row is unchanged, so the two required permissions
        // render exactly as before; the optional state adds a line beneath it rather
        // than restructuring the row.
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.x2) {
                indicator
                Text(label).typo(.body)
                    // The whole state of the row, in words, on the element VoiceOver
                    // lands on first. The dot and the trailing status text are hidden
                    // below so this is said once, not three times.
                    .accessibilityLabel("\(label): \(need.spoken)")
                Spacer()
                trailing
            }
            if let reason = need.reason {
                // `Ink.secondary`, never `Ink.tertiary`: tertiary is documented
                // decorative-only and measured 2.68:1 on this fill. `.caption`
                // already resolves to secondary - spelled out here because it is
                // load-bearing, not a default worth inheriting silently.
                Text(reason).typo(.caption, ink: Ink.secondary)
                    // Indented past the dot so it hangs under the label.
                    .padding(.leading, Self.dotSize + Space.x2)
                    .fixedSize(horizontal: false, vertical: true)
                    // Folded into the label above rather than read twice.
                    .accessibilityHidden(true)
            }
        }
        // The optional state adds a whole line under the row, so this animates the
        // row's height - the travel Reduce Motion is asking to be spared.
        .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange, value: need)
    }

    private static let dotSize: CGFloat = 8

    /// Filled for a decided state, a hollow ring for the optional one.
    ///
    /// `Tint.success`/`Tint.warning` rather than `.green`/`.orange`: the NSColor-backed
    /// tokens lighten correctly in dark mode. The *shape* carries the third state, not
    /// the hue - a dot fading from amber to a neutral grey is the definition of
    /// conveying state by colour alone. Decorative either way, hence hidden from
    /// VoiceOver: the label element says which state this is.
    @ViewBuilder
    private var indicator: some View {
        Group {
            switch need {
            case .granted: Circle().fill(Tint.success)
            case .required: Circle().fill(Tint.warning)
            case .optional: Circle().strokeBorder(Ink.secondary, lineWidth: Line.width)
            }
        }
        .frame(width: Self.dotSize, height: Self.dotSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        switch need {
        case .granted:
            Text("Granted").typo(.caption, ink: Tint.successText)
                .accessibilityHidden(true)
        case .required:
            GlassButton(title: "Grant", size: .small, action: openPrivacySettings)
                // Three rows otherwise offer three identically-named "Grant" buttons,
                // which in the VoiceOver rotor is three of the same thing.
                .accessibilityLabel("Grant \(label)")
        case .optional:
            // A text link, not the bordered `GlassButton`.
            //
            // The button is the call to action, and a call to action is precisely what
            // this state must not be. But a user who *does* want meeting capture has to
            // be able to get there, so the route stays and only its weight drops.
            //
            // `Tint.accentText`, not `Tint.accent`: the accent that reads well as a
            // fill measured 3.70:1 as this very link on the dark card and 2.03:1 on
            // cream, which is the reason that token exists at all.
            Button(action: openPrivacySettings) {
                Text("Grant").typo(.caption, ink: Tint.accentText)
                    // Inside the label, so the hit region grows with it.
                    .padding(.vertical, Space.x1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Grant \(label)")
        }
    }

    private func openPrivacySettings() {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Privacy (replaces the cloud-credentials tab this app used to have)

/// Utter has no accounts, endpoints, or credentials to configure, so this pane
/// states plainly what runs where instead of offering settings that don't exist  - 
/// and it is where Reset Utter lives.
struct PrivacySettingsContent: View {
    @ObservedObject private var readiness = ReadinessMonitor.shared
    private var aiState: LocalAIEngine.Availability { readiness.aiState }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            AppleSettingsSection(title: "AI COMMANDS") {
                AppleSettingsRow(title: "Engine", subtitle: "Runs on this Mac") {
                    Text("Apple Intelligence")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                }
                AppleSettingsDivider()
                AppleSettingsRow(title: "Status", subtitle: aiState.message) {
                    HStack(spacing: 6) {
                        Image(systemName: aiState.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(aiState.isReady ? Tint.successText : Tint.warningText)
                        Text(aiState.isReady ? "Ready" : "Setup Required")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Ink.primary)
                    }
                }

                if case .appleIntelligenceOff = aiState {
                    AppleSettingsDivider()
                    HStack {
                        Spacer()
                        Button("Open Apple Intelligence Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?AppleIntelligence") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }

            AppleSettingsSection(title: "LOCAL PROCESSING") {
                privacyItem("Speech runs through a local Whisper model. Small is included; other model weights are downloaded only when you choose them.")
                AppleSettingsDivider()
                privacyItem("Writing transforms use Apple’s on-device language model when it is available.")
                AppleSettingsDivider()
                privacyItem("Utter has no account service or telemetry. Updates and model downloads require a network connection.")
                AppleSettingsDivider()
                privacyItem("Utter does not upload dictation audio or transcript text to a service.")
            }

            AppleSettingsSection(title: "AUDIO & RETENTION") {
                privacyItem("Dictation audio is buffered in memory while recording and discarded after transcription.")
                AppleSettingsDivider()
                privacyItem("Meeting capture uses rolling audio buffers and saves recognized words to the selected note.")
                AppleSettingsDivider()
                privacyItem("The microphone is active only during a user-started capture.")
            }

            AppleSettingsSection(title: "PERMISSIONS") {
                privacyItem("Microphone: required to capture your voice for transcription")
                AppleSettingsDivider()
                privacyItem("Accessibility: required to type text into other applications")
                AppleSettingsDivider()
                privacyItem("Screen Recording: only if you record a meeting - captures audio only")
            }

            AppleSettingsSection(
                title: "RESET",
                footer: "Resetting erases all history, notes, installed companion packs, dictionary words, snippets, custom commands, and preferences."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Erase all local data and restore default settings.")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.secondary)
                    DataResetSection()
                }
                .padding(14)
            }
        }
        .onAppear { readiness.startPolling() }
        .onDisappear { readiness.stopPolling() }
    }

    private func privacyItem(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Tint.success)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Ink.primary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Speech

/// Everything about how speech is recognised.
struct SpeechSettingsContent: View {
    @ObservedObject private var userData = UserData.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            AppleSettingsSection(title: "MODEL") {
                ModelChooserView(compact: true)
                    .padding(14)
            }

            AppleSettingsSection(title: "RECOGNITION") {
                AppleSettingsToggle(
                    title: "Fix sentence structure",
                    subtitle: "Repunctuates what you dictate using the on-device language model without changing words",
                    isOn: $userData.sentencePolishEnabled
                )
                .onChange(of: userData.sentencePolishEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Spoken punctuation",
                    subtitle: "Turns spoken \"period\" into \".\", \"comma\" into \",\", and so on",
                    isOn: $userData.spokenPunctuationEnabled
                )
                .onChange(of: userData.spokenPunctuationEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Voice commands",
                    subtitle: "Say a command name to run it instead of typing the words",
                    isOn: $userData.voiceCommandsEnabled
                )
                .onChange(of: userData.voiceCommandsEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Prefer your dictionary words",
                    subtitle: "Tells the speech model your dictionary words before it listens, so unusual names are heard correctly",
                    isOn: $userData.speechBiasEnabled
                )
                .onChange(of: userData.speechBiasEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Match the app you’re writing in",
                    subtitle: "Keeps chat messages short and email in full sentences without altering words",
                    isOn: $userData.perAppToneEnabled
                )
                .onChange(of: userData.perAppToneEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Read text around the cursor",
                    subtitle: "Uses words near your cursor as an on-device hint so new text flows naturally",
                    isOn: $userData.useSurroundingContext
                )
                .onChange(of: userData.useSurroundingContext) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Keep dictation history",
                    subtitle: "Utter keeps a private searchable log of past dictations on this Mac",
                    isOn: $userData.keepHistory
                )
                .onChange(of: userData.keepHistory) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsToggle(
                    title: "Show words as you speak",
                    subtitle: "Displays a rough live transcript preview in the pill while you talk",
                    isOn: $userData.livePreviewEnabled
                )
                .onChange(of: userData.livePreviewEnabled) { _ in userData.save() }

                AppleSettingsDivider()

                AppleSettingsRow(title: "Language", subtitle: "The bundled speech model is English-only") {
                    GlassChip(text: "English")
                }
            }
        }
    }
}

// MARK: - About

/// The About pane.
struct AboutContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            AppleSettingsSection {
                VStack(spacing: Space.x3) {
                    AppIconView(size: 64)

                    Text("Utter")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Ink.primary)

                    Text("Private voice to text, powered by Whisper on your Mac")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.x4)
            }

            AppleSettingsSection {
                AppleSettingsRow(title: "Version") {
                    Text(ConfigManager.shared.appVersion)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

// `ValidatedField` was removed here rather than restyled.
//
// It had no callers anywhere in the target - it was the last of the credential form
// from the cloud version, and it carried three of the defects this pass exists to
// remove: `.textFieldStyle(.roundedBorder)` (not the app's field), a bare
// `Color.red.opacity(0.5)` invalid-state stroke, and `.foregroundStyle(.red)` error
// text. Fixing an unreachable view would only have made the next reader trust it.
// `GlassTextField` is the field; an error line beneath it belongs to whichever
// screen needs one.

/// Read-only label/value row, used by the Privacy pane.
///
/// `LabeledContent` is the system component for exactly this, and it deletes the parts that
/// were only ever imitating it: a `.frame(width: 90)` hand-set label column and a trailing
/// `Spacer()`. Inside the pane's grouped `Form` the label column is now the group's - shared
/// with every other row in it, rather than a number that happened to fit two labels - and the
/// pairing is real to VoiceOver instead of implied by position.
///
/// The value keeps `.typo(.mono)` rather than taking the row's own value styling, and that is
/// deliberate: `LabeledContent` renders the value `secondaryLabelColor`, which measures 4.01:1
/// on this app's translucent tiles, under the 4.5:1 floor `Ink` exists to hold. Passing the
/// value as a view rather than through `init(_:value:)` is what makes that possible.
struct LockedRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label) {
            // `Typo.mono` is 13pt, one point up from the 12pt this used. There is no
            // 12pt monospaced step on the scale, and a value the user may quote is the
            // wrong place to invent one.
            Text(value)
                .typo(.mono)
                .textSelection(.enabled)
        }
    }
}
