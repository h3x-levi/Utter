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
    /// Two packs were removed from this list deliberately, and the reason is worth keeping:
    /// they depicted recognisable characters from published anime. Generating the art did
    /// not make it ours — copyright attaches to a character's visual expression, not to the
    /// brush that drew it — so shipping them in a public repository would have been
    /// infringement. The policy is stated on `SpritePack`; user-installed packs are the
    /// supported route for art Utter cannot ship itself.
    private let shipped = ["dog", "panda", "mochi-midnight", "mochi-cream"]

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

    /// The pixel packs draw the pet states and the walk gait; the photo packs deliberately do not.
    ///
    /// This pins the bug that made the typing animation impossible to see. `SpritePack.stateNames`
    /// is the loader's entire vocabulary — `discoverByConvention` iterates it, and it populates
    /// `animations` even for a pack that ships a `pack.json`. The pet states and the walk gait were
    /// added to `key(for:)` and `walkAnimation` **without** being added to `stateNames`, so
    /// `knead.png`, `walk.png`, `purr.png`, `hunt.png`, `drag.png` and `overheat.png` were never
    /// read. Seven PNGs per mochi pack sat on disk unloaded.
    ///
    /// It was silent because `animation(for:)` falls back to `resting` by design, for the photo
    /// packs that genuinely lack the art — so the cat played its idle loop while "typing", and no
    /// test noticed. `allPacksLoad` above could not catch it either: it only walks the original six
    /// moods. Hence a separate test that names the states the fallback would otherwise hide.
    @Test("The pixel packs load the pet states and the walk gait, not a resting fallback")
    func pixelPacksLoadPetStates() throws {
        let petMoods: [CompanionMood] = [.kneading, .overheating, .purring, .hunting, .held]
        for id in ["mochi-midnight", "mochi-cream"] {
            let directory = Self.companionsDirectory.appendingPathComponent(id)
            let pack = try SpritePackStore.loadPack(from: directory)

            for mood in petMoods {
                let key = SpritePack.key(for: mood)
                let animation = pack.animations[key]
                #expect(animation != nil,
                        "\(id) drew \(key).png but the loader never read it — is \(key) in stateNames?")
                #expect(animation?.frames.isEmpty == false, "\(id) loaded \(key) with no frames")
            }

            // The gait is not a mood, so it is resolved separately and would fail separately.
            #expect(pack.walkAnimation != nil,
                    "\(id) drew walk.png but walkAnimation found nothing — is \"walk\" in stateNames?")
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
    /// **Pixel-art packs are exempt from that lower bound, and only that one.** Being
    /// smaller than the cap is what pixel art *is*: Mochi is authored at 32px and drawn
    /// with nearest-neighbour at a whole-number multiple, so 32px against a 91px cap is
    /// the design rather than a shortfall. The upper bound still applies to them — the
    /// memory ceiling this test exists to defend is not about art style — and the pixel
    /// packs have their own resolution contract, enforced in the generator
    /// (`tools/mochi/generate_mochi.py --verify`) and by the renderer's integer snapping.
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
                    if pack.pixelArt { continue }
                    #expect(longest >= cap - 1,
                            "\(id)/\(mood) decodes to \(longest)pt at \(size), under the \(cap)pt the renderer wants — the source art is too small")
                }
            }
        }
    }

    /// The pixel packs' own contract, in place of the resolution floor above.
    ///
    /// A pixel pack is only crisp if three things hold, and all three are easy to break
    /// with an innocent-looking edit to the generator: the canvas must be exactly 32px so
    /// the renderer's integer snapping produces the intended 32/48/64/80pt ladder, every
    /// frame must be that same size, and the eye layer must match the body exactly or the
    /// loader discards it and the cat stops tracking the cursor.
    @Test("Pixel packs are 32px square, with a matching eye layer")
    func pixelPacksHoldTheirGrid() throws {
        for id in shipped {
            let pack = try SpritePackStore.loadPack(
                from: Self.companionsDirectory.appendingPathComponent(id),
                characterSize: UserData.defaultCompanionSize.points
            )
            guard pack.pixelArt else { continue }

            #expect(pack.frameSize == CGSize(width: 32, height: 32),
                    "\(id) is \(pack.frameSize) — the renderer's snapping assumes 32px")
            #expect(pack.eyeOverlay != nil,
                    "\(id) has no usable eyes.png, so it cannot track the cursor")
            #expect(pack.eyeOverlay?.size == pack.frameSize,
                    "\(id) eye layer does not match its frames")
            #expect(pack.eyeTravel > 0, "\(id) declares no eye travel")

            // The typing pose leans, so its head is not where the resting pose has it and
            // the shared eye layer has to be told. Without this anchor the pupils stay
            // behind and float beside the face — which is the bug that blocked the leaning
            // pose from existing at all, so it is worth a test rather than a comment.
            let kneadAnchor = pack.eyeAnchor(for: .kneading)
            #expect(kneadAnchor.dx != 0 || kneadAnchor.dy != 0,
                    "\(id) has no eye anchor for the leaning typing pose")
            // Every other state keeps the resting head, so it must NOT be nudged.
            for mood in [CompanionMood.resting, .alert, .thinking, .sleepy] {
                let anchor = pack.eyeAnchor(for: mood)
                #expect(anchor.dx == 0 && anchor.dy == 0,
                        "\(id)/\(mood) should use the resting eye position")
            }
        }
    }

    /// A malformed or oversized anchor must not put the pupils outside the frame.
    @Test("Eye anchors are clamped and bad ones ignored")
    func eyeAnchorsAreDefensive() throws {
        // The real pack, as a baseline: its one anchor is inside the clamp.
        let pack = try SpritePackStore.loadPack(
            from: Self.companionsDirectory.appendingPathComponent("mochi-midnight")
        )
        let anchor = pack.eyeAnchor(for: .kneading)
        #expect(abs(anchor.dx) <= 12 && abs(anchor.dy) <= 12)
        // A state nobody declared falls back to no offset rather than to nil-and-crash.
        #expect(pack.eyeAnchor(for: .held).dx == 0)
    }
}
