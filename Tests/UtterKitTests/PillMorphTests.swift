import Testing
import AppKit
@testable import UtterKit

/// The pill's morph into the note box, in the parts that are arithmetic.
///
/// The morph itself has to be watched, but three things underneath it are pure and are
/// exactly the things that break silently:
///
///   * the **window** has to be tall enough for every shell it will ever draw, or SwiftUI
///     lays the box out inside a panel that clips it — and its height must leave the capsule
///     on the spot the user parked it on,
///   * the **destination** the box names has to be the one the transcript is filed to,
///   * the **transcript tail** has to keep the newest words, which is the whole point of
///     showing it.
@Suite("Pill morph")
struct PillMorphTests {

    /// A 16:10 display with a menu bar and a Dock, in the coordinates AppKit reports.
    private static let visible = NSRect(x: 0, y: 70, width: 1512, height: 887)

    /// The capsule's bottom edge on screen — the quantity that must not move when the
    /// window changes height. The content is bottom-anchored inside the window, so it is
    /// the window origin plus the transparent inset below the pill.
    private func capsuleBottom(_ frame: NSRect) -> CGFloat {
        frame.minY + PillMetrics.verticalInset
    }

    /// A pill parked just above the Dock, where a fresh launch puts it.
    private var parked: NSRect {
        NSRect(x: 596,
               y: Self.visible.minY + 10 - PillMetrics.verticalInset,
               width: PillMetrics.windowWidth,
               height: PillMetrics.windowHeight)
    }

    // MARK: Which states are which size

