import SwiftUI

/// The pill's interior once it has grown into a note card, for `.capturingNote`.
///
/// The state exists because the *destination* is the one thing a recording cannot show:
/// ⌃⌥N dictation goes into a Utter note the user is not looking at, rather than into the
/// app in front of them. A 28pt capsule can carry a glyph meaning "a note". It cannot say
/// *which* note, and it cannot show the words arriving - which is what the box is for.
///
/// Everything here is either a real signal or a fixed fact:
///
///   * the destination comes from `NoteStore.captureDestination`, the same decision
///     `AppDelegate.deliverToNote` files the text with,
///   * the transcript is `previewText`, the live preview pass - and when that preview is
///     switched off the box says so rather than drawing an empty pane,
///   * the dot and meter are the capsule's own, carried across the morph, and the meter
///     is real microphone RMS,
///   * the elapsed count and the chord that stops it are real,
///   * the companion, when there is one, is the *same* character that was on the desktop a
///     moment ago, still driven by the same engine - see `model.companionBehaviour`.
///
/// No word count, no progress bar, no ticker: the pill is a `.nonactivatingPanel` that
/// cannot take key focus, so this is a display and not an editor.
@MainActor
private final class NoteCaptureBoxModel: ObservableObject {
    @Published var entered = false
}

struct NoteCaptureBox: View {
    @ObservedObject var model: PillStateModel
    /// The live-indicator colour, passed in rather than picked here: `PillContent.dotTint`
    /// is where "note capture reads as the accent, not the hands-free hue" is decided, and
    /// the dot is the same dot that was in the capsule a moment ago.
    let liveTint: Color
    /// Observed, not read through the singleton at draw time: the header names the open
    /// note, so the box has to redraw when the selection or that note's title changes.
    @ObservedObject private var notes = NoteStore.shared
    @ObservedObject private var userData = UserData.shared
    /// Observed for the same reason `CompanionContainerView` observes it: a pack installed,
    /// removed or switched has to reach the character without a relaunch.
    @ObservedObject private var packStore = SpritePackStore.shared
    @ObservedObject private var motion = MotionPreference.shared

    @StateObject private var boxModel = NoteCaptureBoxModel()

    var body: some View {
        // 6 above, 10 below - the same 16pt total the two 8s spent, redistributed. Tightening the
        // header to its transcript says "this is the note, and here are the words"; loosening the
        // footer lets the live signals read as a status band rather than as another line of content.
        VStack(alignment: .leading, spacing: Space.x1 + 2) {
            header.cardRow(0, entered: boxModel.entered, reduceMotion: motion.reduceMotion)
            // With a companion to draw, the character takes a column of its own down the
            // left; with none, this is the card exactly as it was - one column, full-width
            // transcript, no gutter.
            //
            // `noteCardSettled` gates it rather than `companionBehaviour != nil` alone: this
            // subtree is the expensive part of the card (a first APNG frame decode plus a
            // subscription to a 30 Hz ticker), and building it on the morph's first frame is what
            // made opening look hurried. See the flag's own doc for the measurements.
            if model.noteCardSettled, let behaviour = model.companionBehaviour,
               hasCardCharacter {
                HStack(alignment: .bottom, spacing: Space.x2) {
                    cardCharacter(behaviour: behaviour)
                    liveColumn
                }
            } else {
                liveColumn
            }
        }
        .frame(width: PillMetrics.noteContentWidth, alignment: .leading)
        .onAppear {
            guard !motion.reduceMotion else {
                boxModel.entered = true
                return
            }
            // Deferred by a turn. Setting the flag and animating it in one synchronous pass is what
            // made the pill's settle inert: SwiftUI coalesces the writes and interpolates from the
            // committed value to itself. `onAppear` runs after a render, so this is belt-and-braces
            // rather than strictly required - and it costs one turn.
            DispatchQueue.main.async { boxModel.entered = true }
        }
        // Horizontal padding comes from `PillContent`, which applies it to every state.
        .padding(.vertical, Space.x2 + 2)
    }

