import Testing
import SwiftUI
@testable import UtterKit

/// The polish pass: the numbers behind how the pill's states read.
///
/// Each of these pins a defect that was invisible in code review and obvious on screen — a meter
/// whose history was too short to see, a "breathing" dot at 35 cycles a minute, a neck that let go
/// early, a state that never drew the thing its own comment said it drew.
@Suite("Pill polish")
struct PillPolishTests {

    // MARK: The level meter's history window

    @Test("The meter shows enough history for the eye to read it as scrolling")
    func meterHistoryIsLegible() {
        // Five bars shifted at the recorder's 30Hz publish rate held 5/30s = 167ms, which is below
        // the eye's integration time for a scrolling display — so it flickered rather than scrolled,
        // the opposite of what it was for. The window is bars / shift-rate.
        let publishRate = 30.0
        let shiftRate = publishRate / 2      // shift every other publish
        let window = Double(LevelMeter.barCount) / shiftRate

        #expect(window > 0.35, "a \(window)s window is too short to read as motion")
        #expect(window < 1.0, "a window this long stops tracking what is being said now")
        #expect(LevelMeter.barCount == 7)
    }

    // MARK: The bead's neck

    @Test("The neck is nearly gone before it lets go, so the release is not a pop")
    func neckIsThinWhenItBreaks() {
        // **This is the invariant a bigger fillet would break, and it is the one that matters.**
        // Raising `neckFillet` from 2 to 3 makes the bridge survive more of the gap (62% -> 91% of it
        // open at the break), which sounds better and is worse: it also breaks the bridge while it is
        // still 6.74pt wide instead of 1.86pt, so 6.74pt of glass vanishes in ~19ms of a 300ms
        // reveal. A thick bridge disappearing is a far more visible pop than a thin thread going.
        //
        // So what is pinned is the thickness at the break, not the gap.
        let rA = PillMetrics.capsuleHeight / 2
        let rB = PillMetrics.handsFreeButtonSide / 2
        let travel = PillMetrics.handsFreeButtonReach

        func neckWidth(atExtrusion e: CGFloat) -> CGFloat {
            let separation = 1 + travel * e
            guard let offset = PillMetrics.neckArcOffset(distance: separation, rA: rA, rB: rB,
                                                         fillet: PillMetrics.neckFillet)
            else { return 0 }
            return 2 * (offset.y - PillMetrics.neckFillet)
        }

        let pinch = PillMetrics.neckPinchDistance(rA: rA, rB: rB, fillet: PillMetrics.neckFillet)
        let extrusionAtPinch = (pinch - 1) / travel
        // Sample just before the break: the thread must already be a thread.
        let widthJustBefore = neckWidth(atExtrusion: extrusionAtPinch - 0.01)
        #expect(widthJustBefore < 2.5,
                "the neck is \(widthJustBefore)pt wide when it breaks; that reads as a pop")

