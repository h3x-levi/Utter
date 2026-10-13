import Testing
import AppKit
import SwiftUI
@testable import UtterKit
@testable import UtterCore

/// A model whose timers only fire when the test says so.
private final class ManualClock {
    var pending: [(TimeInterval, () -> Void)] = []

    func install(on model: PillStateModel) {
        model.schedule = { [unowned self] delay, work in pending.append((delay, work)) }
        model.previewEnabled = { false }
    }

    func fire() {
        let due = pending
        pending = []
        due.forEach { $0.1() }
    }
}

private func model(_ clock: ManualClock = ManualClock()) -> PillStateModel {
    let model = PillStateModel()
    clock.install(on: model)
    model.offersHandsFree = true
    return model
}

@Suite("Pill look")
struct PillLookTests {
    @Test("Every capture state has the look the brief describes")
    func looksPerState() {
        let cases: [(PillState, PillLook)] = [
            (.preparing, .rest),
            (.idle, .rest),
            (.recording, .listening(nil)),
            (.handsFree, .listening(.lock)),
            (.capturingNote, .listening(.note)),
            (.capturingMemory, .listening(.memory)),
            (.processing(.transcribing), .thinking),
            (.error("Microphone is busy"), .message("Microphone is busy", .error)),
            (.notice("Reminder saved"), .message("Reminder saved", .notice)),
            (.island("hello"), .island("hello")),
        ]
        for (state, look) in cases {
            #expect(PillLook.derive(state: state, revealed: false, unseen: nil, celebrating: false,
                                    offersHandsFree: true) == look, "\(state)")
        }
    }

    @Test("Hover opens the resting pill, and offers hands-free only once the model is ready")
    func hover() {
        #expect(PillLook.derive(state: .idle, revealed: true, unseen: nil, celebrating: false,
                                offersHandsFree: true) == .hover(handsFree: true))
        #expect(PillLook.derive(state: .preparing, revealed: true, unseen: nil, celebrating: false,
                                offersHandsFree: true) == .hover(handsFree: false))
        let clock = ManualClock()
        let pill = model(clock)
        pill.state = .idle
        pill.pointer(inside: true)
        #expect(pill.look == .rest, "a pointer passing by does not open it")
        clock.fire()
        #expect(pill.look == .hover(handsFree: true))
        pill.pointer(inside: false)
        #expect(pill.look == .rest, "leaving is immediate")

        pill.pointer(inside: true)
        pill.pointer(inside: false)
        clock.fire()
        #expect(pill.look == .rest, "an intent the pointer abandoned never opens it")
    }

    @Test("A delivered turn smiles briefly, then rests")
    func doneThenRest() {
        let clock = ManualClock()
        let pill = model(clock)
        pill.state = .recording
        pill.state = .processing(.typing)
        pill.state = .idle
        #expect(pill.look == .done)
        clock.fire()
        #expect(pill.look == .rest)
    }

    @Test("An unseen error collapses to a dot that stays until it has been read")
    func errorDotLifecycle() {
        let clock = ManualClock()
        let pill = model(clock)
        pill.state = .error("Microphone is busy")
        pill.state = .idle
        #expect(pill.look == .dot(.error))
        clock.fire()
        #expect(pill.look == .dot(.error), "no timer may take an unread message away")

        pill.pointer(inside: true)
        clock.fire()
        #expect(pill.look == .message("Microphone is busy", .error))
        pill.pointer(inside: false)
        #expect(pill.look == .message("Microphone is busy", .error), "it lingers briefly after the pointer leaves")
        clock.fire()
        #expect(pill.look == .rest)
        #expect(pill.unseen == nil)
    }

    @Test("A click reopens the dot's message, and it rests once that has run its course")
    func clickReopens() {
        let clock = ManualClock()
        let pill = model(clock)
        pill.state = .error("Microphone is busy")
        pill.state = .idle
        #expect(pill.look == .dot(.error))
        pill.click()
        #expect(pill.look == .message("Microphone is busy", .error))
        clock.fire()
        #expect(pill.look == .rest)
    }

    @Test("A notice nobody saw leaves no dot; only errors wait to be read")
    func unseenNoticeLeavesNoDot() {
        let pill = model(ManualClock())
        pill.state = .notice("Cancelled")
        pill.state = .idle
        #expect(pill.look == .rest)
        #expect(pill.unseen == nil)
    }

    @Test("A message read while it was showing leaves no dot behind")
    func seenMessageLeavesNoDot() {
        let clock = ManualClock()
        let pill = model(clock)
        pill.state = .error("No speech detected")
        pill.pointer(inside: true)
        clock.fire()
        pill.pointer(inside: false)
        pill.state = .idle
        #expect(pill.look == .rest)
    }

    @Test("A new turn replaces a waiting dot")
    func newTurnClearsTheDot() {
        let pill = model()
        pill.state = .error("No speech detected")
        pill.state = .idle
        pill.state = .recording
        #expect(pill.unseen == nil)
        pill.state = .processing(.typing)
        pill.state = .error("Transcription failed")
        pill.state = .recording
        pill.state = .idle
        #expect(pill.look == .rest)
    }

    @Test("Words appear above the pill only with the preference on")
    func captionNeedsThePreference() {
        let off = model()
        off.state = .recording
        #expect(off.presentation.caption == false)

        let on = model()
        on.previewEnabled = { true }
        on.state = .recording
        #expect(on.presentation.caption)
        on.state = .processing(.transcribing)
        #expect(on.presentation.caption == false)
    }

    @Test("The pill hides only in a resting look")
    func onlyRestingLooksHide() {
        #expect(PillLook.rest.isResting)
        #expect(PillLook.hover(handsFree: true).isResting)
        for look: PillLook in [.listening(nil), .thinking, .done, .message("x", .error), .dot(.error), .island("x")] {
            #expect(!look.isResting, "\(look)")
        }
    }

    @Test("Each look drives the bars it should, and nothing moves at rest")
    func barsPerLook() {
        #expect(PillLook.rest.bars == .hidden)
        #expect(PillLook.dot(.error).bars == .hidden)
        #expect(PillLook.island("x").bars == .hidden)
        #expect(PillLook.hover(handsFree: true).bars == .rest)
        #expect(PillLook.listening(nil).bars == .voice)
        #expect(PillLook.thinking.bars == .thinking)
        #expect(PillLook.done.bars == .hidden, "the tick takes their place")
        #expect(PillLook.message("x", .error).bars == .hidden, "the exclamation takes their place")
        #expect(PillLook.message("x", .notice).bars == .flat)
    }

    @Test("VoiceOver hears the message on the dot, not only the word error")
    @MainActor
    func accessibilityCarriesTheMessage() {
        let pill = model()
        pill.state = .error("Speech model missing")
        pill.state = .idle
        #expect(pill.accessibilityValue.hasPrefix("Speech model missing"))
        #expect(pill.accessibilityLabel == "Utter, error")
    }
}

