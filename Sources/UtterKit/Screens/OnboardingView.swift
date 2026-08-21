import SwiftUI
import AVFoundation
import ApplicationServices

/// First-run onboarding: a short guided flow that walks the user through the two
/// permissions Utter needs (Microphone + Accessibility) and confirms the on-device
/// speech model is ready, so the app actually works the first time it's launched.
///
/// Shown once, gated by the `hasCompletedOnboarding` flag in UserDefaults. The user
/// can re-open it any time, but it won't auto-present again after completion.
///
/// An unfinished run is resumable: the current step is written to UserDefaults on
/// every move, so quitting part-way — which the Screen Recording step obliges the
/// user to do — reopens where they were rather than at the welcome screen.
struct OnboardingView: View {
    /// Called when the user finishes or skips onboarding.
    var onFinish: () -> Void

    /// Where the flow opens, restored from the last unfinished run.
    ///
    /// Granting Screen Recording *requires* macOS to relaunch the app, so an
    /// interrupted first run is the main path here, not an edge case: this used to be
    /// a plain `0`, and the relaunch after the meetings step sent the user back to
    /// the welcome screen to redo microphone, accessibility and the model choice.
    /// `OnboardingState` owns the clamping — see `resumeStep`.
    @State private var step = OnboardingState.resumeStep(stepCount: OnboardingView.totalSteps)
    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var axGranted = AXIsProcessTrusted()
    @State private var modelReady = LocalWhisperProvider.modelURL() != nil
    @State private var screenGranted = SystemAudioCapture.permissionState() == .granted
    /// Companion opt-in, asked once here rather than left to be discovered.
    @State private var wantsCompanion = UserData.shared.companionEnabled

    // Re-checks permission state on a timer while the window is open, so the UI
    // updates as soon as the user grants access in System Settings.
    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @ObservedObject private var motion = MotionPreference.shared

