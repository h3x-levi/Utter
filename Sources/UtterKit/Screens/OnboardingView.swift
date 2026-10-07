import SwiftUI
import AVFoundation
import ApplicationServices
import Combine

/// A short, resumable first-run flow: explain dictation, obtain required access,
/// choose an on-device speech model, then show the shortcut and a test field.
///
/// Shown once, gated by the `hasCompletedOnboarding` flag in UserDefaults. The user
/// can re-open it any time, but it won't auto-present again after completion.
///
/// An unfinished run is resumable: the current step is written to UserDefaults on
/// every move, so leaving to System Settings does not lose the user's place.
@MainActor
final class OnboardingViewModel: ObservableObject {
    static let totalSteps = 4

    @Published var step: Int
    @Published var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published var axGranted = AXIsProcessTrusted()
    @Published var modelReady = ModelStore.url(for: ModelStore.shared.active) != nil
    @Published var sampleTestText: String = ""

    init(stepOverride: Int? = nil) {
        step = stepOverride.map { min(max($0, 0), Self.totalSteps - 1) }
            ?? OnboardingState.resumeStep(stepCount: Self.totalSteps)
    }

    func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        axGranted = AXIsProcessTrusted()
        modelReady = ModelStore.url(for: ModelStore.shared.active) != nil
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

    func requestAccessibility() {
        AccessibilityPermission.openSettingsPane()
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The first-launch setup: purpose, permissions, model choice, and first capture.
struct OnboardingView: View {
    var onFinish: (_ skipped: Bool) -> Void

    @StateObject private var model: OnboardingViewModel
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared

    private let poll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init(onFinish: @escaping (_ skipped: Bool) -> Void, previewStep: Int? = nil) {
        self.onFinish = onFinish
        _model = StateObject(wrappedValue: OnboardingViewModel(stepOverride: previewStep))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Setup is local; show progress without account framing.
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
                    GlassButton(title: "Set up later") { finish(skipped: true) }
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
            case 1: accessStep
            case 2: modelStep
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
        VStack(alignment: .leading, spacing: Space.x5) {
            HStack(spacing: Space.x2) {
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Utter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
            }

            VStack(alignment: .leading, spacing: Space.x2) {
                Text("Speak. Keep your flow.")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Text("Hold a shortcut, say what you mean, then release. Utter types your words into the app you’re already using.")
                    .font(.system(size: 15))
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: Space.x4) {
                onboardingStep("Hold", detail: "Your shortcut", symbol: "keyboard")
                onboardingStep("Speak", detail: "Naturally", symbol: "mic")
                onboardingStep("Type", detail: "Text appears", symbol: "text.cursor")
            }
            .padding(.vertical, Space.x3)

            HairlineDivider()

            VStack(alignment: .leading, spacing: Space.x2) {
                Label("Private by default", systemImage: "lock.shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Text("Speech recognition runs on this Mac. Small is included; downloading another model is optional. Utter does not upload your audio or text.")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func onboardingStep(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.primary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            VStack(alignment: .leading, spacing: Space.x1) {
                Text("Allow the two things dictation needs").typo(.heading)
                Text("Utter listens only while you hold the shortcut. Recognition stays on this Mac.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PermissionStep(
                icon: "mic.fill",
                iconColor: Tint.recording,
                title: "Microphone",
                message: "Used only while you dictate or explicitly record a note.",
                granted: model.micGranted,
                grantedLabel: "Microphone ready",
                actionLabel: "Allow microphone",
                action: { model.requestMic() }
            )
            PermissionStep(
                icon: "accessibility",
                iconColor: Tint.accent,
                title: "Accessibility",
                message: "Lets Utter detect your shortcut and type finished words into the app you’re using.",
                granted: model.axGranted,
                grantedLabel: "Text insertion ready",
                actionLabel: "Open Accessibility settings",
                action: { model.requestAccessibility() }
            )
        }
    }

    private var modelStep: some View {
        ModelChooserView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.x2)
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

            VStack(alignment: .leading, spacing: Space.x4) {
                ContentSection(title: "Your shortcut", systemImage: "keyboard") {
                    AppleSettingsRow(title: "Hold to dictate", subtitle: "You can change this later in Workflow settings.") {
                        Picker("Dictation shortcut", selection: $userData.hotkeyName) {
                            ForEach(HotkeyOption.options) { option in
                                Text(option.name).tag(option.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                        .onChange(of: userData.hotkeyName) { _ in
                            userData.save()
                            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                        }
                    }
                }

                ContentSection(title: "Try a first capture", systemImage: "waveform") {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        Text("Click the field, hold \(userData.hotkeyName), and speak. Your words should appear here.")
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("Your words will appear here", text: $model.sampleTestText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }
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
        ContentSection(title: title, systemImage: icon, tint: granted ? Tint.success : iconColor) {
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
    /// The step the user was last on. Cleared on completion - see `markCompleted`.
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
        case 1: return microphoneGranted && accessibilityGranted
        case 2: return modelReady
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
    ///     deliberate act - someone who returned to the microphone step to re-read it
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
        // onboarding - which means clearing `hasCompletedOnboarding` - straight back
        // into the middle of the flow they just finished.
        UserDefaults.standard.removeObject(forKey: stepKey)
    }
}

/// One readiness row on the final onboarding step: what it is, and whether it's ready.
///
/// `LabeledContent` - the system's label/value row, `@available(macOS 13.0)`, so no
/// availability branch at this target. It replaces a hand-built `HStack` carrying a
/// `Circle().frame(width: 7, height: 7)` and a manually composed
/// `accessibilityElement(children: .combine)` + `accessibilityLabel("\(label): ready")`.
/// The system now supplies the label/value pairing VoiceOver reads, the alignment
/// between the four rows, and the trailing-value layout - including under a large
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
/// translucent tiles (see `Ink.secondary`'s own note) - under the 4.5:1 floor, and this
/// row sits inside a `ContentSection`.
private struct ReadinessRow: View {
    let label: String
    let ok: Bool
    /// What to say when a requirement is missing.
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
/// Matches `FlowContent.windowSurface` rather than inventing its own - this
/// is the very first screen, and having it read as a different app's window was
/// the most visible inconsistency in the app.
struct OnboardingBacking: View {
    @ObservedObject private var motion = MotionPreference.shared
    /// Observed although the body never names it: `Surface.canvas` resolves
    /// `ThemeManager.shared.current`, and without a dependency on the manager this
    /// body is not re-evaluated when the theme changes - so the window kept the
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