    @Test("Only note capture leaves the capsule's height")
    func onlyTheNoteBoxIsTall() {
        let capsuleStates: [PillState] = [
            .preparing, .idle, .recording, .handsFree,
            .processing(.transcribing), .processing(.rewriting), .processing(.typing),
            .notice("New note — keep talking"), .error("No speech detected"),
        ]
        for state in capsuleStates {
            #expect(PillMetrics.shellHeight(for: state) == PillMetrics.capsuleHeight,
                    "\(state) should still draw as a capsule")
            // `isExpanded` is the same fact read as a predicate, and it now decides which
            // surface draws the companion (`CompanionWindow.noteCardDrawsCharacter`). The
            // pill widens ~26-37pt a side during ordinary recording, and that must not
            // count: it is still a 28pt capsule, so the character stays on the desktop.
            #expect(!PillMetrics.isExpanded(state), "\(state) is still a capsule")
        }
        #expect(PillMetrics.shellHeight(for: .capturingNote) > PillMetrics.capsuleHeight)
        #expect(PillMetrics.isExpanded(.capturingNote))
    }

    /// Every state the pill can be in. One list, because three tests need it and a fourth
    /// that forgets to add a new state is how a state gets shipped un-sized.
    private static let everyState: [PillState] = [
        .preparing, .idle, .recording, .handsFree, .capturingNote, .capturingMemory,
        .processing(.transcribing), .processing(.rewriting), .processing(.typing),
        .notice("New note — keep talking"), .error("No speech detected"),
    ]

    // MARK: Both axes are one mechanism

    @Test("Both axes of the shell are sizes, for every state")
    func bothAxesAreSizedForEveryState() {
        // The defect this pins is the one the pill was rejected five times for, and it is not
        // a number being wrong — it is an axis not being a *number* at all. The height was
        // `.frame(height: shellHeight(for:))`, an animatable value interpolating 28 -> 124. The
        // width was intrinsic: resolved from the content's ideal size by `.fixedSize()` above
        // every animation in the chain, so it stepped 56 -> 292 in the layout pass the state
        // changed in and no transaction could interpolate it. One shape expanding needs two
        // interpolations, not one interpolation and one relayout.
        //
        // So: for every state, both axes resolve to a finite width the shell can be *told*.
        for state in Self.everyState {
            let width = PillMetrics.shellWidth(for: state,
                                               measured: PillMetrics.minimumCapsuleWidth)
            let height = PillMetrics.shellHeight(for: state)
            #expect(width.isFinite && width >= PillMetrics.minimumCapsuleWidth,
                    "\(state) has no width the shell can animate to")
            #expect(height.isFinite && height >= PillMetrics.capsuleHeight,
                    "\(state) has no height the shell can animate to")
        }
        // The note card's width is the box plus the padding every state gets, not a number
        // tuned beside it: `NoteCaptureBox` pins its content to `noteContentWidth`, so a shell
        // narrower than this clips the card and a wider one leaves a gap inside the glass.
        #expect(PillMetrics.shellWidth(for: .capturingNote)
                == PillMetrics.noteContentWidth + PillMetrics.horizontalPadding * 2)
        #expect(PillMetrics.shellWidth(for: .capturingNote) == 292)
    }

    @Test("Both endpoints of the note-card morph are known numbers, not measurements")
    func morphEndpointsAreKnownWidths() {
        // A measured width lands a layout pass *after* the state changes, which is one pass too
        // late to be the destination of an animation that started in the pass the state changed
        // in. So the states the morph runs between must have widths
        // `PillMetrics.shellWidth(for:)` can answer without measuring anything.
        //
        // The list is not decorative — it is read off `AppDelegate`, and it is the thing a
        // future `setState` can quietly invalidate:
        //
        //   * into the card, from `.idle` (⌃⌥N at rest, via `startRecording`), `.recording`
        //     (upgrading a push-to-talk hold) and `.handsFree` (redirecting a latched session);
        //   * out of the card, to `.processing(.transcribing)` (`stopRecording`) or `.idle`.
        //
        // Entering may start from a measured width — the pill already *has* it, settled, from
        // the previous pass — so only the destinations have to be known. Both are.
        #expect(PillMetrics.shellWidth(for: .capturingNote) != nil,
                "the card has no width to grow to; the shell would snap wide and then grow tall")
        #expect(PillMetrics.shellWidth(for: .idle) != nil,
                "leaving the card for idle would hold 292pt through the shrink and then snap")
        #expect(PillMetrics.shellWidth(for: .processing(.transcribing)) != nil,
                "leaving the card for transcribing would hold 292pt and then snap")
        // And both destinations are *constants*, which is the property the morph needs. All three
        // processing phases share one width, so moving between them costs no width change — the pen
        // is the same size whatever it is working on.
        #expect(PillMetrics.shellWidth(for: .idle) == PillMetrics.minimumCapsuleWidth)
        #expect(PillMetrics.shellWidth(for: .processing(.typing))
                == PillMetrics.minimumCapsuleWidth)
        #expect(PillMetrics.shellWidth(for: .processing(.transcribing))
                == PillMetrics.shellWidth(for: .processing(.rewriting)),
                "the three phases must share one width or the pill snaps between them")
    }

    @Test("A state whose width is content-driven says so, and floors at its own minimum")
    func contentDrivenStatesFallBackToTheMeasuredWidth() {
        // The other half of the contract: a width may only be a constant when the state's
        // content is a fixed set of glyphs. These four carry text of a length nothing here can
        // know — a level meter and a live transcript, a message, a localised string — so
        // claiming a number for them would either clip the text or leave dead glass.
        for state in [PillState.preparing, .recording, .handsFree,
                      .notice("New note — keep talking"), .error("No speech detected")] {
            #expect(PillMetrics.shellWidth(for: state) == nil,
                    "\(state) cannot have a constant width: its content decides it")
            // The measurement is used as-is once it is big enough...
            #expect(PillMetrics.shellWidth(for: state, measured: 280) == 280)
            // ...but never below that state's own floor. The floor is what stops the pill drawing at
            // the resting width for one frame — while the probe is still a pass behind — and then
            // jumping, which read as the pill stretching open when a dictation started. `.recording`
            // and `.handsFree` reserve room for the dot, the meter and the timer; the others have no
            // fixed row to reserve for and floor at the resting width.
            #expect(PillMetrics.shellWidth(for: state, measured: 0)
                    == PillMetrics.widthFloor(for: state))
            #expect(PillMetrics.shellWidth(for: state, measured: 0)
                    >= PillMetrics.minimumCapsuleWidth,
                    "\(state) could draw narrower than a pill")
        }
        // A constant ignores the measurement outright — that is the whole point of it.
        #expect(PillMetrics.shellWidth(for: .capturingNote, measured: 9_999) == 292)
    }

    @Test("The shell's two axes ride one animatable value")
    func shellSizeCarriesBothAxesInOneValue() {
        // The structural guarantee, and the thing a future refactor is meant to trip over: the
        // axes are not two animatable properties that happen to share a transaction, they are
        // one `AnimatablePair` that both are read from. Two independently animated quantities
        // are phase-locked only while no frame is dropped, and the frame they disagree on puts
        // the outer contrast ring a point off the glass body.
        //
        // Interpolating `animatableData` is exactly what SwiftUI does per frame, so this walks
        // the morph the way the render server does.
        var size = ShellSize(width: PillMetrics.minimumCapsuleWidth,
                             height: PillMetrics.capsuleHeight)
        let target = ShellSize(width: 292, height: PillMetrics.noteBoxHeight)
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            var midpoint = size.animatableData
            midpoint.scale(by: 1 - t)
            var toward = target.animatableData
            toward.scale(by: t)
            midpoint += toward
            var frame = ShellSize(width: 0, height: 0)
            frame.animatableData = midpoint
            // Both axes moved, and by the same fraction of their travel — which is what
            // "one shape expanding" means arithmetically. A mechanism that animated only one
            // of them would leave the other pinned at an endpoint for the whole morph.
            let widthProgress = (frame.width - PillMetrics.minimumCapsuleWidth)
                / (292 - PillMetrics.minimumCapsuleWidth)
            let heightProgress = (frame.height - PillMetrics.capsuleHeight)
                / (PillMetrics.noteBoxHeight - PillMetrics.capsuleHeight)
            #expect(abs(widthProgress - heightProgress) < 0.000_1,
                    "the axes are \(widthProgress) and \(heightProgress) through at t=\(t)")
            #expect(abs(widthProgress - t) < 0.000_1)
        }
    }

    // MARK: The window is one size, and it fits everything

    @Test("The window is tall enough for every state, so nothing is ever clipped")
    func windowFitsEveryShell() {
        // This is the invariant the old per-state resize maintained at runtime, and getting
        // it wrong is invisible until a state actually appears: a panel shorter than the
        // shell does not scroll or complain, it silently cuts the top off the note card.
        // Now that the height is a constant, the check belongs here.
        for state in Self.everyState {
            let needed = PillMetrics.shellHeight(for: state) + PillMetrics.verticalInset * 2
            #expect(PillMetrics.windowHeight >= needed,
                    "\(state) needs \(needed)pt but the window is \(PillMetrics.windowHeight)pt")
        }
        // And no slack beyond what the tallest state needs — the panel is transparent, but a
        // taller one would push the capsule's saved position further from the window origin.
        #expect(PillMetrics.windowHeight
                == PillMetrics.noteBoxHeight + PillMetrics.verticalInset * 2)
    }

    @Test("The capsule sits 30pt off the window's bottom edge, as it always has")
    func capsuleEyeLineIsUnchanged() {
        // The number every position calculation is calibrated against. `positionAtBottomCenter`
        // and `restorePosition` offset by `verticalInset` to hold the capsule 10pt off the
        // Dock, and `CompanionWindow.placeBesidePill` puts the character on this line.
        //
        // It survived the window becoming a fixed 156pt *because* the content is
        // bottom-anchored: at the old 60pt the capsule was centred, and (60 - 28) / 2 == 16
        // == verticalInset. Change either number and every parked pill moves on next launch,
        // and the companion stops standing beside the capsule.
        #expect(PillMetrics.verticalInset == 16)
        #expect(PillMetrics.capsuleCentreAboveBottom == 30)
        #expect(PillMetrics.capsuleCentreAboveBottom
                == PillMetrics.verticalInset + PillMetrics.capsuleHeight / 2)
    }

    @Test("The note box fits inside the window it is drawn in")
    func boxFitsTheWindow() {
        // The window's width is fixed, so this is the constraint that stops the box being
        // widened until its edges are clipped by the panel.
        let shellWidth = PillMetrics.noteContentWidth + PillMetrics.horizontalPadding * 2
        #expect(shellWidth <= PillMetrics.windowWidth)
        // And there is room left for the shadow and the glass rim to breathe.
        #expect(PillMetrics.windowWidth - shellWidth >= 16)
    }

    @Test("The window fits on the smallest supported display")
    func windowFitsASmallDisplay() {
        // 1280x800 is the smallest built-in display Utter runs on; 90pt covers a menu bar
        // and a Dock. A window taller than the screen could not be positioned at all — and
        // it is now this size permanently, not only during note capture.
        #expect(PillMetrics.windowHeight <= 800 - 90)
        #expect(PillMetrics.windowWidth <= 1280)
    }

    // MARK: The morph resolves to the same numbers every time

    /// The shell size for a state, resolved exactly as `PillContent` resolves it before handing
    /// it to `ShellSize`: `shellWidth(for:measured:)` by `shellHeight(for:)`. `measured` is the
    /// live `capsuleWidth` the content publishes — passed in so a test can vary it and prove
    /// which states ignore it.
    private func resolvedShell(_ state: PillState, measured: CGFloat) -> CGSize {
        CGSize(width: PillMetrics.shellWidth(for: state, measured: measured),
               height: PillMetrics.shellHeight(for: state))
    }

    /// The pill's window frame, computed the way `PillWindow.positionAtBottomCenter` fixes it:
    /// a constant size, placed once against the screen, with **no term that reads the pill's
    /// state**. Reproduced here — as `PillHitRegionTests` reproduces `drawnShellRect` — so the
    /// arithmetic can be checked without standing up a live NSPanel in a headless test.
    private func windowFrame(on visible: NSRect) -> NSRect {
        let size = NSSize(width: PillMetrics.windowWidth, height: PillMetrics.windowHeight)
        // `dockGap` is 10 (private in `PillWindow`); the pill carries `verticalInset` of
        // transparent padding below the capsule, so the origin sits that far below the Dock gap.
        let origin = NSPoint(x: visible.midX - size.width / 2,
                             y: visible.minY + 10 - PillMetrics.verticalInset)
        return NSRect(origin: origin, size: size)
    }

    @Test("A note-capture cycle resolves to byte-identical numbers on every pass, whatever the pill measured")
    func noteCaptureResolutionIsDeterministic() {
        // This is the test for the bug the user reports as "sometimes smaller, sometimes bigger…
        // sometimes it goes down… then comes up" — non-determinism, plus vertical window
        // movement. Neither can live in the size resolution if the resolution is a pure function
        // of the state and nothing else, so this drives the note-capture cycle 50 times, feeds a
        // DIFFERENT measured capsule width every pass, and asserts the resolved shell sizes and
        // the window frame are identical every time.
        //
        // The varying measurement is the point. `capsuleWidth` is republished as the note card's
        // 30 Hz companion ticker fires and its live transcript grows; if any step of a note cycle
        // read it, these passes would drift and this test would catch the drift. The states in a
        // note cycle are all morph *endpoints* (`AppDelegate`: ⌃⌥N opens `.capturingNote`, then
        // `.processing(.transcribing)` on finish or `.idle` on cancel), and an endpoint's width
        // must be a known constant — so every one of these ignores `measured` by construction.
        let endpointCycle: [PillState] = [.idle, .capturingNote,
                                          .processing(.transcribing), .idle]
        for state in endpointCycle {
            #expect(PillMetrics.shellWidth(for: state) != nil,
                    "\(state) is measurement-driven, so it must not be a note-cycle endpoint: a note morph into or out of it would follow the transcript's width")
        }

        var referenceShells: [CGSize]?
        let referenceWindow = windowFrame(on: Self.visible)
        for pass in 0..<50 {
            // Wildly varying, never below the resting width — a plausible live measurement, not a
            // degenerate one. 137 is coprime with the modulus so the sequence does not repeat.
            let measured = CGFloat(Int(PillMetrics.minimumCapsuleWidth) + (pass * 137) % 600)
            let shells = endpointCycle.map { resolvedShell($0, measured: measured) }
            if let referenceShells {
                #expect(shells == referenceShells,
                        "shell sizes drifted on pass \(pass) (measured=\(measured)): a measurement is feeding a note-capture size")
            } else {
                referenceShells = shells
            }
            // The window frame has no state term at all, so it is the same rect on every pass and
            // for every state. That is the arithmetic proof a morph cannot move the pill: the
            // window is a fixed size, positioned once, and `sizingOptions = []` keeps the SwiftUI
            // content from resizing it out from under that position.
            for state in endpointCycle {
                _ = state
                #expect(windowFrame(on: Self.visible) == referenceWindow)
            }
        }

        // Spell the endpoints out, so a future change that makes `.capturingNote` measured-driven
        // fails here with a concrete number rather than only as "drift".
        let capsule = CGSize(width: PillMetrics.minimumCapsuleWidth,
                             height: PillMetrics.capsuleHeight)
        #expect(referenceShells == [capsule,
                                    CGSize(width: 292, height: PillMetrics.noteBoxHeight),
                                    capsule,
                                    capsule])
        // The far endpoint ignores even an absurd measurement — the whole point of it being a
        // constant, and the close direction (292 -> 56) is its exact inverse for the same reason.
        #expect(resolvedShell(.capturingNote, measured: 9_999)
                == CGSize(width: 292, height: PillMetrics.noteBoxHeight))
    }

    @Test("The window is decoupled from the shell, so opening the card cannot slide the pill")
    func windowSizeIsNeverTheShellSize() {
        // The vertical movement, stated as the invariant that forbids it. The window is a fixed
        // `windowHeight` for every state; it is emphatically NOT `shellHeight(for: state) +
        // verticalInset * 2`, which is what an NSHostingView left on its default `.standardBounds`
        // sizingOptions would have driven it to — 60pt at rest, 156pt as a card. The content is
        // bottom-anchored, so had the window tracked the shell, the capsule's on-screen bottom
        // edge would have jumped by (noteBoxHeight - capsuleHeight) = 96pt as the card opened.
        for state in Self.everyState where state != .capturingNote {
            let ifItTrackedTheShell = PillMetrics.shellHeight(for: state)
                + PillMetrics.verticalInset * 2
            #expect(PillMetrics.windowHeight != ifItTrackedTheShell,
                    "\(state): the window height equals the shell-tracking height, so the pill would resize and slide on the morph")
        }
        // The capsule's bottom edge is `frame.minY + verticalInset` in every state, because the
        // window height is a state-free constant — so it does not move when the card opens.
        let frame = windowFrame(on: Self.visible)
        #expect(frame.minY + PillMetrics.verticalInset
                == Self.visible.minY + 10, "the capsule's bottom edge is not the resting Dock gap")
    }

    // MARK: The hands-free button stays on the panel

    @Test("The hands-free button is never drawn past the panel's edge")
    func handsFreeButtonFitsThePanel() {
        // The regression: `restX` was `capsuleWidth / 2 + gap + side / 2` with nothing
        // bounding it. In `.handsFree` with a live preview the capsule reaches ~277pt, which
        // put the button's right edge ~10pt outside the 320pt panel — the stop control, cut
        // in half, in the one state where it is the only way to end the recording.
        for capsuleWidth in stride(from: 56.0, through: 400.0, by: 3.0) {
            let centre = PillMetrics.windowWidth / 2
                + PillMetrics.handsFreeButtonCentreX(capsuleWidth: capsuleWidth)
            #expect(centre + PillMetrics.handsFreeButtonSide / 2 <= PillMetrics.windowWidth,
                    "clipped on the right at capsule width \(capsuleWidth)")
            #expect(centre - PillMetrics.handsFreeButtonSide / 2 >= 0)
        }
    }

    @Test("Tucked, the bead is inscribed in the capsule's rounded end")
    func tuckedBeadIsInscribedInTheCapsule() {
        // The whole liquid effect rests on this. The bead's glass is drawn at full strength at
        // all times — that is what makes its journey out read as the pill *extruding* rather
        // than a button fading in beside it — so when tucked it must contribute nothing to the
        // silhouette, or a permanent lump sits on the resting pill.
        //
        // Both are circles at the capsule's mid-height: the capsule's end is a semicircle of
        // radius `capsuleHeight / 2` centred that far in from the trailing edge, and the bead
        // is a circle of radius `handsFreeButtonSide / 2` centred `handsFreeButtonSide / 2` in.
        // Internal tangency — fully inside, touching — is `centreGap + beadRadius == endRadius`.
        let endRadius = PillMetrics.capsuleHeight / 2
        let beadRadius = PillMetrics.handsFreeButtonSide / 2
        // Offsets are measured from the capsule's centre, so both reduce to a distance from
        // the trailing edge and the capsule's width cancels out.
        let centreGap = abs(endRadius - beadRadius)
        #expect(centreGap + beadRadius == endRadius,
                "the bead is not inscribed: it would break the capsule's outline at rest")
        // And it is not so much smaller that the tuck leaves a visible gap the merge has to
        // bridge before it can even start stretching.
        #expect(beadRadius >= endRadius - 2)
    }

    @Test("The bead's travel is the same distance whatever the pill is showing")
    func beadTravelIsConstant() {
        // `Motion.morph` is a single spring, so a travel distance that changed with the
        // capsule's width would make the extrusion visibly faster in some states than others.
        // Both endpoints are measured from the capsule's centre and both scale with it, so the
        // difference is a constant — worth pinning, because it is only true while neither
        // endpoint is clamped.
        let expected = PillMetrics.handsFreeButtonGap + PillMetrics.handsFreeButtonSide
        for capsuleWidth in stride(from: 56.0, through: 240.0, by: 4.0) {
            let rest = PillMetrics.handsFreeButtonCentreX(capsuleWidth: capsuleWidth)
            let tucked = capsuleWidth / 2 - PillMetrics.handsFreeButtonSide / 2
            #expect(abs((rest - tucked) - expected) < 0.001,
                    "travel changed at capsule width \(capsuleWidth)")
        }
    }

    // The bead's neck used to be `GlassEffectContainer(spacing: PillMetrics.glassBlendSpacing)`,
    // and this suite asserted the pinch against that constant. The neck is now geometry —
    // `PillShellShape`'s concave fillet — so the same requirement is asserted against
    // `PillMetrics.neckPinchDistance` in `PillShellShapeTests.beadDetachesBeforeRest`, which can
    // additionally check the drawn silhouette rather than only the number that was meant to
    // produce it.

    @Test("At rest the button still clears the capsule rather than overlapping it")
    func handsFreeButtonClearsTheRestingCapsule() {
        // Clamping must only bite at the wide end. On the resting pill the button has to sit
        // clear of the glass, or the "bead separating from the pill" reading is lost.
        let centre = PillMetrics.handsFreeButtonCentreX(
            capsuleWidth: PillMetrics.minimumCapsuleWidth)
        let gap = centre - PillMetrics.handsFreeButtonSide / 2
            - PillMetrics.minimumCapsuleWidth / 2
        #expect(gap == PillMetrics.handsFreeButtonGap)
    }

    // MARK: The two halves of the morph stay in step


    // MARK: The destination the box names

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
        // The failure this prevents: `NoteStore.append(_:to:)` finds no such note and
        // returns, so the capture would be filed nowhere at all.
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
        // The empty note `routeNextDictation` creates for "start a new note" is exactly
        // this case: the next capture appends to a note with no body yet.
        let blank = Note(id: UUID(), source: .dictated)
        let destination = NoteCaptureDestination.resolve(appendsToOpenNote: true,
                                                        selectedID: blank.id,
                                                        notes: [blank])
        #expect(destination.label == "Adding to Untitled note")
    }

    // MARK: The elapsed clock

    @Test("Elapsed seconds read as m:ss")
    func elapsedFormatting() {
        let model = PillStateModel()
        for (seconds, expected) in [(0, "0:00"), (7, "0:07"), (59, "0:59"),
                                    (60, "1:00"), (605, "10:05"), (3_600, "60:00")] {
            model.elapsed = seconds
            #expect(model.elapsedText == expected)
        }
    }

    // MARK: The transcript tail

    @Test("A transcript that fits is left alone")
    func shortTranscriptUntouched() {
        let text = "send the design doc to the team"
        #expect(LiveTranscript.tail(of: text) == text)
        #expect(LiveTranscript.tail(of: "") == "")
    }

    @Test("A long transcript keeps its newest words")
    func longTranscriptKeepsTheEnd() {
        // `previewText` is a pass over *all* the audio so far, so it grows without limit
        // through a long note while the box stays one size. The end is the live part.
        let words = (1...200).map { "word\($0)" }.joined(separator: " ")
        let tail = LiveTranscript.tail(of: words, maxCharacters: 60)
        #expect(tail.hasSuffix("word200"))
        #expect(tail.count <= 61, "the ellipsis is the only thing added")
        #expect(!tail.contains("word1 "), "the head is what gets dropped")
    }

    @Test("The tail starts on a whole word")
    func tailStartsOnAWordBoundary() {
        let text = "alpha bravo charlie delta echo foxtrot"
        // 14 characters back from the end lands inside "delta", leaving "a echo foxtrot";
        // the fragment goes rather than being shown as a word.
        #expect(LiveTranscript.tail(of: text, maxCharacters: 14) == "\u{2026}echo foxtrot")
        // Landing exactly on a space keeps everything after it.
        #expect(LiveTranscript.tail(of: text, maxCharacters: 13) == "\u{2026}echo foxtrot")
    }

    @Test("A single unbroken token is truncated rather than emptied")
    func tailHandlesTextWithNoSpaces() {
        // Whisper has produced runs like this, and a language that does not space its
        // words would produce them by design.
        let text = String(repeating: "x", count: 300)
        let tail = LiveTranscript.tail(of: text, maxCharacters: 50)
        #expect(tail == "\u{2026}" + String(repeating: "x", count: 50))
    }

    @Test("A trailing space does not leave the tail empty")
    func tailWithOnlyOneSpace() {
        // The pathological shape: the cut window contains exactly one space, at the very
        // end. Dropping through it would leave nothing to show.
        let text = String(repeating: "y", count: 100) + " "
        let tail = LiveTranscript.tail(of: text, maxCharacters: 10)
        #expect(tail.contains("y"))
    }
}

