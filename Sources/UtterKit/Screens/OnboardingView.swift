import SwiftUI
import AVFoundation
import ApplicationServices
import Combine

/// First-run onboarding: a short guided flow that walks the user through the two
/// permissions Utter needs (Microphone + Accessibility) and confirms the on-device
/// speech model is ready, so the app actually works the first time it's launched.
///
/// Shown once, gated by the `hasCompletedOnboarding` flag in UserDefaults. The user
/// can re-open it any time, but it won't auto-present again after completion.
///
/// An unfinished run is resumable: the current step is written to UserDefaults on
/// every move, so quitting part-way — which the Screen Recording step obliges the
@MainActor
final class OnboardingViewModel: ObservableObject {
    static let totalSteps = 7

    @Published var step = OnboardingState.resumeStep(stepCount: OnboardingViewModel.totalSteps)
    @Published var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published var axGranted = AXIsProcessTrusted()
    @Published var modelReady = LocalWhisperProvider.modelURL() != nil
    @Published var screenGranted = SystemAudioCapture.permissionState() == .granted
    @Published var wantsCompanion = UserData.shared.companionEnabled
    @Published var sampleTestText: String = ""

    func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        axGranted = AXIsProcessTrusted()
        modelReady = LocalWhisperProvider.modelURL() != nil
        screenGranted = SystemAudioCapture.permissionState() == .granted
    }

    func requestMic() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.micGranted = granted
                }
            }
        case .denied, .restricted:
            openSettings("Privacy_Microphone")
        default:
            micGranted = true
        }
    }

    func requestScreenRecording() {
        _ = SystemAudioCapture.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibility() {
        AccessibilityPermission.openSettingsPane()
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The first-launch walkthrough: permissions, model verification, and key assignment.
struct OnboardingView: View {
    var onFinish: (_ skipped: Bool) -> Void

    @StateObject private var model = OnboardingViewModel()
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared

    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots & Account State Chip
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<OnboardingViewModel.totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == model.step ? Tint.accent : Color.primary.opacity(0.15))
                            .frame(width: i == model.step ? 20 : 7, height: 7)
                            .animation(motion.reduceMotion ? Motion.reduced : Motion.layout,
                                       value: model.step)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(model.step + 1) of \(OnboardingViewModel.totalSteps)")

                Spacer()

                // Account status chip
                HStack(spacing: 4) {
                    Image(systemName: userData.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle.badge.checkmark")
                        .font(.system(size: 11))
                        .foregroundStyle(Tint.accent)
                    Text(userData.isAuthenticated ? (userData.userDisplayName.isEmpty ? userData.userEmail : userData.userDisplayName) : "Guest (Offline)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
            }
            .padding(.horizontal, Space.x5)
            .padding(.top, 18)

            GeometryReader { proxy in
                ScrollView {
                    stepContent
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                        .padding(.vertical, Space.x3)
                }
            }

            // Nav buttons
            HStack {
                if model.step > 0 {
                    GlassButton(title: "Back") {
                        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                            model.step -= 1
                        }
                    }
                }

                if model.step < OnboardingViewModel.totalSteps - 1 {
                    GlassButton(title: "Skip") { finish(skipped: true) }
                }

                Spacer()
                GlassButton(
                    title: model.step == OnboardingViewModel.totalSteps - 1 ? "Get started" : "Continue",
                    prominent: true
                ) {
                    if model.step < OnboardingViewModel.totalSteps - 1 {
                        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                            model.step += 1
                        }
                    } else {
                        finish(skipped: false)
                    }
                }
                .disabled(!canAdvance)
                .keyboardShortcut(.defaultAction)
            }
            .padding(Space.x5)
        }
        .frame(minWidth: Layout.onboardingMinWidth,
               idealWidth: Layout.onboardingIdealWidth,
               maxWidth: .infinity,
               minHeight: Layout.onboardingMinHeight,
               idealHeight: Layout.onboardingIdealHeight,
               maxHeight: .infinity)
        .background(OnboardingBacking())
        .onReceive(poll) { _ in
            model.refresh()
        }
        .onChange(of: model.step) { value in OnboardingState.recordStep(value) }
    }

    private var canAdvance: Bool {
        OnboardingState.canAdvance(
            step: model.step,
            microphoneGranted: model.micGranted,
            accessibilityGranted: model.axGranted,
            modelReady: model.modelReady
        )
    }

    // MARK: - Steps

    private var stepContent: some View {
        Group {
            switch model.step {
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
        .transition(
            motion.reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                  )
        )
        .id(model.step)
    }

    private var welcomeStep: some View {
        VStack(spacing: Space.groupGap) {
            VStack(spacing: Space.x2) {
                AppIconView(size: 64)
                Text("Welcome to Utter").typo(.title)
            }

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
            granted: model.micGranted,
            grantedLabel: "Microphone access granted",
            actionLabel: "Grant Microphone Access",
            action: { model.requestMic() }
        )
    }

    private var axStep: some View {
        PermissionStep(
            icon: "accessibility",
            iconColor: Tint.accent,
            title: "Accessibility access",
            message: "Utter needs Accessibility access to type the transcribed text into whatever app you’re using, and to detect your hotkey. Toggle Utter on in the window that opens.",
            granted: model.axGranted,
            grantedLabel: "Accessibility access granted",
            actionLabel: "Open Accessibility Settings",
            action: { model.requestAccessibility() }
        )
    }

    private var modelStep: some View {
        ModelChooserView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.x2)
    }

    private var meetingsStep: some View {
        PermissionStep(
            icon: "person.wave.2.fill",
            iconColor: Tint.accent,
            title: "Meetings — optional",
            message: "To transcribe a meeting Utter needs Screen Recording, which is how macOS lets an app hear other participants. It captures audio only, never the screen, and only while you are recording a meeting. Skip this and everything else still works.",
            granted: model.screenGranted,
            grantedLabel: "Screen Recording granted",
            actionLabel: "Open Screen Recording Settings",
            action: { model.requestScreenRecording() }
        )
    }

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
                    HStack(spacing: Space.x4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Tint.accent.opacity(0.2), Color.purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 56, height: 56)

                            Image(systemName: model.wantsCompanion ? "cat.fill" : "moon.zzz.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Tint.accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.wantsCompanion ? "Pixel Pet: Active" : "Pixel Pet: Resting")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Ink.primary)
                            Text("Watches cursor, kneads paws during typing, and cheers your dictations.")
                                .font(.caption2)
                                .foregroundStyle(Ink.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    GlassToggle(
                        title: "Show a companion",
                        description: "You can change this any time, and pick from multiple characters.",
                        isOn: $model.wantsCompanion
                    )
                    .onChange(of: model.wantsCompanion) { value in
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
                Image(systemName: model.modelReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(model.modelReady ? Tint.successText : Tint.warningText)
                Text(model.modelReady ? "You\u{2019}re all set" : "Speech model missing")
                    .typo(.title)
            }

            BentoTile(title: "Ready to use", systemImage: "checklist") {
                VStack(alignment: .leading, spacing: Space.x2) {
                    ReadinessRow(label: "Microphone", ok: model.micGranted)
                    ReadinessRow(label: "Accessibility", ok: model.axGranted)
                    ReadinessRow(label: "Speech model", ok: model.modelReady)
                    ReadinessRow(label: "Screen Recording",
                                 ok: model.screenGranted,
                                 pendingText: "Optional \u{2014} for meetings")
                }
            }

            // Live Dictation Test Bar Playground
            BentoTile(title: "Test Dictation", systemImage: "waveform", tint: Color.purple) {
                VStack(alignment: .leading, spacing: Space.x2) {
                    Text("Try holding \(UserData.shared.hotkeyName) and speaking now:")
                        .font(.caption)
                        .foregroundStyle(Ink.secondary)

                    HStack(spacing: Space.x2) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Tint.accent)
                        TextField("Transcribed text appears here as you speak…", text: $model.sampleTestText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                    .padding(Space.x3)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Text(model.modelReady
                 ? "Hold \(UserData.shared.hotkeyName) anywhere and start dictating."
                 : "The bundled speech model couldn\u{2019}t be found. Reinstalling Utter should restore it.")
                .typo(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func finish(skipped: Bool) {
        OnboardingState.markCompleted()
        onFinish(skipped)
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
                    HStack(spacing: Space.x2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Tint.success)
                            .scaleEffect(1.05)
                        Text(grantedLabel)
                            .typo(.caption, ink: Tint.successText)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Tint.success.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    GlassButton(title: actionLabel, prominent: true, action: action)
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

    static func canAdvance(
        step: Int,
        microphoneGranted: Bool,
        accessibilityGranted: Bool,
        modelReady: Bool
    ) -> Bool {
        switch step {
        case 1: return microphoneGranted
        case 2: return accessibilityGranted
        case 3: return modelReady
        default: return true
        }
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

/// One readiness row on the final onboarding step: what it is, and whether it's ready.
///
/// `LabeledContent` — the system's label/value row, `@available(macOS 13.0)`, so no
/// availability branch at this target. It replaces a hand-built `HStack` carrying a
/// `Circle().frame(width: 7, height: 7)` and a manually composed
/// `accessibilityElement(children: .combine)` + `accessibilityLabel("\(label): ready")`.
/// The system now supplies the label/value pairing VoiceOver reads, the alignment
/// between the four rows, and the trailing-value layout — including under a large
/// system text size, where the hand-built version simply grew wider.
///
/// The status is a `Label`, not a bare colour, so the state is legible without relying
/// on hue: a dot at `Tint.warning` on cream measures 1.48:1 (the figure recorded on the
/// step's own header glyph), and colour alone fails the same test for anyone who cannot
/// separate the two hues. The word "Ready" carries the meaning; the tint only reinforces
/// it, and uses the `*Text` variants that were measured against these tiles.
///
/// `Ink.secondary` for the label, not `.secondary`: `secondaryLabelColor` is calibrated
/// against an opaque control background and measures **4.01:1** on this app's
/// translucent tiles (see `Ink.secondary`'s own note) — under the 4.5:1 floor, and this
/// row sits inside a `BentoTile`.
private struct ReadinessRow: View {
    let label: String
    let ok: Bool
    /// What to say when it isn't ready. Overridden for Screen Recording, which is
    /// optional — "Needs attention" would be wrong for a feature the user may never use.
    var pendingText: String = "Needs attention"

    var body: some View {
        LabeledContent(label) {
            Label(ok ? "Ready" : pendingText,
                  systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .labelStyle(.titleAndIcon)
                .typo(.caption, ink: ok ? Tint.successText : Tint.warningText)
        }
        .typo(.caption, ink: Ink.secondary)
    }
}


/// The onboarding window's surface.
///
/// Matches `FlowContent.windowSurface` rather than inventing its own — this
/// is the very first screen, and having it read as a different app's window was
/// the most visible inconsistency in the app.
struct OnboardingBacking: View {
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