@Suite("Pill geometry")
struct PillGeometryTests {
    @Test("The sizes are the small ones the owner asked for")
    func sizes() {
        #expect(PillMetrics.shellSize(for: .rest) == CGSize(width: 32, height: 6))
        #expect(PillMetrics.shellSize(for: .hover(handsFree: true)) == CGSize(width: 48, height: 16))
        #expect(PillMetrics.shellSize(for: .listening(nil)) == CGSize(width: 64, height: 20))
        #expect(PillMetrics.shellSize(for: .listening(.lock)) == CGSize(width: 80, height: 20))
        #expect(PillMetrics.shellSize(for: .listening(.note)) == PillMetrics.shellSize(for: .listening(.memory)))
        #expect(PillMetrics.shellSize(for: .thinking) == PillMetrics.shellSize(for: .listening(nil)))
        #expect(PillMetrics.shellSize(for: .dot(.error)) == CGSize(width: 8, height: 8))
    }

    @Test("A message widens the pill just enough for the flat bars and its words, a long one is capped")
    func messageWidth() {
        let short = PillMetrics.messageWidth("No speech")
        let medium = PillMetrics.messageWidth("Microphone is busy")
        let words = ceil(("No speech" as NSString).size(withAttributes: [.font: PillMetrics.messageFont]).width)
        #expect(short == ceil(PillMetrics.messagePadding * 2 + PillBarGeometry.span + PillMetrics.messageGap + words))
        #expect(medium > short && medium < PillMetrics.messageMaxWidth)
        #expect(PillMetrics.messageWidth(String(repeating: "word ", count: 40)) == PillMetrics.messageMaxWidth)
    }

    @Test("The island scrolls past six lines and stays compact")
    func islandBounds() {
        let short = PillMetrics.shellSize(for: .island("Thanks Priya, Thursday works."))
        let long = PillMetrics.shellSize(for: .island(String(repeating: "Thanks Priya, Thursday works. ", count: 40)))
        #expect(short.width == 360)
        #expect(short.height < long.height)
        #expect(long.height <= 175)
        let line = ceil(NSLayoutManager().defaultLineHeight(for: .preferredFont(forTextStyle: .body)))
        #expect(PillMetrics.islandTextHeight(for: String(repeating: "word ", count: 400)) == line * 6)
    }