    /// `static` so the initial value of `step` can be resolved against it — a stored
    /// property's default expression cannot reach an instance member.
    private static let totalSteps = 7

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            //
            // These were the inconsistency inside this one file: `stepContent` below
            // already branches its transition on `motion.reduceMotion` (:145-152), and
            // the dots — which grow from 7pt to 20pt as the selection moves — did not.
            // So with Reduce Motion on, the content correctly crossfaded while the
            // indicator above it kept animating its width.
            HStack(spacing: 6) {
                ForEach(0..<Self.totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Tint.accent : Color.primary.opacity(0.15))
                        .frame(width: i == step ? 20 : 7, height: 7)
                        .animation(motion.reduceMotion ? Motion.reduced : Motion.layout,
                                   value: step)
                }
            }
            // Decorative: the step is already announced by the content, and seven
            // unlabelled capsules in the rotor are seven things to skip.
            .accessibilityHidden(true)
            .padding(.top, 22)

            // Centred when the step fits, scrollable when it doesn't.
            //
            // The window opens at 620×600, where the tallest step (welcome, with the
            // live pill demo) comes to roughly 491pt of the ~501pt available. That
            // fits at the default text size and not much above it: previously the
            // step content simply overflowed, pushing the nav row below the window
            // edge, so at a larger system text size "Continue" was reachable only
            // through its keyboard shortcut. The spacers live *inside* the scroll
            // content, and `minHeight` matches the space available, so the layout is
            // pixel-identical while it fits and starts scrolling exactly when it
            // stops fitting — at whatever size the window currently is, since the
            // proxy measures the space actually given rather than a fixed 600.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        stepContent
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }

            // Nav buttons
            //
            // This row is the closest thing this window has to a chrome layer: it
            // persists across all seven steps while everything above it changes, it
            // carries the flow's primary control, and it sits flush to the window's
            // bottom edge. It was the obvious candidate for a Liquid Glass bar when the
            // Settings column got one. It does not get one, for a reason that is a fact
            // about this code rather than a taste call:
            //
            // **The glass here is already the buttons.** `GlassButtonLook` resolves
            // `GlassButton` to `.buttonStyle(.glassProminent)` on macOS 26 (and to
            // `.glass` for the permission buttons on every step above), so "Continue"
            // is a real Liquid Glass control today. A glass band behind it would stack
            // a second glass layer under a glass button — the glass-on-glass the HIG
            // rules out, and the same trap `FlowSidebar.navRows` avoids by keeping its
            // sidebar rows on flat fills. Given a choice between glass on a *standard*
            // component, whose accessibility adaptation Apple actually promises, and
            // glass on a custom band, the standard component wins.
            //
            // The full Apple pattern for a bottom bar over scrolling content is
            // `safeAreaBar(edge: .bottom)` — it exists at macOS 26.0, and unlike
            // `safeAreaInset` it insets the safe area so the bar gets scroll-edge
            // treatment and content passes under it — with the buttons regrouped in a
            // `GlassEffectContainer` so they merge *into* the bar instead of sitting on
            // it. That is a real upgrade and it is deliberately not taken here: this row
            // is a sibling in the `VStack`, and the `GeometryReader` above hands the
            // `ScrollView` exactly the height between the dots and this row
            // (`minHeight: proxy.size.height`). Insetting the safe area would leave that
            // measurement too tall by the bar's height, so the content would always
            // overflow by that much and never centre — reopening the scar recorded above
            // it, where "Continue" was reachable only by keyboard shortcut. Take it when
            // the arithmetic is reworked to subtract the inset, not before.
            HStack {
                Button("Skip") { finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Ink.secondary)
                Spacer()
                GlassButton(
                    title: step == Self.totalSteps - 1 ? "Get started" : "Continue",
                    prominent: true
                ) {
                    if step < Self.totalSteps - 1 {
                        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                            step += 1
                        }
                    } else {
                        finish()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(Space.x5)
        }
        // A minimum and an ideal, not a fixed size. This was `.frame(width: 620,
        // height: 600)`: with the window now `.resizable`, a fixed frame would have
        // ignored every size it was given and left a resizable window whose content
        // never moved. The minimum matches the window's `contentMinSize`, so the view
        // is never asked to lay out smaller than it can.
        .frame(minWidth: Layout.onboardingMinWidth,
               idealWidth: Layout.onboardingIdealWidth,
               maxWidth: .infinity,
               minHeight: Layout.onboardingMinHeight,
               idealHeight: Layout.onboardingIdealHeight,
               maxHeight: .infinity)
        // Same shell as the main window: translucent material plus a warm veil,
        // so the first screen a user sees is the same material as the rest.
        .background(OnboardingBacking())
        .onReceive(poll) { _ in
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            axGranted = AXIsProcessTrusted()
            screenGranted = SystemAudioCapture.permissionState() == .granted
        }
        // Drop an anchor on every move, forwards or back, so a relaunch reopens the
        // step the user was actually looking at.
        .onChange(of: step) { value in OnboardingState.recordStep(value) }
    }

    // MARK: - Steps

    /// The current step, with the shared padding and transition.
    private var stepContent: some View {
        Group {
            switch step {
            case 0: welcomeStep
            case 1: micStep
            case 2: axStep
            case 3: modelStep
            case 4: meetingsStep
            case 5: companionStep
            default: readyStep
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.x10)
        // Steps slide sideways as you advance, and fade under Reduce Motion.
        // Previously only the progress dots moved, so the content itself
        // changed as a hard cut.
        .transition(
            motion.reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                  )
        )
        .id(step)
    }

    private var welcomeStep: some View {
        VStack(spacing: Space.groupGap) {
            VStack(spacing: Space.x2) {
                AppIconView(size: 64)
                Text("Welcome to Utter").typo(.title)
            }

            // Show the pill rather than describing it.
            //
            // This tile used to be prose — "hold your hotkey anywhere and your words
            // are typed into whatever app you're using" — sitting beside a real pill
            // that was already on screen, unexplained. `PillDemoView` renders the
            // actual pill view through its real states, so the first thing a new
            // user sees is the thing itself doing the thing.
            BentoTile(title: "How it works", systemImage: "mic") {
                PillDemoView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.x2)
            }

            BentoTile(title: "Private by design", systemImage: "lock.shield") {
                Text("Speech recognition runs on this Mac. No account, no internet, "
                     + "and nothing is uploaded.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Two quick permissions, then choose a speech model.")
                .typo(.caption)
        }
    }

    private var micStep: some View {
        PermissionStep(
            icon: "mic.fill",
            iconColor: Tint.recording,
            title: "Microphone access",
            message: "Utter records your voice only while you hold the hotkey, and transcribes it on this Mac. Your audio never leaves the device, and nothing is recorded otherwise.",
            granted: micGranted,
            grantedLabel: "Microphone access granted",
            actionLabel: "Grant Microphone Access",
            action: requestMic
        )
    }

    private var axStep: some View {
        PermissionStep(
            icon: "accessibility",
            iconColor: Tint.accent,
            title: "Accessibility access",
            message: "Utter needs Accessibility access to type the transcribed text into whatever app you’re using, and to detect your hotkey. Toggle Utter on in the window that opens.",
            granted: axGranted,
            grantedLabel: "Accessibility access granted",
            actionLabel: "Open Accessibility Settings",
            action: requestAccessibility
        )
    }

    /// No `ScrollView` of its own: the step container is now scrollable, and nesting
    /// a second scroll view inside it gives two competing scrollers over the same
    /// gesture — the inner one swallows the wheel and the outer never moves.
    private var modelStep: some View {
        ModelChooserView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.x2)
    }

    /// Screen Recording, framed as optional because it is.
    ///
    /// Asked here rather than on first use so the user meets it in context, with an
    /// explanation, instead of a bare system prompt appearing the moment they try to
    /// record a meeting. Skipping costs them nothing but that one feature.
    private var meetingsStep: some View {
        PermissionStep(
            icon: "person.wave.2.fill",
            iconColor: Tint.accent,
            title: "Meetings — optional",
            message: "To transcribe a meeting Utter needs Screen Recording, which is how macOS lets an app hear other participants. It captures audio only, never the screen, and only while you are recording a meeting. Skip this and everything else still works.",
            granted: screenGranted,
            grantedLabel: "Screen Recording granted",
            actionLabel: "Open Screen Recording Settings",
            action: requestScreenRecording
        )
    }

    /// The companion opt-in.
    ///
    /// Asked once, here, because a character that appears on the desktop unannounced
    /// is a surprise rather than a feature — and one buried in Settings would never
    /// be found. Off by default; this is the moment it gets offered.
    private var companionStep: some View {
        VStack(spacing: Space.groupGap) {
            VStack(spacing: Space.x2) {
                Image(systemName: "figure.wave")
                    .font(.system(size: 40))
                    .foregroundStyle(Tint.accent)
                Text("A desk companion?").typo(.title)
            }

            BentoTile(title: "Companion", systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: Space.x3) {
                    Text("A small animated character can sit beside the pill and react "
                         + "as you dictate. Purely for company — it changes nothing "
                         + "about how Utter works.")
                        .typo(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    GlassToggle(
                        title: "Show a companion",
                        description: "You can change this any time, and pick a character.",
                        isOn: $wantsCompanion
                    )
                    .onChange(of: wantsCompanion) { value in
                        UserData.shared.companionEnabled = value
                        UserData.shared.save()
                    }
                }
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: Space.groupGap) {
            VStack(spacing: Space.x2) {
                Image(systemName: modelReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    // Text variants — see the note in `AIStatusRow`. 40pt is large, but amber
                    // measured 1.48:1 on cream, which no point size rescues.
                    .foregroundStyle(modelReady ? Tint.successText : Tint.warningText)
                Text(modelReady ? "You\u{2019}re all set" : "Speech model missing")
                    .typo(.title)
            }

            BentoTile(title: "Ready to use", systemImage: "checklist") {
                VStack(alignment: .leading, spacing: Space.x2) {
                    ReadinessDot(ok: micGranted, label: "Microphone")
                    ReadinessDot(ok: axGranted, label: "Accessibility")
                    ReadinessDot(ok: modelReady, label: "Speech model")
                    // Optional, so its absence is not a failure — the label says so
                    // rather than showing a red dot for a feature the user may never
                    // use.
                    ReadinessDot(ok: screenGranted,
                                 label: screenGranted ? "Screen Recording (meetings)"
                                                      : "Screen Recording — optional, for meetings")
                }
            }

            Text(modelReady
                 ? "Hold \(UserData.shared.hotkeyName) anywhere and start dictating."
                 : "The bundled speech model couldn\u{2019}t be found. Reinstalling Utter should restore it.")
                .typo(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func requestMic() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { micGranted = granted }
            }
        case .denied, .restricted:
            // Already decided — send the user to System Settings to change it.
            openSettings("Privacy_Microphone")
        default:
            micGranted = true
        }
    }

    /// Trigger the system prompt, then send the user to the pane.
    ///
    /// `CGRequestScreenCaptureAccess` shows the prompt only once per app signature;
    /// after a denial macOS never asks again, so the Settings deep link is the only
    /// way back and is opened regardless.
    private func requestScreenRecording() {
        _ = SystemAudioCapture.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccessibility() {
        // Open the pane, and deliberately do NOT raise the system's own dialog.
        //
        // This used to do both. `AXIsProcessTrustedWithOptions([prompt: true])` puts up macOS's
        // "Utter would like to control this computer … Grant access in Privacy & Security
        // settings" modal — advice that is already obsolete by the time it appears, because the
        // next line opens exactly that pane. The modal then sits in front of the pane and covers
        // the switch the user came to flip. One ask, and it is this screen's.
        AccessibilityPermission.openSettingsPane()
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func finish() {
        OnboardingState.markCompleted()
        onFinish()
    }
}

// MARK: - Reusable permission step

private struct PermissionStep: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let granted: Bool
    let grantedLabel: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        BentoTile(title: title, systemImage: icon, tint: granted ? Tint.success : iconColor) {
            VStack(alignment: .leading, spacing: Space.x3) {
                Text(message)
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                if granted {
                    Label(grantedLabel, systemImage: "checkmark.circle.fill")
                        .typo(.caption, ink: Tint.successText)
                } else {
                    // `GlassButton`. This one call site is the primary action of four
                    // of the seven onboarding steps — microphone, accessibility,
                    // meetings — and it was a bare system `Button` sitting two views
                    // away from a `.glassProminent` "Continue" and a `.plain` "Skip".
                    // Three button styles on the first screen a user ever sees.
                    //
                    // Not `prominent`: "Continue" in the nav row is the prominent
                    // control, and the HIG allows one or two per view. Granting the
                    // permission and moving on are competing calls to action, so only
                    // one of them can look like one — and on an already-granted step
                    // the only thing to do is continue.
                    GlassButton(title: actionLabel, action: action)
                }
            }
        }
    }
}

// MARK: - Onboarding completion flag

/// Tracks whether the user has finished first-run onboarding, and how far an
/// unfinished run got.
///
/// Both facts live here rather than in the view so onboarding's persistence is one
/// type with one set of keys.
enum OnboardingState {
    private static let completedKey = "hasCompletedOnboarding"
    /// The step the user was last on. Cleared on completion — see `markCompleted`.
    private static let stepKey = "onboardingStep"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    /// Remember the step the user is on.
    static func recordStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: stepKey)
    }

    /// Which step an unfinished run should reopen on.
    static func resumeStep(stepCount: Int) -> Int {
        resumeStep(stored: UserDefaults.standard.integer(forKey: stepKey),
                   completed: hasCompleted,
                   stepCount: stepCount)
    }

    /// The resume rule, taking its inputs directly so it can be tested without
    /// writing to the user's defaults.
    ///
    /// Three decisions are encoded here:
    ///
    ///   * **The step they left, not the furthest they reached.** Going back is a
    ///     deliberate act — someone who returned to the microphone step to re-read it
    ///     and then quit wants that step again, not the one they had already moved
    ///     past.
    ///   * **Clamped into range.** A step stored by a build with more steps than this
    ///     one must not survive: `stepContent` falls through to the ready step for any
    ///     unknown index, but the nav row only finishes the flow at
    ///     `totalSteps - 1`, so an out-of-range step would show "Continue" on the
    ///     final screen and count upwards forever with no way out.
    ///   * **A completed run never resumes.** `markCompleted` clears the step, and
    ///     this check means that even a stored one cannot pull a deliberate re-open
    ///     into the middle of the flow.
    static func resumeStep(stored: Int, completed: Bool, stepCount: Int) -> Int {
        guard stepCount > 0, !completed else { return 0 }
        return min(max(stored, 0), stepCount - 1)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
        // Forget the anchor. Leaving it behind would drop anyone who later replays
        // onboarding — which means clearing `hasCompletedOnboarding` — straight back
        // into the middle of the flow they just finished.
        UserDefaults.standard.removeObject(forKey: stepKey)
    }
}

