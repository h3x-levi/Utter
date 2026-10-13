import Testing
@testable import UtterKit
@testable import UtterCore

/// Which voice commands survive a note capture, and why the distinction exists.
///
/// While dictation is being filed into a Utter note, only the *routing* commands are
/// obeyed. The editing ones are keystrokes aimed at the frontmost app's text field,
/// and the text is not going there - obeying them typed into an unrelated document.
/// They are also not swallowed as recognised-but-refused, because
/// `checkVoiceCommand` matches on `hasSuffix`: an ordinary sentence can end in a
/// command phrase, and dropping it would delete words from the only copy the user has.
@Suite("Voice command routing")
struct VoiceCommandRoutingTests {

    @Test("Only the note commands are classified as routing")
    func routingClassification() {
        #expect(VoiceAction.startNewNote.isNoteRouting)
        #expect(VoiceAction.continueNote.isNoteRouting)

        for action: VoiceAction in [.undo, .selectAll, .newLine, .newParagraph,
                                    .goToEnd, .copy, .paste] {
            #expect(!action.isNoteRouting, "\(action) edits text; it must not route")
        }
    }

    /// The reason editing commands fall through to the note as plain text rather than
    /// being dropped. If this ever stops matching, the fall-through is still correct
    /// but its justification has changed.
    @Test("A sentence merely ending in a command phrase matches the command")
    @MainActor
    func suffixMatchIsAmbiguous() {
        let data = UserData.shared
        let wasEnabled = data.voiceCommandsEnabled
        data.voiceCommandsEnabled = true
        defer { data.voiceCommandsEnabled = wasEnabled }

        // Not instructions - the closing words of sentences somebody dictated. Each
        // of these is read as an editing command, which during a note capture would
        // have fired a keystroke at the frontmost app *and* dropped the sentence.
        #expect(data.checkVoiceCommand("the old config is stale so I'll delete that") == .undo)
        #expect(data.checkVoiceCommand("put the shipping address on a new line") == .newLine)
        #expect(data.checkVoiceCommand("send them the deck, they can copy that") == .copy)

        // For contrast: a command *word* alone is not enough, so the ambiguity comes
        // from whole phrases landing at the end of a sentence, not from loose matching.
        #expect(data.checkVoiceCommand("he asked for a redlined copy") == nil)
    }

    @Test("The note commands are still recognised from speech")
    @MainActor
    func noteCommandsRecognised() {
        let data = UserData.shared
        let wasEnabled = data.voiceCommandsEnabled
        data.voiceCommandsEnabled = true
        defer { data.voiceCommandsEnabled = wasEnabled }

        // Trailing punctuation is stripped before matching, so the transcriber's
        // full stop must not stop these from being commands.
        #expect(data.checkVoiceCommand("start a new note.") == .startNewNote)
        #expect(data.checkVoiceCommand("continue the note") == .continueNote)
    }
}
