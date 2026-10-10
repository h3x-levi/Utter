import Testing
@testable import UtterKit

/// The three-step flow's rules. View models are built with a step override, which never writes
/// the stored step, and an in-memory `UserData`.
@Suite("Onboarding flow")
@MainActor
struct OnboardingFlowTests {

    private func model(step: Int, hotkey: String = "fn", doubleTap: Bool = true) -> OnboardingViewModel {
        let userData = UserData(storageDir: nil)
        userData.hotkeyName = hotkey
        userData.doubleTapHotkeyForHandsFree = doubleTap
        return OnboardingViewModel(stepOverride: step, userData: userData)
    }

    @Test("The demo holds an empty plate, adds one live word at a time, then rests on the full line")
    func demoScript() {
        let words = OnboardingDemo.words
        #expect(OnboardingDemo.phase(0) == .hold)
        #expect(OnboardingDemo.caption(0) == ("", nil))
        for frame in 1...words.count {
            #expect(OnboardingDemo.phase(frame) == .speak)
            let caption = OnboardingDemo.caption(frame)
            #expect(caption.live == words[frame - 1])
            #expect(caption.text == words.prefix(frame - 1).joined(separator: " "))
        }
        let full = words.joined(separator: " ")
        #expect(OnboardingDemo.phase(words.count + 1) == .release)
        #expect(OnboardingDemo.caption(words.count + 1) == (full, nil))
        #expect(OnboardingDemo.phase(OnboardingDemo.restFrame) == nil)
        #expect(OnboardingDemo.caption(OnboardingDemo.restFrame) == (full, nil))
    }

    @Test("Reduce Motion lands on the finished line at once")
    func reduceMotionShowsFinalText() async {
        let model = model(step: 0)
        model.demoFrame = 0
        await model.playDemo(reduceMotion: true)
        #expect(model.demoFinished)
    }

    @Test("Every dictation key has its own keycap, and fn reads as fn")
    func hotkeyLabels() {
        let labels = HotkeyOption.options.map(HotkeyLabel.init)
        #expect(Set(labels.map(\.cap)).count == HotkeyOption.options.count)
        #expect(Set(labels.map(\.word)).count == HotkeyOption.options.count)
        #expect(model(step: 2).hotkey.word == "fn")
        #expect(model(step: 2, hotkey: "rightOption").hotkey.word == "right Option")
    }

    @Test("Hands-free is described the way the user's settings start it")
    func handsFreeHint() {
        #expect(model(step: 2).handsFree == "Double-tap for hands-free.")
        #expect(model(step: 2, doubleTap: false).handsFree.hasPrefix(KeyChord.handsFree.symbols))
    }

    @Test("A paste of words counts as dictation; typing, deleting and blank space do not")
    func dictationDetection() {
        #expect(OnboardingState.looksDictated(old: "", new: "Hello there."))
        #expect(OnboardingState.looksDictated(old: "Hi. ", new: "Hi. Hello there."))
        #expect(!OnboardingState.looksDictated(old: "H", new: "He"))
        #expect(!OnboardingState.looksDictated(old: "Hello there.", new: ""))
        #expect(!OnboardingState.looksDictated(old: "", new: "   "))
    }

    @Test("Try it unlocks Done only when dictated text lands, and stays unlocked")
    func tryItGate() {
        let model = model(step: 2)
        model.micGranted = true
        model.axGranted = true
        #expect(!model.canContinue)
        model.typed = "H"
        #expect(!model.canContinue)
        model.typed = "Hello, this is my first sentence."
        #expect(model.canContinue)
        model.typed = ""
        #expect(model.canContinue)
    }

    @Test("Permissions unlock Continue only with both granted")
    func permissionsGate() {
        let model = model(step: 1)
        #expect(!model.canContinue)
        model.micGranted = true
        #expect(!model.canContinue)
        model.axGranted = true
        #expect(model.canContinue)
    }

    @Test("Steps move one at a time in both directions and stop at the ends")
    func movement() {
        let model = model(step: 0)
        model.move(by: -1)
        #expect(model.step == .welcome)
        model.move(by: 1)
        #expect(model.step == .permissions && model.movingForward)
        model.move(by: 1)
        #expect(model.step == .tryIt)
        model.move(by: 1)
        #expect(model.step == .tryIt)
        model.move(by: -1)
        #expect(model.step == .permissions && !model.movingForward)
    }

    @Test("A preview step override is clamped into the flow")
    func previewStepClamped() {
        #expect(model(step: 9).step == .tryIt)
        #expect(model(step: -2).step == .welcome)
    }
}
