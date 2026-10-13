import Foundation

/// On-device document intelligence for notes.
///
/// Every action is one instruction string handed to `LocalAIEngine.rewrite`, the
/// same seam the dictation transforms use. Nothing new is downloaded, no account
/// exists, and nothing leaves the machine.
///
/// The important distinction is between actions that **add** and actions that
/// **replace**:
///
///   * *Summarise* and *extract action items* produce new text alongside the note.
///     If the model does something odd, the user sees an obviously wrong summary
///     and deletes it - the original is untouched.
///   * *Clean up* and *format* overwrite the note's body. Here a misbehaving model
///     destroys the user's writing, so those results are checked before being
///     applied, in the spirit of `SentencePolish.isPlausible`.
///
/// `SentencePolish`'s own check is deliberately not reused: it is tuned for
/// punctuation-scale edits (25% drift, 85% word retention) which is far too tight
/// for reflowing paragraphs and adding Markdown headings. The rules here are
/// per-action, because "how much may this legitimately change the text?" is
/// different for each one.
package enum NoteAction: String, CaseIterable, Identifiable {
    case summarise
    case actionItems
    case cleanUp
    case format
    case suggestTitle

    package var id: String { rawValue }

    package var title: String {
        switch self {
        case .summarise: return "Summarise"
        case .actionItems: return "Find action items"
        case .cleanUp: return "Clean up"
        case .format: return "Format as document"
        case .suggestTitle: return "Suggest title"
        }
    }

    package var systemImage: String {
        switch self {
        case .summarise: return "text.line.first.and.arrowtriangle.forward"
        case .actionItems: return "checklist"
        case .cleanUp: return "wand.and.sparkles"
        case .format: return "textformat"
        case .suggestTitle: return "character.cursor.ibeam"
        }
    }

    /// Present-tense label for the in-progress state.
    package var runningLabel: String {
        switch self {
        case .summarise: return "Summarising…"
        case .actionItems: return "Finding action items…"
        case .cleanUp: return "Cleaning up…"
        case .format: return "Formatting…"
        case .suggestTitle: return "Thinking of a title…"
        }
    }

    /// How the result is applied to the note.
    enum Effect {
        /// Insert above the existing body under a heading.
        case prepend(heading: String)
        /// Add below the existing body under a heading.
        case append(heading: String)
        /// Overwrite the body. Guarded.
        case replaceBody
        /// Set the note's title.
        case setTitle
    }

    var effect: Effect {
        switch self {
        case .summarise: return .prepend(heading: "## Summary")
        case .actionItems: return .append(heading: "## Action items")
        case .cleanUp, .format: return .replaceBody
        case .suggestTitle: return .setTitle
        }
    }

    /// Whether the result overwrites the user's own words, and so must be checked
    /// before it is applied.
    var overwritesBody: Bool {
        if case .replaceBody = effect { return true }
        return false
    }

    /// Shortest input worth sending. A two-line note has nothing to summarise, and
    /// the round trip is several seconds.
    var minimumWords: Int {
        switch self {
        case .suggestTitle: return 3
        case .cleanUp: return 8
        default: return 20
        }
    }

    /// Upper bound on growth for body-replacing actions, as a multiple of the
    /// original length.
    ///
    /// Cleaning up punctuation and paragraph breaks barely changes the length.
    /// Formatting adds headings and list markers, so it may grow more - but not
    /// double, which would mean the model wrote new prose.
    var maxGrowth: Double {
        switch self {
        case .cleanUp: return 1.30
        case .format: return 1.60
        default: return .infinity
        }
    }

    /// Fraction of the original words that must survive a body-replacing action.
    ///
    /// Looser than `SentencePolish`'s 0.85 because reflowing and adding structure
    /// legitimately drops filler, but tight enough that a summary or an invented
    /// paragraph cannot pass as a "clean up".
    var minimumWordRetention: Double {
        switch self {
        case .cleanUp: return 0.85
        case .format: return 0.75
        default: return 0
        }
    }

    var instructions: String {
        // All framed as transformation functions rather than assistants, and told
        // explicitly not to preamble. `SentencePolish` documents why: asked
        // conversationally, the model answers the *content* of the note instead of
        // transforming it, burying any usable output under an explanation.
        let preamble = """
            You are a text transformation function, not an assistant. You never \
            explain, comment, apologise, or answer the content of the text. You \
            never write "Here is" or "Sure" or any preamble. Your entire reply is \
            the transformed text.
            """

        switch self {
        case .summarise:
            return preamble + "\n\n" + """
                Summarise the note in 3 to 5 short bullet points, each starting \
                with "- ". Cover only what the note actually says. Add no \
                conclusions, opinions, or information that is not present.
                """
        case .actionItems:
            return preamble + "\n\n" + """
                List the tasks the note says someone needs to do. Format each as \
                "- [ ] task". Include only tasks explicitly stated in the note - \
                do not infer, suggest, or invent work. If the note contains no \
                tasks, reply with exactly: NONE
                """
        case .cleanUp:
            return preamble + "\n\n" + """
                The text was dictated, so its punctuation follows speech pauses \
                rather than grammar. Fix punctuation, capitalisation, and \
                paragraph breaks. Split run-on sentences. Remove filler words \
                like "um" and "you know".

                Preserve every fact, name, number, and the author's own wording. \
                Do not rephrase for style, do not summarise, do not add anything.
                """
        case .format:
            return preamble + "\n\n" + """
                Add Markdown structure to the note: headings (##) for its \
                sections, "- " bullets for lists, and blank lines between \
                paragraphs.

                Reorganise only the presentation. Keep all of the original \
                sentences and their wording. Add no new content, no introduction, \
                and no conclusion.
                """
        case .suggestTitle:
            return preamble + "\n\n" + """
                Reply with a single title for the note: at most 8 words, no \
                quotation marks, no trailing full stop, no "Title:" prefix.
                """
        }
    }
}