/// The pill's hit region — the rect that decides where clicks land.
///
/// A pure test on the geometry alone. The regression this pins: the pill's window is a
/// fixed 320x156, but the drawn capsule is ~56x28 — the rest is transparent. Without a
/// hit-test rule the whole panel accepted the mouse, so a click beside the pill vanished
/// into the dead zone instead of reaching the desktop behind. `ShapedHostingView` asks the
/// window for `drawnShellRect` on every hit-test, so the rule has to hold — and it matters
/// more now that the panel is permanently note-tall, because 96pt of it is empty in every
/// resting state.
@Suite("Pill hit region")
@MainActor
struct PillHitRegionTests {

    /// The window, at the one size it is ever built at.
    private static let windowBounds = NSRect(x: 0, y: 0,
                                             width: PillMetrics.windowWidth,
                                             height: PillMetrics.windowHeight)

    /// What `PillWindow.drawnShellRect` computes, minus the AppKit `contentView` lookup —
    /// so the arithmetic is checked without asking SwiftUI to lay out a real window.
    private func shellRect(for state: PillState, capsuleWidth: CGFloat,
                           bounds: NSRect = windowBounds) -> NSRect {
        let height = PillMetrics.shellHeight(for: state)
        // `shellWidth(for:measured:)`, the same expression `PillContent` hands to `ShellSize` —
        // so the region that takes the mouse is the box that was drawn. It was
        // `max(capsuleWidth, minimumCapsuleWidth)`, which was the drawn width only while the
        // published value *was* it; it is now the content's ideal.
        let width = min(PillMetrics.shellWidth(for: state, measured: capsuleWidth), bounds.width)
        // Bottom-anchored in the hosting view's flipped space — mirrors
        // `PillWindow.drawnShellRect`. Measured from the bottom, not the top, so it stays
        // correct in every resting state, where the panel is 96pt taller than the shell.
        return NSRect(x: (bounds.width - width) / 2,
                      y: bounds.height - PillMetrics.verticalInset - height,
                      width: width,
                      height: height)
    }

