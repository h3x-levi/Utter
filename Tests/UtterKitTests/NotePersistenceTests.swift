import Testing
import Foundation
@testable import UtterKit

/// Encoding and decoding `notes.json`.
///
/// Notes are the only copy of the user's own writing - `NoteStore` deliberately has no
/// entry cap for that reason - so the encoder and decoder are the narrowest point at
/// which everything can be silently lost. Two failures matter: a field that does not
/// survive a round trip (data loss on the next launch), and a file the decoder chokes
/// on in a way that takes the app down rather than being reported.
///
/// These exercise `JSONEncoder`/`JSONDecoder` configured the way `NoteStore`
/// configures them - ISO 8601 *with fractional seconds*, `.prettyPrinted` - rather than
/// going through the singleton, which is bound to the real Application Support
/// directory and whose `load()`/`writeToDisk()` would read and overwrite the user's
/// actual notes.
///
/// The coders below mirror the *shape* of `writeToDisk()`/`load()` but use the store's
/// own `NoteDateFormat` formatters rather than copies of them. That matters: the two
/// formatters are the wire format, and a local copy would keep passing after the store
/// changed its own - testing a contract nothing upholds. `wireFormatMatchesTheStoresOwnOutput`
/// pins the encoded text on top of that, so a change to `NoteDateFormat` itself is
/// caught rather than silently agreed with.
@Suite("Note persistence")
struct NotePersistenceTests {

