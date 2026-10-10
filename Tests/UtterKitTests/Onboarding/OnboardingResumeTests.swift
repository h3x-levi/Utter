import Testing
@testable import UtterKit

/// The rule that decides which onboarding step an interrupted first run reopens on.
///
/// Worth testing because the interruption is not hypothetical: granting Accessibility
/// access sends the user to System Settings part-way through the flow. Only the pure form is exercised - the
/// `resumeStep(stepCount:)` overload reads `UserDefaults.standard`, and a test that
/// wrote there would be editing the developer's own onboarding state.
@Suite("Onboarding resume")
struct OnboardingResumeTests {

    /// The flow's real step count, so the boundary cases below are the ones that ship.
    private static let steps = OnboardingViewModel.Step.allCases.count

    @Test("An interrupted run reopens on the step it left")
    func resumesTheRecordedStep() {
        #expect(OnboardingState.resumeStep(stored: 1, completed: false,
                                           stepCount: Self.steps) == 1)
    }

    @Test("The last step is resumable, not clamped away")
    func lastStepSurvives() {
        #expect(OnboardingState.resumeStep(stored: Self.steps - 1, completed: false,
                                           stepCount: Self.steps) == Self.steps - 1)
    }

    @Test("A step from a build with more steps lands on the last one")
    func clampsAStepBeyondTheEnd() {
        // The old four-step flow stored up to 3; its model step and ready step both land on Try it.
        #expect(OnboardingState.resumeStep(stored: 9, completed: false,
                                           stepCount: Self.steps) == Self.steps - 1)
        // The off-by-one that a shrunk flow actually produces: the old last index.
        #expect(OnboardingState.resumeStep(stored: Self.steps, completed: false,
                                           stepCount: Self.steps) == Self.steps - 1)
    }

    @Test("A negative stored step falls back to the beginning")
    func clampsBelowZero() {
        // `UserDefaults.integer(forKey:)` will hand back whatever is under the key,
        // including a value another version or a defaults write put there.
        #expect(OnboardingState.resumeStep(stored: -3, completed: false,
                                           stepCount: Self.steps) == 0)
    }

    @Test("Nothing recorded starts at the welcome step")
    func absentStepStartsAtZero() {
        // A missing key reads as 0, which is the welcome step - no special case needed.
        #expect(OnboardingState.resumeStep(stored: 0, completed: false,
                                           stepCount: Self.steps) == 0)
    }

    @Test("A completed run never resumes mid-flow")
    func completedRunsStartOver() {
        // `markCompleted` clears the stored step, so this is the second guard: someone
        // who deliberately replays onboarding gets the whole flow, not the tail of the
        // one they finished.
        #expect(OnboardingState.resumeStep(stored: 3, completed: true,
                                           stepCount: Self.steps) == 0)
    }

    @Test("A flow with no steps cannot produce an index")
    func zeroStepCountIsSafe() {
        // Guards the `stepCount - 1` upper bound: -1 would be a crash the first time
        // anything indexed with it.
        #expect(OnboardingState.resumeStep(stored: 3, completed: false,
                                           stepCount: 0) == 0)
    }

    @Test("Every stored value resolves to a step that exists")
    func alwaysInRange() {
        for stored in -5...20 {
            let resolved = OnboardingState.resumeStep(stored: stored, completed: false,
                                                      stepCount: Self.steps)
            #expect((0..<Self.steps).contains(resolved))
        }
    }

    @Test("Required setup steps cannot advance before they work")
    func requiredStepsGateContinue() {
        #expect(!OnboardingState.canAdvance(step: 1, microphoneGranted: false,
                                            accessibilityGranted: true, dictated: false))
        #expect(!OnboardingState.canAdvance(step: 1, microphoneGranted: true,
                                            accessibilityGranted: false, dictated: false))
        #expect(OnboardingState.canAdvance(step: 1, microphoneGranted: true,
                                           accessibilityGranted: true, dictated: false))
        #expect(!OnboardingState.canAdvance(step: 2, microphoneGranted: true,
                                            accessibilityGranted: true, dictated: false))
        #expect(OnboardingState.canAdvance(step: 2, microphoneGranted: true,
                                           accessibilityGranted: true, dictated: true))
    }
}
