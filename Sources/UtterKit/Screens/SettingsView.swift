import SwiftUI
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
    @State private var launchAtLogin = false
    @ObservedObject private var readiness = ReadinessMonitor.shared

    private var micGranted: Bool { readiness.micGranted }
    private var axGranted: Bool { readiness.axGranted }
    private var screenGranted: Bool { readiness.screenRecordingGranted }
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared

    /// Read only to decide whether Screen Recording is needed *now* — see
    /// `PermissionNeed.screenRecording`.
    ///
    /// `@ObservedObject` and not a computed lookup, for the same reason `NotesView`
    /// spells it this way: `state` is `@Published`, and reading it through a plain
    /// `AppDelegate.current?.meetingSession` would not subscribe, so a capture failing
    /// while this pane is open would leave the row still saying "optional".
    @ObservedObject private var meeting = AppDelegate.current?.meetingSession ?? MeetingSession()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
                // App settings — grouped the way the user expects to find them:
                // what the app does at the OS level, then sound, then per-screen
                // behaviour. Speech settings moved to their own pane.
                SettingsCard(title: "App") {
                    GlassToggle(
                        title: "Launch at login",
                        description: "Start Utter automatically when you log in.",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { val in
                        if #available(macOS 13.0, *) {
                            try? val ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        }
                    }
                    .onAppear {
                        if #available(macOS 13.0, *) {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }

                    HairlineDivider()

                    GlassToggle(
                        title: "Always show the pill",
                        description: "Keep it on screen. When off, it appears only while dictating.",
                        isOn: $userData.alwaysShowPill
                    )
                    .onChange(of: userData.alwaysShowPill) { _ in userData.save() }

                    HairlineDivider()

                    GlassToggle(
                        title: "Show in Dock",
                        description: "Utter lives in the menu bar. Turn this on to add a Dock icon too.",
                        isOn: $userData.showInDock
                    )
                    .onChange(of: userData.showInDock) { _ in userData.save() }

                    HairlineDivider()

                    // Here rather than under Speech or Notes: what it switches on is the app
                    // watching the audio devices and putting a panel on screen by itself, which
                    // is OS-level behaviour, and the permission it needs is in this same pane.
                    GlassToggle(
                        title: "Offer to transcribe calls",
                        description: "When Utter notices you\u{2019}re in a call it offers to "
                            + "transcribe it into a note. Nothing is recorded unless you accept. "
                            + "Needs Screen Recording, below, to capture the other people and "
                            + "not just you.",
                        isOn: $userData.offerToTranscribeCalls
                    )
                    .onChange(of: userData.offerToTranscribeCalls) { _ in userData.save() }
                }

                SettingsCard(title: "Sound") {
                    GlassToggle(
                        title: "Dictation sounds",
                        description: "Soft cues when recording starts, stops, and finishes.",
                        isOn: $userData.soundsEnabled
                    )
                    .onChange(of: userData.soundsEnabled) { _ in
                        userData.save()
                        // Play one so the choice is audible immediately.
                        if userData.soundsEnabled { SoundPlayer.playDone() }
                    }

                    HairlineDivider()

                    GlassToggle(
                        title: "Pause other audio while dictating",
                        description: "Sends the play/pause key so music doesn\u{2019}t bleed into the microphone.",
                        isOn: $userData.muteMusicWhileDictating
                    )
                    .onChange(of: userData.muteMusicWhileDictating) { _ in userData.save() }
                }

                SettingsCard(title: "Notes") {
                    VStack(alignment: .leading, spacing: Space.x3) {
                        // Replaces the old "when you open the Scratchpad" choice,
                        // which stopped meaning anything once notes became a list:
                        // every note persists and you pick the one you want. The
                        // real question now is where dictated text lands.
                        Text("When you dictate into Utter").typo(.body)
                        GlassSegmentedControl(
                            options: [true, false],
                            label: { $0 ? "Add to the open note" : "Always start a new note" },
                            selection: $userData.captureAppendsToOpenNote
                        )
                        .onChange(of: userData.captureAppendsToOpenNote) { _ in userData.save() }
                    }
                }

                // Hotkey — a segmented control, not a pop-up menu.
                //
                // Four short options fit comfortably, and the previous pop-up hid
                // every alternative behind a click for no space saving. The
                // description below updates with the selection, which is the real
                // reason to show the choices: each key has a different trade-off.
                SettingsCard(title: "Hotkey") {
                    Text("Hold this key to dictate. Release to transcribe.").typo(.caption)

                    GlassSegmentedControl(
                        options: HotkeyOption.options.map(\.name),
                        label: { $0 },
                        selection: $userData.hotkeyName
                    )
                    .onChange(of: userData.hotkeyName) { _ in
                        userData.save()
                        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                    }

                    let opt = HotkeyOption.options.first { $0.name == userData.hotkeyName } ?? HotkeyOption.options[0]
                    VStack(alignment: .leading, spacing: Space.x1) {
                        Text(opt.description)
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(opt.impact)
                            .typo(.caption, ink: opt.impact.hasPrefix("Use with caution")
                                  ? Tint.warningText : Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // The description block below changes height as the selection
                    // moves between hotkeys, so this is layout travel, not a fade.
                    .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange,
                               value: userData.hotkeyName)

                    HairlineDivider()

                    // The other two ways into dictation, named here rather than only
                    // in the status-item menu. Nothing on screen reveals them — the pill
                    // shows the hold hotkey and that is all. Every shortcut comes from
                    // `KeyChord` or `HoldTap`, the same values `KeyMonitor` matches on,
                    // so this card cannot advertise a gesture that no longer fires.
                    //
                    // Hold-then-tap needs an event tap to swallow the tapped key, so it
                    // is shown only when there is one. `axGranted` is both a precondition
                    // for that tap and what makes this view re-render when it appears —
                    // `HoldTap.isAvailable` alone would go stale on screen.
                    let handsFreeHoldTap = (axGranted && HoldTap.isAvailable)
                        ? HoldTap.binding(for: .handsFree) : nil

                    VStack(alignment: .leading, spacing: Space.x2) {
                        ShortcutHint(keys: KeyChord.handsFree.keycaps,
                                     caption: ShortcutAction.handsFree.label,
                                     spokenKeys: KeyChord.handsFree.spelled)
                        if let handsFreeHoldTap {
                            ShortcutHint(keys: handsFreeHoldTap.keycaps(holdKey: userData.hotkeyName),
                                         caption: "while dictating",
                                         spokenKeys: handsFreeHoldTap.spelled(holdKey: userData.hotkeyName))
                        }
                        Text("Starts recording without holding anything, and keeps "
                             + "going until you press it again or stop speaking for "
                             + "three seconds.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        if let handsFreeHoldTap {
                            Text("Already dictating? Keep \(userData.hotkeyName) down and "
                                 + "tap \(handsFreeHoldTap.keyLabel) — that recording keeps "
                                 + "going after you let go. Tap it again to finish, or just "
                                 + "stop talking.")
                                .typo(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.x2) {
                        ShortcutHint(keys: KeyChord.noteCapture.keycaps,
                                     caption: ShortcutAction.noteCapture.label,
                                     spokenKeys: KeyChord.noteCapture.spelled)
                        Text("Press it, say what you want to keep, then press it again "
                             + "\u{2014} or simply stop talking, as with hands-free. The "
                             + "text goes to your notes instead of the app in front: "
                             + "into the note that is open, or a new one, following the "
                             + "Notes setting above. Pressing it while already dictating "
                             + "redirects that recording into a note.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Or say \u{201C}start a new note\u{201D} or \u{201C}continue "
                             + "the note\u{201D} while dictating: the phrase is the "
                             + "command, and whatever you say next is filed there. "
                             + "Needs Voice commands, under Speech.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        // Answers the obvious question the row above raises. Only worth
                        // saying once hold-and-tap has been introduced, hence the same
                        // condition.
                        if handsFreeHoldTap != nil {
                            Text("This one has no hold-and-tap spelling: macOS keeps "
                                 + "Fn and N for Notification Center.")
                                .typo(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                SettingsCard(title: "Permissions") {
                    PermRow(need: .core(granted: axGranted), label: "Accessibility",
                            url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    PermRow(need: .core(granted: micGranted), label: "Microphone",
                            url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                    // Only meeting capture needs this, so it is listed last and it is
                    // optional until meeting capture is in play — see `PermissionNeed`
                    // for which signals count as "in play" and why.
                    //
                    // The label lost its "(meetings)" parenthetical: it named the
                    // feature but never said the permission was optional, which was the
                    // whole of the problem, and in the optional state it would now say
                    // "meetings" twice over the reason line beneath. In the required
                    // state the "Offer to transcribe calls" switch above already says
                    // "Needs Screen Recording, below", so nothing is lost there either.
                    PermRow(need: .screenRecording(granted: screenGranted,
                                                   offersToTranscribeCalls: userData.offerToTranscribeCalls,
                                                   meetingCaptureUnderway: meeting.state != .idle),
                            label: "Screen Recording",
                            url: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                }

                // What was a "How to use" card restating all three shortcuts now that
                // the Hotkey card above carries them properly. This line was the only
                // thing unique to it — and it said "this window", which stopped being
                // true when Settings moved out of the main window: a long press opens
                // Utter, not Settings.
                SettingsCard(title: "The pill") {
                    Text("Long-press the pill for two seconds to open the Utter window.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onAppear { readiness.startPolling() }
            .onDisappear { readiness.stopPolling() }
    }
}

/// A horizontal rule between rows, in the app's own neutral ramp.
///
/// Not `Divider()`. `Divider` draws `NSColor.separatorColor`, and `Line.hairline`
/// exists precisely because that colour is wrong here — see `Line` in
/// DesignTokens.swift: "macOS's `separatorColor` is cool blue-gray. Mixing the two is
/// the single fastest way to make a warm layout look wrong."
///
/// This replaces 22 `Divider().opacity(0.5)` call sites. The `0.5` was the tell: an
/// opacity tuned to mute the wrong hue rather than to set a weight, repeated as a
/// magic number at every one of them. The shape is the one `SettingsWindowView`
/// already uses for the rule between its two panes — a `Rectangle` filled with the
/// token, sized on `Line.width`.
///
/// One exception was left alone deliberately: `HomeView`'s `.contextMenu` still calls
/// `Divider()`, because inside a menu that is the API for a *menu separator* — AppKit
/// draws it, it is not a line in this layout, and a `Rectangle` there would be a 1pt
/// item in the menu rather than a divider between items.
///
/// Lives in `Screens/` rather than `DesignSystem/` only because that folder is owned
/// by another change in flight; it belongs beside `Line` in DesignTokens.swift.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Line.hairline)
            .frame(height: Line.width)
            // A rule carries no information VoiceOver needs — the rows either side
            // of it are already separate elements.
            .accessibilityHidden(true)
    }
}

/// Settings group, rendered as a bento tile so Settings matches the rest of
/// the app. The uppercase header is gone — sentence case is the macOS convention.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        BentoTile(title: title) {
            VStack(alignment: .leading, spacing: Space.x3) {
                content()
            }
        }
    }
}

/// How a permission row should read, and the rule for picking one.
///
/// Three states, not two. `PermRow` took a bare `ok: Bool` — granted, or a warning
/// dot and a "Grant" button — which is correct for Accessibility and the microphone
/// and wrong for Screen Recording. Meeting capture is off by default
/// (`UserData.offerToTranscribeCalls` starts `false`, and the Notes screen's Record
/// button is a deliberate press), so the *default* state of a fresh install was a
/// warning indicator and a call to action for a permission the user may never need.
/// That reads as "something in this app is broken" when nothing is.
///
/// A pure enum with the rule as a static function, following `PillHoverControl`: the
/// view cannot be tested on this machine, the decision can — and this is a decision
/// that is wrong quietly in both directions. Nagged for when it is not needed is a
/// support question; presented as optional at the moment it is actually required is a
/// feature that silently half-works, which for meeting capture means a transcript
/// with one side of the conversation in it.
enum PermissionNeed: Equatable {
    case granted
    /// Not granted, and something the user has switched on needs it now — the
    /// existing warning-plus-Grant treatment, which is right here.
    case required
    /// Not granted, and nothing needs it yet. Neutral and informational.
    /// `reason` is the supporting line that says so, shown and spoken.
    case optional(reason: String)

    /// A permission the app cannot do its core job without. Missing means required
    /// immediately — there is no "later" for dictation.
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
    /// Two signals, OR'd, and the reasoning for each — this is the judgement call:
    ///
    ///   * `offersToTranscribeCalls` is the user's own declaration that they want
    ///     meeting capture. With it on, `CallDetector` runs and will put an offer
    ///     card on screen during the next call, and accepting that card without this
    ///     permission records only the user. So from the moment the switch is on the
    ///     permission is genuinely needed and the warning is honest — this is the
    ///     primary signal, because it is durable and it is the user's intent rather
    ///     than an inference about it.
    ///   * `meetingCaptureUnderway` covers the other route in, which the preference
    ///     does not: the Notes screen's Record button starts a capture with the
    ///     preference off. `MeetingSession.state` is non-`.idle` while a capture is
    ///     recording, finishing, or has **failed and not been retried** — and the
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
    /// work in a view body — the exact thing `ReadinessMonitor` exists to keep out of
    /// the render path — and it would pin the row to required forever after a single
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
                // already resolves to secondary — spelled out here because it is
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
        // row's height — the travel Reduce Motion is asking to be spared.
        .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange, value: need)
    }

    private static let dotSize: CGFloat = 8

    /// Filled for a decided state, a hollow ring for the optional one.
    ///
    /// `Tint.success`/`Tint.warning` rather than `.green`/`.orange`: the NSColor-backed
    /// tokens lighten correctly in dark mode. The *shape* carries the third state, not
    /// the hue — a dot fading from amber to a neutral grey is the definition of
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
/// states plainly what runs where instead of offering settings that don't exist —
/// and it is where Reset Utter lives.
///
/// This was a thin pane of live status, while a much fuller `PrivacyView` — five
/// `PolicyCard`s **and the app's only Reset Utter button** — sat in the source with
/// no caller anywhere: `SettingsGroup.privacy` routes here
/// (`SettingsWindowView.detail`) and nothing routed there. So `clearAllData()` was
/// unreachable, which means the reset the app promises could not be performed at
/// all, and the copy describing it ("The button below erases all history, your
/// notes…") named a button that was not on screen. The main window records the
/// intent this restores — `SidebarItem.primary` in FlowMainView.swift: "they live in Settings only —
/// which also puts 'Reset Utter' alongside the other settings instead of next to
/// your snippets."
///
/// The cards run one per row rather than `PrivacyView`'s `BentoRow(columns: 2)`.
/// This is the settings detail column, which is 152pt of group list out of
/// `Layout.settingsMinWidth` 620 — so roughly 420pt of content, where two-up would
/// leave each four-bullet card under 200pt.
struct PrivacySettingsContent: View {
    @ObservedObject private var readiness = ReadinessMonitor.shared
    private var aiState: LocalAIEngine.Availability { readiness.aiState }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            SettingsCard(title: "AI commands") {
                LockedRow(label: "Engine", value: "Apple Intelligence")
                LockedRow(label: "Runs on", value: "This Mac")
                HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                    // The glyph changes *shape* as well as hue, so the state survives
                    // being read without colour vision. The point size is a symbol
                    // metric, not the type scale — see the note on `AboutContent`.
                    Image(systemName: aiState.isReady ? "checkmark.circle.fill"
                                                      : "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        // The *text* variants, even though this is a glyph: the shape carries
                        // the state, but a shape at 1.48:1 cannot be read either. 11pt is small
                        // enough that the 3:1 non-text floor is the wrong bar anyway.
                        .foregroundStyle(aiState.isReady ? Tint.successText : Tint.warningText)
                    Text(aiState.message)
                        .typo(.caption, ink: Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if case .appleIntelligenceOff = aiState {
                    GlassButton(title: "Open Apple Intelligence Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?AppleIntelligence") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            // The policy statements, no longer stranded in a view with no caller.
            //
            // Wording is carried over unchanged apart from the headings: this is what
            // the app promises about the user's data, so it is not copy to reword in a
            // styling pass. Headings drop to sentence case, the convention `SettingsCard`
            // records above.
            //
            // The former bespoke "Network" card is gone rather than kept beside these:
            // its text was the first bullet of "Nothing leaves this Mac" almost verbatim.
            // Its one unique clause is preserved as the last bullet there.
            PolicyCard(icon: "wifi.slash", title: "Nothing leaves this Mac", items: [
                "Downloading a larger speech model is the only time Utter uses the network, and only when you ask",
                "Speech recognition runs on a Whisper model bundled inside the app",
                "AI commands run on Apple’s on-device language model",
                "No account, no API keys, no usage limits, and it works offline",
                "Your voice and text never leave this Mac",
            ])

            PolicyCard(icon: "waveform.badge.mic", title: "Audio recording", items: [
                "Audio is captured in memory only while you hold the record key",
                "No audio files are ever written to disk",
                "Audio is discarded from memory immediately after transcription",
                "The microphone is only active during recording — never in the background",
            ])

            PolicyCard(icon: "lock.shield.fill", title: "Your data stays on your device", items: [
                "Transcription history is stored locally, in your user Library folder",
                "Dictionary words, snippets, and preferences are saved on-device only",
                "No analytics, telemetry, or usage tracking of any kind",
                "Nothing is synced to a cloud service or shared with third parties",
            ])

            PolicyCard(icon: "hand.raised.fill", title: "Permissions", items: [
                "Microphone: required to capture your voice for transcription",
                "Accessibility: required to type text into other applications",
                "Screen Recording: only if you record a meeting — it captures audio, never the screen",
                "You can revoke permissions at any time in System Settings",
            ])

            PolicyCard(icon: "trash.fill", title: "Reset", items: [
                "The button below erases all history, your notes, installed companion packs, dictionary words, snippets, and preferences",
                "Uninstalling the app removes the binary but leaves saved data behind",
            ])

            DataResetSection()

            Spacer(minLength: 0)
        }
        .onAppear { readiness.startPolling() }
        .onDisappear { readiness.stopPolling() }
    }
}

// MARK: - Speech

/// Everything about how speech is recognised.
///
/// The model chooser used to sit under Privacy, which was the wrong home: it is a
/// speed/accuracy decision, not a privacy one. Privacy now only states what
/// leaves the machine (nothing), and the download lives here beside the language
/// and punctuation settings it actually relates to.
struct SpeechSettingsContent: View {
    @ObservedObject private var userData = UserData.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            SettingsCard(title: "Model") {
                ModelChooserView(compact: true)
            }

            SettingsCard(title: "Recognition") {
                GlassToggle(
                    title: "Fix sentence structure",
                    description: "Repunctuates what you dictate using the on-device language model. Whisper guesses punctuation from pauses, so it puts a comma at every breath; this splits run-on sentences properly. Words are never changed.",
                    isOn: $userData.sentencePolishEnabled
                )
                .onChange(of: userData.sentencePolishEnabled) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Spoken punctuation",
                    description: "Turns spoken \"period\" into \".\", \"comma\" into \",\", and so on.",
                    isOn: $userData.spokenPunctuationEnabled
                )
                .onChange(of: userData.spokenPunctuationEnabled) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Voice commands",
                    description: "Say a command name to run it instead of typing the words.",
                    isOn: $userData.voiceCommandsEnabled
                )
                .onChange(of: userData.voiceCommandsEnabled) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Prefer your dictionary words",
                    description: "Tells the speech model your dictionary words before it listens, so unusual names are heard correctly instead of being repaired afterwards. Only affects recognition once you have added words.",
                    isOn: $userData.speechBiasEnabled
                )
                .onChange(of: userData.speechBiasEnabled) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Match the app you’re writing in",
                    description: "Keeps chat messages short and email in full sentences. Adjusts punctuation and formality only — never your words.",
                    isOn: $userData.perAppToneEnabled
                )
                .onChange(of: userData.perAppToneEnabled) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Read text around the cursor",
                    description: "Uses the words just before your cursor as a hint, so names already on screen are recognised and new text continues the sentence properly. Read on-device only, never saved, never sent anywhere. Skipped in password fields.",
                    isOn: $userData.useSurroundingContext
                )
                .onChange(of: userData.useSurroundingContext) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Keep dictation history",
                    description: "Utter keeps a searchable log of what you dictated. Turn this off to stop recording it.",
                    isOn: $userData.keepHistory
                )
                .onChange(of: userData.keepHistory) { _ in userData.save() }

                HairlineDivider()

                GlassToggle(
                    title: "Show words as you speak",
                    description: "Displays a rough live transcript in the pill while you talk. It is a preview only — the final text is transcribed properly when you stop. Uses noticeably more battery.",
                    isOn: $userData.livePreviewEnabled
                )
                .onChange(of: userData.livePreviewEnabled) { _ in userData.save() }

                HairlineDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Language").typo(.body)
                        Text("The bundled speech model is English-only.").typo(.caption)
                    }
                    Spacer()
                    GlassChip(text: "English")
                }
            }
        }
    }
}

