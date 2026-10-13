import AVFoundation
import AppKit
import Combine
import SwiftUI
import UtterCore

/// First run in three steps: watch the pill hear a sentence, allow the two permissions, dictate one
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

/// The welcome step's synthetic dictation: the key goes down, the pill listens for one beat per
/// spoken word, thinks once the key is let go, then rests as the icon.
enum OnboardingDemo {
    enum Phase {
        case hold, speak, release
    }

    static let beats = 8
    static var restFrame: Int { beats + 2 }

    static func phase(_ frame: Int) -> Phase? {
        switch frame {
        case 0: .hold
        case 1...beats: .speak
        case beats + 1: .release
        default: nil
        }
    }

    static func look(_ frame: Int) -> PillLook {
        switch phase(frame) {
        case .hold, .speak: .listening(nil)
        case .release: .thinking
        case nil: .hover(handsFree: false)
        }
    }

    static func level(_ frame: Int) -> Double {
        switch phase(frame) {
        case .hold: 0.12
        case .speak: [0.55, 0.8, 0.45, 0.7][frame % 4]
        default: 0
        }
    }

    static func hold(_ frame: Int) -> Duration {
        switch phase(frame) {
        case .hold: .milliseconds(800)
        case .speak: frame == beats ? .milliseconds(600) : .milliseconds(300)
        default: .milliseconds(1400)
        }
    }
}

/// The setup window as a J-card: the red stripe counts the steps, each step a caps heading over rows on
/// the rules, and the pen buttons on a fixed bar.
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
            Text("Set up Utter")
                .font(Mixtape.body(12))
                .foregroundStyle(Mixtape.ink3)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)
            SetupStripe(step: model.step)
            ZStack(alignment: .topLeading) {
                stepView
                    .id(model.step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 28)
            .padding(.horizontal, 56)
            bar
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Mixtape.paper)
        .foregroundStyle(Mixtape.ink)
        .tint(Mixtape.ink)
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

    /// The arriving step travels 40 pt along the one axis, in the direction of travel; the leaving one fades.
    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let offset: CGFloat = model.movingForward ? 40 : -40
        return .asymmetric(insertion: .modifier(active: StepArrival(offset: offset), identity: StepArrival(offset: 0)),
                           removal: .opacity)
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .mixtapeCaps(30, tracking: 0.02)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(Mixtape.body(14))
                .foregroundStyle(Mixtape.ink2)
                .lineSpacing(4)
                .frame(maxWidth: 500, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 26) {
            heading("Talk instead of typing",
                    "Hold \(model.hotkey.word), say what you want to write, then let go. Utter types it wherever your cursor is, in any app.")
            hero
        }
        .task { await model.playDemo(reduceMotion: reduceMotion) }
    }

    private var hero: some View {
        let frame = model.demoFrame
        let phase = OnboardingDemo.phase(frame)
        return HStack(spacing: 26) {
            DemoKey(cap: model.hotkey.cap, pressed: phase == .hold || phase == .speak)
            PillCapsule(look: OnboardingDemo.look(frame), level: Float(OnboardingDemo.level(frame)))
                .scaleEffect(1.4)
                .frame(width: 96, height: 28)
        }
        .lookAnimation(.settle, value: frame)
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(Mixtape.spine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Mixtape.rule) }
        .accessibilityHidden(true)
    }

    // MARK: - Permissions

    private var permissions: some View {
        let left = [model.micGranted, model.axGranted].filter { !$0 }.count
        return VStack(alignment: .leading, spacing: 26) {
            heading("Two quick permissions",
                    "Utter needs to hear you and to type for you. If System Settings opens, switch Utter on there and come back.")
            SettingsSection("Permissions", detail: left == 0 ? "all set" : "\(left) to go") {
                PermissionRow(name: "Microphone",
                              purpose: "Hears you only while you hold \(model.hotkey.word). Your voice stays on this Mac.",
                              need: .core(granted: model.micGranted), grant: model.requestMic)
                PermissionRow(name: "Accessibility",
                              purpose: "Lets Utter notice \(model.hotkey.word) and type your words where your cursor is.",
                              need: .core(granted: model.axGranted), grant: model.requestAccessibility)
            }
        }
    }

    // MARK: - Try it

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Try it now", "Hold \(model.hotkey.word) and say anything. Let go, and your words appear here.")
            TextField(text: $model.typed, prompt: Text("Your words will appear here.").foregroundStyle(Mixtape.ink3),
                      axis: .vertical) {
                Text("Practice text box")
            }
            .textFieldStyle(.plain)
            .font(Mixtape.body(16.5))
            .foregroundStyle(Mixtape.penInk)
            .tint(Mixtape.red)
            .lineSpacing(14)
            .lineLimit(3)
            .focused($fieldFocused)
            .padding(.top, 11)
            .frame(maxWidth: .infinity, minHeight: Mixtape.ruleSpacing * 3, maxHeight: Mixtape.ruleSpacing * 3, alignment: .topLeading)
            .background(alignment: .top) { RuledBackground() }
            practiceStatus
                .frame(height: 18, alignment: .leading)
        }
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder private var practiceStatus: some View {
        if model.dictated {
            SettingsStatus(text: "It works. Hold \(model.hotkey.word) to talk in any app. \(model.handsFree)", kind: .ok)
        } else if !model.micGranted || !model.axGranted {
            SettingsStatus(text: "Utter still needs both permissions. Go back to allow them.", kind: .warn)
        } else {
            SettingsStatus(text: "Ready")
        }
    }

    // MARK: - Navigation

    private var bar: some View {
        HStack(spacing: 8) {
            Button("Set up later") { finish(skipped: true) }
                .buttonStyle(.pen(.ghost))
                .keyboardShortcut(.cancelAction)
            Spacer()
            if model.step != .welcome {
                Button("Back") { go(-1) }
                    .buttonStyle(.pen(.outline))
            }
            Button(model.step == .tryIt ? "Done" : "Continue") {
                if model.step == .tryIt { finish(skipped: false) } else { go(1) }
            }
            .buttonStyle(.pen(.fill))
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canContinue)
        }
        .padding(.horizontal, 56)
        .frame(height: 76)
        .overlay(alignment: .top) { Rectangle().fill(Mixtape.rule).frame(height: 1) }
    }

    private func go(_ delta: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.14) : .spring(duration: 0.46, bounce: 0.16)) { model.move(by: delta) }
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

    /// The setup window, shared by `AppDelegate.showOnboarding` and the snapshot tests.
    static func makeWindow(_ root: some View) -> NSWindow {
        let hosting = NSHostingView(rootView: root)
        // The hosting view must never size the window: that is the ~133 pt collapse `showMainWindow` guards.
        hosting.sizingOptions = []
        let size = NSSize(width: Layout.onboardingIdealWidth, height: Layout.onboardingIdealHeight)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Set up Utter"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        return window
    }
}