    /// The transcript and the footer, which the character stands beside rather than in.
    ///
    /// **A column, not a slot in the footer, and the card's fixed height is why.** The
    /// footer is 20pt tall - the level meter sets it - and the three transcript lines leave
    /// about 7pt of slack inside `noteBoxHeight`, so a character sized to the footer would
    /// be ~27pt, under the 36pt the art needs to read as a character at all (see
    /// `CompanionSize.points`). Growing the card instead would move the pill's window
    /// height, the morph target and the position calibration for a passenger.
    ///
    /// So the cost is taken in width, which the card has: the transcript goes 272 -> 228pt.
    /// It is a head-truncated live preview whose newest words are the interesting end, and
    /// those are what survive a narrower line; `LiveTranscript.tailCharacters` (240) still
    /// hands over comfortably more than the ~126 characters 228pt of 12pt text shows.
    ///
    /// The vertical layout is untouched by the split: the outer stack still spends one 8pt
    /// gap and this one spends the other, so header/transcript/footer land on the same
    /// heights they did as three siblings.
    private var liveColumn: some View {
        VStack(alignment: .leading, spacing: Space.x2 + 2) {
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .cardRow(1, entered: boxModel.entered, reduceMotion: motion.reduceMotion)
            footer.cardRow(2, entered: boxModel.entered, reduceMotion: motion.reduceMotion)
        }
    }

    /// Where the text is going. Resolved through the store so the box and the delivery
    /// path cannot disagree about which note is being written to.
    private var destination: NoteCaptureDestination {
        notes.captureDestination(appendsToOpenNote: userData.captureAppendsToOpenNote)
    }

    /// Destination on the left, elapsed time on the right.
    private var header: some View {
        HStack(spacing: Space.x1 + 2) {
            // The glyph the capsule used to carry alone for this state, in the same
            // accent. It means "this is going into Utter"; here it finally has room for
            // the rest of the sentence beside it.
            Image(systemName: "note.text")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tint.accent)
            // Tail truncation here, unlike the transcript: the front of a note's title
            // is what identifies it.
            // Primary ink: this names the note being written to, so it is the card's title. Every
            // text in here used to resolve to `Ink.secondary` or `Ink.tertiary` - including the
            // transcript - so the card's whole reason to exist was drawn in the same grey as its own
            // footnote. That is the convergence failure `Ink.secondary`'s own doc records for the
            // main window, reproduced here.
            Text(destination.label)
                .typo(.captionEmphasis, ink: Ink.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Space.x2)
            Text(model.elapsedText).typo(.timestamp)
        }
    }

    /// The live transcript, or an honest reason there isn't one.
    @ViewBuilder
    private var transcript: some View {
        if !model.previewText.isEmpty {
            // Head-truncated, and pre-trimmed to a tail that comfortably exceeds three
            // lines: the newest words are the interesting end of a transcript that only
            // grows, so the tail has to be what survives both steps.
            // The words arriving are the point of the card, so they get the primary ink.
            //
            // Still 12pt (`.caption`), deliberately: 13pt would fit the three lines only if its line
            // spacing stayed at 1.5, and `.callout` carries 3 - which lands within half a point of
            // the card's height, and system font metrics are not ours to promise. Ink carries the
            // hierarchy here; size would have bought a clipped third line.
            Text(LiveTranscript.tail(of: model.previewText))
                .typo(.caption, ink: Ink.primary)
                .lineLimit(3)
                .truncationMode(.head)
                .multilineTextAlignment(.leading)
        } else {
            // The microphone is open and nothing has come back from the first preview
            // pass yet, which takes about a second of speech.
            //
            // There is no third branch asking the user to switch `livePreviewEnabled`
            // on: `startLivePreview` now previews unconditionally while capturing a
            // note, because a card whose purpose is to show the words arriving cannot
            // be gated on a preference that is off by default.
            Text("Listening\u{2026}").typo(.caption, ink: Ink.tertiary)
        }
    }

    /// The live signals, plus how to stop.
    private var footer: some View {
        HStack(spacing: Space.x2) {
            Circle()
                .fill(liveTint)
                .frame(width: 8, height: 8)
            LevelMeter(signal: model.levels)
            Spacer(minLength: Space.x2)
            // Read from the same `KeyChord` value `KeyMonitor` matches on, so this line
            // cannot advertise a chord that no longer fires. Note capture is hands-free
            // - nothing on screen otherwise says how to end it.
            Text("\(KeyChord.noteCapture.symbols) to finish")
                .typo(.caption, ink: Ink.tertiary)
        }
    }
}