    @Test("A resting pill's hit region is the drawn capsule, not the whole window")
    func restingHitRegionIsTheCapsule() {
        let rect = shellRect(for: .idle, capsuleWidth: PillMetrics.minimumCapsuleWidth)
        #expect(rect.width == PillMetrics.minimumCapsuleWidth)
        #expect(rect.height == PillMetrics.capsuleHeight)
        // Centred horizontally: (320 - 56) / 2 = 132.
        #expect(rect.origin.x == (Self.windowBounds.width - PillMetrics.minimumCapsuleWidth) / 2)
        // Bottom-anchored with `verticalInset` of clearance, in flipped space — so its
        // origin is `windowHeight - verticalInset - capsuleHeight` from the top, not
        // `verticalInset`.
        #expect(rect.maxY == Self.windowBounds.height - PillMetrics.verticalInset)
    }

    @Test("When the window is taller than the state, the hit region stays on the drawn capsule")
    func hitRegionTracksTheShellWhileTheWindowIsTallerThanTheState() {
        // This is now every resting state, not an 0.45s transient: the panel is permanently
        // note-tall while the shell is a 28pt capsule. The capsule is bottom-anchored, so its
        // hit region must sit against the bottom — not `verticalInset` down from the top,
        // which is 96pt of empty space and left the visible pill unclickable. The rect is in
        // the flipped (top-left, y-down) hosting space, so "against the bottom" is a large y.
        let tall = NSRect(x: 0, y: 0, width: PillMetrics.windowWidth,
                          height: PillMetrics.windowHeight)
        let rect = shellRect(for: .idle, capsuleWidth: PillMetrics.minimumCapsuleWidth,
                             bounds: tall)
        #expect(rect.height == PillMetrics.capsuleHeight)
        // Bottom-anchored: verticalInset of clearance below it, so its origin is that far
        // up from the window's bottom edge.
        #expect(rect.maxY == tall.height - PillMetrics.verticalInset)
        // And emphatically NOT the top-anchored value that shipped: verticalInset.
        #expect(rect.origin.y != PillMetrics.verticalInset)
    }