/// The brand stripe as setup progress: the step's name, one tape segment per step, the count.
private struct SetupStripe: View {
    let step: OnboardingViewModel.Step
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let steps = OnboardingViewModel.Step.allCases
        HStack(spacing: 12) {
            Text(step.name).mixtapeCaps(10.5, tracking: 0.2).fixedSize()
            HStack(spacing: 2) {
                ForEach(steps, id: \.self) { each in
                    RoundedRectangle(cornerRadius: 1).fill(.white.opacity(each.rawValue <= step.rawValue ? 1 : 0))
                }
            }
            .frame(height: 8)
            .background(.white.opacity(0.26))
            .clipShape(Capsule())
            Text("\(step.rawValue + 1) / \(steps.count) steps")
                .font(Mixtape.mono(11, .semibold))
                .tracking(0.22)
                .textCase(.uppercase)
                .fixedSize()
        }
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
        .background(Mixtape.red)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 1, 0.3, 1, duration: 0.7), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(steps.count), \(step.name)")
    }
}

private struct StepArrival: ViewModifier {
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .blur(radius: abs(offset) / 5)
            .opacity(offset == 0 ? 1 : 0)
    }
}

/// The dictation key as a deck key, its legend in the lower left, sinking while the demo holds it.
private struct DemoKey: View {
    let cap: String
    let pressed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Text(cap)
            .font(Mixtape.mono(15))
            .foregroundStyle(Mixtape.ink)
            .padding(.leading, 11)
            .padding(.bottom, 9)
            .frame(width: 64, height: 58, alignment: .bottomLeading)
            .background {
                shape.fill(Mixtape.key)
                    .overlay {
                        shape.fill(LinearGradient(stops: [.init(color: Mixtape.keyHi, location: 0),
                                                          .init(color: Mixtape.keyHi.opacity(0), location: 0.4)],
                                                  startPoint: .top, endPoint: .bottom))
                            .opacity(pressed ? 0 : 1)
                    }
                    .overlay { shape.strokeBorder(Mixtape.edge) }
            }
            .background(shape.fill(Mixtape.keyLo).offset(y: pressed ? 0.5 : 2))
            .offset(y: pressed ? 1.5 : 0)
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