private extension View {
    /// One row of the note card, fading and rising into place on its own delay.
    ///
    /// Opacity and offset only - both are transforms of an already-drawn row, so neither can
    /// re-anchor the glass body behind it. That is the whole constraint the card's entrance has to
    /// respect: the shell's *size* cannot animate (see `PillWindow.apply`), so everything that sells
    /// the arrival has to be something else.
    ///
    /// Under Reduce Motion the row is simply present at full opacity - not a faster stagger. A
    /// shorter animation is still an animation, and the setting asks for none.
    func cardRow(_ index: Int, entered: Bool, reduceMotion: Bool) -> some View {
        opacity(reduceMotion || entered ? 1 : 0)
            .offset(y: reduceMotion || entered ? 0 : Motion.cardRowRise)
            .animation(reduceMotion ? nil : Motion.cardRow(index), value: entered)
    }
}

/// The companion, standing in the note card.
///
/// A view of its own for one concrete reason: `@ObservedObject` cannot be optional, and
/// whether there is an engine to observe is exactly the question `NoteCaptureBox` is asking.
/// Passing the engine down here is what subscribes the card's character to the 30 Hz tick,
/// so its animation is the real one rather than a snapshot taken when the card opened.
///
/// **The pose travels; the travel does not.** `mood`, `pose` and `moodElapsed` are read
/// live - that is the handover. `behaviour.offsetX`/`offsetY` are deliberately not applied:
/// they are a stroll bounded by the desktop panel's transparent padding
/// (`CompanionGeometry.roamRange`, 18pt at this size), and a card has no such padding - the
/// character would walk into the transcript. In practice the engine has already parked it:
/// note capture puts the mood at `.alert`, which does not allow wandering, so the offsets
/// are being eased back to zero anyway (`CompanionBehaviour.advanceAmbientAct`).
/// The small character standing beside the note card's level meter.
extension NoteCaptureBox {
    /// Whether a character resolves, so the `HStack` is only built when there is something to
    /// put in it. Separate from the builder below because a `@ViewBuilder` result is never
    /// Optional and so cannot be tested with `if let`.
    var hasCardCharacter: Bool {
        packStore.pack(matching: userData.companionCharacter) != nil
    }

    @ViewBuilder
    func cardCharacter(behaviour: CompanionBehaviour) -> some View {
        if let pack = packStore.pack(matching: userData.companionCharacter) {
            CardCharacter(behaviour: behaviour, pack: pack)
        }
    }
}

private struct CardCharacter: View {
    @ObservedObject var behaviour: CompanionBehaviour
    let pack: SpritePack

    var body: some View {
        SpritePackView(pack: pack,
                       mood: behaviour.mood,
                       pose: behaviour.pose,
                       size: CompanionGeometry.inCardCharacterSize,
                       elapsed: behaviour.moodElapsed)
            // No hover lift, no poke, no drag - the desktop panel owns all three. Inside
            // the card the character is a status indicator standing next to the level
            // meter, and a click here would be a click on a panel that cannot take focus.
            .allowsHitTesting(false)
    }
}

/// Preparing a live transcript for a box that shows its last few lines.
enum LiveTranscript {
    /// How much of the tail to keep.
    ///
    /// Comfortably more than the three lines the box draws - measured at ~150 characters
    /// of ordinary prose across its 272pt at 12pt - so the view's own head truncation
    /// makes the exact cut and this only bounds how much text is handed to it. Trimming
    /// to the visible amount instead would need a text measurement per preview pass, and
    /// would cut the newest words off whenever the estimate ran short.
    static let tailCharacters = 240

    /// The end of `text`, starting on a word boundary.
    ///
    /// A growing transcript is only ever interesting at the end, and `previewText` is a
    /// pass over *all* the audio so far - so it grows without limit through a long note
    /// while the box stays one size. Cutting at a word boundary keeps the first visible
    /// word whole, and the leading ellipsis is there because silently dropping the start
    /// of a sentence would read as the transcript having begun there.
    static func tail(of text: String, maxCharacters: Int = tailCharacters) -> String {
        guard text.count > maxCharacters else { return text }
        let cut = text.suffix(maxCharacters)
        // Drop the partial word at the front, unless that is the whole of it (one very
        // long token, or a language that does not space its words).
        if let firstSpace = cut.firstIndex(where: { $0.isWhitespace }) {
            let whole = cut[cut.index(after: firstSpace)...]
            if !whole.isEmpty { return "\u{2026}" + whole }
        }
        return "\u{2026}" + cut
    }
}