    @Test("The panel is the shell plus a small margin, never a permanent wide area")
    func panelHugsTheShell() {
        for look: PillLook in [.rest, .hover(handsFree: true), .listening(nil), .listening(.lock), .thinking,
                               .done, .message("Microphone is busy", .error), .dot(.error), .island("hello")] {
            let shell = PillMetrics.shellSize(for: look)
            let panel = PillMetrics.panelSize(for: look, caption: false)
            #expect(panel.width - shell.width <= PillMetrics.margin * 2 + 1, "\(look)")
            #expect(panel.height - shell.height <= PillMetrics.margin * 2 + 1, "\(look)")
            #expect(panel.width.truncatingRemainder(dividingBy: 2) == 0, "even, so the shell centres on a point")
        }
        #expect(PillMetrics.panelSize(for: .rest, caption: false).width < 80)
    }

    @Test("Every panel shares the anchor, so changing state never moves the pill")
    func anchoredAtTheBottomCentre() {
        let anchor = CGPoint(x: 700, y: 40)
        for look: PillLook in [.rest, .listening(nil), .island("hello")] {
            let frame = PillMetrics.panelFrame(anchor: anchor, size: PillMetrics.panelSize(for: look, caption: false))
            #expect(frame.midX == anchor.x)
            #expect(frame.minY + PillMetrics.margin == anchor.y)
            let shell = PillMetrics.shellRect(for: look, in: frame.size)
            #expect(shell.midX == frame.width / 2)
            #expect(shell.maxY == frame.height - PillMetrics.margin, "bottom edge in the flipped space")
        }
    }

    @Test("The sliver and the dot are bigger to click than to see")
    func forgivingTargets() {
        let bounds = PillMetrics.panelSize(for: .dot(.error), caption: false)
        let hit = PillMetrics.hitRect(for: .dot(.error), in: bounds)
        #expect(hit.width >= 22 && hit.height >= 22)
        let rest = PillMetrics.hitRect(for: .rest, in: PillMetrics.panelSize(for: .rest, caption: false))
        #expect(rest.height >= 14)
    }
}

@Suite("Pill motion")
struct PillMotionTests {
    /// The furthest past its target a spring travels, as a fraction of the distance.
    private func overshoot(_ spring: Spring) -> Double {
        stride(from: 0.0, through: spring.settlingDuration, by: 0.002)
            .map { spring.value(target: 1.0, time: $0) - 1 }.max() ?? 0
    }

    @Test("Opening may overshoot a little, closing and the island's return never do")
    func motionPerChange() {
        #expect(PillMotion.between(.rest, .hover(handsFree: true)) == .hover)
        #expect(PillMotion.between(.hover(handsFree: true), .rest) == .close)
        #expect(PillMotion.between(.rest, .listening(nil)) == .open)
        #expect(PillMotion.between(.listening(nil), .island("x")) == .open)
        #expect(PillMotion.between(.island("x"), .rest) == .close)
        #expect(PillMotion.between(.message("Microphone is busy", .error), .dot(.error)) == .close)
        #expect(PillMotion.close.spring.bounce == 0)
        for motion in [PillMotion.open, .close, .hover] {
            #expect(motion.spring.bounce <= 0.2, "Apple's caution is 0.4; the pill stays well under")
            #expect(motion.settle(reduceMotion: true) <= 0.18)
        }
    }

    @Test("The shell's overshoot stays inside the panel's margin, even for the island")
    func overshootFitsTheMargin() {
        let island = PillMetrics.shellSize(for: .island(String(repeating: "word ", count: 400)))
        let rest = PillMetrics.shellSize(for: .rest)
        let past = overshoot(PillMotion.open.spring)
        #expect(past > 0 && past < 0.03)
        #expect((island.width - rest.width) / 2 * past < PillMetrics.margin)
        #expect((island.height - rest.height) * past < PillMetrics.margin)
        #expect(overshoot(PillMotion.close.spring) < 0.001)
    }

    @Test("The morph settles in well under a second, and the panel waits for it")
    func settleTimes() {
        let open = PillMotion.open.settle(reduceMotion: false)
        #expect(abs(open - 0.79) < 0.03, "Spring(0.42, 0.2) measured at 0.79 s")
        #expect(open > 0.7, "the old fixed 0.7 s shrink clipped this tail")
        #expect(PillMotion.close.settle(reduceMotion: false) < open)
    }

    @Test("The island's words start once the shape is most of the way there")
    func islandTextFollowsTheShape() {
        let progress = PillMotion.open.spring.value(target: 1.0, time: PillMetrics.islandTextDelay)
        #expect(progress >= 0.8 && progress < 1, "the shape leads, the words follow: \(progress)")
        #expect(PillMetrics.islandTextDelay >= 0.12 && PillMetrics.islandTextDelay <= 0.18)
    }

    @Test("Hover waits for intent, the done tick is whole inside its hold, and Copied is readable")
    func shortTimings() {
        #expect(PillMetrics.hoverIntent >= 0.08 && PillMetrics.hoverIntent <= 0.12)
        #expect(PillMetrics.tickDelay + PillMetrics.tickDraw <= PillMetrics.doneHold)
        #expect(PillMetrics.copiedHold >= 0.5 && PillMetrics.copiedHold <= 1)
    }