    /// Matches `NoteStore.writeToDisk()`.
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(NoteDateFormat.fractional.string(from: date))
        }
        return encoder
    }

    /// Matches `NoteStore.load()`, including its acceptance of both date shapes.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = NoteDateFormat.fractional.date(from: text) { return date }
            if let date = NoteDateFormat.whole.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised date: \(text)"
            )
        }
        return decoder
    }

    /// The legacy whole-second formatter must reject a fractional stamp, and the
    /// fractional one must reject a whole-second stamp.
    ///
    /// This is the assumption `load()`'s two-line fallback rests on. If
    /// `NoteDateFormat.fractional` ever started accepting whole seconds the fallback
    /// would be dead code, and if `whole` started accepting fractions the order of the
    /// two lines would stop mattering - either way the next person would be reading a
    /// comment that no longer describes anything.
    @Test("The two formatters are genuinely different shapes, which is why load() tries both")
    func formattersAreNotInterchangeable() {
        let fractional = "2023-11-14T22:13:20.125Z"
        let whole = "2023-11-14T22:13:20Z"

        #expect(NoteDateFormat.fractional.date(from: fractional) != nil)
        #expect(NoteDateFormat.fractional.date(from: whole) == nil)
        #expect(NoteDateFormat.whole.date(from: whole) != nil)
        #expect(NoteDateFormat.whole.date(from: fractional) == nil)
    }

    /// A note with every field set to something distinguishable from its default, so a
    /// dropped field shows up as a mismatch rather than coincidentally matching.
    ///
    /// Millisecond-resolution dates: the wire format carries 3 decimal places, so a
    /// stamp with more precision than that does not compare equal after a round trip.
    /// That residual limit is pinned by `precisionIsMillisecondsNotArbitrary` below
    /// rather than smuggled into every other assertion.
    private func fixture() -> Note {
        Note(
            id: UUID(uuidString: "5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F")!,
            title: "Pinned title",
            body: "# Standup\n\nShipped the rollback fix.",
            // Deliberately sub-second: the store's format carries milliseconds, so a
            // fractional stamp must survive. A whole-second fixture here would pass
            // even under the old lossy `.iso8601` strategy and prove nothing.
            created: Date(timeIntervalSince1970: 1_700_000_000.125),
            modified: Date(timeIntervalSince1970: 1_700_003_600.875),
            tags: ["work", "standup"],
            source: .meeting,
            titleIsCustom: true
        )
    }

    // MARK: Round trip

    @Test("Every field survives a round trip through the store's own coders")
    func roundTripPreservesAllFields() throws {
        let original = fixture()
        let decoded = try decoder().decode(Note.self, from: encoder().encode(original))

        #expect(decoded == original)

        // Field by field as well as by `==`: `Note`'s `Equatable` is synthesised, so if
        // a property is ever added without being coded, `==` still compares it and this
        // stays honest - but naming them documents which ones matter.
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.body == original.body)
        #expect(decoded.created == original.created)
        #expect(decoded.modified == original.modified)
        #expect(decoded.tags == original.tags)
        // The two flags that change behaviour rather than presentation: losing
        // `titleIsCustom` makes the next body edit silently rename a note the user
        // titled themselves, and losing `source` mislabels a meeting capture.
        #expect(decoded.titleIsCustom == true)
        #expect(decoded.source == .meeting)
    }

    @Test("An array of notes round-trips, which is the shape actually on disk")
    func roundTripsAsAnArray() throws {
        // `notes.json` holds `[Note]`, not a wrapper object.
        //
        // Millisecond-resolution stamps, per `fixture()`: a default `Date()` would
        // carry more precision than the wire format and fail on that rather than on
        // anything to do with array coding.
        let stamp = Date(timeIntervalSince1970: 1_700_000_000.500)
        let notes = [
            fixture(),
            Note(body: "dictated one", created: stamp, modified: stamp, source: .dictated),
            Note(body: "", created: stamp, modified: stamp, source: .typed),
        ]
        let decoded = try decoder().decode([Note].self, from: encoder().encode(notes))
        #expect(decoded.count == 3)
        #expect(decoded == notes)
        #expect(decoded.map(\.source) == [.meeting, .dictated, .typed])
    }

    @Test("Each source case survives by name, so a rename would be caught")
    func sourceRoundTripsByRawValue() throws {
        for source in [NoteSource.typed, .dictated, .meeting] {
            let note = Note(body: "b", source: source)
            let decoded = try decoder().decode(Note.self, from: encoder().encode(note))
            #expect(decoded.source == source)
        }

        // Pin the on-disk spelling: these strings are in every existing user's file,
        // so changing a case name without a migration silently orphans their notes.
        let json = String(data: try encoder().encode(Note(body: "b", source: .meeting)),
                          encoding: .utf8)
        #expect(json?.contains("\"meeting\"") == true)
    }

    // MARK: Dates

    @Test("Two notes touched in the same second stay distinct and correctly ordered")
    func subSecondOrderingSurvives() throws {
        // `NoteStore.load()` sorts by `modified` descending, and `grouped()` sorts each
        // group the same way. If sub-second precision were dropped, two notes edited
        // within one second would compare equal on reload and the list order would be
        // arbitrary across launches - the note the user just touched could sort below
        // an older one.
        let earlier = Date(timeIntervalSince1970: 1_700_000_000.100)
        let later = Date(timeIntervalSince1970: 1_700_000_000.900)
        #expect(earlier.timeIntervalSince1970.rounded(.down)
                == later.timeIntervalSince1970.rounded(.down))   // same whole second

        let notes = [Note(body: "older", created: earlier, modified: earlier),
                     Note(body: "newer", created: later, modified: later)]
        let decoded = try decoder().decode([Note].self, from: encoder().encode(notes))

        #expect(decoded[0].modified != decoded[1].modified)
        #expect(decoded[1].modified > decoded[0].modified)
        // Sorted the way the store sorts, the newer note still leads.
        #expect(decoded.sorted { $0.modified > $1.modified }.first?.body == "newer")
    }

    @Test("A legacy whole-second notes file still loads")
    func legacyWholeSecondDatesStillLoad() throws {
        // Files written before the fractional-seconds change carry `...:20Z` with no
        // decimal part. The decoder accepts both shapes on purpose: rejecting the old
        // one would make every existing note undecodable, and `load()`'s `try?` would
        // turn that into an apparently empty notes list.
        let legacy = """
            [{"id":"5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F","title":"Old note",
              "body":"written by an earlier build","created":"2023-11-14T22:13:20Z",
              "modified":"2023-11-14T22:13:20Z","tags":[],"source":"typed",
              "titleIsCustom":false}]
            """
        let decoded = try decoder().decode([Note].self, from: Data(legacy.utf8))
        #expect(decoded.count == 1)
        #expect(decoded.first?.body == "written by an earlier build")
        #expect(decoded.first?.modified == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("The wire format is fractional ISO 8601, which is what makes a file portable")
    func wireFormatMatchesTheStoresOwnOutput() throws {
        // Pins the encoded shape rather than only the round trip. A round trip passes
        // even if both sides change to something no other build can read, which would
        // silently orphan the user's file on downgrade.
        let note = Note(created: Date(timeIntervalSince1970: 1_700_000_000.125),
                        modified: Date(timeIntervalSince1970: 1_700_000_000.125))
        let json = String(data: try encoder().encode(note), encoding: .utf8) ?? ""

        #expect(json.contains("2023-11-14T22:13:20.125Z"))
        // Not a bare epoch number, which is what `.secondsSince1970` would emit.
        #expect(!json.contains("1700000000"))
    }

    @Test("Precision is milliseconds, so equality needs a millisecond-resolution stamp")
    func precisionIsMillisecondsNotArbitrary() throws {
        // The residual limit of the format, documented so the next person does not read
        // it as a decoding bug. Harmless: `modified` only drives ordering and grouping,
        // and a millisecond is finer than any two user edits.
        let overPrecise = Date(timeIntervalSince1970: 1_700_000_000.1234567)
        let decoded = try decoder().decode(
            Note.self, from: encoder().encode(Note(created: overPrecise, modified: overPrecise)))

        #expect(decoded.created != overPrecise)
        #expect(abs(decoded.created.timeIntervalSince(overPrecise)) < 0.001)

        // At millisecond resolution it is exact.
        let exact = Date(timeIntervalSince1970: 1_700_000_000.123)
        let round = try decoder().decode(
            Note.self, from: encoder().encode(Note(created: exact, modified: exact)))
        #expect(round.created == exact)
    }

    // MARK: Hostile files

    @Test("A malformed notes file is reported as an error, never a crash")
    func malformedFilesThrowRatherThanCrash() throws {
        // `NoteStore.load()` swallows these with `try?` and keeps the file untouched.
        // What matters here is that decoding *throws* - if any of these trapped
        // instead, the app would crash on launch with the user's notes on disk and
        // no way to get past it.
        let good = try encoder().encode([fixture()])
        let goodText = String(data: good, encoding: .utf8)!

        let hostile: [(String, Data)] = [
            ("not JSON at all", Data("{not json at all".utf8)),
            ("empty file", Data()),
            ("truncated mid-record", Data(goodText.prefix(goodText.count / 2).utf8)),
            ("a single byte", Data("[".utf8)),
            // A plausible-looking file of the wrong shape: an object where an array
            // is expected, which is what a future schema change would produce.
            ("wrapped in an object", Data("{\"notes\":[]}".utf8)),
            // Valid JSON, valid array, but the elements are not notes.
            ("array of strings", Data("[\"a\",\"b\"]".utf8)),
            // Right shape, missing a required key.
            ("record missing id", Data("[{\"title\":\"t\",\"body\":\"b\"}]".utf8)),
            // A `source` this build has never heard of - what a downgrade after a
            // future release adds a case would look like.
            ("unknown source value",
             Data(goodText.replacingOccurrences(of: "\"meeting\"", with: "\"telepathy\"").utf8)),
            // Dates in a format `.iso8601` will not accept.
            ("epoch-number dates",
             Data(#"[{"id":"5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F","title":"t","body":"b","created":1700000000,"modified":1700000000,"tags":[],"source":"typed","titleIsCustom":false}]"#.utf8)),
        ]

        for (name, data) in hostile {
            #expect(throws: (any Error).self, "\(name) should be reported, not accepted") {
                _ = try decoder().decode([Note].self, from: data)
            }
            // And the way `NoteStore.load()` actually calls it yields nil rather than
            // trapping, which is what keeps launch survivable.
            #expect((try? decoder().decode([Note].self, from: data)) == nil, "\(name)")
        }
    }

    @Test("An empty notes array is a valid file, not a corrupt one")
    func emptyArrayDecodes() throws {
        // The state left behind by Privacy → Clear All Data. It must decode to zero
        // notes, because treating it as corrupt would make `deleteAll` look broken on
        // the next launch.
        let decoded = try decoder().decode([Note].self, from: Data("[]".utf8))
        #expect(decoded.isEmpty)
    }

    @Test("A note whose body holds JSON and control characters survives verbatim")
    func awkwardBodiesSurvive() throws {
        // Dictation and meeting capture put arbitrary text in `body`. Quotes,
        // backslashes and braces are the classic way a hand-rolled serialiser
        // corrupts a file; this proves the real one escapes them.
        let nasty = #"{"not":"a note"} \ " \n <script> emoji 🎧 tab\there"# + "\n\treal newline"
        let note = Note(body: nasty, source: .dictated)
        let decoded = try decoder().decode(Note.self, from: encoder().encode(note))
        #expect(decoded.body == nasty)
    }
}
