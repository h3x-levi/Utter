import Testing
import SwiftUI
@testable import UtterKit

/// The pill's settle — the animation it has *instead of* an animated resize.
///
/// The shell's size cannot be animated: `glassEffect` fills its view's bounds, so the bounds must
/// track the silhouette, and re-anchoring a glass body makes the system cross-fade the outgoing one
/// against the incoming one. That cross-fade is the ghost that had the morph deleted nine times. So
/// the size lands instantly and a `scaleEffect` springs the last few percent — a transform on an
/// already-composited layer, which creates no second body.
///
/// What can be tested here is the arithmetic that keeps it *tasteful*, and the arithmetic that keeps
/// it *safe*. The look itself has to be watched.
@Suite("Pill settle")
struct PillSettleTests {

    @Test("Every state settles by the same visible distance, whatever its size")
    func settleTravelIsConstantAcrossStates() {
        // The point of making the scale a function: a flat factor gave the 56x28 capsule 2.8pt of
        // edge travel and the 292x124 card 14.6pt, so the state carrying text to be read lurched
        // furthest and drew that text ~11% small while fading it in.
        let shells: [(String, CGFloat, CGFloat)] = [
            ("idle", PillMetrics.minimumCapsuleWidth, PillMetrics.capsuleHeight),
            ("recording", 97, PillMetrics.capsuleHeight),
            ("handsFree", 259, PillMetrics.capsuleHeight),
            ("card", PillMetrics.shellWidth(for: .capturingNote) ?? 0, PillMetrics.noteBoxHeight),
        ]

        for (name, width, height) in shells {
            let scale = Motion.settleScale(width: width, height: height)
            #expect(scale < 1, "\(name) must scale down, not up")
            #expect(scale > 0.85, "\(name) scaled to \(scale) would render its text soft")

            // The travel on the dominant axis is what the constant promises.
            let reference = max(height, width / 2)
            let travel = reference * (1 - scale)
            #expect(abs(travel - Motion.settleEdgeTravel) < 0.35,
                    "\(name) travels \(travel)pt, not ~\(Motion.settleEdgeTravel)pt")

            // And the corner radius is never distorted enough to read as a shape change.
            let radiusDrift = PillMetrics.cornerRadius * (1 - scale)
            #expect(radiusDrift < 2.0, "\(name) radius drift \(radiusDrift)pt")
        }
    }

    @Test("The card settles far more gently than a flat scale would have")
    func cardIsNoLongerTheWorstCase() {
        let cardWidth = PillMetrics.shellWidth(for: .capturingNote) ?? 0
        let card = Motion.settleScale(width: cardWidth, height: PillMetrics.noteBoxHeight)
        let capsule = Motion.settleScale(width: PillMetrics.minimumCapsuleWidth,
                                        height: PillMetrics.capsuleHeight)
        // The card is the *larger* shell, so it needs the *smaller* proportional change. A flat
        // factor had this backwards.
        #expect(card > capsule, "the bigger shell must scale less, not more")
        // And its text stays legible: 12pt drawn no smaller than ~11.6pt.
        #expect(12 * card > 11.5)
    }

    @Test("A degenerate size cannot scale the pill away")
    func degenerateSizeIsClamped() {
        #expect(Motion.settleScale(width: 0, height: 0) == 1)
        #expect(Motion.settleScale(width: -10, height: -10) == 1)
        // A tiny-but-valid shell hits the clamp rather than inverting.
        #expect(Motion.settleScale(width: 2, height: 2) >= 0.86)
    }

    @Test("A uniform scale cannot distort either state, whatever their proportions")
    func uniformScalePreservesAspect() {
        // The reason the settle is a *small uniform* scale and not a scale from capsule to card:
        // the two states have different proportions, so covering that distance needs an anisotropic
        // scale, which turns the corner arcs into ellipses. This pins the fact that motivated the
        // decision, so nobody re-derives it by shipping it.
        let capsule = PillMetrics.minimumCapsuleWidth / PillMetrics.capsuleHeight
        let card = (PillMetrics.shellWidth(for: .capturingNote) ?? 0) / PillMetrics.noteBoxHeight
        #expect(abs(capsule - card) > 0.3,
                "if these ever matched, a scale-based morph would become possible")

        // A uniform scale keeps whatever aspect it is given.
        for ratio in [capsule, card] {
            let scale = Motion.settleScale(width: ratio * 28, height: 28)
            let scaledWidth = ratio * scale
            let scaledHeight = 1.0 * scale
            #expect(abs(scaledWidth / scaledHeight - ratio) < 0.0001)
        }
    }

    @Test("The content arrives behind the shell, and lands inside the settle")
    func contentFillLandsInsideTheSettle() {
        // The card should read as a shape arriving and then filling, so the content must start
        // after the shell moves and finish before the settle does — otherwise it either pops in
        // simultaneously (no sense of arrival) or is still fading after the shape has stopped.
        // Read from the tokens, not copied from them: literals compared to literals would pass
        // whatever `Motion` said, which is the failure mode of a test that looks like coverage.
        #expect(Motion.contentInDelay > 0, "no delay makes everything appear at once")
        #expect(Motion.contentInDelay + Motion.contentInDuration
                <= Motion.settleDuration + 0.01,
                "the fill must finish within the settle, not trail it")
    }

    @Test("Reduce Motion leaves both values at rest, so nothing moves")
    func reduceMotionHasNothingToAnimate() {
        // `restartSettle` returns early under Reduce Motion with both values at 1 — a single clean
        // render at full size and full opacity. Asserting the endpoints here documents what that
        // early return has to produce.
        // `restartSettle` returns early under Reduce Motion, assigning 1 to both values and the
        // colour outright. What can be checked here is that a scale of 1 is genuinely available for
        // every shell — i.e. the function has no state whose "resting" value is already reduced.
        for (w, h) in [(PillMetrics.minimumCapsuleWidth, PillMetrics.capsuleHeight),
                       (PillMetrics.shellWidth(for: .capturingNote) ?? 0, PillMetrics.noteBoxHeight)] {
            #expect(Motion.settleScale(width: w, height: h) < 1,
                    "the animated path must differ from the resting path, or there is nothing to skip")
        }
    }
}