// MARK: - About

/// The About pane.
///
/// `Typo.wordmark` for the app name, which is the one token this is allowed to be:
/// it was `.font(.system(size: 20, weight: .bold, design: .rounded))`, breaking two
/// written rules at once, both in the `Typo` header comment in DesignTokens.swift:
/// "Only three weights ship: regular, medium, semibold", and "`.rounded` survives in
/// exactly one place: the wordmark". The app name set beside its own 64pt icon *is*
/// the wordmark, and
/// `Typo.wordmark` (19pt semibold rounded) is the token that exists for it, so the
/// rounded face is kept legitimately and the bold weight goes.
///
/// Note the remaining raw `.font(.system(size:))` calls in this file are all on
/// `Image(systemName:)`. A symbol's point size is a glyph metric, not a step on the
/// type scale — `BentoTile`, `EmptyStateView` and `GlassChip` in `DesignSystem/` all
/// size their glyphs the same way — so they are deliberately left alone.
struct AboutContent: View {
    var body: some View {
        VStack(spacing: Space.x3) {
            AppIconView(size: 64)

            Text("Utter").typo(.wordmark)

            Text("Version \(ConfigManager.shared.appVersion)")
                .typo(.caption, ink: Ink.secondary)

            Text("Private voice to text, powered by Whisper on your Mac")
                .typo(.caption, ink: Ink.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.x5)
        .frame(maxWidth: .infinity)
    }
}

// `ValidatedField` was removed here rather than restyled.
//
// It had no callers anywhere in the target — it was the last of the credential form
// from the cloud version, and it carried three of the defects this pass exists to
// remove: `.textFieldStyle(.roundedBorder)` (not the app's field), a bare
// `Color.red.opacity(0.5)` invalid-state stroke, and `.foregroundStyle(.red)` error
// text. Fixing an unreachable view would only have made the next reader trust it.
// `GlassTextField` is the field; an error line beneath it belongs to whichever
// screen needs one.

/// Read-only label/value row, used by the Privacy pane.
struct LockedRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .typo(.caption, ink: Ink.secondary)
                .frame(width: 90, alignment: .leading)
            // `Typo.mono` is 13pt, one point up from the 12pt this used. There is no
            // 12pt monospaced step on the scale, and a value the user may quote is the
            // wrong place to invent one.
            Text(value)
                .typo(.mono)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
