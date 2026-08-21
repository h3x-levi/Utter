import SwiftUI

/// A live, working pill, shown inside onboarding.
///
/// Onboarding used to *describe* the pill in prose — "hold your hotkey anywhere
/// and your words are typed into whatever app you're using" — while the actual
/// pill sat on screen the whole time, unexplained. Two bento tiles of text asking
/// the user to imagine a thing they can already see.
///
/// This renders `PillContent`, the same view the floating panel hosts, driven
/// through the same `PillStateModel`. It is not a mockup, a screenshot, or a
/// re-drawn approximation: change the pill's design and this changes with it,
/// because it *is* the pill. That matters more than it sounds — a hand-drawn
/// facsimile is a second source of truth that silently rots.
///
/// The states are stepped on a timer rather than driven by real audio, which is
/// the one honest exception to "animation must come from real signals": there is
/// no microphone input during onboarding, and the timer is animating a *scripted
/// demonstration*, not misrepresenting live data. The label above always names the
/// state being shown, so nothing is implied that isn't happening.
struct PillDemoView: View {
    /// Seconds each beat of the demo holds.
    private let beat: TimeInterval = 2.2

    @StateObject private var model = PillStateModel()
    @ObservedObject private var motion = MotionPreference.shared
    @State private var beatIndex = 0
    @State private var timer: Timer?
    /// Whether `start()` has already run for this appearance.
    ///
    /// A `timer == nil` check would not do: under Reduce Motion no timer is ever
    /// created, so that test can never become false and every `onAppear` would
    /// re-run setup.
    @State private var started = false

    /// One beat of the demonstration: a pill state plus what to call it.
    private struct Beat {
        let state: PillState
        let caption: String
        let level: Float
        let elapsed: Int
        let preview: String
    }

    private var beats: [Beat] {
        [
            Beat(state: .idle,
                 caption: "Resting. It stays out of the way.",
                 level: 0, elapsed: 0, preview: ""),
            Beat(state: .recording,
                 caption: "Hold \(UserData.shared.hotkeyName) — the meter follows your voice.",
                 level: 0.55, elapsed: 3, preview: ""),
            Beat(state: .recording,
                 caption: "What it hears appears as you speak.",
                 level: 0.4, elapsed: 6, preview: "send the design doc to the team"),
            Beat(state: .processing(.transcribing),
                 caption: "Release, and it transcribes on this Mac.",
                 level: 0, elapsed: 0, preview: ""),
            Beat(state: .idle,
                 caption: "Your words are typed where you were already working.",
                 level: 0, elapsed: 0, preview: ""),
        ]
    }

    var body: some View {
        VStack(spacing: Space.x4) {
            // A fixed-height stage so the surrounding layout doesn't shift as the
            // pill grows and shrinks between states.
            ZStack {
                // No hover control in the demo: it is a scripted playback, not a live pill.
                PillContent(model: model)
            }
            .frame(height: PillMetrics.windowHeight)

            Text(beats[beatIndex].caption)
                .typo(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 34, alignment: .top)
                // Keyed to the index so SwiftUI crossfades between captions
                // instead of blurring one string into the next.
                .id(beatIndex)
                .transition(.opacity)

            beatIndicator
        }
        .onAppear { start() }
        .onDisappear { stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A demonstration of the dictation pill")
        .accessibilityValue(beats[beatIndex].caption)
    }

    /// Which beat is showing. Dots rather than a progress bar: this loops, so a
    /// bar would imply an end that never comes.
    private var beatIndicator: some View {
        HStack(spacing: Space.x1) {
            ForEach(beats.indices, id: \.self) { index in
                Circle()
                    .fill(index == beatIndex ? Tint.accent : Ink.tertiary.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .animation(Motion.layout, value: beatIndex)
    }

    // MARK: - Playback

    private func start() {
        // Idempotent: SwiftUI may call `onAppear` more than once for the same view
        // (re-parenting, a step transition that reuses the identity), and a second
        // `scheduledTimer` would orphan the first — leaving a timer that wakes the
        // main thread every couple of seconds for the rest of the process's life.
        guard !started else { return }
        started = true

        apply(beats[0])

        // Reduce Motion: show the resting pill and the first caption, and stop.
        // Someone who has asked the system to stop moving things has not asked for
        // a five-beat animation, and the pill is still shown — which was the point.
        guard !motion.reduceMotion else { return }

        timer = Timer.scheduledTimer(withTimeInterval: beat, repeats: true) { _ in
            Task { @MainActor in advance() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        started = false
    }

    @MainActor
    private func advance() {
        beatIndex = (beatIndex + 1) % beats.count
        withAnimation(Motion.layout) { apply(beats[beatIndex]) }
    }

    private func apply(_ beat: Beat) {
        model.state = beat.state
        model.level = beat.level
        model.elapsed = beat.elapsed
        model.previewText = beat.preview
    }
}