    @Test("The voice springs are calm and quick, the centre bar quickest")
    func voiceSprings() {
        let responses = (0..<PillBarGeometry.count).map(PillBarGeometry.voiceResponse)
        #expect(responses.allSatisfy { $0 >= 0.18 && $0 <= 0.26 })
        #expect(responses[3] == responses.min() && responses[0] == responses.max())
        #expect(PillBarGeometry.voiceBounce >= 0.15 && PillBarGeometry.voiceBounce <= 0.25)
    }

    @Test("The corner radius follows the size: a capsule until the island's corners take over")
    func cornerRadiusFollowsSize() {
        for look: PillLook in [.rest, .hover(handsFree: true), .listening(nil), .listening(.lock), .dot(.error),
                               .message("Microphone is busy", .error)] {
            let size = PillMetrics.shellSize(for: look)
            #expect(PillMetrics.cornerRadius(for: size) == size.height / 2, "\(look)")
        }
        #expect(PillMetrics.cornerRadius(for: PillMetrics.shellSize(for: .island("hello"))) == PillMetrics.islandCornerRadius)
        let heights = stride(from: 20.0, through: 160, by: 4).map { PillMetrics.cornerRadius(for: CGSize(width: 360, height: $0)) }
        #expect(zip(heights, heights.dropFirst()).allSatisfy { $1 >= $0 && $1 - $0 <= 2 }, "no step on the way up")
    }
}

/// The real panel, not a copy of its arithmetic.
@Suite("Pill window", .serialized)
@MainActor
struct PillWindowTests {
    private func pill(_ state: PillState) -> PillWindow {
        let pill = PillWindow(onLongPress: {}, onStartHandsFree: {})
        pill.stateModel.previewEnabled = { false }
        // A main-queue block cannot run inside this test's nested run loop; a timer can.
        pill.stateModel.schedule = { delay, work in
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { work() } }
        }
        pill.setState(state)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        return pill
    }

    private func hits(_ pill: PillWindow, _ point: CGPoint) -> Bool {
        let content = pill.contentView!
        return content.hitTest(content.convert(point, to: content.superview)) != nil
    }

    @Test("The panel shrinks to the listening shell and takes clicks only on it")
    func listeningHitRegion() {
        let pill = pill(.recording)
        #expect(pill.frame.size == PillMetrics.panelSize(for: .listening(nil), caption: false))
        let shell = pill.drawnShellRect
        #expect(shell.size == CGSize(width: 64, height: 20))
        #expect(hits(pill, CGPoint(x: shell.midX, y: shell.midY)))
        #expect(!hits(pill, CGPoint(x: shell.minX - 3, y: shell.midY)))
        #expect(!hits(pill, CGPoint(x: shell.midX, y: shell.minY - 3)))
    }

    @Test("Changing state keeps the pill where it was parked")
    func anchorHoldsAcrossStates() {
        let pill = pill(.idle)
        let midX = pill.frame.midX, bottom = pill.frame.minY
        pill.setState(.recording)
        pill.setState(.island("A transcript with nowhere to go"))
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        #expect(pill.frame.midX == midX)
        #expect(pill.frame.minY == bottom)
        #expect(pill.drawnShellRect.size.width == PillMetrics.islandWidth)
    }

    @Test("The pill sits at the bottom centre of the screen, above the Dock, and returns there when screens change")
    func fixedAtTheBottomCentre() throws {
        let pill = pill(.idle)
        let visible = try #require((NSApplication.shared.keyWindow?.screen ?? NSScreen.main)?.visibleFrame)
        let shellBottom = pill.frame.minY + PillMetrics.margin
        #expect(abs(pill.frame.midX - visible.midX) <= 0.5)
        #expect(pill.frame.midX == pill.frame.midX.rounded(), "whole points, so no width change moves the shell")
        #expect(shellBottom > visible.minY && shellBottom < visible.minY + 20)
        pill.setFrameOrigin(NSPoint(x: visible.minX + 40, y: visible.midY))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(abs(pill.frame.midX - visible.midX) <= 0.5)
        #expect(pill.frame.minY + PillMetrics.margin == shellBottom)
    }

    @Test("The panel holds both looks until the morph has settled, then hugs the new one")
    func shrinksOnlyOnceSettled() throws {
        let pill = pill(.island("A transcript with nowhere to go"))
        let island = pill.frame.size
        #expect(island == PillMetrics.panelSize(for: .island("A transcript with nowhere to go"), caption: false))
        pill.setState(.idle)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        #expect(pill.frame.size == island, "shrinking now would clip the closing island")
        let settle = PillMotion.close.settle(reduceMotion: MotionPreference.shared.reduceMotion)
        RunLoop.current.run(until: Date().addingTimeInterval(settle * 2 + 0.2))
        #expect(pill.frame.size == PillMetrics.panelSize(for: .rest, caption: false))
    }

    @Test("Nothing in the pill's layer tree is still animating once it rests")
    func quiescentAtRest() throws {
        let pill = pill(.processing(.transcribing))
        pill.setState(.idle)
        RunLoop.current.run(until: Date().addingTimeInterval(1.6))
        #expect(pill.stateModel.look == .rest)
        let now = CACurrentMediaTime()
        func running(_ layer: CALayer) -> [String] {
            let own = (layer.animationKeys() ?? []).filter { key in
                guard let animation = layer.animation(forKey: key) else { return false }
                return animation.repeatCount.isInfinite || animation.beginTime + animation.duration > now
            }
            return own + (layer.sublayers ?? []).flatMap(running)
        }
        let root = try #require(pill.contentView?.layer)
        #expect(running(root).isEmpty, "\(running(root))")
    }

    @Test("The open lock is reachable on the hovered pill")
    func lockIsClickable() throws {
        let pill = pill(.idle)
        pill.stateModel.pointer(inside: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let lock = try #require(PillMetrics.lockRect(for: pill.stateModel.look, in: pill.contentView!.bounds.size))
        #expect(pill.drawnShellRect.contains(lock))
        #expect(hits(pill, CGPoint(x: lock.midX, y: lock.midY)))
    }
}

