import Testing
import Foundation
import AppKit
@testable import UtterKit

/// The packs Utter actually ships, loaded from the repository.
///
/// Every other pack test builds a pack in a temporary directory, which proves the loader
/// handles the format but says nothing about whether the art in `Companions/` conforms to
/// it. That gap is where the real defects have been: a state's frames declared in
/// `pack.json` but never written, a per-state `fps` the loader silently ignored, frames
/// of differing sizes so the character changed size with its mood. All three shipped as
/// working builds.
///
/// The packs are found relative to this file rather than through `Bundle.main`: a test
/// binary has no app bundle, so `SpritePackStore.bundledDirectory` is nil here. That ties
/// the test to the repository layout, which is the point — it is asserting about the
/// repository's contents.
@Suite("Shipped companion packs")
struct ShippedPackTests {

    private static let companionsDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // UtterKitTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repository root
        .appendingPathComponent("Companions")

    /// Kept as a literal list rather than reading the directory, so deleting a pack by
    /// accident fails a test instead of quietly shrinking the set under it.
    ///
    /// The pixel cats are code-rendered and tested separately; these are the image packs
    /// copied into the production bundle.
    private let shipped = ["dog", "panda"]

    private let moods: [CompanionMood] = [
        .resting, .alert, .thinking, .delighted, .startled, .sleepy,
    ]

    @Test("Every shipped pack loads, with all six moods animated")
    func allPacksLoad() throws {
        for id in shipped {
            let directory = Self.companionsDirectory.appendingPathComponent(id)
            let pack = try SpritePackStore.loadPack(from: directory)

            #expect(pack.id == id)
            #expect(!pack.name.isEmpty)

            for mood in moods {
                let frames = pack.frames(for: mood)
                #expect(!frames.isEmpty, "\(id) has no frames for \(mood)")
                // A mood must not fall back to another mood's animation: the loader's
                // `animation(for:)` does that on purpose for an incomplete pack, and it
                // would hide a state we forgot to generate.
                let animation = pack.animations[SpritePack.key(for: mood)]
                #expect(animation != nil, "\(id) is missing the \(mood) animation")
            }
        }
    }

    /// The other half of the contract: a pack that does not draw a state must still work.
    ///
    /// The photo packs ship only the six original stills, and the fallback in `animation(for:)` is
    /// what lets them. If a future change made a missing state an error rather than a fallback,
    /// these four packs would stop loading — so the fallback is pinned as behaviour, not left as
    /// an accident of the loader.
    @Test("A pack that does not draw the pet states still loads and falls back")
    func photoPacksFallBackForUndrawnStates() throws {
        for id in ["dog", "panda"] {
            let directory = Self.companionsDirectory.appendingPathComponent(id)
            let pack = try SpritePackStore.loadPack(from: directory)

            // No knead art, so no knead animation …
            #expect(pack.animations[SpritePack.key(for: .kneading)] == nil)
            // … but asking for it still yields something to draw.
            #expect(!pack.frames(for: .kneading).isEmpty,
                    "\(id) has no fallback for an undrawn state")
        }
    }

    /// The defect this pins: the renderer fits each frame into a fixed square with
    /// `aspectRatio(.fit)`, so a taller frame is scaled down more. When the generator
    /// padded each state to its own height, the character shrank and grew as its mood
    /// changed — most visible on `delighted`, which needs the most headroom.
    @Test("A pack's frames are all the same size, so the character cannot change size")
    func frameSizesAreUniformPerPack() throws {
        for id in shipped {
            let pack = try SpritePackStore.loadPack(
                from: Self.companionsDirectory.appendingPathComponent(id)
            )
            let sizes = Set(
                moods.flatMap { pack.frames(for: $0) }.map { "\($0.size.width)x\($0.size.height)" }
            )
            #expect(sizes.count == 1, "\(id) has \(sizes.count) frame sizes: \(sizes.sorted())")
        }
    }

    /// `sleepy` is authored at 5 fps and `delighted` at 12. Both used to play at 8,
    /// because the loader read only a pack-wide `fps` while the generator writes the rate
    /// per state — so one state ran 60% fast and another 33% slow.
    /// Checked against **each pack's own manifest** rather than one hard-coded table.
    ///
    /// The table version asserted 8/10/8/12/12/5 for every pack, which are the rates
    /// `scripts/animate_pack.py` happens to emit — so it was really testing that one
    /// generator, and it failed the moment a hand-authored pack chose its own timing.
    /// Reading each manifest tests the property that actually matters, for every pack
    /// including ones added later: the rate a pack *declares* is the rate its art *plays
    /// at*. It is also strictly stronger, since a pack whose manifest and art disagree now
    /// fails even if both happen to sit in the old table.
    @Test("Per-state frame rates survive the round trip through pack.json")
    func perStateFrameRatesAreRead() throws {
        for id in shipped {
            let directory = Self.companionsDirectory.appendingPathComponent(id)
            let pack = try SpritePackStore.loadPack(from: directory)

            let manifestData = try Data(contentsOf: directory.appendingPathComponent("pack.json"))
            let manifest = try #require(
                try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
            )
            let declared = (manifest["animation"] as? [String: [String: Any]]) ?? [:]
            #expect(!declared.isEmpty, "\(id) declares no per-state rates at all")

            for mood in moods {
                let key = SpritePack.key(for: mood)
                let animation = try #require(pack.animations[key])
                #expect(Set(animation.delays).count == 1, "\(id)/\(mood) has uneven frame timing")

                // A still has no frame rate, and the generator declares none for one.
                guard animation.frames.count > 1 else { continue }
                let fps = try #require((declared[key]?["fps"] as? NSNumber)?.doubleValue,
                                       "\(id)/\(key) animates but declares no fps")
                let delay = try #require(animation.delays.first)
                // The rate reaches the renderer as a per-frame delay, so that is what is
                // checked — `1/12` is not exactly representable, hence the tolerance.
                #expect(
                    abs(delay - 1 / fps) < 0.0001,
                    "\(id)/\(mood) holds each frame \(delay)s, not \(1 / fps)s (\(fps) fps)"
                )
            }
        }
    }

    /// Frames are decoded through a thumbnail cap, so a 320px source costs the same as a
    /// 260px one. Asserting the cap holds is what stops a future pack shipping at 2048px
    /// and quietly costing tens of megabytes of decoded bitmaps.
    ///
    /// Run at every size the settings offer, because the cap is derived from the chosen
    /// one: the shipped art has to be large enough that the biggest character is not
    /// upscaled, and small enough that the smallest does not carry pixels it will never
    /// draw. The `>= cap - 1` half is the first of those — a frame that comes back
    /// *under* the cap at `huge` means the source art has run out of resolution and the
    /// character will render soft.
    ///
    @Test("Every offered size decodes the shipped art at the size it is drawn",
          arguments: CompanionSize.allCases)
    func framesAreCapped(size: CompanionSize) throws {
        let cap = SpritePackStore.maxFrameSide(for: size.points)
        for id in shipped {
            let pack = try SpritePackStore.loadPack(
                from: Self.companionsDirectory.appendingPathComponent(id),
                characterSize: size.points
            )
            for mood in moods {
                for frame in pack.frames(for: mood) {
                    let longest = max(frame.size.width, frame.size.height)
                    #expect(longest <= cap + 1,
                            "\(id)/\(mood) frame is \(longest)pt against a \(cap)pt cap at \(size)")
                    #expect(longest >= cap - 1,
                            "\(id)/\(mood) decodes to \(longest)pt at \(size), under the \(cap)pt the renderer wants — the source art is too small")
                }
            }
        }
    }

}
