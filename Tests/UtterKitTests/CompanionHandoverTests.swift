import Testing
import AppKit
@testable import UtterKit

/// The two decisions behind drawing the companion *inside* the note card.
///
/// This suite replaces `CompanionAvoidanceTests` and `CompanionReconcileTests`, and it is a
/// fraction of their size because the problem changed shape. Those pinned a displacement
/// mechanism: measure the card, compute the smallest escape that clears the character's
/// reach envelope, clamp it, re-test it, remember the old position, hand it back on
/// collapse, and reconcile the lot from five triggers. The card now draws the character
/// itself and the desktop panel steps aside, so there is only ever one character on screen
/// and the collision is impossible rather than corrected. What is left to get wrong is:
///
///   * **which surface draws it** — a rule, and the failure is two characters on screen at
///     once or none at all, and
///   * **how big it is in there** — a number with a real ceiling *and* a real floor, and
///     the failure at either end is silent (a blurry character, or one too small to have a
///     face).
///
/// The screen clamps those old suites also exercised live on in `CompanionGeometryTests`,
/// which owns them properly: it drives `clampedX`/`clampedY` directly with a constructed
/// `visibleFrame`, at every offered size, including the menu-bar overshoot that has been
/// fixed twice.
@Suite("Companion handover")
@MainActor
struct CompanionHandoverTests {

    // MARK: Which surface draws the character

    @Test("The card draws the character only while the pill is drawing a card")
    func onlyTheCardTakesTheCharacter() {
        // Every capsule state leaves the character on the desktop. The pill widens during
        // ordinary recording, but it is still a 28pt capsule the character is *designed* to
        // lean in front of — the companion sits one window level above the pill for exactly
        // that — and it hides nothing, where the card is 292x124pt of text.
        let capsuleStates: [PillState] = [
            .preparing, .idle, .recording, .handsFree,
            .processing(.transcribing), .processing(.rewriting), .processing(.typing),
            .notice("New note — keep talking"), .error("No speech detected"),
        ]
        for state in capsuleStates {
            #expect(!CompanionWindow.noteCardDrawsCharacter(pillState: state,
                                                            hasCharacter: true),
                    "\(state) handed the character to a card that isn't there")
        }
        #expect(CompanionWindow.noteCardDrawsCharacter(pillState: .capturingNote,
                                                       hasCharacter: true))
    }

    @Test("With no character there is nothing to hand over, card or not")
    func noCharacterMeansNoHandover() {
        // The companion is opt-in and may resolve to no installed pack. Getting this wrong
        // is not cosmetic: the panel would order itself out for the length of a note
        // capture on behalf of a character that was never drawn anywhere.
        for state in [PillState.idle, .capturingNote, .recording] {
            #expect(!CompanionWindow.noteCardDrawsCharacter(pillState: state,
                                                            hasCharacter: false))
        }
    }

    // MARK: How big it is in there

    @Test("The in-card character is legible and never upscaled")
    func inCardSizeFitsBothBounds() {
        let size = CompanionGeometry.inCardCharacterSize

        // The floor. `CompanionSize`'s own reasoning: the character grew 28 -> 44 -> 52
        // because sprite art at 28pt puts the face — the entire point of having moods — in
        // a handful of pixels, and 36 is the smallest step that still reads as a character
        // at a glance.
        #expect(size >= CompanionSize.small.points)

        // The ceiling, and the one that fails invisibly. Frames are decoded *once*, capped
        // at `maxFrameSide` of the size the user chose, so the binding case is a user on
        // `small`: 92px. Drawing at `size` needs `size * maxPoseScale` points at the peak
        // stretch, and twice that in pixels on a retina display. Past the cap the card
        // would upscale a bitmap that was decoded smaller — for precisely the users who
        // asked for the smallest character.
        let decoded = SpritePackStore.maxFrameSide(for: CompanionSize.small.points)
        let needed = size * CompanionGeometry.maxPoseScale * 2
        #expect(needed <= decoded,
                "\(size)pt in the card needs \(needed)px but only \(decoded)px is decoded")

        // And the objection that made this a constant rather than the preference: at `huge`
        // the character would be 84pt against the card's 124pt.
        #expect(size < PillMetrics.noteBoxHeight / 2)
        #expect(CompanionSize.huge.points > PillMetrics.noteBoxHeight / 2,
                "the preference would still fit, so a fixed in-card size buys nothing")
    }

    @Test("The character's column leaves the transcript a usable line")
    func theTranscriptSurvivesTheGutter() {
        // The cost of the placement, stated as a number rather than left to be discovered.
        // The character takes a column down the card's left because the footer is 20pt tall
        // and cannot hold 36pt of art, so the transcript pays in width instead.
        let gutter = CompanionGeometry.inCardCharacterSize + Space.x2
        let narrowed = PillMetrics.noteContentWidth - gutter
        #expect(narrowed == 228)
        // Still a majority of the card, and still wide enough that the tail handed to it
        // exceeds what it can show — so the head truncation, not this, decides the cut.
        #expect(narrowed > PillMetrics.noteContentWidth * 0.8)
    }
}
