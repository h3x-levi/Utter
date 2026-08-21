import Testing
@testable import UtterKit

/// Resolving the stored companion selection against the packs that exist.
///
/// This is the upgrade path: Utter used to ship four characters drawn in code, and a
/// `userdata.json` written before they were removed still names one of them. Left
/// unresolved, that selection matches no pack and the companion cannot be shown at all
/// — so the rule has to be exercised directly rather than inferred from a running app.
///
/// The pure `static` form is what is tested. The instance method around it writes to
/// the real `~/Library/Application Support/Utter/userdata.json`, so calling it from a
/// test would edit the user's own preferences; it adds only an assignment and a `save()`
/// on top of what is checked here.
@Suite("Companion selection")
struct CompanionSelectionTests {

    /// The packs Utter bundles, in the order the picker lists them — sorted by display
    /// name, which is what `SpritePackStore.reload()` produces: Golden Dog,
    /// Mochi (Cream), Mochi (Midnight), Panda.
    private let bundled = ["dog", "mochi-cream", "mochi-midnight", "panda"]

    @Test("A selection naming an installed pack is left alone")
    func exactMatchWins() {
        #expect(UserData.resolveCompanionCharacter("dog", available: bundled) == "dog")
    }

    @Test("The default is the bundled Mochi pack")
    func defaultIsMochi() {
        // A fresh install starts here, so it has to be a pack that actually ships.
        #expect(UserData.defaultCompanionPack == "mochi-midnight")
        #expect(bundled.contains(UserData.defaultCompanionPack))
        #expect(
            UserData.resolveCompanionCharacter(
                UserData.defaultCompanionPack, available: bundled
            ) == "mochi-midnight"
        )
    }

    @Test("A character from the old code-drawn set falls back to the default pack")
    func retiredBuiltinFallsBack() {
        // The four ids that used to be valid. None of them is a pack, so each has to
        // resolve to something real rather than to nothing — and to the character a
        // fresh install would get, not to whichever pack happens to sort first.
        // Note `mochi`: one of the retired ids happens to share a prefix with the new
        // `mochi-midnight` pack. It must NOT be resolved to it — a bare `mochi` names the
        // old code-drawn character, which no longer exists, so it falls back like the rest.
        for retired in ["mochi", "nori", "pip", "tori"] {
            #expect(UserData.resolveCompanionCharacter(retired, available: bundled)
                    == "mochi-midnight")
        }
    }

    @Test("An unknown selection falls back to the default pack")
    func unknownFallsBack() {
        #expect(
            UserData.resolveCompanionCharacter("not-a-character", available: bundled)
                == "mochi-midnight"
        )
    }

    @Test("Without the default pack installed, the first available one is used")
    func fallbackOfLastResort() {
        // A user who deleted the bundled packs and installed their own still gets a
        // character rather than nothing.
        #expect(UserData.resolveCompanionCharacter("mochi", available: ["zebra"]) == "zebra")
        #expect(
            UserData.resolveCompanionCharacter("mochi", available: ["aardvark", "zebra"])
                == "aardvark"
        )
    }

    @Test("A legacy pack: prefix is stripped")
    func legacyPrefixIsStripped() {
        // Packs used to be stored with a prefix, to tell them apart from the code-drawn
        // characters. Nothing distinguishes them now, but old files still carry it and
        // the pack behind it must still be found.
        #expect(
            UserData.resolveCompanionCharacter(
                UserData.legacyPackPrefix + "panda", available: bundled
            ) == "panda"
        )
    }

    @Test("A legacy prefix naming a pack that is gone still falls back")
    func legacyPrefixMissingPack() {
        #expect(
            UserData.resolveCompanionCharacter(
                UserData.legacyPackPrefix + "deleted-pack", available: bundled
            ) == "mochi-midnight"
        )
    }

    @Test("With no pack installed there is no character")
    func noPacksResolvesToNothing() {
        // Not a fallback to something invisible: nil is the signal the companion cannot
        // be displayed, which is what `CompanionWindow.show()` refuses to appear on.
        #expect(UserData.resolveCompanionCharacter("panda", available: []) == nil)
        #expect(UserData.resolveCompanionCharacter("mochi", available: []) == nil)
        #expect(UserData.resolveCompanionCharacter("", available: []) == nil)
    }

    @Test("Resolution is stable: resolving twice changes nothing")
    func resolutionIsIdempotent() {
        // The corrected value is written back to disk, so a second launch resolves the
        // *result* of the first. If that moved again the preference would never settle.
        let once = UserData.resolveCompanionCharacter("mochi", available: bundled)
        let twice = UserData.resolveCompanionCharacter(once ?? "", available: bundled)
        #expect(once == twice)
    }
}