/// Outcome of running an action.
package enum NoteActionResult {
    /// The note was changed. `note` is the updated value.
    case applied
    /// The model returned nothing usable, or found nothing (e.g. no action items).
    case nothingToDo(String)
    /// The model ran but its output was rejected as implausible, so the note was
    /// left alone. Surfaced rather than swallowed: silently doing nothing looks
    /// like a broken button.
    case rejected(String)
    /// The model could not run at all.
    case unavailable(String)
}

package enum NoteActionRunner {

    /// Run `action` against the note with `id` and apply the result.
    ///
    /// Reads the note from the store at call time and writes back through it, so
    /// the UI does not have to thread the text through and cannot apply a result
    /// to a note the user has since deleted.
    @MainActor
    /// `store` is optional rather than defaulted to `.shared`: a default argument is
    /// evaluated in the *caller's* isolation, so naming a main-actor-isolated
    /// singleton there is a warning today and an error in the Swift 6 language mode.
    package static func run(
        _ action: NoteAction,
        noteID: UUID,
        store: NoteStore? = nil
    ) async -> NoteActionResult {
        let store = store ?? NoteStore.shared
        guard let note = store.notes.first(where: { $0.id == noteID }) else {
            return .nothingToDo("That note no longer exists.")
        }

        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return .nothingToDo("This note is empty.")
        }

        let wordCount = body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        guard wordCount >= action.minimumWords else {
            return .nothingToDo("The note is too short for that - \(action.minimumWords) words or more.")
        }

        let availability = LocalAIEngine.availability
        guard availability.isReady else {
            return .unavailable(availability.message)
        }

        let raw: String
        do {
            raw = try await LocalAIEngine.rewrite(
                instructions: action.instructions,
                prompt: body
            )
        } catch {
            return .unavailable(error.localizedDescription)
        }

        let result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            return .nothingToDo("The model returned nothing.")
        }

        // The action-items prompt has an explicit "nothing found" answer, so an
        // empty checklist is a real outcome rather than a failure.
        if action == .actionItems, result.uppercased().hasPrefix("NONE") {
            return .nothingToDo("No action items in this note.")
        }

        // Guard only the destructive actions. A summary that reads oddly is
        // visible and deletable; an overwritten note is not recoverable.
        if action.overwritesBody, !isPlausibleReplacement(result, original: body, action: action) {
            return .rejected("The result didn't look like a faithful \(action.title.lowercased()), so the note was left as it was.")
        }

        apply(action: action, result: result, to: noteID, store: store)
        return .applied
    }

    @MainActor
    private static func apply(
        action: NoteAction,
        result: String,
        to id: UUID,
        store: NoteStore
    ) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }

        switch action.effect {
        case .prepend(let heading):
            store.updateBody("\(heading)\n\(result)\n\n\(note.body)", for: id)
        case .append(let heading):
            store.updateBody("\(note.body)\n\n\(heading)\n\(result)", for: id)
        case .replaceBody:
            store.updateBody(result, for: id)
        case .setTitle:
            // Strip a trailing full stop and any stray quotes the model added
            // despite being told not to.
            var title = result
            if let firstLine = title.split(separator: "\n").first { title = String(firstLine) }
            title = title.trimmingCharacters(in: CharacterSet(charactersIn: " \"'“”."))
            store.updateTitle(title, for: id)
        }
        // This is the user's writing and it was just rewritten - persist now rather
        // than on the debounce.
        store.writeToDisk()
    }

    /// Whether a body-replacing result is a transformation of the original rather
    /// than a replacement of it.
    ///
    /// Same shape as `SentencePolish.isPlausible` - length bound plus in-order word
    /// retention - with per-action thresholds, because reflowing text into headings
    /// and bullets moves far more than repunctuating a sentence does.
    static func isPlausibleReplacement(
        _ candidate: String,
        original: String,
        action: NoteAction
    ) -> Bool {
        guard !candidate.isEmpty else { return false }

        // Growth bound. Shrinking is caught by word retention below: an aggressive
        // trim is fine as long as the surviving words are the author's.
        let ratio = Double(candidate.count) / Double(max(original.count, 1))
        guard ratio <= action.maxGrowth else { return false }

        func words(_ s: String) -> [String] {
            s.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        }
        let before = words(original)
        let after = words(candidate)
        guard !before.isEmpty else { return false }

        // In-order match: catches a model that kept the vocabulary but rewrote the
        // structure, which a bag-of-words comparison would wave through.
        var matched = 0
        var cursor = 0
        for word in before {
            if let idx = after[cursor...].firstIndex(of: word) {
                matched += 1
                cursor = idx + 1
            }
        }
        return Double(matched) / Double(before.count) >= action.minimumWordRetention
    }
}
