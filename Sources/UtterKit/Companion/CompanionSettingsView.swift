import SwiftUI
import AppKit

/// The Companion settings pane.
///
/// Three parts, in the order a user needs them: turn it on, size it, then choose who it
/// is. The character grid previews live characters rather than listing names, for the
/// same reason `ThemeSwatchGrid` does — the choice is a visual one, so a list of
/// words is the one representation that shows nothing about it.
struct CompanionCustomizeView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var packStore = SpritePackStore.shared
    /// Live Accessibility state. The typing reactions are inert without it — see the row below.
    @ObservedObject private var readiness = ReadinessMonitor.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.groupGap) {
            SettingsCard(title: "Desktop companion") {
                SettingsToggle(
                    title: "Show a companion",
                    description: "A small character that reacts while you dictate and wanders when idle. It appears beside the pill and can then be dragged anywhere.",
                    isOn: $userData.companionEnabled
                )
                .onChange(of: userData.companionEnabled) { _ in userData.save() }

                if userData.companionEnabled {
                    VStack(alignment: .leading, spacing: Space.x3) {
                        Text("Size").typo(.body)
                        // A segmented control rather than a slider: `CompanionSize` is a
                        // ladder of four (its own doc says why), and this is the control
                        // the app already uses for a short, ordered set — the HIG's test
                        // for a pop-up is more than about five options.
                        GlassSegmentedControl(
                            options: CompanionSize.allCases,
                            label: { $0.label },
                            selection: $userData.companionSize
                        )
                        // The control is a real `Picker(.segmented)` now, and a Picker with
                        // `labelsHidden()` names its segments but not the group — so VoiceOver
                        // announced four sizes with nothing saying what they sized. The "Size"
                        // Text above is the label visually but not semantically; this makes it
                        // both. `.contain` rather than `.combine` so each segment stays its own
                        // element and remains individually selectable.
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Size")
                        .onChange(of: userData.companionSize) { _ in
                            userData.save()
                            // The frames are decoded at the size they are drawn at, so a
                            // size change makes every loaded frame the wrong resolution:
                            // without this the character is upscaled from a smaller
                            // bitmap and visibly soft. Not `force` — `reload` compares
                            // the size it last decoded for, so this is a no-op for every
                            // other reason it is called.
                            packStore.reload()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: Space.x3) {
                        Text("Interactive object").typo(.body)
                        CompanionObjectPicker(
                            options: availableObjects,
                            selection: $userData.companionObject
                        )
                        .onChange(of: userData.companionObject) { _ in userData.save() }
                        Text("Click the object beside your companion to play now. It also starts a short play sequence after about 12 idle seconds, then occasionally.")
                            .typo(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Drag the character to move it. It has a place on screen of its own, so moving it leaves the pill where it is. Right-click it to put it back beside the pill or to hide it.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if userData.companionEnabled {
                SettingsCard(title: "Reactions") {
                    SettingsToggle(
                        title: "React to typing and the cursor",
                        // Says exactly what is observed and what is not, because "reacts to
                        // your typing" is the kind of sentence a reasonable person reads as
                        // "reads what I type". It does not: the character counts keystrokes
                        // and never sees which keys they were.
                        description: "The character watches the pointer, kneads its paws while you type, gets flustered if you type very fast, and purrs when you stroke it. Only the number of keystrokes is counted — never which keys — and nothing leaves your Mac.",
                        isOn: $userData.companionPetBehaviours
                    )
                    .onChange(of: userData.companionPetBehaviours) { _ in userData.save() }

                    if userData.companionPetBehaviours {
                        SettingsToggle(
                            title: "Companion sounds",
                            description: "Cats meow and purr; the dog barks and pants. Reminder cues stay short. Separate from dictation sounds, so you can silence either family.",
                            isOn: $userData.companionSounds
                        )
                        .onChange(of: userData.companionSounds) { _ in userData.save() }

                        VStack(alignment: .leading, spacing: Space.x2) {
                            Text("Your name").typo(.body)
                            GlassTextField(
                                placeholder: "Optional",
                                text: $userData.companionUserName
                            )
                            .onChange(of: userData.companionUserName) { _ in userData.save() }
                            Text("Used when it reminds you about something, so it says your name rather than just the reminder.")
                                .typo(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Live, not a static sentence. Without Accessibility the global key
                        // monitor is COMPLETELY inert — macOS returns a valid token and then
                        // never calls the handler — so the character silently never kneads and
                        // there is nothing on screen to explain why. That is the single most
                        // confusing failure this feature has, and it is invisible until said
                        // out loud.
                        if readiness.axGranted {
                            HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tint.accent)
                                Text("Typing reactions are active. Only the number of keystrokes is counted.")
                                    .typo(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: Space.x2) {
                                HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Tint.warning)
                                    Text("Typing reactions are inactive: Utter does not have Accessibility, so it cannot tell when you are typing in another app. The character still watches the pointer and reacts to dictation.")
                                        .typo(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                GlassButton(title: "Open Privacy Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                        }
                    }

                    SettingsToggle(
                        title: "Use window edges",
                        description: "If the companion overlaps the focused window, it peeks around the nearest side instead of covering the window’s controls or content.",
                        isOn: $userData.companionWindowEdges
                    )
                    .onChange(of: userData.companionWindowEdges) { _ in userData.save() }

                    Text("Click once for a hop, double-click for a playful roll, drag and release to gently toss it, or right-click for Feed and Brush.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsCard(title: "Reminders") {
                    // Minutes, as steppers rather than free text: these are intervals with a
                    // sensible range, and a text field invites "0.5" and "45 min" which then
                    // have to be parsed and rejected.
                    MinuteRow(
                        title: "Stretch break",
                        description: "The character stretches, so you have something to copy.",
                        minutes: $userData.companionStretchMinutes,
                        onChange: { userData.save() }
                    )
                    MinuteRow(
                        title: "Drink water",
                        description: "A short reminder and the selected companion’s cue.",
                        minutes: $userData.companionWaterMinutes,
                        onChange: { userData.save() }
                    )
                    MinuteRow(
                        title: "Pomodoro — focus",
                        description: "Set to 0 to turn the timer off. The character tells you at each switch.",
                        minutes: $userData.companionPomodoroFocusMinutes,
                        onChange: { userData.save() }
                    )
                    if userData.companionPomodoroFocusMinutes > 0 {
                        MinuteRow(
                            title: "Pomodoro — break",
                            description: nil,
                            minutes: $userData.companionPomodoroBreakMinutes,
                            onChange: { userData.save() }
                        )
                    }

                    VStack(alignment: .leading, spacing: Space.x2) {
                        Text("Pinned note").typo(.body)
                        GlassTextField(
                            placeholder: "Stays above its head",
                            text: $userData.companionPinnedMessage
                        )
                        .onChange(of: userData.companionPinnedMessage) { _ in userData.save() }
                        Text("Shown until you clear it. Keep it short — it sits in a single line beside a small character.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsCard(title: "Relationship memory") {
                    SettingsToggle(
                        title: "Remember reminder timing",
                        description: "Stored only on this Mac. When you choose Not Now, that reminder waits five minutes longer next time, up to 30 minutes. Completing a reminder records the hour you usually respond.",
                        isOn: $userData.companionMemoryEnabled
                    )
                    .onChange(of: userData.companionMemoryEnabled) { _ in userData.save() }

                    if userData.companionMemoryEnabled {
                        memoryLine(title: "Stretch", key: "stretch")
                        memoryLine(title: "Water", key: "water")
                        Button("Forget learned timing", role: .destructive) {
                            userData.forgetCompanionMemory()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingsCard(title: "Daily goals") {
                    SettingsToggle(
                        title: "Celebrate small goals",
                        description: "Hydration, stretching, completed focus blocks, and dictated words reset each day. The cat celebrates only when a target is reached.",
                        isOn: $userData.companionGoalsEnabled
                    )
                    .onChange(of: userData.companionGoalsEnabled) { _ in userData.save() }

                    if userData.companionGoalsEnabled {
                        GoalRow(
                            title: "Hydration",
                            progress: userData.companionProgress.hydration,
                            unit: "breaks",
                            target: $userData.companionHydrationGoal,
                            range: 0...20,
                            step: 1,
                            onChange: { userData.save() }
                        )
                        GoalRow(
                            title: "Stretching",
                            progress: userData.companionProgress.stretches,
                            unit: "breaks",
                            target: $userData.companionStretchGoal,
                            range: 0...20,
                            step: 1,
                            onChange: { userData.save() }
                        )
                        GoalRow(
                            title: "Focus",
                            progress: userData.companionProgress.focusBlocks,
                            unit: "blocks",
                            target: $userData.companionFocusGoal,
                            range: 0...20,
                            step: 1,
                            onChange: { userData.save() }
                        )
                        GoalRow(
                            title: "Dictation",
                            progress: userData.companionProgress.dictationWords,
                            unit: "words",
                            target: $userData.companionDictationGoal,
                            range: 0...10_000,
                            step: 100,
                            onChange: { userData.save() }
                        )
                    }
                }

                SettingsCard(title: "Quiet mode") {
                    SettingsToggle(
                        title: "Quiet mode now",
                        description: "The companion curls up, stops wandering and playing, and suppresses its reminder bubble until you turn this off.",
                        isOn: $userData.companionQuietMode
                    )
                    .onChange(of: userData.companionQuietMode) { _ in userData.save() }

                    SettingsToggle(
                        title: "Automatic quiet mode",
                        description: "Sleeps during full-screen presentations, Utter meeting capture, and detected screen-sharing or slideshow helpers. macOS does not expose the active Focus mode through a public Mac API, so use Quiet mode now for Focus.",
                        isOn: $userData.companionAutomaticQuietMode
                    )
                    .onChange(of: userData.companionAutomaticQuietMode) { _ in userData.save() }
                }
            }

            SettingsCard(title: "Character") {
                if packStore.packs.isEmpty {
                    // Not an empty picker. Every character is a sprite pack now, so
                    // with none installed the companion cannot be shown at all,
                    // whatever the toggle says — and this pane is the only place the
                    // user can find that out or fix it. Broken packs are named
                    // separately, below.
                    HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Tint.warning)
                        Text("No characters are installed, so the companion cannot appear. Utter ships characters inside the app; if none are listed here, add a folder of animated PNGs below and press Rescan.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    CompanionCharacterGrid()
                        // Choosing a character while the companion is off would have no
                        // visible effect, so the grid dims to say so rather than
                        // silently doing nothing.
                        .opacity(userData.companionEnabled ? 1 : 0.5)
                        .disabled(!userData.companionEnabled)
                }
            }

            SettingsCard(title: "Your own characters") {
                VStack(alignment: .leading, spacing: Space.x3) {
                    Text("Utter ships its own characters. To use art of your own, put a folder of animated PNGs in the Companions folder and it appears above.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)

                    if !packStore.failures.isEmpty {
                        // Named failures, not silence. Someone who has just
                        // hand-written a pack.json needs to know which line is
                        // wrong; "no packs found" would send them looking in the
                        // wrong place entirely.
                        ForEach(packStore.failures, id: \.id) { failure in
                            HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Tint.warning)
                                Text("\(failure.id): \(failure.reason)")
                                    .typo(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(spacing: Space.x2) {
                        GlassButton(title: "Open Companions Folder", size: .small) {
                            let directory = SpritePackStore.directory
                            try? FileManager.default.createDirectory(
                                at: directory, withIntermediateDirectories: true
                            )
                            NSWorkspace.shared.open(directory)
                        }

                        GlassButton(title: "Rescan", size: .small) {
                            // `force`, because this button's whole purpose is "I just
                            // changed my art". Editing a frame in place leaves the
                            // folder dates alone, so the plain `reload()` the pane
                            // does on appear would correctly decide nothing changed
                            // and the button would do nothing at all.
                            packStore.reload(force: true)
                        }
                    }

                    DisclosureGroup("Pack format") {
                        Text(formatHelp)
                            .typo(.mono, ink: Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.x2)
                    }
                    .typo(.caption)
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.pageInset)
        }
        .onAppear {
            packStore.reload()
            // Correct a selection that names a pack which is not there — a folder the
            // user deleted, or one of the code-drawn characters Utter used to ship.
            // Done here as well as when the companion first appears, because this pane
            // can be opened before the companion has ever been switched on, and the
            // grid would otherwise show nothing selected.
            userData.resolveCompanionCharacter(
                against: packStore.packs.map(\.id)
            )
            if !userData.companionObjectUnlocked(userData.companionObject) {
                userData.companionObject = .none
                userData.save()
            }
            // Without this the Accessibility row above shows whatever `axGranted` last
            // happened to be — which at launch is `false` — so a user who HAS granted it
            // would be told their typing reactions are broken. Polling is reference-counted,
            // so starting it here is safe alongside the other panes that do.
            readiness.startPolling()
        }
        .onDisappear { readiness.stopPolling() }
    }

    /// The pack format, stated exactly once. Kept in the UI rather than a README
    /// because this is where someone stands when they need it.
    ///
    /// APNG leads because it is the right answer: one file per state, full 8-bit
    /// alpha, and its own per-frame timing. The GIF warning is here rather than
    /// buried in a doc comment because "backgroundless GIF" is the obvious thing to
    /// reach for and it looks wrong for a reason nobody guesses.
    ///
    /// The sizes are interpolated from the renderer's own numbers rather than typed
    /// in. This text said "shows at 28pt" after `characterSize` had been raised to
    /// 44 — advice for the wrong target, in the one place a pack author looks for it.
    ///
    /// Computed rather than a `static let` for the same reason: the size is a preference
    /// now, so a value captured once would be stale the moment it changed — and this view
    /// observes `userData`, so it re-reads.
    private var formatHelp: String {
        let characterSize = userData.companionSize.points
        return """
    Best: one animated PNG (APNG) per state. No pack.json needed.

    Companions/my-character/
      resting.png     alert.png       thinking.png
      delighted.png   startled.png    sleepy.png

    Or numbered frames in a folder per state:

    Companions/my-character/
      resting/01.png 02.png 03.png
      alert/01.png 02.png

    Only "resting" is required; every other state falls back to it.
    Draw each frame centred on transparency. The character shows at
    \(Int(characterSize))pt at this size, so frames are kept at up to \
    \(Int(SpritePackStore.maxFrameSide(for: characterSize)))px on their
    longest edge and anything larger is scaled down on load — it would
    cost memory and change nothing on screen. Draw for the largest size
    you might pick: at Huge that bound is \
    \(Int(SpritePackStore.maxFrameSide(for: CompanionSize.huge.points)))px.

    Set a rate per state in pack.json if the art needs one:
      { "animation": { "sleepy": { "fps": 5 } } }

    States: resting (idle) · alert (mic live) · thinking (working)
            delighted (done) · startled (error) · sleepy (long idle)

    Avoid GIF. Its transparency is 1-bit, so soft edges become
    jagged and drop shadows turn into hard blocks. APNG is a PNG,
    so it keeps real transparency, and it stores the timing you
    drew it with.
    """
    }

    private var availableObjects: [CompanionObject] {
        CompanionObject.allCases
    }

    @ViewBuilder
    private func memoryLine(title: String, key: String) -> some View {
        let dismissed = userData.companionProgress.dismissed[key, default: 0]
        let delay = userData.companionProgress.extraDelayMinutes[key, default: 0]
        let hour = userData.companionProgress.preferredHours[key]
        HStack {
            Text(title).typo(.body)
            Spacer()
            Text(memorySummary(dismissed: dismissed, delay: delay, hour: hour))
                .typo(.caption)
                .monospacedDigit()
        }
    }

    private func memorySummary(dismissed: Int, delay: Int, hour: Int?) -> String {
        var parts = ["\(dismissed) dismissed", "+\(delay) min"]
        if let hour {
            let date = Calendar.current.date(
                from: DateComponents(hour: hour)
            ) ?? Date()
            parts.append(date.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Character grid

private struct CompanionObjectPicker: View {
    let options: [CompanionObject]
    @Binding var selection: CompanionObject
    @ObservedObject private var userData = UserData.shared

    var body: some View {
        HStack(spacing: Space.x2) {
            ForEach(options) { object in
                CompanionObjectChoice(
                    object: object,
                    isSelected: selection == object,
                    isUnlocked: userData.companionObjectUnlocked(object),
                    action: { selection = object }
                )
            }
        }
        .frame(maxWidth: 720)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive object")
    }
}

private struct CompanionObjectChoice: View {
    let object: CompanionObject
    let isSelected: Bool
    let isUnlocked: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(object.label, systemImage: isUnlocked ? object.systemImage : "lock.fill")
                .frame(maxWidth: .infinity)
                .lineLimit(1)
        }
        .controlSize(.large)
        .disabled(!isUnlocked)
        .accessibilityHint(
            isUnlocked ? "Select \(object.label)"
                : "\(object.reward?.wordRequirement.formatted() ?? "More") dictated words required"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The character picker. Every tile shows the pack's own first resting frame, so the
/// control previews the thing it selects.
///
/// A still frame, not the animation: the tile is a picker, not a stage, and several
/// characters looping at once in a settings pane is noise. The real one is already on
/// the desktop.
/// One reminder interval, in minutes, with 0 meaning off.
///
/// A native `Stepper` rather than a design-system control, because the design system has
/// no numeric input and this is exactly what the platform's stepper is for. It also brings
/// keyboard and accessibility behaviour that a pair of custom buttons would have to
/// reimplement.
///
/// Steps of 5 with a 5-minute floor above zero: a reminder interval is not a value anyone
/// needs to the minute, and 1-minute granularity turns a 45-minute setting into nine clicks.
private struct MinuteRow: View {
    let title: String
    let description: String?
    @Binding var minutes: Int
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack {
                Text(title).typo(.body)
                Spacer()
                Text(minutes == 0 ? "Off" : "\(minutes) min")
                    .typo(.caption)
                    // Monospaced digits so the row does not shift as the number changes
                    // width — 5 to 10 minutes is a one-character jump that reads as a jolt.
                    .monospacedDigit()
                    .foregroundStyle(minutes == 0 ? Ink.secondary : Ink.primary)
                Stepper(title, value: $minutes, in: 0...480, step: 5)
                    .labelsHidden()
                    .onChange(of: minutes) { _ in onChange() }
            }
            if let description {
                Text(description)
                    .typo(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GoalRow: View {
    let title: String
    let progress: Int
    let unit: String
    @Binding var target: Int
    let range: ClosedRange<Int>
    let step: Int
    let onChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(title).typo(.body)
                Text(target == 0 ? "Off" : "\(progress) of \(target) \(unit)")
                    .typo(.caption)
                    .monospacedDigit()
            }
            Spacer()
            Stepper(title, value: $target, in: range, step: step)
                .labelsHidden()
                .onChange(of: target) { _ in onChange() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(target == 0 ? "off" : "\(progress) of \(target) \(unit)")")
    }
}

private struct CompanionCharacterGrid: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var packStore = SpritePackStore.shared
    /// Live Accessibility state. The typing reactions are inert without it — see the row below.
    @ObservedObject private var readiness = ReadinessMonitor.shared
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        // No `GlassCluster` around the grid.
        //
        // `CharacterTile` draws a `Surface.fillSubtle` rectangle and a stroke — see its
        // body below — so there was no `glassEffect` anywhere in this subtree for a
        // `GlassEffectContainer` to batch into one pass.
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(minimum: 0), spacing: Space.x3),
                count: 4
            ),
            alignment: .leading,
            spacing: Space.x3
        ) {
            ForEach(packStore.packs) { pack in
                CharacterTile(
                    name: pack.name,
                    blurb: pack.author.isEmpty ? "Installed pack" : "by \(pack.author)",
                    isSelected: userData.companionCharacter == pack.id
                ) {
                    select(pack.id)
                } preview: {
                    if let style = CodePixelCatStyle(rawValue: pack.id) {
                        CodePixelCatView(
                            style: style,
                            mood: .resting,
                            pose: .neutral,
                            size: 32,
                            elapsed: 1
                        )
                        .frame(width: 34, height: 34)
                    } else if let frame = pack.frames(for: .resting).first {
                        Image(nsImage: frame)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "questionmark.square.dashed")
                            .font(.system(size: 20))
                            .foregroundStyle(Ink.secondary)
                            .frame(width: 34, height: 34)
                    }
                }
            }
        }
    }

    private func select(_ id: String) {
        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
            userData.companionCharacter = id
        }
        userData.save()
    }
}

private struct CharacterTile<Preview: View>: View {
    let name: String
    let blurb: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.x2) {
                ZStack {
                    // Hover moves the FILL, not the stroke.
                    //
                    // It used to move only the stroke, hairline -> strong. Measured on this
                    // app's light canvases that is a 1.070:1 change on a 1pt border: hairline
                    // is `hairlineInk` at 13% (a dark brown) and strong is `Color.primary` at
                    // 14% (black), so the hover signal was a 0.01 alpha difference on one pixel
                    // of edge. Imperceptible, and in both appearances — the tile simply did not
                    // respond to the pointer.
                    //
                    // fillSubtle -> fillHover measures 1.147:1 and covers the whole 52pt well,
                    // so the signal is large-area rather than hairline-thin. The stroke still
                    // firms up as a second, quieter cue.
                    Radius.rect(Radius.control)
                        .fill(isHovering ? Surface.fillHover : Surface.fillSubtle)
                    preview()
                }
                .frame(height: 52)
                .overlay(
                    Radius.rect(Radius.control).strokeBorder(
                        isSelected ? Tint.accent : (isHovering ? Line.hairlineHover : Line.hairline),
                        lineWidth: isSelected ? 2 : Line.width
                    )
                )

                Text(name)
                    .typo(.caption, ink: isSelected ? Ink.primary : Ink.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        .help(blurb)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel("\(name) companion. \(blurb)")
    }
}
