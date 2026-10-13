import Foundation

/// Which of the two captured audio sources a meeting turn came from.
///
/// Not a speaker. Utter captures the microphone and system output as two separate
/// streams, so it knows which *stream* every word arrived on and nothing else - see
/// `MeetingSession`. Naming the cases after the sources rather than after people is
/// deliberate: `others` is one mixed stream that may contain any number of voices.
package enum SpeakerRole: String, Codable, CaseIterable, Sendable {
    /// The microphone.
    case you
    /// System output - everyone else on the call, already mixed together by the
    /// conferencing app before Utter ever sees it.
    case others
}

/// What a meeting note calls each of its two audio sources.
///
/// Editable, and stored per note, because the machine cannot fill this in and must
/// not guess. Utter has no idea who is on a call: system audio arrives as a single
/// mixed stream, so "Others" is as specific as any *measurement* can be. The user
/// was in the meeting and can be more specific, so the label is theirs to set.
///
/// Two named fields rather than a dictionary keyed by `SpeakerRole`: a Mac in a call
/// has exactly two audio sources, and a map would imply a third could turn up.
/// It also keeps `notes.json` readable by hand, which `NoteStore.writeToDisk` treats
/// as a recovery requirement.
package struct MeetingSpeakers: Codable, Equatable, Sendable {
    /// The microphone - one person, always, because it is the user's own mic.
    package var you: String

    /// System output. Legitimately several people under one name, which is why
    /// renaming this to a single person's name is the user's assertion and not the
    /// app's.
    package var others: String

    /// What meeting capture writes before the user renames anything.
    package static let `default` = MeetingSpeakers(you: "You", others: "Others")

    package subscript(role: SpeakerRole) -> String {
        get {
            switch role {
            case .you: return you
            case .others: return others
            }
        }
        set {
            switch role {
            case .you: you = newValue
            case .others: others = newValue
            }
        }
    }
}

/// The shape meeting capture writes into a note's body, and the one operation that
/// has to understand it after the fact.
///
/// The body is the artefact: the user edits it in the Notes editor, copies it, and
/// exports it as Markdown. So a transcript is plain text with a bold label at the
/// start of each turn, and renaming a speaker means rewriting those labels in place
/// rather than keeping a display-time mapping that the exported file would not have.
enum MeetingTranscript {

    /// The label that opens a turn.
    static func heading(_ label: String) -> String { "**\(label):**" }

    /// One turn as it appears in the note.
    static func line(_ label: String, _ text: String) -> String {
        "\(heading(label)) \(text)"
    }

    /// Rewrite every turn heading for `old` to `new`, leaving everything else alone.
    ///
    /// Anchored to the start of a line, not a global find-and-replace, because
    /// `**Others:**` can legitimately occur *inside* what somebody said - in a
    /// transcript of a meeting about this very feature, for instance. Rewriting that
    /// would be editing the user's words rather than relabelling their transcript.
    ///
    /// Uses ICU's multiline `^` rather than splitting on `"\n"`. Splitting would miss
    /// CRLF entirely (Swift treats it as a single grapheme cluster, so `"\n"` never
    /// matches it - the same trap documented on `Note.derivedTitle`), and rejoining
    /// on `"\n"` afterwards would silently normalise line endings the user had pasted
    /// in. `escapedPattern` and `escapedTemplate` keep a name containing regex or
    /// template metacharacters - `C++ (Ana)`, say, or a stray `$1` - from being
    /// interpreted.
    static func relabel(_ body: String, from old: String, to new: String) -> String {
        let oldHeading = heading(old)
        guard !old.isEmpty, old != new, body.contains(oldHeading) else { return body }

        return body.replacingOccurrences(
            of: "(?m)^" + NSRegularExpression.escapedPattern(for: oldHeading),
            with: NSRegularExpression.escapedTemplate(for: heading(new)),
            options: .regularExpression
        )
    }
}