@Suite("Pill bars")
struct PillBarTests {
    @Test("At rest the bars are the icon: outer tallest, symmetric, in MarkGeometry's proportions")
    func restIsTheIcon() {
        let bars = PillBarGeometry.rest(height: 16)
        #expect(bars == bars.reversed())
        #expect(bars[0] == bars.max() && bars[3] == bars.min())
        #expect(abs(bars[1] / bars[0] - MarkGeometry.rest[1] / MarkGeometry.rest[0]) < 0.01)
        #expect(bars[0] <= 16 - 6)
    }

    @Test("A louder voice lifts the bars, the outer ones highest, never past the capsule")
    func voiceLifts() {
        let quiet = PillBarGeometry.voice(level: 0.1, time: 3, height: 20, reduceMotion: true)
        let loud = PillBarGeometry.voice(level: 1, time: 3, height: 20, reduceMotion: true)
        #expect(zip(loud, quiet).allSatisfy { $0 > $1 })
        #expect(loud[0] > loud[3] && loud[6] > loud[3])
        #expect(loud.allSatisfy { $0 <= PillBarGeometry.tallest(height: 20) })
        let silent = PillBarGeometry.voice(level: 0, time: 3, height: 20, reduceMotion: false)
        #expect(silent == PillBarGeometry.flat(height: 20))
    }

    @Test("Each bar wobbles on its own, so the row never moves as one block")
    func barsWobbleApart() {
        let a = PillBarGeometry.voice(level: 0.6, time: 1, height: 20, reduceMotion: false)
        let b = PillBarGeometry.voice(level: 0.6, time: 1.2, height: 20, reduceMotion: false)
        let deltas = zip(a, b).map { $1 - $0 }
        #expect(Set(deltas.map { ($0 * 100).rounded() }).count > 3)
    }

    @Test("The thinking wave travels: each bar's cycle is offset from its neighbour's")
    func waveTravels() {
        let first = PillBarGeometry.wave(index: 0, height: 20), second = PillBarGeometry.wave(index: 1, height: 20)
        #expect(first != second)
        #expect(first.first == first.last, "the loop closes, so the repeat has no seam")
        let top = PillBarGeometry.tallest(height: 20), dot = PillBarGeometry.width
        #expect((first + second).allSatisfy { $0 >= dot - 0.001 && $0 <= top })
    }