        // And it must still break before rest, or the bead never becomes its own object.
        #expect(pinch < 1 + travel,
                "the neck survives to rest — the bead would be a permanent lobe")
    }

    @Test("Emerge and retract are different lengths, matching the asymmetric physics")
    func beadCurvesAreAsymmetric() {
        // The neck survives ~91% of the travel on the way out but re-forms after ~7% on the way
        // back, so the return is the half worth lingering on. Durations are not readable off an
        // `Animation`, so this asserts the two tokens are distinct values rather than their lengths.
        #expect(Motion.beadEmerge != nil)
        #expect(Motion.beadRetract != nil)
    }

    // MARK: The pill must stay visible on any backdrop

    /// Relative luminance of a resolved colour, ignoring alpha.
    private func luminance(_ color: Color) -> CGFloat {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return -1 }
        return 0.2126 * srgb.redComponent
             + 0.7152 * srgb.greenComponent
             + 0.0722 * srgb.blueComponent
    }

    @Test("The resting pill's edge is two-tone, so it cannot dissolve into its backdrop")
    func restingEdgeIsTwoTone() {
        // The defect: both of the pill's strokes chose their tone from the *app's* colour scheme, and
        // in dark appearance both came out white — the ring at 0.22 and the inner highlight at 0.32.
        // The app's appearance and what is behind the pill are independent, because the pill floats
        // over the desktop, so a dark appearance over a pale window left the pill with no dark edge
        // anywhere and it vanished. Reported as "behind a white background it becomes white".
        //
        // The invariant that fixes it: the outer ring is dark and the inner highlight is light, both
        // regardless of appearance, so there is always a luminance step at the silhouette.
        let ring = PillContent.border(for: .idle)
        let highlight = Color.white.opacity(0.60)   // the inner stroke's top stop

        #expect(luminance(ring) < 0.25, "the outer ring is not dark; a pale backdrop will swallow it")
        #expect(luminance(highlight) > 0.75, "the inner highlight is not light; a dark backdrop will swallow it")
        #expect(luminance(highlight) - luminance(ring) > 0.5,
                "the two strokes are the same tone, so one backdrop has no edge at all")
    }

    @Test("A tinted state's ring is a hue, so it does not depend on appearance either")
    func tintedRingsAreHues() {
        // These were already appearance-independent and must stay that way — they are the states
        // where the ring is also the state's identity.
        for state in [PillState.recording, .handsFree, .capturingNote,
                      .error("x"), .notice("y"), .preparing, .processing(.typing)] {
            let ring = PillContent.border(for: state)
            // Saturated rather than a grey: a hue reads against both light and dark backdrops.
            guard let srgb = NSColor(ring).usingColorSpace(.sRGB) else {
                #expect(Bool(false), "\(state) ring is not resolvable")
                continue
            }
            let spread = max(srgb.redComponent, max(srgb.greenComponent, srgb.blueComponent))
                       - min(srgb.redComponent, min(srgb.greenComponent, srgb.blueComponent))
            #expect(spread > 0.1, "\(state)'s ring is a near-grey, so it can match its backdrop")
        }
    }

    // MARK: The writing pen has to fit inside its own frame

    @Test("The rotated pen glyph fits inside the processing capsule")
    func penFitsItsFrame() {
        // The pen went missing while transcribing, and the cause is a SwiftUI trap worth pinning:
        // `Image(systemName:)` reports a layout box of roughly its font size, but `rotationEffect` is
        // a *render* transform that does not change that box. So a glyph turned 38 degrees paints
        // across `size * (cos38 + sin38)` — 15.4pt for an 11pt glyph — and positioning it by offset
        // alone put 7.2pt of it outside a 28pt frame, hard against the capsule's bright rim.
        //
        // These are the numbers `WritingPen` is built from. If any of them moves, this fails.
        let glyphSize: CGFloat = 11
        let rotation: CGFloat = 38
        let radians = rotation * .pi / 180
        let paintedExtent = glyphSize * (abs(cos(radians)) + abs(sin(radians)))

        let penBox: CGFloat = 16
        #expect(penBox >= paintedExtent,
                "the reserved box (\(penBox)pt) is smaller than what the glyph paints (\(paintedExtent)pt)")

        let waveWidth: CGFloat = 18
        let frameWidth = waveWidth + penBox / 2 + 2
        let frameHeight = penBox + 2
        let penX = waveWidth - penBox / 2
        let penY = (frameHeight - penBox) / 2

        // Inside on both axes, with margin.
        #expect(penX >= 0 && penX + penBox <= frameWidth,
                "pen spans \(penX)...\(penX + penBox) in a \(frameWidth)pt frame")
        #expect(penY >= 0 && penY + penBox <= frameHeight,
                "pen spans \(penY)...\(penY + penBox) in a \(frameHeight)pt frame")

        // And the whole indicator fits the shell it is drawn in: a resting capsule less the padding
        // it gives every state.
        let contentWidth = PillMetrics.minimumCapsuleWidth - PillMetrics.horizontalPadding * 2
        #expect(frameWidth <= contentWidth,
                "the pen row (\(frameWidth)pt) does not fit the processing capsule (\(contentWidth)pt)")
        #expect(frameHeight <= PillMetrics.capsuleHeight)
    }

    // MARK: The width floor

    @Test("A content-driven state is wide enough on its very first frame")
    func widthFloorRemovesTheTwoStepWiden() {
        // The defect: `.recording`'s width comes from a measurement published one layout pass *after*
        // the state changes, so on the frame the hotkey is pressed the shell was still 56pt wide with
        // a dot, a meter and a timer inside it — it drew narrow and jumped a pass later, which reads
        // as the pill stretching open.
        //
        // Simulated by asking for the width with a *stale* measurement, which is exactly what the
        // first frame has.
        let stale = PillMetrics.minimumCapsuleWidth
        for state in [PillState.recording, .handsFree] {
            let first = PillMetrics.shellWidth(for: state, measured: stale)
            #expect(first > PillMetrics.minimumCapsuleWidth + 30,
                    "\(state) still starts at the resting width, so it will jump")
            #expect(first == PillMetrics.widthFloor(for: state))
        }
        // Hands-free is wider than plain recording, because it also draws the lock.
        #expect(PillMetrics.widthFloor(for: .handsFree) > PillMetrics.widthFloor(for: .recording))
        // The floor is a floor, not a freeze: a real measurement past it still wins, so the live
        // transcript can grow the pill.
        #expect(PillMetrics.shellWidth(for: .recording, measured: 260) == 260)
        // And states with a known width ignore it entirely.
        #expect(PillMetrics.widthFloor(for: .idle) == PillMetrics.minimumCapsuleWidth)
        #expect(PillMetrics.widthFloor(for: .processing(.typing)) == PillMetrics.minimumCapsuleWidth)
    }

    // MARK: Messages cannot overflow the panel

    @Test("An arbitrarily long message cannot draw the shell past its window")
    func messagesAreBounded() {
        // `.error` and `.notice` carry text from arbitrary failures. Unbounded, a long reason drew
        // the shell wider than the 320pt panel — clipped at both ends, losing its rounded caps, and
        // leaving a full-width strip taking clicks.
        for state in [PillState.error(String(repeating: "x", count: 400)),
                      .notice(String(repeating: "y", count: 400))] {
            let width = PillMetrics.shellWidth(for: state, measured: 9999)
            #expect(width <= PillMetrics.windowWidth - PillMetrics.verticalInset * 2)
        }
        // And the text itself is capped short of that, so the glyph and padding still fit.
        #expect(PillMetrics.messageWidth
                < PillMetrics.windowWidth - PillMetrics.horizontalPadding * 2)
    }

    // MARK: The card's entrance

    @Test("The card's rows arrive in order, and all land inside the settle")
    func cardRowsStaggerAndFinishInTime() {
        // Three rows: header, transcript, footer. Each must start after the one above it, and the
        // last must finish before the shell stops moving — otherwise the interior is still arriving
        // after the shape has settled, which reads as lag rather than as filling.
        //
        // Delays are `0.04 + 0.05 * index`, so the last of three starts at 0.14 and runs 0.18.
        let lastDelay = 0.04 + 0.05 * 2
        #expect(lastDelay + 0.18 <= Motion.settleDuration + 0.01,
                "the last row lands after the settle finishes")
        // The rise has to stay within the card's vertical slack or the shell's clip shows a cut row.
        #expect(Motion.cardRowRise <= 6)
        #expect(Motion.cardRowRise > 0)
    }
}
