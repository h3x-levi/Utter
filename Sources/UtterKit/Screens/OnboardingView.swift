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

/// The v2 setup window: steps centred in the top 440 pt, a fixed 80 pt bar under them.
struct OnboardingView: View {
    var onFinish: (_ skipped: Bool) -> Void

    @State private var model: OnboardingViewModel
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillGlass
    @Namespace private var progress

    init(onFinish: @escaping (_ skipped: Bool) -> Void, previewStep: Int? = nil) {
        self.init(model: OnboardingViewModel(stepOverride: previewStep), onFinish: onFinish)
    }

    init(model: OnboardingViewModel, onFinish: @escaping (_ skipped: Bool) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                stepView
                    .id(model.step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 40)
            .padding(.horizontal, 70)
            bar
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { PaneGround().ignoresSafeArea() }
        .foregroundStyle(Pane.ink)
        .tint(Look.Color.tint)
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
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Pane.ink2)
                .lineSpacing(4)
                .frame(maxWidth: 440)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            hero
            heading("Talk instead of typing",
                    "Hold \(model.hotkey.word), say what you want to write, then let go. Utter types it wherever your cursor is, in any app.")
                .padding(.top, 26)
        }
        .task { await model.playDemo(reduceMotion: reduceMotion) }
    }

    private var hero: some View {
        let frame = model.demoFrame
        let phase = OnboardingDemo.phase(frame)
        return HStack(spacing: 22) {
            DemoKey(cap: model.hotkey.cap, pressed: phase == .hold || phase == .speak)
            PillCapsule(look: OnboardingDemo.look(frame), level: Float(OnboardingDemo.level(frame)), namespace: pillGlass)
                .scaleEffect(1.4)
                .frame(width: 96, height: 28)
        }
        .lookAnimation(.settle, value: frame)
        .accessibilityHidden(true)
    }

    // MARK: - Permissions

    private var permissions: some View {
        VStack(spacing: 0) {
            heading("Two quick permissions",
                    "Utter needs to hear you and to type for you. If System Settings opens, switch Utter on there and come back.")
            PaneGroup {
                PermissionRow(name: "Microphone",
                              purpose: "Hears you only while you hold \(model.hotkey.word). Your voice stays on this Mac.",
                              need: .core(granted: model.micGranted), grant: model.requestMic)
                PermissionRow(name: "Accessibility",
                              purpose: "Lets Utter notice \(model.hotkey.word) and type your words where your cursor is.",
                              need: .core(granted: model.axGranted), grant: model.requestAccessibility)
            }
            .frame(width: 460)
            .padding(.top, 24)
        }
    }

    // MARK: - Try it

    private var tryIt: some View {
        VStack(spacing: 0) {
            heading("Try it now", "Hold \(model.hotkey.word) and say anything. Let go, and your words appear here.")
            TextField(text: $model.typed, prompt: Text("Your words will appear here.").foregroundStyle(Pane.ink3),
                      axis: .vertical) {
                Text("Practice text box")
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .lineSpacing(4)
            .lineLimit(4)
            .focused($fieldFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 460, height: 110, alignment: .topLeading)
            .background { PaneCard() }
            .padding(.top, 24)
            practiceStatus
                .frame(width: 460, height: 18, alignment: .leading)
                .padding(.top, 12)
        }
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder private var practiceStatus: some View {
        if model.dictated {
            PaneStatus(text: "It works. Hold \(model.hotkey.word) to talk in any app. \(model.handsFree)", kind: .ok)
        } else if !model.micGranted || !model.axGranted {
            PaneStatus(text: "Utter still needs both permissions. Go back to allow them.", kind: .warn)
        } else {
            PaneStatus(text: "Ready")
        }
    }

    // MARK: - Navigation

    private var bar: some View {
        HStack(spacing: 8) {
            Button("Set up later") { finish(skipped: true) }
                .buttonStyle(.pane(.plain))
                .keyboardShortcut(.cancelAction)
            Spacer()
            if model.step != .welcome {
                Button("Back") { go(-1) }
                    .buttonStyle(.pane())
            }
            Button(model.step == .tryIt ? "Done" : "Continue") {
                if model.step == .tryIt { finish(skipped: false) } else { go(1) }
            }
            .buttonStyle(.pane(.prime))
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canContinue)
        }
        .overlay { progressLens }
        .padding(.horizontal, 26)
        .frame(height: 80)
    }

    /// Seven-point dots with one 20 pt lens that travels between them.
    private var progressLens: some View {
        HStack(spacing: 18) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(Pane.sep)
                    .frame(width: 7, height: 7)
                    .overlay {
                        if step == model.step {
                            Capsule()
                                .fill(Look.Color.tint)
                                .frame(width: 20, height: 7)
                                .matchedGeometryEffect(id: "lens", in: progress)
                        }
                    }
            }
        }
        .animation(PaneMotion.lens(reduceMotion: reduceMotion), value: model.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepLabel(model.step))
    }

    private func go(_ delta: Int) {
        withAnimation(PaneMotion.page(reduceMotion: reduceMotion)) { model.move(by: delta) }
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

private struct StepArrival: ViewModifier {
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .blur(radius: abs(offset) / 5)
            .opacity(offset == 0 ? 1 : 0)
    }
}

/// The dictation key, drawn like a real keycap with its legend in the lower left, pressed while the demo holds it.
private struct DemoKey: View {
    let cap: String
    let pressed: Bool

    var body: some View {
        Text(cap)
            .font(.system(size: 15, design: .monospaced))
            .padding(.leading, 11)
            .padding(.bottom, 9)
            .frame(width: 64, height: 58, alignment: .bottomLeading)
            .background { PaneCard(radius: 14) }
            .offset(y: pressed ? 2 : 0)
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