    @Test("The bars stand inside the shell, clear of the lock or glyph and before the message")
    func barsFitTheShell() {
        for look: PillLook in [.hover(handsFree: true), .hover(handsFree: false), .listening(nil), .listening(.lock),
                               .listening(.note), .thinking, .done, .message("Microphone is busy", .error)] {
            let shell = PillMetrics.shellSize(for: look)
            let span = PillBarGeometry.span
            let centre = shell.width / 2 + PillMetrics.barsOffset(for: look)
            #expect(centre - span / 2 > 0 && centre + span / 2 < shell.width, "\(look)")
            if look.hasTrailingGlyph { #expect(centre + span / 2 <= shell.width - shell.height, "\(look)") }
        }
    }

    @MainActor
    @Test("The view hands the render server one spring per bar, a looping wave to think, and nothing at rest")
    func viewAnimations() throws {
        let levels = PillLevelSignal()
        let view = PillBarsView(levels: levels)
        view.frame = CGRect(x: 0, y: 0, width: PillBarGeometry.span, height: 20)
        view.layoutSubtreeIfNeeded()
        let bars = try #require(view.layer?.sublayers)
        #expect(bars.count == 7)

        func springs(_ bar: CALayer) -> [CASpringAnimation] {
            (bar.animationKeys() ?? []).filter { $0.hasPrefix("h") }.compactMap { bar.animation(forKey: $0) as? CASpringAnimation }
        }
        view.update(.voice, height: 20, reduceMotion: false)
        levels.value = 0.8
        levels.value = 0.2
        #expect(bars.allSatisfy { springs($0).count >= 2 }, "a new level adds to the spring in flight rather than replacing it")
        #expect(bars.allSatisfy { springs($0).allSatisfy { $0.isAdditive && ($0.toValue as? CGFloat) == 0 } })
        let before = bars.map { springs($0).count }
        levels.value = 0.2001
        #expect(bars.map { springs($0).count } == before, "a change below the noise floor sends nothing")
        let still = PillBarGeometry.voice(level: 0.8, time: 0, height: 20, reduceMotion: true)
        #expect(still[0] > still[3], "outer bars reach highest")

        view.update(.thinking, height: 20, reduceMotion: false)
        let waves = bars.compactMap { $0.animation(forKey: "wave") as? CAKeyframeAnimation }
        #expect(waves.count == 7)
        #expect(Set(waves.map(\.beginTime)).count == 7)
        #expect(bars.allSatisfy { springs($0).count <= 1 }, "the voice springs are folded in before the wave starts")

        view.update(.hidden, height: 6, reduceMotion: false)
        let left = bars.flatMap { bar in (bar.animationKeys() ?? []).compactMap { bar.animation(forKey: $0) } }
        #expect(left.allSatisfy { $0.repeatCount == 0 && $0.duration <= 0.12 }, "only the fade-out, nothing that loops")
        #expect(bars.allSatisfy { $0.opacity == 0 && $0.animation(forKey: "wave") == nil })
        let keys = bars.map { $0.animationKeys() ?? [] }
        levels.value = 0.9
        #expect(bars.map { $0.animationKeys() ?? [] } == keys, "a mic level at rest starts nothing")
    }
}

@Suite("Pill note destination")
struct PillNoteDestinationTests {
    private static let openNote = Note(id: UUID(), title: "", body: "Standup notes\nships today",
                                       source: .dictated)

    @Test("An open note is named as the destination")
    func appendsToTheOpenNote() {
        let destination = NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                                        selectedID: Self.openNote.id,
                                                        notes: [Self.openNote])
        #expect(destination == .appending(id: Self.openNote.id, title: "Standup notes"))
        #expect(destination.label == "Adding to Standup notes")
    }

    @Test("With the preference off, a new note is the destination even with one open")
    func preferenceWins() {
        let destination = NoteCaptureDestination.resolve(appendsToOpenNote: false,
                                                        selectedID: Self.openNote.id,
                                                        notes: [Self.openNote])
        #expect(destination == .newNote)
        #expect(destination.label == "New note")
    }

    @Test("A selection that no longer exists falls back to a new note")
    func staleSelectionDoesNotSwallowTheCapture() {
        let destination = NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                                        selectedID: UUID(),
                                                        notes: [Self.openNote])
        #expect(destination == .newNote)
    }

    @Test("Nothing open means a new note")
    func nothingOpen() {
        #expect(NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                               selectedID: nil,
                                               notes: [Self.openNote]) == .newNote)
        #expect(NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                               selectedID: Self.openNote.id,
                                               notes: []) == .newNote)
    }

    @Test("An untitled note is still named, not left blank")
    func blankNoteHasALabel() {
        let blank = Note(id: UUID(), source: .dictated)
        let destination = NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                                        selectedID: blank.id,
                                                        notes: [blank])
        #expect(destination.label == "Adding to Untitled note")
    }
}

@Suite("Pill island")
@MainActor
struct PillIslandTests {
    @Test("Save as note files a new dictated note and leaves the open note, where note capture adds, alone")
    func saveAsNote() {
        let open = Note(id: UUID(), body: "Standup notes", source: .typed)
        let store = NoteStore(storageDir: nil, seed: [open], selectedID: open.id)
        PillIsland.saveAsNote("Thanks Priya, Thursday works.", in: store)
        #expect(store.notes.count == 2)
        #expect(store.notes.first?.body == "Thanks Priya, Thursday works.")
        #expect(store.notes.first?.source == .dictated)
        #expect(store.selectedNoteID == open.id)
    }
}

