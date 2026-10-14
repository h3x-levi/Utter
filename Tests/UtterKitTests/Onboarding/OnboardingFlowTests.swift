import AppKit
import Testing
@testable import UtterKit
@testable import UtterCore

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

    @Test("The demo holds the key, speaks one beat at a time, lets go, then rests")
    func demoScript() {
        #expect(OnboardingDemo.phase(0) == .hold)
        for frame in 1...OnboardingDemo.beats {
            #expect(OnboardingDemo.phase(frame) == .speak)
        }
        #expect(OnboardingDemo.phase(OnboardingDemo.beats + 1) == .release)
        #expect(OnboardingDemo.phase(OnboardingDemo.restFrame) == nil)
    }

    @Test("The demo pill listens while the key is down, thinks on release, then rests as the icon")
    func demoPill() {
        #expect(OnboardingDemo.look(0) == .listening(nil))
        #expect(OnboardingDemo.look(1) == .listening(nil))
        #expect(OnboardingDemo.look(OnboardingDemo.beats + 1) == .thinking)
        #expect(OnboardingDemo.look(OnboardingDemo.restFrame) == .hover(handsFree: false))
        #expect(OnboardingDemo.level(1) > OnboardingDemo.level(0))
        #expect(OnboardingDemo.level(OnboardingDemo.restFrame) == 0)
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

/// The account session's rules, against a stand-in for the Google provider.
@Suite("Sign-in session")
@MainActor
struct AccountSessionTests {
    private final class FakeProvider: SignInProvider {
        var next: Result<Account, Error> = .success(Account(name: "Priya Shah", email: "priya@example.com"))
        var restored: Account?
        var signedOut = false
        func restore() async -> Account? { restored }
        func signIn(presenting window: NSWindow?) async throws -> Account { try next.get() }
        func signOut() { signedOut = true }
    }

    private func defaults() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    @Test("Without a provider nothing is required and the button says so")
    func notConnected() async {
        let session = AccountSession(defaults: defaults())
        #expect(!session.isRequired && !session.needsSignIn)
        #expect(await !session.signIn(presenting: nil))
        #expect(session.problem == "Google sign-in isn\u{2019}t connected yet.")
    }

    @Test("Signing in is kept across launches until sign out")
    func signInPersists() async {
        let store = defaults()
        let provider = FakeProvider()
        let session = AccountSession(provider: provider, defaults: store)
        #expect(session.needsSignIn)
        #expect(await session.signIn(presenting: nil))
        #expect(session.account?.email == "priya@example.com")

        let relaunched = AccountSession(provider: provider, defaults: store)
        await relaunched.restore()
        #expect(!relaunched.needsSignIn)

        relaunched.signOut()
        #expect(provider.signedOut)
        #expect(AccountSession(provider: provider, defaults: store).needsSignIn)
    }

    @Test("A restore that can't tell keeps the stored account; a fresh one replaces it")
    func restore() async {
        let store = defaults()
        let provider = FakeProvider()
        let session = AccountSession(provider: provider, defaults: store)
        await session.signIn(presenting: nil)
        await session.restore()
        #expect(session.account?.name == "Priya Shah")
        provider.restored = Account(name: "Priya S.", email: "priya@example.com")
        await session.restore()
        #expect(session.account?.name == "Priya S.")
    }

    @Test("Closing the browser shows nothing; a real failure says why")
    func failures() async {
        let provider = FakeProvider()
        let session = AccountSession(provider: provider, defaults: defaults())
        provider.next = .failure(CancellationError())
        #expect(await !session.signIn(presenting: nil))
        #expect(session.problem == nil)
        provider.next = .failure(URLError(.notConnectedToInternet))
        #expect(await !session.signIn(presenting: nil))
        #expect(session.problem?.hasPrefix("Couldn\u{2019}t sign in:") == true)
        #expect(session.needsSignIn)
    }
}

