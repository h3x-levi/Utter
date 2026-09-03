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
@MainActor
final class PillDemoPlayer: ObservableObject {
    private let beat: TimeInterval = 2.2
    let model = PillStateModel()
    @Published var beatIndex = 0
    private var timer: Timer?
    private var started = false

    struct Beat {
        let state: PillState
        let caption: String
        let level: Float
        let elapsed: Int
        let preview: String
    }

    var beats: [Beat] {
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

    func start() {
        guard !started else { return }
        started = true
        apply(beats[0])

        guard !MotionPreference.shared.reduceMotion else { return }

        timer = Timer.scheduledTimer(withTimeInterval: beat, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advance()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        started = false
    }

    private func advance() {
        beatIndex = (beatIndex + 1) % beats.count
        withAnimation(Motion.layout) {
            apply(beats[beatIndex])
        }
    }

    private func apply(_ beat: Beat) {
        model.state = beat.state
        model.level = beat.level
        model.elapsed = beat.elapsed
        model.previewText = beat.preview
    }
}

struct PillDemoView: View {
    @StateObject private var player = PillDemoPlayer()

    var body: some View {
        VStack(spacing: Space.x4) {
            ZStack {
                PillContent(model: player.model)
            }
            .frame(height: PillMetrics.windowHeight)

            Text(player.beats[player.beatIndex].caption)
                .typo(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 34, alignment: .top)
                .id(player.beatIndex)
                .transition(.opacity)

            beatIndicator
        }
        .onAppear { player.start() }
        .onDisappear { player.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A demonstration of the dictation pill")
        .accessibilityValue(player.beats[player.beatIndex].caption)
    }

    private var beatIndicator: some View {
        HStack(spacing: Space.x1) {
            ForEach(player.beats.indices, id: \.self) { index in
                Circle()
                    .fill(index == player.beatIndex ? Tint.accent : Ink.tertiary.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .animation(Motion.layout, value: player.beatIndex)
    }
}