@Suite("Pill live transcript")
struct PillLiveTranscriptTests {
    @Test("Elapsed seconds read as m:ss")
    func elapsedFormatting() {
        let model = PillStateModel()
        for (seconds, expected) in [(0, "0:00"), (7, "0:07"), (59, "0:59"),
                                    (60, "1:00"), (605, "10:05"), (3_600, "60:00")] {
            model.elapsed = seconds
            #expect(model.elapsedText == expected)
        }
    }

    @Test("A transcript that fits is left alone")
    func shortTranscriptUntouched() {
        let text = "send the design doc to the team"
        #expect(LiveTranscript.tail(of: text) == text)
        #expect(LiveTranscript.tail(of: "") == "")
    }

    @Test("A long transcript keeps its newest words")
    func longTranscriptKeepsTheEnd() {
        let words = (1...200).map { "word\($0)" }.joined(separator: " ")
        let tail = LiveTranscript.tail(of: words, maxCharacters: 60)
        #expect(tail.hasSuffix("word200"))
        #expect(tail.count <= 61, "the ellipsis is the only thing added")
        #expect(!tail.contains("word1 "), "the head is what gets dropped")
    }

    @Test("The tail starts on a whole word")
    func tailStartsOnAWordBoundary() {
        let text = "alpha bravo charlie delta echo foxtrot"
        #expect(LiveTranscript.tail(of: text, maxCharacters: 14) == "\u{2026}echo foxtrot")
        #expect(LiveTranscript.tail(of: text, maxCharacters: 13) == "\u{2026}echo foxtrot")
    }

    @Test("A single unbroken token is truncated rather than emptied")
    func tailHandlesTextWithNoSpaces() {
        let text = String(repeating: "x", count: 300)
        #expect(LiveTranscript.tail(of: text, maxCharacters: 50) == "\u{2026}" + String(repeating: "x", count: 50))
    }

    @Test("A trailing space does not leave the tail empty")
    func tailWithOnlyOneSpace() {
        let text = String(repeating: "y", count: 100) + " "
        #expect(LiveTranscript.tail(of: text, maxCharacters: 10).contains("y"))
    }
}

