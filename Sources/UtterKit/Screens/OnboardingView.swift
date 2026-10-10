import AVFoundation
import AppKit
import Combine
import SwiftUI

/// First run in three steps: watch a sentence appear, allow the two permissions, dictate one
/// sentence. The step is stored on every move, so a trip to System Settings or a quit mid-way
/// reopens where the user left.
@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, permissions, tryIt

        var name: String {
            switch self {
            case .welcome: "Welcome"
            case .permissions: "Permissions"
            case .tryIt: "Try it"
            }
        }
    }

    var step: Step {
        didSet { if !isPreview { OnboardingState.recordStep(step.rawValue) } }
    }
    private(set) var movingForward = true
    var micGranted = false
    var axGranted = false
    var demoFrame = OnboardingDemo.restFrame
    private(set) var demoRun = 0
    var typed = "" {
        didSet { if OnboardingState.looksDictated(old: oldValue, new: typed) { dictated = true } }
    }
    private(set) var dictated = false

    let hotkey: HotkeyLabel
    let handsFree: String

    private let readiness: ReadinessMonitor
    private let isPreview: Bool
    @ObservationIgnored private var subscriptions: Set<AnyCancellable> = []

    /// `stepOverride` is for previews and snapshots: it pins the step and never touches the stored one.
    init(stepOverride: Int? = nil, readiness: ReadinessMonitor? = nil, userData: UserData = .shared) {
        let count = Step.allCases.count
        let index = stepOverride.map { min(max($0, 0), count - 1) }
            ?? OnboardingState.resumeStep(stepCount: count)
        step = Step(rawValue: index) ?? .welcome
        isPreview = stepOverride != nil
        hotkey = HotkeyLabel(HotkeyOption.find(id: userData.hotkeyId))
        handsFree = userData.doubleTapHotkeyForHandsFree
            ? "Double-tap for hands-free."
            : "\(KeyChord.handsFree.symbols) for hands-free."
        self.readiness = readiness ?? .shared
    }

    var canContinue: Bool {
        OnboardingState.canAdvance(step: step.rawValue, microphoneGranted: micGranted,
                                   accessibilityGranted: axGranted, dictated: dictated)
    }

    var demoFinished: Bool { demoFrame >= OnboardingDemo.restFrame }

    func start() {
        guard !isPreview, subscriptions.isEmpty else { return }
        readiness.startPolling()
        readiness.$micGranted.sink { [weak self] in self?.micGranted = $0 }.store(in: &subscriptions)
        readiness.$axGranted.sink { [weak self] in self?.axGranted = $0 }.store(in: &subscriptions)
    }

    func stop() {
        guard !subscriptions.isEmpty else { return }
        subscriptions.removeAll()
        readiness.stopPolling()
    }

    func aim(forward: Bool) { movingForward = forward }

    func move(by delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        movingForward = delta > 0
        step = next
    }

    func playDemo(reduceMotion: Bool) async {
        guard !reduceMotion else {
            demoFrame = OnboardingDemo.restFrame
            return
        }
        guard !isPreview else { return }
        for frame in 0...OnboardingDemo.restFrame {
            demoFrame = frame
            guard frame < OnboardingDemo.restFrame,
                  (try? await Task.sleep(for: OnboardingDemo.hold(frame))) != nil else { return }
        }
    }

    func replayDemo() { demoRun += 1 }

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

    func finish() {
        if !isPreview { OnboardingState.markCompleted() }
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The dictation key as a keycap and as a word in a sentence.
struct HotkeyLabel: Equatable {
    let cap: String
    let word: String

    init(_ option: HotkeyOption) {
        switch option.id {
        case "rightOption": (cap, word) = ("\u{2325}", "right Option")
        case "rightCommand": (cap, word) = ("\u{2318}", "right Command")
        case "rightControl": (cap, word) = ("\u{2303}", "right Control")
        default: (cap, word) = ("fn", "fn")
        }
    }
}

/// The welcome step's synthetic dictation: an empty plate while the key goes down, a word at a
/// time while speaking, the finished line once the key is let go, then rest.
enum OnboardingDemo {
    enum Phase: CaseIterable {
        case hold, speak, release
    }

    static let words = "Thanks Priya, Thursday at two works for me.".split(separator: " ").map(String.init)
    static var restFrame: Int { words.count + 2 }

    static func phase(_ frame: Int) -> Phase? {
        switch frame {
        case 0: .hold
        case 1...words.count: .speak
        case words.count + 1: .release
        default: nil
        }
    }

    static func caption(_ frame: Int) -> (text: String, live: String?) {
        let shown = min(max(frame, 0), words.count)
        guard phase(frame) == .speak else { return (words.prefix(shown).joined(separator: " "), nil) }
        return (words.prefix(shown - 1).joined(separator: " "), words[shown - 1])
    }

    static func hold(_ frame: Int) -> Duration {
        switch phase(frame) {
        case .hold: .milliseconds(800)
        case .speak: frame == words.count ? .milliseconds(600) : .milliseconds(300)
        default: .milliseconds(1400)
        }
    }
}

struct OnboardingView: View {
    var onFinish: (_ skipped: Bool) -> Void

    @State private var model: OnboardingViewModel
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onFinish: @escaping (_ skipped: Bool) -> Void, previewStep: Int? = nil) {
        self.init(model: OnboardingViewModel(stepOverride: previewStep), onFinish: onFinish)
    }

    init(model: OnboardingViewModel, onFinish: @escaping (_ skipped: Bool) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ZStack(alignment: .top) {
                    stepView
                        .id(model.step)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, Look.Space.x8)
                .padding(.top, Look.Space.x6)
                .padding(.bottom, Look.Space.x4)
            }
            .scrollBounceBehavior(.basedOnSize)
            navBar
        }
        .frame(minWidth: Layout.onboardingMinWidth,
               idealWidth: Layout.onboardingIdealWidth,
               maxWidth: .infinity,
               minHeight: Layout.onboardingMinHeight,
               idealHeight: Layout.onboardingIdealHeight,
               maxHeight: .infinity)
        .background(Look.Color.ground.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.step) { _, step in announce(stepLabel(step)) }
        .onChange(of: model.dictated) { _, dictated in
            if dictated { announce("It works. Hold \(model.hotkey.word) to talk in any app.") }
        }
    }

    @ViewBuilder private var stepView: some View {
        switch model.step {
        case .welcome: welcome
        case .permissions: permissions
        case .tryIt: tryIt
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = model.movingForward
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading),
                           removal: .move(edge: forward ? .leading : .trailing))
            .combined(with: .opacity)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label { Text("Utter") } icon: { Image(systemName: "waveform") }
                .font(Look.Font.body.weight(.bold))
                .foregroundStyle(Look.Color.ink)
            Text("Hold \(model.hotkey.word), say what you mean, and let go. Utter types it where your cursor is.")
                .font(Look.Font.body)
                .foregroundStyle(Look.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Look.Space.x2)
            demo.padding(.top, Look.Space.x6)
            Label {
                Text("Utter runs on this Mac. Your voice and words never leave it.")
            } icon: {
                Image(systemName: "lock").foregroundStyle(Look.Color.inkTertiary)
            }
            .font(Look.Font.body)
            .foregroundStyle(Look.Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Look.Space.x8)
        }
    }

    private var demo: some View {
        let caption = OnboardingDemo.caption(model.demoFrame)
        let phase = OnboardingDemo.phase(model.demoFrame)
        return VStack(alignment: .leading, spacing: Look.Space.x3) {
            Look.CaptionPlate(text: caption.text, liveWord: caption.live, caret: phase == .hold || phase == .speak)
                .accessibilityHidden(true)
            HStack(spacing: Look.Space.x3) {
                HStack(spacing: Look.Space.x3) {
                    Look.Keycap(model.hotkey.cap)
                    ForEach(OnboardingDemo.Phase.allCases, id: \.self) { step in
                        ZStack {
                            Look.SoundTag(phaseLabel(step), state: .live).hidden()
                            Look.SoundTag(phaseLabel(step), state: step == phase ? .live : .neutral)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Example: hold \(model.hotkey.word), speak, then let go, and your words are typed.")
                Spacer(minLength: Look.Space.x3)
                if model.demoFinished, !reduceMotion {
                    Button("Replay example") { model.replayDemo() }
                        .buttonStyle(Look.QuietButtonStyle())
                } else {
                    Look.SoundTag("example").accessibilityHidden(true)
                }
            }
        }
        .task(id: model.demoRun) { await model.playDemo(reduceMotion: reduceMotion) }
    }

    private func phaseLabel(_ phase: OnboardingDemo.Phase) -> String {
        switch phase {
        case .hold: "hold \(model.hotkey.cap)"
        case .speak: "speak"
        case .release: "let go"
        }
    }

    // MARK: - Permissions

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Let Utter hear you and type for you")
                .font(Look.Font.body.weight(.semibold))
                .foregroundStyle(Look.Color.ink)
            Text("If System Settings opens, switch Utter on there and come back.")
                .font(Look.Font.secondary)
                .foregroundStyle(Look.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Look.Space.x1)
            Look.Well(spacing: Look.Space.x5) {
                PermissionRow(title: "Microphone",
                              why: "Hears you only while you hold \(model.hotkey.word).",
                              granted: model.micGranted,
                              grant: model.requestMic)
                PermissionRow(title: "Accessibility",
                              why: "Lets Utter notice \(model.hotkey.word) and type your words where your cursor is.",
                              granted: model.axGranted,
                              grant: model.requestAccessibility)
            }
            .padding(.top, Look.Space.x5)
        }
    }

    // MARK: - Try it

    private var tryIt: some View {
        let blocked = !model.micGranted || !model.axGranted
        return VStack(alignment: .leading, spacing: 0) {
            Text("Try it")
                .font(Look.Font.body.weight(.semibold))
                .foregroundStyle(Look.Color.ink)
            Text("Hold \(model.hotkey.word) and say anything.")
                .font(Look.Font.body)
                .foregroundStyle(Look.Color.inkSecondary)
                .padding(.top, Look.Space.x1)
            TextField("Your words appear here", text: $model.typed, axis: .vertical)
                .font(Look.Font.body)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($fieldFocused)
                .accessibilityLabel("Practice field")
                .padding(.top, Look.Space.x4)
            Look.SoundTag(model.dictated ? "it works" : blocked ? "not ready" : "ready",
                          state: model.dictated ? .ok : blocked ? .warn : .neutral,
                          widest: "not ready")
                .padding(.top, Look.Space.x3)
            if blocked, !model.dictated {
                Text("Utter still needs both permissions. Go back to allow them.")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
                    .padding(.top, Look.Space.x1)
            }
            if model.dictated {
                shortcutSummary
                    .padding(.top, Look.Space.x5)
                    .transition(.opacity)
            }
        }
        .lookAnimation(.settle, value: model.dictated)
        .onAppear { fieldFocused = true }
    }

    private var shortcutSummary: some View {
        Look.Well(spacing: Look.Space.x4) {
            Text("That\u{2019}s it. It works the same in any app.")
                .font(Look.Font.body)
                .foregroundStyle(Look.Color.ink)
            HStack(alignment: .top, spacing: Look.Space.x3) {
                Look.Keycap(model.hotkey.cap)
                VStack(alignment: .leading, spacing: Look.Space.x1) {
                    Text("Hold to talk.").foregroundStyle(Look.Color.ink)
                    Text(model.handsFree).foregroundStyle(Look.Color.inkSecondary)
                }
                .font(Look.Font.body)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Navigation

    private var navBar: some View {
        HStack(spacing: Look.Space.x3) {
            Button("Set up later") { finish(skipped: true) }
                .buttonStyle(Look.QuietButtonStyle())
                .keyboardShortcut(.cancelAction)
            Spacer()
            if model.step != .welcome {
                Button("Back") { go(-1) }
            }
            Button(model.step == .tryIt ? "Done" : "Continue") {
                if model.step == .tryIt { finish(skipped: false) } else { go(1) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canContinue)
        }
        .overlay { pager }
        .padding(.horizontal, Look.Space.x8)
        .padding(.vertical, Look.Space.x5)
    }

    private var pager: some View {
        HStack(spacing: Look.Space.x2) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(step == model.step ? Look.Color.ink : Look.Color.inkTertiary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .lookAnimation(.settle, value: model.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepLabel(model.step))
    }

    private func go(_ delta: Int) {
        model.aim(forward: delta > 0)
        // The leaving step takes its removal edge from the previous render, so the direction lands a turn early.
        DispatchQueue.main.async {
            withAnimation(Look.Motion.settle.animation(reduceMotion: reduceMotion)) { model.move(by: delta) }
        }
    }

    private func finish(skipped: Bool) {
        model.finish()
        onFinish(skipped)
    }

    private func stepLabel(_ step: OnboardingViewModel.Step) -> String {
        "Step \(step.rawValue + 1) of \(OnboardingViewModel.Step.allCases.count), \(step.name)"
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

/// One permission: what it is, why Utter needs it, and its state or the button that asks for it.
private struct PermissionRow: View {
    let title: String
    let why: String
    let granted: Bool
    let grant: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Look.Space.x4) {
            VStack(alignment: .leading, spacing: Look.Space.x1) {
                Text(title)
                    .font(Look.Font.heading)
                    .foregroundStyle(Look.Color.ink)
                Text(why)
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityValue(granted ? "On" : "Off")
            ZStack(alignment: .trailing) {
                status(granted: false).hidden()
                status(granted: granted)
            }
        }
    }

    @ViewBuilder private func status(granted: Bool) -> some View {
        if granted {
            Look.ReadinessTag(label: "on", state: .ready).accessibilityHidden(true)
        } else {
            HStack(spacing: Look.Space.x2) {
                Look.SoundTag("off", state: .warn).accessibilityHidden(true)
                Button("Grant", action: grant)
                    .accessibilityLabel("Grant \(title) access")
            }
        }
    }
}

// MARK: - Onboarding completion flag

/// Whether the user has finished first-run onboarding, and how far an unfinished run got.
enum OnboardingState {
    private static let completedKey = "hasCompletedOnboarding"
    /// The step the user was last on. Cleared on completion - see `markCompleted`.
    private static let stepKey = "onboardingStep"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func canAdvance(step: Int, microphoneGranted: Bool, accessibilityGranted: Bool, dictated: Bool) -> Bool {
        switch step {
        case 1: microphoneGranted && accessibilityGranted
        case 2: dictated
        default: true
        }
    }

    // ponytail: any insertion of two or more characters counts, so a manual paste passes too; hook the dictation pipeline if that matters.
    static func looksDictated(old: String, new: String) -> Bool {
        new.count - old.count >= 2 && new.contains { !$0.isWhitespace }
    }

    static func recordStep(_ step: Int) {
        UserDefaults.standard.set(step, forKey: stepKey)
    }

    static func resumeStep(stepCount: Int) -> Int {
        resumeStep(stored: UserDefaults.standard.integer(forKey: stepKey),
                   completed: hasCompleted,
                   stepCount: stepCount)
    }

    /// The step they left (not the furthest reached), clamped so a step stored by a longer flow
    /// lands on the last one, and never mid-flow once completed.
    static func resumeStep(stored: Int, completed: Bool, stepCount: Int) -> Int {
        guard stepCount > 0, !completed else { return 0 }
        return min(max(stored, 0), stepCount - 1)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
        // Leaving the step behind would drop a later replay of onboarding into the middle of the flow.
        UserDefaults.standard.removeObject(forKey: stepKey)
    }
}