/// Single readiness indicator used by the final onboarding step.
private struct ReadinessDot: View {
    let ok: Bool
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ok ? Tint.success : Tint.warning)
                .frame(width: 7, height: 7)
            // `Ink.secondary`, not `.secondary`. `secondaryLabelColor` is calibrated
            // against an opaque control background and measured **4.01:1** on this
            // app's translucent tiles (`Ink.secondary`'s own note) — under the 4.5:1
            // floor, and this dot sits inside a `BentoTile`. `Typo.caption` at 12pt
            // also brings it back onto the scale, whose floor is 12.
            Text(label)
                .typo(.caption, ink: Ink.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(ok ? "ready" : "needs attention")")
    }
}


/// The onboarding window's surface.
///
/// Matches `FlowContent.windowSurface` rather than inventing its own — this
/// is the very first screen, and having it read as a different app's window was
/// the most visible inconsistency in the app.
private struct OnboardingBacking: View {
    @ObservedObject private var motion = MotionPreference.shared
    /// Observed although the body never names it: `Surface.canvas` resolves
    /// `ThemeManager.shared.current`, and without a dependency on the manager this
    /// body is not re-evaluated when the theme changes — so the window kept the
    /// previous theme's canvas whenever the two themes shared an appearance
    /// (Paper → Linen, or any of the four dark themes), where `colorScheme` alone
    /// does not change.
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if motion.reduceTransparency {
            Surface.canvas
        } else {
            ZStack {
                WindowBacking(material: .underWindowBackground).ignoresSafeArea()
                // Same values it already carried; the token is now where they live.
                Surface.canvas
                    .opacity(Veil.windowShell(isDark: colorScheme == .dark))
                    .ignoresSafeArea()
            }
        }
    }
}