/// Every look in light and dark, over a busy and a plain backdrop, captured by the window server so
/// the shadow is in the picture.
@Suite("Pill snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZPillSnapshots {
    private static let transcript = "Thanks Priya, Thursday at two works for me. I\u{2019}ll bring the draft and we can go "
        + "through the numbers together, then send the summary to the team before Friday."

    private static let scenarios: [(String, (PillStateModel) -> Void)] = [
        ("rest", { $0.state = .idle }),
        ("hover", { $0.state = .idle; $0.pointer(inside: true) }),
        ("listening", { $0.state = .recording; $0.level = 0.7 }),
        ("hands-free", { $0.state = .handsFree; $0.level = 0.5 }),
        ("note", { $0.state = .capturingNote; $0.level = 0.6 }),
        ("memory", { $0.state = .capturingMemory; $0.level = 0.4 }),
        ("caption", { $0.previewEnabled = { true }; $0.state = .recording; $0.previewText = "Thanks Priya, Thursday at two works for me" }),
        ("thinking", { $0.state = .processing(.transcribing) }),
        ("done", { $0.state = .processing(.typing); $0.state = .idle }),
        ("error", { $0.state = .error("Microphone is busy") }),
        ("error-dot", { $0.state = .error("Microphone is busy"); $0.state = .idle }),
        ("notice", { $0.state = .notice("Reminder saved") }),
        ("island", { $0.state = .island(transcript) }),
    ]

    @Test func everyLook() throws {
        for (name, drive) in Self.scenarios {
            for dark in [false, true] {
                for busy in [true, false] {
                    let model = PillStateModel()
                    model.schedule = { delay, work in if delay <= PillMetrics.hoverIntent { work() } }
                    model.previewEnabled = { false }
                    model.offersHandsFree = true
                    drive(model)
                    try render(model, "pill-\(name)-\(busy ? "busy" : "plain")", dark: dark, busy: busy)
                }
            }
        }
    }

    /// The island rising out of the listening capsule, a few frames in. Capture latency makes the
    /// times approximate; the strip shows one shape growing, not two crossing.
    @Test func islandRise() throws {
        let model = PillStateModel()
        model.schedule = { _, _ in }
        model.previewEnabled = { false }
        model.state = .recording
        let (window, host) = try stage(model, panel: PillMetrics.panelSize(for: .island(Self.transcript), caption: false),
                                       dark: false, busy: true)
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        model.state = .island(Self.transcript)
        for frame in 0..<5 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
            try SnapshotCanvas.capture(window, view: host, "pill-island-rise-\(frame)", dark: false)
        }
    }

    /// The meeting offer card at the size its window is created with, plain and carrying a failure.
    @Test func meetingOffer() throws {
        for failure in [nil, SystemAudioCapture.PermissionState.denied.message] {
            for dark in [false, true] {
                let model = MeetingOfferModel()
                model.contentVisible = true
                model.failure = failure
                try SnapshotCanvas.write(MeetingOfferView(title: MeetingOfferMetrics.defaultTitle, model: model, onAccept: {}, onDecline: {}),
                                         failure == nil ? "meeting-offer" : "meeting-offer-failed",
                                         size: MeetingOfferMetrics.size(message: failure), dark: dark)
            }
        }
    }

    private static let canvas = CGSize(width: 440, height: 260)

    private func backdrop(dark: Bool, busy: Bool) -> some View {
        ZStack {
            if busy {
                LinearGradient(colors: dark ? [Color(red: 0.12, green: 0.18, blue: 0.36), Color(red: 0.42, green: 0.16, blue: 0.24)]
                                            : [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.99, green: 0.74, blue: 0.48)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<9, id: \.self) { row in
                        Text("Quarterly planning notes, row \(row): budgets, owners and the launch checklist")
                            .font(.system(size: 12))
                            .foregroundStyle(dark ? Color.white.opacity(0.75) : Color.black.opacity(0.7))
                    }
                }
                .padding(18)
                Circle().fill(Color.yellow.opacity(0.7)).frame(width: 90).offset(x: 120, y: 70)
                Circle().fill(Color.green.opacity(0.6)).frame(width: 60).offset(x: -140, y: 80)
            } else {
                dark ? Color(white: 0.11) : Color(white: 0.96)
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private func render(_ model: PillStateModel, _ name: String, dark: Bool, busy: Bool) throws {
        let panel = PillMetrics.panelSize(for: model.look, caption: model.presentation.caption)
        let (window, host) = try stage(model, panel: panel, dark: dark, busy: busy)
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        try SnapshotCanvas.capture(window, view: host, name, dark: dark)
    }

    /// The pill in its own dark view over the backdrop, in one on-screen window, as the panel draws it.
    private func stage(_ model: PillStateModel, panel: CGSize, dark: Bool, busy: Bool) throws -> (NSWindow, NSView) {
        let canvas = CGRect(origin: .zero, size: Self.canvas)
        let host = NSView(frame: canvas)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let ground = NSHostingView(rootView: backdrop(dark: dark, busy: busy))
        ground.frame = canvas
        let pill = NSHostingView(rootView: PillRootView(model: model, onStartHandsFree: {}, onCloseIsland: {}))
        pill.appearance = PillWindow.darkAppearance
        pill.frame = CGRect(x: (canvas.width - panel.width) / 2, y: 0, width: panel.width, height: panel.height)
        host.addSubview(ground)
        host.addSubview(pill)
        let window = NSWindow(contentRect: canvas, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        SnapshotCanvas.center(window)
        window.orderFrontRegardless()
        return (window, host)
    }
}

/// What the bars cost the main thread: one level update hands seven springs to the render server,
/// and nothing runs on main between updates.
@Suite("Pill bars measurement", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_PILL_MEASURE"] == "1"))
@MainActor
struct ZZPillMeasurement {
    private func cpu() -> UInt64 { clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) }

    private func spin(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    @Test func mainThreadPerUpdate() throws {
        let model = PillStateModel()
        model.previewEnabled = { false }
        let host = NSHostingView(rootView: PillRootView(model: model, onStartHandsFree: {}, onCloseIsland: {}))
        host.frame = CGRect(origin: .zero, size: PillMetrics.panelSize(for: .listening(nil), caption: false))
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        model.state = .recording
        host.layoutSubtreeIfNeeded()
        spin(0.3)

        let updates = 5_000
        let start = cpu()
        for i in 0..<updates { model.level = Float(i % 100) / 100 }
        let perUpdate = Double(cpu() - start) / Double(updates) / 1000
        spin(1)

        let idle0 = cpu()
        spin(3)
        let idle = Double(cpu() - idle0) / 3e6

        let timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { _ in
            MainActor.assumeIsolated { model.level = Float.random(in: 0.2...0.9) }
        }
        defer { timer.invalidate() }
        let live0 = cpu()
        spin(3)
        let live = Double(cpu() - live0) / 3e6

        let report = """
        Pill bars, measured \(Date())
        main thread, one mic level update (seven springs handed to the render server): \(String(format: "%.1f", perUpdate)) us
        main thread CPU: \(String(format: "%.2f", idle)) ms/s listening with no level updates, \(String(format: "%.2f", live)) ms/s with 30 updates a second
        per rendered frame on main: 0, the springs and the thinking wave run in the render server
        """
        try report.write(to: SnapshotCanvas.directory().appendingPathComponent("pill-bars-timing.txt"), atomically: true, encoding: .utf8)
        #expect(perUpdate < 200)
    }
}
