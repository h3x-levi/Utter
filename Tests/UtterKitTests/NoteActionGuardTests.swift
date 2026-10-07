import Testing
import Foundation
@testable import UtterKit

/// The guard that stops a misbehaving model from destroying a note.
///
/// `.cleanUp` and `.format` overwrite the note's body, and `NoteStore` keeps no undo
/// history and no previous revision on disk - so if an implausible result is applied,
/// the user's writing is gone. `isPlausibleReplacement` is the only thing between the
/// model's output and that overwrite, which makes it the most safety-critical pure
/// function here.
///
/// The fixtures are one dictated paragraph and a set of realistic model responses to it,
/// including the failure mode `SentencePolish` documents from real testing: asked to
/// transform text, the model answers its *content* instead. Every threshold assertion
/// below was checked against the real implementation's arithmetic, so each test
/// distinguishes accept from reject rather than restating whichever answer came out.
@Suite("Note action plausibility guard")
struct NoteActionGuardTests {

    // MARK: Fixtures

    /// A dictated paragraph, punctuated the way Whisper punctuates: comma splices,
    /// filler words, no sentence boundaries. 301 characters, 60 words.
    static let dictated = """
        so i looked at the deployment this morning and it failed again um the alarm fired at \
        around four in the morning and the rollback did not happen automatically you know so i \
        had to go in and roll it back by hand we should probably add a canary stage before prod \
        and file a ticket about the missing alarm
        """

    /// What a well-behaved `.cleanUp` returns: the same words, repunctuated, fillers
    /// dropped. 295 characters, 95% of the words retained in order.
    static let repunctuated = """
        So I looked at the deployment this morning and it failed again. The alarm fired at \
        around four in the morning, and the rollback did not happen automatically, so I had to \
        go in and roll it back by hand. We should probably add a canary stage before prod, and \
        file a ticket about the missing alarm.
        """

    // MARK: Faithful transformations are accepted

