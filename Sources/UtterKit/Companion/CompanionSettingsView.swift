import SwiftUI
import AppKit

/// The Companion settings pane.
///
/// Three parts, in the order a user needs them: turn it on, size it, then choose who it
/// is. The character grid previews live characters rather than listing names, for the
/// same reason `ThemeSwatchGrid` does — the choice is a visual one, so a list of
/// words is the one representation that shows nothing about it.
struct CompanionSettingsContent: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var packStore = SpritePackStore.shared
    /// Live Accessibility state. The typing reactions are inert without it — see the row below.
    @ObservedObject private var readiness = ReadinessMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            SettingsCard(title: "Desktop companion") {
                GlassToggle(
                    title: "Show a companion",
                    description: "A small character that reacts while you dictate and wanders when idle. It appears beside the pill and can then be dragged anywhere.",
                    isOn: $userData.companionEnabled
                )
                .onChange(of: userData.companionEnabled) { _ in userData.save() }

                if userData.companionEnabled {
                    HairlineDivider()

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

                    HairlineDivider()
                    Text("Drag the character to move it. It has a place on screen of its own, so moving it leaves the pill where it is. Right-click it to put it back beside the pill or to hide it.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if userData.companionEnabled {
                SettingsCard(title: "Reactions") {
                    GlassToggle(
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
                        HairlineDivider()
                        GlassToggle(
                            title: "Cat sounds",
                            description: "A meow when you tap it, a purr while you stroke it, and a chirp when a reminder lands. Separate from the dictation sounds, so you can have one without the other.",
                            isOn: $userData.companionSounds
                        )
                        .onChange(of: userData.companionSounds) { _ in userData.save() }

                        HairlineDivider()
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

                        HairlineDivider()
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
                    HairlineDivider()
                    MinuteRow(
                        title: "Drink water",
                        description: "A short reminder and a meow.",
                        minutes: $userData.companionWaterMinutes,
                        onChange: { userData.save() }
                    )
                    HairlineDivider()
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

                    HairlineDivider()
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
        .onAppear {
            packStore.reload()
            // Correct a selection that names a pack which is not there — a folder the
            // user deleted, or one of the code-drawn characters Utter used to ship.
            // Done here as well as when the companion first appears, because this pane
            // can be opened before the companion has ever been switched on, and the
            // grid would otherwise show nothing selected.
            userData.resolveCompanionCharacter(against: packStore.packs.map(\.id))
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
}

// MARK: - Character grid

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
                    if let frame = pack.frames(for: .resting).first {
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
                    Radius.rect(Radius.control).fill(Surface.fillSubtle)
                    preview()
                }
                .frame(height: 52)
                .overlay(
                    Radius.rect(Radius.control).strokeBorder(
                        isSelected ? Tint.accent : (isHovering ? Line.strong : Line.hairline),
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