    @Test("A click in the dead zone would not be hit-tested")
    func deadZoneIsTransparentToClicks() {
        let rect = shellRect(for: .idle, capsuleWidth: PillMetrics.minimumCapsuleWidth)
        // A point 10pt beyond the drawn shell on every side. Any of these landing inside
        // the shell would mean the transparent margin is still eating clicks.
        let points: [NSPoint] = [
            NSPoint(x: rect.minX - 10, y: rect.midY),
            NSPoint(x: rect.maxX + 10, y: rect.midY),
            NSPoint(x: rect.midX, y: rect.minY - 10),
            NSPoint(x: rect.midX, y: rect.maxY + 10),
        ]
        for p in points {
            #expect(!rect.contains(p),
                    "point \(p) is inside the shell \(rect) — the margin is not transparent")
        }
        // But the middle of the capsule is inside — the mouse has to still reach the pill
        // it is meant to.
        #expect(rect.contains(NSPoint(x: rect.midX, y: rect.midY)))
    }

    @Test("The note card takes the mouse everywhere on itself")
    func noteCardOwnsItsRectangle() {
        // The panel is always tall enough for the card; the hit rect grows into it. Otherwise
        // the top half of the note card would be a dead zone — precisely where the header
        // and the transcript sit.
        let windowSize = NSSize(width: PillMetrics.windowWidth, height: PillMetrics.windowHeight)
        let bounds = NSRect(origin: .zero, size: windowSize)
        let rect = shellRect(for: .capturingNote,
                             capsuleWidth: PillMetrics.noteContentWidth + 20,
                             bounds: bounds)
        #expect(rect.height == PillMetrics.noteBoxHeight)
        #expect(rect.contains(NSPoint(x: rect.midX, y: rect.maxY - 5)),
                "a click near the top of the card must land on the card")
    }

    @Test("A capsule wider than the window is capped short of the window's edges")
    func hitRectStaysInsideTheWindow() {
        // A content-driven width can exceed 320 — `.error` and `.notice` carry arbitrary message
        // text — and it used to be handled by letting the shell overflow and then clamping the *hit
        // rect* to the panel. That produced a 320x28 strip across the bottom of the screen eating
        // desktop clicks, and a shell drawn wider than its panel loses its rounded caps to the clip.
        //
        // `PillMetrics.shellWidth(for:measured:)` now caps the width itself, so the shell keeps the
        // panel's own margin on both sides and stays a pill. This asserts the cap, not the old clamp.
        //
        // Asked of `.handsFree` rather than `.idle`, and the swap is the point rather than a
        // detail: `.idle` no longer *has* a measured width — `PillMetrics.shellWidth(for:)`
        // answers it with `minimumCapsuleWidth` outright, so it can no longer overflow anything.
        // The states that can are exactly the ones whose width is content-driven.
        let rect = shellRect(for: .handsFree, capsuleWidth: 9999)
        let cap = PillMetrics.windowWidth - PillMetrics.verticalInset * 2
        #expect(rect.width == cap)
        #expect(rect.maxX <= Self.windowBounds.width, "the shell must not reach the panel's edge")
        // Still centred, which is what keeps it under the pointer where the pill has always been.
        #expect(abs(rect.midX - Self.windowBounds.midX) < 0.01)
        // And a state with a known width ignores the measurement entirely, so no clamp is
        // reached at all.
        #expect(shellRect(for: .idle, capsuleWidth: 9999).width
                == PillMetrics.minimumCapsuleWidth)
    }
}