    @Test("A faithful repunctuation of a dictated paragraph is accepted")
    func acceptsFaithfulRepunctuation() {
        // The whole point of the feature. If this were rejected, `.cleanUp` would
        // always report "the result didn't look faithful" and never do anything.
        #expect(NoteActionRunner.isPlausibleReplacement(
            Self.repunctuated, original: Self.dictated, action: .cleanUp))
        // Anything `.cleanUp` accepts, the looser `.format` must accept too.
        #expect(NoteActionRunner.isPlausibleReplacement(
            Self.repunctuated, original: Self.dictated, action: .format))
    }

    @Test("Adding headings and bullets is accepted as formatting")
    func acceptsMarkdownStructure() {
        // `##` headings and `- ` bullets over the author's own sentences: exactly what
        // the `.format` instructions ask for.
        let formatted = """
            ## Deployment failure

            So I looked at the deployment this morning and it failed again. The alarm fired at \
            around four in the morning, and the rollback did not happen automatically, so I had to \
            go in and roll it back by hand.

            ## Follow-ups

            - We should probably add a canary stage before prod
            - and file a ticket about the missing alarm
            """
        #expect(NoteActionRunner.isPlausibleReplacement(
            formatted, original: Self.dictated, action: .format))
        #expect(formatted.contains("## "))
        #expect(formatted.contains("- "))
    }

    // MARK: Destructive results are rejected

    @Test("A summary is rejected, because it would silently replace the note")
    func rejectsSummary() {
        // A summary is a perfectly good answer to the wrong question. Applied as a
        // `.cleanUp`, it deletes four fifths of what the user dictated: the 4 a.m.
        // timing, the manual rollback, who did it. Only 5% of the original words
        // survive in order, so the retention floor catches it.
        let summary = """
            The deployment failed overnight and the rollback did not fire, so add a canary stage \
            and file a ticket about the alarm.
            """
        #expect(!NoteActionRunner.isPlausibleReplacement(
            summary, original: Self.dictated, action: .cleanUp))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            summary, original: Self.dictated, action: .format))

        // Note it is *not* caught by length: at 39% of the original it is well inside
        // both growth bounds, so shrinkage alone proves nothing and the in-order word
        // check is what does the work here.
        #expect(Double(summary.count) / Double(Self.dictated.count) < 1.30)
    }

    @Test("A conversational answer to the note's content is rejected")
    func rejectsConversationalAnswer() {
        // The documented real-world failure: `SentencePolish` measured this exact
        // behaviour ("I'm sorry to hear that…" plus an explanation) in testing. Its
        // length happens to be almost identical to the original - 95% - so a
        // length-only check waves it straight through and the note becomes the
        // model's chit-chat.
        let chatty = """
            I'd be happy to help! Here are some thoughts on what you have written. It sounds like \
            you are dealing with a flaky deployment pipeline, which is frustrating. My suggestion \
            would be to look into why nobody was paged, and to consider whether a canary really is \
            the right mitigation here.
            """
        let ratio = Double(chatty.count) / Double(Self.dictated.count)
        #expect(ratio > 0.9 && ratio < 1.30)   // inside every growth bound

        #expect(!NoteActionRunner.isPlausibleReplacement(
            chatty, original: Self.dictated, action: .cleanUp))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            chatty, original: Self.dictated, action: .format))
    }

    @Test("Inventing whole new sections is rejected even when the original is kept intact")
    func rejectsInventedSections() {
        // The dangerous shape: the author's text is preserved verbatim - retention is
        // 95%, so the word check is satisfied - and the model has appended "## Risks"
        // and "## Owner" containing claims the user never made. Only the growth bound
        // stops this, which is why `.format` caps at 1.60 rather than trusting
        // retention alone.
        let invented = """
            ## Deployment failure

            So I looked at the deployment this morning and it failed again. The alarm fired at \
            around four in the morning, and the rollback did not happen automatically, so I had to \
            go in and roll it back by hand.

            ## Follow-ups

            - We should probably add a canary stage before prod
            - and file a ticket about the missing alarm

            ## Risks

            If the rollback keeps failing silently the next outage will go unnoticed for hours and \
            on-call will have no signal at all. A synthetic probe against the health endpoint would \
            catch this class of failure much earlier.

            ## Owner

            Unassigned. Whoever is on call next week should pick this up and confirm the rollback \
            automation points at the correct target group.
            """
        // 235% of the original.
        #expect(Double(invented.count) / Double(Self.dictated.count) > 1.60)
        #expect(!NoteActionRunner.isPlausibleReplacement(
            invented, original: Self.dictated, action: .format))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            invented, original: Self.dictated, action: .cleanUp))
    }

    // MARK: Degenerate input

    @Test("An empty candidate and an empty original are both rejected")
    func rejectsEmptyInput() {
        for action in [NoteAction.cleanUp, .format] {
            // An empty candidate would blank the note outright - the worst possible
            // outcome, and the first thing the function guards.
            #expect(!NoteActionRunner.isPlausibleReplacement(
                "", original: Self.dictated, action: action))
            #expect(!NoteActionRunner.isPlausibleReplacement("", original: "", action: action))
            #expect(!NoteActionRunner.isPlausibleReplacement("", original: "a", action: action))
        }

        // The `!candidate.isEmpty` guard is only *observable* through an action with no
        // retention floor: for `.cleanUp`/`.format` an empty candidate is rejected a
        // second time by retention scoring 0, so deleting the guard would not change
        // their answers. `.summarise` has `maxGrowth` `.infinity` and a floor of 0, so
        // it is the case that proves the guard is present and load-bearing.
        //
        // `run` never reaches the guard for `.summarise` today (it does not overwrite
        // the body, and empty output is caught earlier), but the function is public and
        // takes any action, so it must not report "plausible" for nothing at all.
        #expect(!NoteActionRunner.isPlausibleReplacement(
            "", original: Self.dictated, action: .summarise))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            "", original: Self.dictated, action: .suggestTitle))
    }

    @Test("An original with no words rejects any candidate, however short")
    func rejectsWordlessOriginal() {
        // An original with nothing in it has no words to retain, so no candidate can be
        // judged faithful to it - approving here would let arbitrary text be written
        // into a note the guard knows nothing about.
        //
        // The candidates are deliberately *shorter* than the originals. A long
        // candidate against a blank original trips the growth bound first (ratio 63 for
        // a full paragraph against ""), so it would pass this test even if the
        // `before.isEmpty` guard were deleted. These reach that guard specifically.
        for action in [NoteAction.cleanUp, .format] {
            #expect(!NoteActionRunner.isPlausibleReplacement("x", original: "", action: action))

            // Whitespace only: a non-zero character count, so the growth ratio stays
            // below 1.0, but no alphanumeric words at all.
            #expect(!NoteActionRunner.isPlausibleReplacement(
                "some text", original: "   \n\t\n   \n  ", action: action))

            // Punctuation only, on both sides: `words()` strips non-alphanumerics, so
            // the original still reduces to nothing.
            #expect(!NoteActionRunner.isPlausibleReplacement(
                "-- ...", original: "   \n\t\n   \n  ", action: action))
            #expect(!NoteActionRunner.isPlausibleReplacement(
                "ok", original: ".,;-- !?", action: action))
        }
    }

    @Test("The same words in reversed order are rejected, so the check is not bag-of-words")
    func rejectsReorderedWords() {
        // Identical vocabulary, identical length, every word present - and meaning
        // destroyed. A set- or multiset-based comparison scores this 100% and applies
        // it. The in-order walk scores it 5%.
        let reversed = Self.dictated
            .split(whereSeparator: { $0.isWhitespace })
            .reversed()
            .joined(separator: " ")

        #expect(reversed.count == Self.dictated.count)   // same length, so not a size catch
        #expect(Set(reversed.split(separator: " ")) == Set(Self.dictated.split(separator: " ")))

        #expect(!NoteActionRunner.isPlausibleReplacement(
            reversed, original: Self.dictated, action: .cleanUp))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            reversed, original: Self.dictated, action: .format))
    }

    // MARK: The per-action thresholds genuinely differ

    @Test("Heavy Markdown scaffolding passes format's growth bound but not clean-up's")
    func growthBoundDiffersByAction() {
        // Every word is the author's, in order (95% retention) - the extra characters
        // are purely headings, bullet markers and blank lines. At 134% of the original
        // it sits in the gap between `.cleanUp`'s 1.30 ceiling and `.format`'s 1.60.
        //
        // This is the assertion that proves `maxGrowth` is actually consulted per
        // action: a single shared constant makes one of these two expectations fail.
        let structureHeavy = """
            ## Deployment

            - So I looked at the deployment this morning.
            - And it failed again.

            ## The alarm

            - The alarm fired at around four in the morning.

            ## The rollback

            - And the rollback did not happen automatically.
            - So I had to go in and roll it back by hand.

            ## Follow-ups

            - We should probably add a canary stage before prod.
            - And file a ticket about the missing alarm.

            ## Notes

            - Nothing further.
            """
        let ratio = Double(structureHeavy.count) / Double(Self.dictated.count)
        #expect(ratio > 1.30 && ratio <= 1.60)

        #expect(NoteActionRunner.isPlausibleReplacement(
            structureHeavy, original: Self.dictated, action: .format))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            structureHeavy, original: Self.dictated, action: .cleanUp))
    }

    @Test("Dropping a whole clause passes format's retention floor but not clean-up's")
    func retentionFloorDiffersByAction() {
        // Faithfully repunctuated, but the closing clause is gone: 82% of the words
        // survive, between `.format`'s 0.75 floor and `.cleanUp`'s 0.85. Losing a
        // sentence is acceptable slack when reflowing into a document and is not
        // acceptable when the only stated job was fixing punctuation.
        //
        // Length cannot be what separates them here: at 84% of the original this is
        // inside both growth bounds, so only `minimumWordRetention` can tell them
        // apart.
        let clauseDropped = """
            So I looked at the deployment this morning and it failed again. The alarm fired at \
            around four in the morning, and the rollback did not happen automatically, so I had to \
            go in and roll it back by hand. We should probably add a canary stage before prod.
            """
        #expect(Double(clauseDropped.count) / Double(Self.dictated.count) < 1.30)

        #expect(NoteActionRunner.isPlausibleReplacement(
            clauseDropped, original: Self.dictated, action: .format))
        #expect(!NoteActionRunner.isPlausibleReplacement(
            clauseDropped, original: Self.dictated, action: .cleanUp))
    }

    // MARK: The guard is wired to the right actions

    @Test("Only the body-replacing actions are guarded")
    func onlyDestructiveActionsAreGuarded() {
        // The guard is applied by `run` under `if action.overwritesBody`, so which
        // actions carry it is part of the safety property. A summary that reads oddly
        // sits above the note and is deletable; an overwritten note is not.
        #expect(NoteAction.cleanUp.overwritesBody)
        #expect(NoteAction.format.overwritesBody)
        #expect(!NoteAction.summarise.overwritesBody)
        #expect(!NoteAction.actionItems.overwritesBody)
        #expect(!NoteAction.suggestTitle.overwritesBody)

        // The unguarded actions have no thresholds at all, which is only safe because
        // they never replace the body.
        #expect(NoteAction.summarise.maxGrowth == .infinity)
        #expect(NoteAction.summarise.minimumWordRetention == 0)

        // And the guarded ones are ordered tight-to-loose rather than being equal.
        #expect(NoteAction.cleanUp.maxGrowth < NoteAction.format.maxGrowth)
        #expect(NoteAction.cleanUp.minimumWordRetention > NoteAction.format.minimumWordRetention)
    }
}
