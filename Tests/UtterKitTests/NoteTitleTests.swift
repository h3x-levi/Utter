import Testing
import Foundation
@testable import UtterKit

/// Titling a note from its body.
///
/// `derivedTitle` is the only thing standing between a note and being unfindable: it
/// runs on every keystroke of an untitled note, and whatever it returns is what the
/// user scans the list for. It is also pure and static, so it is testable directly  - 
/// no store, no disk, and in particular no contact with the real
/// `~/Library/Application Support/Utter/notes.json`.
@Suite("Note titling")
struct NoteTitleTests {

    // MARK: The first line wins

    @Test("The title is the first line that has something in it")
    func firstNonEmptyLine() {
        #expect(Note.derivedTitle(from: "Standup notes\nrest of the body") == "Standup notes")
        // Leading blank and whitespace-only lines are skipped rather than titling the
        // note with a space - `omittingEmptySubsequences` alone does not do this,
        // because "   " is not an empty subsequence.
        #expect(Note.derivedTitle(from: "\n\n   \n\t\nStandup notes\nmore") == "Standup notes")
        // Surrounding whitespace on the chosen line is trimmed.
        #expect(Note.derivedTitle(from: "   Standup notes   \nmore") == "Standup notes")
    }

    @Test("Markdown heading markers are stripped, at any depth")
    func stripsHeadingMarkers() {
        #expect(Note.derivedTitle(from: "# Standup") == "Standup")
        #expect(Note.derivedTitle(from: "### Deploy review") == "Deploy review")
        // Meeting capture writes exactly this shape (`MeetingSession.start`), so a
        // meeting note must not be titled "# Meeting - …".
        #expect(Note.derivedTitle(from: "# Meeting - Aug 11, 2:15 PM\n") == "Meeting - Aug 11, 2:15 PM")
        // No space after the marker, and a marker mid-line that must survive.
        #expect(Note.derivedTitle(from: "#Standup") == "Standup")
        #expect(Note.derivedTitle(from: "Ticket #4821 triage") == "Ticket #4821 triage")
    }

    // MARK: Nothing to derive

    @Test("A note with no usable first line derives no title")
    func emptyBodies() {
        #expect(Note.derivedTitle(from: "") == "")
        #expect(Note.derivedTitle(from: "\n\n\n") == "")
        #expect(Note.derivedTitle(from: "   \n\t\n  ") == "")
        // A line of nothing but heading markers reduces to empty, which is the case
        // the `!line.isEmpty` guard after stripping exists for - without it this
        // would return "" from a different path or crash on `prefix`.
        #expect(Note.derivedTitle(from: "###\nReal title here") == "")
    }

    // MARK: Truncation

    @Test("A long first line is cut on a word boundary with an ellipsis")
    func truncatesOnWordBoundary() {
        // 84 characters, so truncation must happen.
        let long = "The quarterly deployment review meeting covering all of the pipeline failures we saw"
        #expect(long.count > 60)

        let title = Note.derivedTitle(from: long)
        #expect(title.hasSuffix("…"))
        // Cut at the last space inside the first 60 characters, so the visible text is
        // whole words - never a word sliced in half.
        #expect(title == "The quarterly deployment review meeting covering all of the…")
        #expect(!title.dropLast().hasSuffix(" "))
        #expect(long.hasPrefix(String(title.dropLast())))
    }

    @Test("Truncation triggers above 60 characters, not at it")
    func truncationBoundary() {
        let exactly60 = String(repeating: "x", count: 60)
        #expect(Note.derivedTitle(from: exactly60) == exactly60)
        #expect(!Note.derivedTitle(from: exactly60).hasSuffix("…"))

        let sixtyOne = String(repeating: "x", count: 61)
        #expect(Note.derivedTitle(from: sixtyOne).hasSuffix("…"))
    }

    @Test("A long line with no late word boundary is cut hard rather than dropped")
    func hardCutWhenNoWordBoundary() {
        // A single 80-character token: there is no space to cut on, so the fallback
        // hard cut must produce something rather than returning empty.
        let unbroken = String(repeating: "a", count: 80)
        let title = Note.derivedTitle(from: unbroken)
        #expect(title.hasSuffix("…"))
        #expect(title.dropLast().count == 60)

        // A space too early to be a sensible cut (index <= 30) also falls through to
        // the hard cut - cutting here would leave a 2-character title.
        let earlySpace = "ab " + String(repeating: "c", count: 80)
        let earlyTitle = Note.derivedTitle(from: earlySpace)
        #expect(earlyTitle.dropLast().count == 60)
        #expect(earlyTitle != "ab…")
    }

    // MARK: displayTitle

    @Test("displayTitle is never empty, whatever the note contains")
    func displayTitleNeverEmpty() {
        // A brand-new blank note: the case that would otherwise render as an
        // unclickable empty row in the notes list.
        #expect(Note(body: "").displayTitle == "Untitled note")
        #expect(Note(body: "   \n\n  ").displayTitle == "Untitled note")
        #expect(Note(body: "###").displayTitle == "Untitled note")

        // Derived when there is a body to derive from.
        #expect(Note(body: "# Standup\nnotes").displayTitle == "Standup")

        // An explicit title always wins over the body.
        #expect(Note(title: "Pinned", body: "# Something else").displayTitle == "Pinned")
    }

    @Test("wordCount counts across every kind of whitespace")
    func wordCount() {
        #expect(Note(body: "one two three").wordCount == 3)
        // Tabs, single and double newlines all separate; runs do not inflate the count.
        #expect(Note(body: "one\ttwo\nthree\n\nfour").wordCount == 4)
        #expect(Note(body: "one     two").wordCount == 2)
        #expect(Note(body: "").wordCount == 0)
        #expect(Note(body: "  \n\t ").wordCount == 0)
    }
}
