import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// One state's animation: its frames, and how long each is held.
///
/// Per-frame timing rather than a single frame rate, because that is the whole reason
/// to prefer **APNG** over a sprite strip. An animator holds a pose for four frames
/// and snaps through the next three; a fixed fps flattens that into a metronome and
/// the performance dies. APNG stores a delay per frame, so the timing the art was
/// drawn with is the timing it plays at.
struct CompanionAnimation: Equatable {
    let frames: [NSImage]
    /// Seconds to hold each frame. Same count as `frames`.
    let delays: [Double]

    /// Total cycle length. Used to wrap the clock, so animations of different lengths
    /// stay independent instead of all restarting together.
    var duration: Double { max(delays.reduce(0, +), 0.001) }

    /// The frame showing at `time` seconds into the loop.
    ///
    /// Walks the accumulated delays rather than dividing by an average: with variable
    /// timing, dividing would show the wrong frame everywhere except by coincidence.
    /// Never returns an index `frames` does not have.
    ///
    /// The walk runs over `delays`, so a value built with more delays than frames
    /// would return an index past the end — and the renderer subscripts `frames`
    /// with it, which is a crash rather than a glitch. The loader keeps the two
    /// arrays in step on every path, so this is unreachable today; it is clamped
    /// anyway because "unreachable" is a property of the current call sites, not of
    /// the type, and the cost is one `min`.
    func frameIndex(at time: Double) -> Int {
        guard frames.count > 1 else { return 0 }
        let cycle = time.truncatingRemainder(dividingBy: duration)
        var accumulated = 0.0
        for (index, delay) in delays.enumerated() {
            accumulated += delay
            if cycle < accumulated { return min(index, frames.count - 1) }
        }
        return frames.count - 1
    }

    /// A single still image, held indefinitely.
    static func still(_ image: NSImage) -> CompanionAnimation {
        CompanionAnimation(frames: [image], delays: [1])
    }
}

/// A companion loaded from disk instead of drawn in code.
///
/// This is how a user brings their own character. Utter ships no third-party art —
/// anime characters are copyrighted, and bundling them would be infringement — but
/// a pack the user installs themselves is their own business, and this is the seam
/// that makes it possible without the app ever fetching anything.
///
/// Packs live in `~/Library/Application Support/Utter/Companions/<pack-id>/`.
/// Three layouts are accepted, in the order they are looked for. The first two need
/// no `pack.json` at all — the filenames say everything the loader needs:
///
/// **1. One animated PNG per state (recommended).** APNG keeps full 8-bit alpha and
/// carries its own per-frame timing, and macOS decodes it natively:
///
/// ```
/// my-character/
///   resting.png      alert.png      thinking.png
///   delighted.png    startled.png   sleepy.png
/// ```
///
/// **2. A folder of numbered frames per state.** Sorted naturally, so `2.png` comes
/// before `10.png`:
///
/// ```
/// my-character/resting/01.png 02.png 03.png
/// my-character/alert/01.png 02.png
/// ```
///
/// **3. A horizontal sprite strip per state, described by `pack.json`:**
///
/// ```json
/// {
///   "name": "My Character",
///   "frameWidth": 64, "frameHeight": 64, "fps": 8,
///   "states": { "resting": { "file": "idle.png", "frames": 4 } }
/// }
/// ```
///
/// Only `resting` is required; any missing state falls back to it, so a
/// one-animation pack works.
///
/// **Not GIF.** An animated GIF loads — refusing a file the OS can read would be
/// unhelpful — but its transparency is a single bit, so every anti-aliased edge
/// becomes a staircase and every soft shadow a block of hard pixels. Measured on a
/// 56px character: 32 distinct alpha levels collapsed to 2, and all 212
/// partially-transparent pixels went fully opaque or fully clear. Use APNG.
struct SpritePack: Identifiable, Equatable {
    let id: String
    let name: String
    let author: String
    let frameSize: CGSize

    /// Whether this pack is pixel art, from `"pixelArt": true` in `pack.json`.
    ///
    /// Two things have to change for pixel art, and both are wrong for the photo-derived
    /// packs, which is why it is a per-pack flag rather than a global switch:
    ///
    ///   * **Interpolation.** The renderer smooths frames with `.interpolation(.high)`,
    ///     which is right for a 1792px illustration scaled down to 52pt and fatal for a
    ///     32px sprite scaled *up* — bilinear filtering turns every hard pixel edge into
    ///     a gradient, and the art's entire character is those edges.
    ///   * **Integer scaling.** See `SpritePackView.renderedSize`.
    ///
    /// Defaults to false, so every existing pack behaves exactly as before.
    let pixelArt: Bool

    /// A separate eye layer, drawn over the body and offset to follow the cursor.
    ///
    /// Optional, and absent for every photo-derived pack: their eyes are painted into the
    /// frame, and there is nothing to move. A pack opts in by shipping `eyes.png` on the
    /// same canvas as its body frames, with everything but the eyes transparent.
    ///
    /// The eyes have to be a separate asset rather than baked per-direction frames because
    /// the aim is continuous — the cursor can be anywhere — and authoring a frame per
    /// direction for every state would multiply the art by nine to express two pixels of
    /// movement.
    let eyeOverlay: NSImage?

    /// How far the eye layer may travel from centre, in *source pixels*, from
    /// `"eyeTravel"` in `pack.json`.
    ///
    /// In source pixels because that is the only unit the artist can reason in: a 32px cat
    /// has room for about two pixels of iris travel before the eye leaves the socket, and
    /// the renderer scales that by whatever the sprite is being drawn at. Expressing it in
    /// points would break the moment the user changed the companion's size.
    let eyeTravel: CGFloat

    /// Per-state eye positions, in source pixels, from `"eyeAnchors"` in `pack.json`.
    ///
    /// The eye layer is one shared asset, anchored to wherever the head sits in the resting
    /// pose. That is fine while every pose keeps the head in the same place, and it is what
    /// blocked the character from ever *leaning*: move the head for one state and the pupils
    /// stay behind, floating beside the face.
    ///
    /// An anchor per state solves it without multiplying the art. The alternative — baking
    /// the eyes into that state's frames — would lose cursor tracking in exactly the state
    /// where the pointer matters most, since the typing pose is the one you are looking at
    /// while your hands are on the keyboard.
    ///
    /// Keyed by state name rather than by mood, because the pack speaks in state names and
    /// the mapping from mood to state already lives in `key(for:)`.
    let eyeAnchors: [String: CGVector]

    /// Animations per state, keyed by state name.
    let animations: [String: CompanionAnimation]

    /// Where the eye layer sits for a mood, in source pixels. Zero for states that keep the
    /// head where the resting pose has it, which is most of them.
    func eyeAnchor(for mood: CompanionMood) -> CGVector {
        eyeAnchors[Self.key(for: mood)] ?? CGVector(dx: 0, dy: 0)
    }

    static func == (lhs: SpritePack, rhs: SpritePack) -> Bool { lhs.id == rhs.id }

    /// The animation for a mood, falling back to `resting`.
    func animation(for mood: CompanionMood) -> CompanionAnimation? {
        if let exact = animations[Self.key(for: mood)], !exact.frames.isEmpty { return exact }
        return animations["resting"]
    }

    /// The walk-cycle animation, if the pack ships distinct `walk` frames.
    ///
    /// Separate from `animation(for:)` because walking is an ambient *gait*, not a mood — the
    /// mood stays `resting` while the character crosses the desktop, so there is no mood to
    /// key it on (see `CompanionPose.gait`). A pack without a `walk` state returns nil and the
    /// renderer falls back to the resting loop, which is exactly how the photo packs behaved
    /// while the stroll was only an in-panel shuffle.
    var walkAnimation: CompanionAnimation? {
        guard let walk = animations["walk"], !walk.frames.isEmpty else { return nil }
        return walk
    }

    /// The frames for a mood. Kept for the picker, which only needs a thumbnail.
    func frames(for mood: CompanionMood) -> [NSImage] {
        animation(for: mood)?.frames ?? []
    }

    static func key(for mood: CompanionMood) -> String {
        switch mood {
        case .resting: return "resting"
        case .alert: return "alert"
        case .thinking: return "thinking"
        case .delighted: return "delighted"
        case .startled: return "startled"
        case .sleepy: return "sleepy"
        // The pet states. A pack that does not draw them falls back to `resting` in
        // `animation(for:)`, which is why the four shipped character packs needed no new
        // art when these were added.
        case .kneading: return "knead"
        case .overheating: return "overheat"
        case .purring: return "purr"
        case .hunting: return "hunt"
        case .held: return "drag"
        case .grooming: return "grooming"
        case .rolling: return "rolling"
        case .loaf: return "loaf"
        }
    }

    /// The side a pixel-art sprite is drawn at, snapped so nearest-neighbour stays on a
    /// whole pixel grid. `SpritePackView.renderedSize` is the only caller.
    ///
    /// Two directions, and the second one is a bug fix. Where the canvas is *smaller* than
    /// the box in device pixels, snap down to the largest whole multiple that fits — a 32px
    /// cat in a 52pt box on a 2x display gets 1x rather than 1.625x, so no source pixel is
    /// drawn 3 device pixels wide while its neighbour gets 4.
    ///
    /// Where the canvas is **larger** than the box, there is no whole multiple that fits at
    /// all, and the previous `max(1, …)` clamped to 1x — which returns a side *bigger than
    /// the box it was asked for*. That silently broke the invariant every other piece of the
    /// companion's geometry is derived from: `CompanionGeometry` sizes the panel from the
    /// requested `characterSize`, and a borderless panel clips its content, so the character
    /// was sliced at the window edge mid-roam. It needed a 64px pack on a **1x** display to
    /// show up — 64px in a 36pt box — which is why it shipped: every Retina display divides
    /// the other way. So snap to the largest whole *divisor* instead: 1/2, 1/3, …, which is
    /// just as exact under nearest-neighbour and always fits.
    ///
    /// Returns `box` unchanged for a canvas or scale that cannot be divided by, rather than
    /// dividing by zero.
    static func snappedSide(box: CGFloat, canvas: CGFloat, displayScale: CGFloat) -> CGFloat {
        let devicePixels = box * displayScale
        guard canvas >= 1, displayScale >= 1, devicePixels >= 1 else { return box }
        let multiple = (devicePixels / canvas).rounded(.down)
        guard multiple >= 1 else {
            return canvas / (canvas / devicePixels).rounded(.up) / displayScale
        }
        return canvas * multiple / displayScale
    }
}

/// Finds, validates and loads sprite packs from disk.
@MainActor
final class SpritePackStore: ObservableObject {
    static let shared = SpritePackStore()

    @Published private(set) var packs: [SpritePack] = []
    /// Packs that were present but could not be loaded, with the reason.
    ///
    /// Surfaced in Settings rather than swallowed: a user who has just hand-built
    /// a pack needs to know *why* it did not appear, and silence would send them
    /// to the wrong conclusion.
    @Published private(set) var failures: [(id: String, reason: String)] = []

    /// The pack a selection resolves to, or `nil` when none of the loaded packs can
    /// serve it — which includes the case where none is loaded at all.
    ///
    /// Both the renderer and the window's decision to appear go through this, so they
    /// cannot disagree: a panel shown with no pack behind it is an invisible companion
    /// beside the pill and a click target the user cannot see or explain.
    ///
    /// Takes the selection as an argument rather than reading `UserData` itself so a
    /// SwiftUI body that calls it also *observes* the preference. Reading the singleton
    /// in here would resolve correctly and then fail to redraw when the user picked a
    /// different character.
    ///
    /// Read-only: it never writes the resolved value back, because it is called from a
    /// view body. `UserData.resolveCompanionCharacter(against:)` persists the
    /// correction, once, after a scan.
    /// Memoised, because this is called from a view body that re-runs 30 times a second.
    ///
    /// The companion's behaviour ticker publishes at 30 Hz, so `CompanionContainerView.character`
    /// re-evaluates that often for as long as the character is on screen — and every evaluation
    /// used to build a fresh `[String]` of every pack's id (`packs.map(\.id)`) purely to hand it to
    /// the resolver, then scan the packs again to turn the answer back into a pack. Two allocations
    /// and two linear scans per frame, forever, to compute a value that changes only when the user
    /// picks a different character or a pack is installed.
    ///
    /// Keyed on the selection so the argument still decides the answer — which is what lets a view
    /// body observe the preference and redraw when it changes, exactly as the note above requires.
    /// Cleared whenever `packs` is reassigned, so an installed, removed or repaired pack is picked
    /// up without a relaunch.
    private var resolved: [String: SpritePack] = [:]

    func pack(matching selection: String) -> SpritePack? {
        if let hit = resolved[selection] { return hit }
        guard let id = UserData.resolveCompanionCharacter(
            selection, available: packs.map(\.id)
        ) else { return nil }
        guard let pack = packs.first(where: { $0.id == id }) else { return nil }
        resolved[selection] = pack
        return pack
    }

    /// Where packs live. Created on demand so the "Open Folder" button in Settings
    /// always has somewhere to open.
    ///
    /// `nonisolated` because it is a pure path computation that touches none of this
    /// class's state — requiring the main actor to ask where a folder is would push
    /// the isolation outward onto every caller for no reason.
    nonisolated static var directory: URL {
        AppDirectory.subdirectory("Companions")
    }

    /// Packs shipped inside the app bundle.
    ///
    /// These are defaults, not user content: they must be present on a fresh
    /// install with nothing in Application Support. Keeping them in the bundle also
    /// means they cannot be half-deleted — a user who wants rid of one turns the
    /// companion off or picks another, rather than leaving a broken folder behind.
    ///
    /// `nil` when running from a plain `swift build` binary rather than an .app,
    /// which is the test and development case.
    nonisolated static var bundledDirectory: URL? {
        Bundle.main.url(forResource: "Companions", withExtension: nil)
    }

    private init() {}

    /// What the last scan saw, so an unchanged folder is not decoded again.
    private var lastScanSignature: [String: Date]?

    /// The character size the frames currently in `packs` were decoded for.
    ///
    /// Part of the skip condition, not a separate check: the frame cap is derived from
    /// this (`maxFrameSide(for:)`), so a size change makes the loaded frames the wrong
    /// resolution even though every folder is untouched — which is exactly the case the
    /// modification-date signature is blind to. Without it, raising the size upscaled a
    /// bitmap decoded for a smaller one and the character went soft.
    private var lastDecodedSize: CGFloat?

    /// Rescan the packs directory. Cheap when empty, which is the common case.
    ///
    /// Skips the work when the pack folders look exactly as they did last time.
    /// This is called from `CompanionSettingsView.onAppear`, so without the guard
    /// every visit to the Companion pane re-decoded every frame of every installed
    /// pack — measured at 170-230 ms of main-thread work for the three shipped packs,
    /// for a result identical to the one already in `packs`.
    ///
    /// The signature is folder modification dates, which catch a pack being added,
    /// removed or renamed — the reasons this is called on appear. They do *not* catch
    /// a frame edited in place, because writing a file does not touch its parent
    /// directory's mtime. That case is what `force` is for, and it is what the Rescan
    /// button in Settings passes.
    ///
    /// The size the frames were decoded for is part of the condition too, because
    /// nothing on disk changes when the user resizes the character — see
    /// `lastDecodedSize`.
    func reload(force: Bool = false) {
        let fm = FileManager.default
        let root = Self.directory
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        func folders(in directory: URL) -> [URL] {
            (try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }

        // Bundled packs first, then the user's. The code-drawn cats reserve their legacy
        // ids so an old PNG folder cannot silently replace the built-in implementation.
        var entries = folders(in: Self.bundledDirectory ?? root)
        if Self.bundledDirectory != nil { entries += folders(in: root) }
        let codePackIDs = Set(CodePixelCatStyle.allCases.map(\.rawValue))
        entries.removeAll { codePackIDs.contains($0.lastPathComponent) }

        // The one place the drawn size enters the loader. Read here, on the main actor,
        // where reading a preference is safe and obvious.
        let characterSize = UserData.shared.companionSize.points
        let signature = Self.signature(of: entries)
        if !force, let lastScanSignature, lastScanSignature == signature,
           lastDecodedSize == characterSize { return }

        var found = CodePixelCatStyle.allCases.map(\.pack)
        var failed: [(id: String, reason: String)] = []

        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            else { continue }
            do {
                found.append(try Self.loadPack(from: entry, characterSize: characterSize))
            } catch {
                failed.append((id: entry.lastPathComponent,
                               reason: (error as? PackError)?.message ?? "Could not read the pack"))
            }
        }

        // Dedupe by id, last-one-wins, so a user pack shadows a bundled image pack
        // with the same name rather than the grid showing duplicates.
        var byID: [String: SpritePack] = [:]
        for pack in found { byID[pack.id] = pack }

        packs = byID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        // The memoised resolutions describe the *previous* set of packs. Dropping them here is what
        // keeps `pack(matching:)`'s cache honest: a pack installed, removed, renamed or repaired
        // has to reach the companion without a relaunch, and a stale entry would either keep
        // rendering a pack that is gone or refuse to notice one that has arrived.
        resolved.removeAll()
        failures = failed
        lastScanSignature = signature
        lastDecodedSize = characterSize
    }

    /// Folder paths to their modification dates. Recorded only after a scan
    /// succeeds, so a scan that threw part-way is retried rather than remembered.
    ///
    /// `.distantPast` for a folder whose date cannot be read: unreadable is a state
    /// that should compare equal to itself and unequal to a folder that later becomes
    /// readable, and defaulting to "now" would make every scan look different.
    ///
    /// Not private so the comparison can be tested directly. Testing it through
    /// `reload()` is not an option: the store is a singleton reading the real
    /// Application Support folder, so a test of it would depend on — and could
    /// disturb — whatever the user has installed.
    nonisolated static func signature(of entries: [URL]) -> [String: Date] {
        var signature: [String: Date] = [:]
        for entry in entries {
            let values = try? entry.resourceValues(
                forKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            guard values?.isDirectory == true else { continue }
            signature[entry.path] = values?.contentModificationDate ?? .distantPast
        }
        return signature
    }

    // MARK: Loading

    /// Load one pack folder.
    ///
    /// `nonisolated static` rather than an instance method on the main actor: loading is
    /// pure input-to-value work with no shared state, and this is the seam the tests
    /// drive. Requiring the main actor and the singleton just to parse a folder would
    /// force every test to hop actors and share one global store.
    ///
    /// `characterSize` is the size the frames will be *drawn* at, which is what decides
    /// how much of each one is worth keeping (`maxFrameSide`). Passed in rather than read
    /// from `UserData` here for the same reason nothing else in this file reads it: a
    /// loader that consulted a preference from a nonisolated context would be both a
    /// hidden dependency and a test whose result depended on the developer's settings.
    /// It defaults to the shipped size so a caller that genuinely does not care — every
    /// loader test — gets a deterministic cap.
    nonisolated static func loadPack(
        from directory: URL,
        characterSize: CGFloat = UserData.defaultCompanionSize.points
    ) throws -> SpritePack {
        let maxFrameSide = Self.maxFrameSide(for: characterSize)
        let manifestURL = directory.appendingPathComponent("pack.json")
        let json: [String: Any]
        if let data = try? Data(contentsOf: manifestURL) {
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PackError("pack.json is not valid JSON")
            }
            json = parsed
        } else {
            // No manifest at all is fine when the folder uses the convention-based
            // layouts (an animated PNG or numbered frames per state). Requiring a
            // hand-written JSON file to describe what the filenames already say is
            // busywork, and hand-computed frame sizes are the single most common way
            // to get a pack wrong.
            json = [:]
        }

        var animations: [String: CompanionAnimation] = [:]

        if let states = json["states"] as? [String: [String: Any]], !states.isEmpty {
            // Explicit layout: a strip per state, sliced by declared frame size.
            //
            // Frame dimensions are required here, and only here: a horizontal strip
            // cannot be cut without them, and guessing (say, assuming square frames)
            // would silently mangle any pack that isn't.
            guard let frameWidth = (json["frameWidth"] as? NSNumber)?.doubleValue,
                  let frameHeight = (json["frameHeight"] as? NSNumber)?.doubleValue,
                  frameWidth > 0, frameHeight > 0 else {
                throw PackError("pack.json needs positive frameWidth and frameHeight")
            }
            let frameSize = CGSize(width: frameWidth, height: frameHeight)

            for (state, spec) in states {
                guard let file = spec["file"] as? String else { continue }
                let declaredFrames = (spec["frames"] as? NSNumber)?.intValue ?? 1
                // Clamp the number of frames *kept* to the same per-state ceiling both
                // convention paths apply, so a hand-written `frames` count can't ask the
                // slicer to produce thousands.
                let frameCount = min(declaredFrames, maxFramesPerState)
                guard frameCount > 0 else { continue }

                let url = try Self.resolve(file, in: directory, state: state)
                let fps = Self.declaredFPS(in: json, state: state)

                // A single animated file (APNG) named in `states` is read as its own
                // frames rather than sliced — the frames are already separate, and
                // slicing one would cut the first frame into pieces.
                if let animated = Self.animatedAnimation(at: url, overrideFPS: fps,
                                                         maxFrameSide: maxFrameSide) {
                    animations[state] = animated
                    continue
                }

                // Bound the sheet decode. `NSImage(contentsOf:)` decodes the whole file
                // at full resolution, so a hand-written pack.json that pairs a tiny
                // `frameWidth` with a huge PNG hangs the main thread on a multi-GB bitmap.
                //
                // The budget bounds two separate abuses:
                //   * the declared sheet width (`declaredFrames * frameWidth`) — a tiny
                //     declared frameWidth caps it to near-nothing whatever the file's real
                //     size, which is exactly the attack above;
                //   * an absolute ceiling of one full-size strip at the frame limit
                //     (`maxFrameSide * maxFramesPerState`) — backstops a huge *declared*
                //     frame count so that can't reopen the multi-GB decode either.
                //
                // A sheet within budget is read with `NSImage(contentsOf:)`, unchanged:
                // `slice` relies on `rep.pixelsWide` equalling the file's real pixels,
                // and only that call preserves it (the size-capped `decodeImage` wraps a
                // CGImage, whose rep reports backing-scaled pixels on a Retina display and
                // would throw the frame count off). The pixel dimensions are read from the
                // image source's metadata first, which does not decode the bitmap, so an
                // oversized file is recognised *before* it is opened and routed to the
                // capped thumbnail decode instead — bounded, at the cost of exact framing
                // on a sheet that already disagrees with its own manifest. `slice` then
                // caps each kept frame again.
                let declaredWidth = CGFloat(max(declaredFrames, 0)) * frameWidth
                let absoluteCeiling = maxFrameSide * CGFloat(maxFramesPerState)
                let sheetCap = min(max(declaredWidth, frameHeight), absoluteCeiling)

                let sheet: NSImage?
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                   let pw = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
                   let ph = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
                   max(pw, ph) <= Double(sheetCap) {
                    sheet = NSImage(contentsOf: url)
                } else {
                    // Oversized, or dimensions unreadable → decode a bounded thumbnail
                    // rather than trusting the file's own size.
                    sheet = Self.decodeImage(at: url, maxFrameSide: sheetCap)
                }
                guard let sheet else {
                    throw PackError("\(state): could not read \(file)")
                }
                let frames = Self.slice(sheet: sheet, frameSize: frameSize,
                                        count: frameCount, maxFrameSide: maxFrameSide)
                guard !frames.isEmpty else {
                    throw PackError("\(state): \(file) is smaller than one frame")
                }
                animations[state] = Self.evenlyTimed(frames, fps: fps ?? 8)
            }
        } else {
            // Convention-based layout: discover the states from the filenames, so a
            // pack can be "drop these files in a folder" with no manifest at all.
            animations = try Self.discoverByConvention(in: directory, manifest: json,
                                                       maxFrameSide: maxFrameSide)
            guard !animations.isEmpty else {
                throw PackError("No pack.json, and no resting.png or resting/ folder found")
            }
        }

        guard let resting = animations["resting"], !resting.frames.isEmpty else {
            throw PackError("No \u{201C}resting\u{201D} animation found")
        }

        return SpritePack(
            id: directory.lastPathComponent,
            name: (json["name"] as? String) ?? directory.lastPathComponent,
            author: (json["author"] as? String) ?? "",
            // Taken from the art rather than the manifest: the renderer scales to the
            // companion's own box, whatever size the user chose, so this is only
            // reported, never used to slice.
            frameSize: resting.frames[0].size,
            pixelArt: (json["pixelArt"] as? NSNumber)?.boolValue ?? false,
            eyeOverlay: Self.loadEyeOverlay(in: directory, matching: resting.frames[0].size),
            // Clamped to 4px: beyond that an iris leaves the socket on any sprite small
            // enough to need this feature, and the result is a cat with eyes floating
            // beside its head. Zero is allowed, and means "loaded the layer, don't move it".
            eyeTravel: min(4, max(0, (json["eyeTravel"] as? NSNumber)?.doubleValue ?? 2)),
            eyeAnchors: Self.parseEyeAnchors(json["eyeAnchors"]),
            animations: animations
        )
    }

    /// Read `"eyeAnchors": { "knead": [0, 3] }` — a per-state `[dx, dy]` in source pixels.
    ///
    /// Clamped to ±12px, which is a third of a 32px canvas: an anchor larger than that is a
    /// typo rather than an intention, and an unclamped one would park the pupils outside the
    /// frame where they simply vanish. Malformed entries are skipped rather than failing the
    /// pack — this is hand-edited data, and a pack with one bad anchor should still load with
    /// the rest of its states working.
    nonisolated private static func parseEyeAnchors(_ raw: Any?) -> [String: CGVector] {
        guard let table = raw as? [String: [NSNumber]] else { return [:] }
        var anchors: [String: CGVector] = [:]
        for (state, pair) in table where pair.count == 2 {
            let dx = min(12, max(-12, pair[0].doubleValue))
            let dy = min(12, max(-12, pair[1].doubleValue))
            anchors[state] = CGVector(dx: dx, dy: dy)
        }
        return anchors
    }

    /// Load `eyes.png` if the pack ships one.
    ///
    /// Rejected rather than scaled when its canvas does not match the body frames: the
    /// whole layer works by sitting exactly on top of the body, so a mismatched size means
    /// eyes landing somewhere near the ear. Failing to find them is a pack that does not
    /// track the cursor, which is a missing feature; drawing them in the wrong place is a
    /// broken character, which is worse.
    nonisolated private static func loadEyeOverlay(in directory: URL,
                                                   matching size: CGSize) -> NSImage? {
        let url = directory.appendingPathComponent("eyes.png")
        guard FileManager.default.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url)
        else { return nil }
        guard image.size == size else {
            print("⚠️ \(directory.lastPathComponent): eyes.png is \(image.size) but frames are "
                  + "\(size) — ignoring the eye layer")
            return nil
        }
        return image
    }

    /// The frame rate to play one state at, or `nil` for "whatever the art says".
    ///
    /// A pack can declare a rate in three places. They are read most-specific first,
    /// because a per-state rate is a deliberate choice and a whole-pack rate is a
    /// default:
    ///
    ///   * `states.<state>.fps` — beside the strip that state is cut from
    ///   * `animation.<state>.fps` — the block `scripts/animate_pack.py` writes when
    ///     it renders numbered frames
    ///   * `fps` — one rate for the whole pack
    ///
    /// **The per-state rates were being dropped.** Only the top-level `fps` was ever
    /// read, and none of the three shipped packs sets it — every one of them declares
    /// its rates per state under `animation`, and every state was therefore playing at
    /// the 8 fps fallback. Measured against the manifests: `sleepy` is authored at
    /// 5 fps and ran 60% too fast, `delighted` and `startled` at 12 fps and ran 33%
    /// too slow, `alert` at 10 fps. The generator's own comment records the gap
    /// ("for numbered frames it uses its own default, so this is documentation of
    /// intent rather than something it consumes today") — this is that gap closed.
    ///
    /// Out-of-range values are clamped and non-finite ones ignored rather than
    /// rejected: `fps` is hand-edited data, and a pack with one silly number in it
    /// should still play. A non-finite rate has to be dropped rather than clamped —
    /// `min(max(nan, 1), 60)` is `nan`, which makes every delay `nan`, which makes
    /// `frameIndex` compare false forever and freezes the state on its last frame.
    nonisolated private static func declaredFPS(in json: [String: Any], state: String) -> Double? {
        func rate(_ container: String) -> Double? {
            guard let states = json[container] as? [String: Any],
                  let spec = states[state] as? [String: Any],
                  let value = (spec["fps"] as? NSNumber)?.doubleValue
            else { return nil }
            return value
        }
        guard let raw = rate("states") ?? rate("animation")
                ?? (json["fps"] as? NSNumber)?.doubleValue,
              raw.isFinite
        else { return nil }
        return min(max(raw, 1), 60)
    }

    /// Frames held for equal time, for a source that carries no timing of its own.
    nonisolated private static func evenlyTimed(_ frames: [NSImage], fps: Double) -> CompanionAnimation {
        let delay = 1.0 / min(max(fps, 1), 60)
        return CompanionAnimation(frames: frames,
                                  delays: Array(repeating: delay, count: frames.count))
    }


    /// Resolve a manifest-supplied filename inside the pack folder, refusing to
    /// leave it.
    ///
    /// A `pack.json` is user-editable data, so `"file": "../../../secrets.png"` has to
    /// be rejected rather than resolved — the app never trusts a path it did not
    /// construct itself.
    nonisolated private static func resolve(_ file: String, in directory: URL,
                                            state: String) throws -> URL {
        // `isDirectory: true` matters, and its absence was a real bug: without it,
        // `URL(fileURLWithPath:relativeTo:)` treats the base as a *file* and resolves
        // against its parent, so a perfectly ordinary `"file": "idle.png"` came out as
        // a SIBLING of the pack folder rather than a child. The containment check below
        // then correctly rejected it — meaning every legitimate strip pack was refused
        // with a security error. Caught by the strip tests, not by inspection.
        let base = URL(fileURLWithPath: directory.path, isDirectory: true)
        let candidate = URL(fileURLWithPath: file, relativeTo: base).standardizedFileURL

        // Compare against the resolved base: a temporary directory reached through a
        // symlink (`/tmp` → `/private/tmp`) standardizes differently from the path the
        // caller held, and a prefix test between the two forms fails for a file that is
        // genuinely inside the folder.
        let root = base.resolvingSymlinksInPath().standardizedFileURL.path
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolved == root || resolved.hasPrefix(root + "/") else {
            throw PackError("\(state): file must be inside the pack folder")
        }
        return candidate
    }

    /// Read a multi-frame image (APNG, or an animated GIF/WebP) with its own timing.
    ///
    /// Returns `nil` for an ordinary single-frame image, which is how the caller tells
    /// an animated file from a sprite strip.
    ///
    /// **APNG is the format to hand someone who wants "one animated file".** It is a
    /// PNG, so it keeps full 8-bit alpha and per-frame delays, and macOS's ImageIO
    /// decodes it natively — `CGImageSourceGetCount` reports the frames and each
    /// frame's properties carry `APNGDelayTime`.
    ///
    /// GIF cannot do this: its transparency is one bit, so every anti-aliased edge
    /// becomes a staircase and every soft shadow a block of hard pixels. Measured on a
    /// 56px character, 32 distinct alpha levels collapsed to 2 and all 212
    /// partially-transparent pixels went fully opaque or fully clear. Animated GIFs
    /// still load here — refusing a file the OS can read would be unhelpful — but they
    /// will look wrong, and that is the format, not the loader.
    nonisolated static func animatedAnimation(at url: URL, overrideFPS: Double?,
                                              maxFrameSide: CGFloat) -> CompanionAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        // A pathological file could claim thousands of frames; a companion animation
        // needs a handful. Cap it rather than decoding an arbitrary amount into RAM.
        let limit = min(count, maxFramesPerState)

        var frames: [NSImage] = []
        var delays: [Double] = []
        frames.reserveCapacity(limit)
        delays.reserveCapacity(limit)

        for index in 0..<limit {
            guard let frame = decodeFrame(source: source, index: index,
                                         maxFrameSide: maxFrameSide) else { continue }
            frames.append(frame)
            delays.append(frameDelay(source: source, index: index))
        }
        guard !frames.isEmpty else { return nil }

        if let fps = overrideFPS {
            return evenlyTimed(frames, fps: fps)
        }
        return CompanionAnimation(frames: frames, delays: delays)
    }

    /// Decode one frame, no larger than the character is ever drawn.
    ///
    /// **This is the whole memory budget of the feature.** A frame is held as a
    /// decoded bitmap for as long as the pack is loaded, and the cost is pixels, not
    /// file size. Uncapped, the four shipped packs are 192 frames of 243x357-to-283x360
    /// source art: 18.1 Mpx, **72.5 MB** at RGBA8, to draw one character an inch tall.
    ///
    /// Every pixel past `maxFrameSide` is thrown away by the renderer anyway
    /// (`SpritePackView` fits the frame into a `characterSize` box), so it is thrown
    /// away here instead, once, rather than being carried for the process lifetime.
    /// Because the cap is derived from the drawn size, the cost scales with the character
    /// the user chose. Measured over those same 192 frames, through this function, at
    /// RGBA8:
    ///
    ///   small (36pt, 92px)   4.75 MB     large (68pt, 174px)  16.97 MB
    ///   medium (52pt, 133px) 9.88 MB     huge (84pt, 215px)   25.92 MB
    ///
    /// So the default costs what it always did, and the largest character costs 2.6x
    /// that — paid only by someone who picked it, and still a third of the uncapped
    /// figure.
    ///
    /// `CGImageSourceCreateThumbnailAtIndex` rather than decoding and then scaling:
    /// it produces the reduced image *directly*, so the full-size bitmap is never
    /// allocated at all. `…FromImageAlways` because a PNG has no embedded thumbnail
    /// to prefer, and without it the call returns nil.
    nonisolated private static func decodeFrame(source: CGImageSource, index: Int,
                                               maxFrameSide: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxFrameSide,
            // Honour an EXIF orientation, so a rotated frame is not stored sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        // The thumbnail path only ever shrinks, so an already-small frame must go
        // through the plain decode — asking for a 113px "thumbnail" of a 64px frame
        // would upscale it and throw away nothing but sharpness.
        let cgImage: CGImage?
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
           let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
           let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
           max(width, height) > Double(maxFrameSide) {
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
                ?? CGImageSourceCreateImageAtIndex(source, index, nil)
        } else {
            cgImage = CGImageSourceCreateImageAtIndex(source, index, nil)
        }
        guard let cgImage else { return nil }
        // Size from the pixel dimensions, so the frame is not scaled by whatever
        // DPI the exporter happened to write into the file.
        return NSImage(cgImage: cgImage,
                       size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Decode the single image in a file, size-capped. `nil` if it is not an image.
    nonisolated private static func decodeImage(at url: URL,
                                               maxFrameSide: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return decodeFrame(source: source, index: 0, maxFrameSide: maxFrameSide)
    }

    /// Pixels of backing store per point to decode for.
    ///
    /// 2 is the ceiling on macOS — there is no 3x mode, and a display running a scaled
    /// resolution still renders at 2x of its logical size. **This is the one knob**:
    /// raise it, not the art, if a capped frame ever looks soft on screen.
    nonisolated static let maxBackingScale: CGFloat = 2

    /// The largest frame worth keeping, on its longest edge, in pixels.
    ///
    /// Derived from the size the art is drawn at, so it cannot drift out of step with the
    /// renderer:
    ///
    ///   `characterSize` x `maxPoseScale` (1.16, the peak stretch)
    ///   x `hoverScale` (1.10) x `maxBackingScale` (2)
    ///
    /// which is 92px at the smallest offered character (36pt), 133px at the default 52pt
    /// and 215px at the largest (84pt).
    ///
    /// Both axes are covered by one bound: `squash` scales y by `s` and x by `1/s`,
    /// and the extremes it reaches (1.16 stretching, 0.86 landing -> 1.163 wide) are
    /// the same magnitude, so whichever way the character deforms it never exceeds
    /// `characterSize * maxPoseScale` on either axis.
    ///
    /// **A function of the size, not a constant, because the size is a preference.** The
    /// alternative was to cap once against the largest size the settings offer, which
    /// would never need a re-decode — but it makes everyone pay the largest character's
    /// memory (see `decodeFrame` for the measured figures) including the majority who
    /// never change the setting. So the frames are decoded for the chosen size and
    /// `reload` re-decodes when it changes. That costs one pass over the packs: measured
    /// 180-225 ms on the main thread for the four shipped ones, once, in a settings pane
    /// — against 16 MB of permanently resident bitmaps for a character nobody chose.
    nonisolated static func maxFrameSide(for characterSize: CGFloat) -> CGFloat {
        (characterSize * CompanionGeometry.maxPoseScale
            * CompanionGeometry.hoverScale * maxBackingScale).rounded(.up)
    }

    /// A frame's display duration, in seconds.
    ///
    /// The key differs per format (`APNGDelayTime`, `GIFDelayTime`, `WebPDelayTime`)
    /// and lives in that format's own sub-dictionary, so all three are checked rather
    /// than assuming the file is one of them.
    nonisolated private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
            as? [CFString: Any] ?? [:]
        let containers: [CFString] = [
            kCGImagePropertyPNGDictionary,
            kCGImagePropertyGIFDictionary,
            kCGImagePropertyWebPDictionary,
        ]
        let delayKeys: [CFString] = [
            kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime,
            kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime,
            kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime,
        ]
        for container in containers {
            guard let dictionary = properties[container] as? [CFString: Any] else { continue }
            for key in delayKeys {
                if let value = dictionary[key] as? Double, value > 0 { return value }
            }
        }
        // The convention every browser uses for a missing or zero delay.
        return 0.1
    }

    /// Discover states from filenames, for packs with no manifest.
    ///
    /// Two conventions, both keyed on the state names Utter already uses:
    ///
    ///   * `resting.png` — one animated PNG per state (the "one file like a GIF" case)
    ///   * `resting/01.png, 02.png…` — a folder of numbered frames per state
    ///
    /// Numbered frames are sorted with `localizedStandardCompare`, so `2.png` sorts
    /// before `10.png` — a plain string sort puts `10` second, which silently plays
    /// the animation out of order.
    nonisolated private static func discoverByConvention(
        in directory: URL, manifest json: [String: Any], maxFrameSide: CGFloat
    ) throws -> [String: CompanionAnimation] {
        let fm = FileManager.default
        var animations: [String: CompanionAnimation] = [:]

        for state in Self.stateNames {
            // Resolved per state, not once for the pack: the shipped packs give every
            // state its own rate (5 fps asleep, 12 fps celebrating) and a single
            // pack-wide value cannot express that.
            let overrideFPS = Self.declaredFPS(in: json, state: state)

            // A folder of numbered frames wins over a single file, so a pack can ship
            // both without ambiguity about which was intended.
            let stateDirectory = directory.appendingPathComponent(state)
            if (try? stateDirectory.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory == true {
                let files = ((try? fm.contentsOfDirectory(at: stateDirectory,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles])) ?? [])
                    .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
                    // `localizedStandardCompare` so `2.png` sorts before `10.png`; a
                    // plain string sort puts `10` second and plays the animation out
                    // of order.
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                        == .orderedAscending }
                    .prefix(Self.maxFramesPerState)
                let frames = files.compactMap {
                    Self.decodeImage(at: $0, maxFrameSide: maxFrameSide)
                }
                if !frames.isEmpty {
                    // Numbered stills carry no timing, so they get an even cadence.
                    animations[state] = Self.evenlyTimed(frames, fps: overrideFPS ?? 8)
                }
                continue
            }

            // A single file per state: animated if it has frames, still if it doesn't.
            for ext in Self.imageExtensions {
                let file = directory.appendingPathComponent("\(state).\(ext)")
                guard fm.fileExists(atPath: file.path) else { continue }
                if let animated = Self.animatedAnimation(at: file, overrideFPS: overrideFPS,
                                                         maxFrameSide: maxFrameSide) {
                    animations[state] = animated
                } else if let still = Self.decodeImage(at: file, maxFrameSide: maxFrameSide) {
                    animations[state] = .still(still)
                }
                break
            }
        }
        return animations
    }

    /// The state names the companion understands, and the order they are looked for.
    /// Every state name the loader looks for on disk.
    ///
    /// This list is the loader's whole vocabulary — `discoverByConvention` iterates it, and it is
    /// the *only* thing that populates `animations`, even for a pack that ships a `pack.json`
    /// (see the call at the manifest path). So a state missing from this list can never load, no
    /// matter what art the pack contains.
    ///
    /// It held only the original six, and the pet states plus the walk gait were added to
    /// `key(for:)` and `walkAnimation` without being added here. The result was silent because
    /// `animation(for:)` falls back to `resting` by design: the shipped pixel packs each carried
    /// seven PNGs — `knead`, `walk`, `purr`, `hunt`, `drag`, `overheat`, `stretch` — that were
    /// never read, and the cat played its idle loop while "typing" or "walking". The typing
    /// animation could not appear even with the keystroke signal working and Accessibility
    /// granted, because there was no knead art loaded to play.
    ///
    /// Must stay in step with `key(for:)` and `walkAnimation`. `stretch` is deliberately absent:
    /// nothing looks it up, so loading it would cost memory for frames no code can reach.
    /// A pack that does not draw a state simply has no file to find, which is the documented
    /// fallback the four photo packs rely on.
    nonisolated static let stateNames = [
        "resting", "alert", "thinking", "delighted", "startled", "sleepy",
        "knead", "overheat", "purr", "hunt", "drag",
        "walk", "grooming", "rolling", "loaf",
    ]

    /// Extensions tried for a convention-named file, best format first.
    ///
    /// PNG leads because it is the only one of these that keeps 8-bit alpha *and*
    /// decodes everywhere; `gif` is last because it cannot.
    nonisolated static let imageExtensions = ["png", "webp", "heic", "tiff", "gif"]

    /// Upper bound on frames decoded for one state. A companion animation is a
    /// handful of frames; this stops a malformed or malicious file from asking the app
    /// to hold thousands in memory.
    nonisolated static let maxFramesPerState = 64

    /// Cut a horizontal strip into `count` frames.
    ///
    /// Draws each frame into its own image rather than handing out crop rects, so
    /// the renderer can treat every frame as an ordinary image and the sheet can
    /// be released.
    ///
    /// **Units.** `frameWidth`/`frameHeight` in the manifest describe the PNG's
    /// *pixels* — that is what a pack author reads off the file in an image editor.
    /// `NSImage.size` and the `from:` rect of `draw` are in *points*, which are the
    /// same thing only for a @1x image: a `@2x`-tagged sheet reports half its pixel
    /// dimensions. Counting frames in pixels while cropping in points therefore
    /// slices the wrong regions and can yield twice as many frames as exist —
    /// measured on a 512×128 pixel sheet declaring 64pt frames, which produced 8
    /// frames from a 4-frame strip, the back half duplicated.
    ///
    /// So the pixel dimensions decide how many frames there are, and the crop
    /// rectangle is converted into the image's own point space.
    nonisolated private static func slice(sheet: NSImage, frameSize: CGSize, count: Int,
                                         maxFrameSide: CGFloat) -> [NSImage] {
        guard let rep = sheet.representations.first else { return [] }
        let pixelWidth = CGFloat(rep.pixelsWide)
        let pixelHeight = CGFloat(rep.pixelsHigh)
        guard pixelWidth >= frameSize.width, pixelHeight >= frameSize.height else { return [] }
        guard sheet.size.width > 0, sheet.size.height > 0 else { return [] }

        // Pixels per point on each axis. 1 for an ordinary PNG, 2 for a @2x sheet.
        let scaleX = pixelWidth / sheet.size.width
        let scaleY = pixelHeight / sheet.size.height

        // Never read past the end of the sheet, however many frames the manifest
        // claims.
        let available = Int(pixelWidth / frameSize.width)
        let frameCount = min(count, max(available, 0))
        guard frameCount > 0 else { return [] }

        // The frame's size in the sheet's point space, which is what `from:` wants.
        let sourceSize = CGSize(width: frameSize.width / scaleX,
                                height: frameSize.height / scaleY)

        // The destination keeps the manifest's pixel dimensions, so no resolution is
        // thrown away when a @2x sheet is sliced — up to the point where the renderer
        // would throw it away anyway. A strip declaring 512px frames costs 1 MB per
        // frame decoded and is drawn into a box a fraction of that, so it is cut down to
        // `maxFrameSide` here for the same reason `decodeFrame` does it: this is the
        // only copy that gets kept. Aspect ratio is preserved, so a non-square frame
        // is not distorted by the cap.
        let destinationSize = cappedToDrawnSize(frameSize, maxFrameSide: maxFrameSide)

        var frames: [NSImage] = []
        frames.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            let source = CGRect(
                x: CGFloat(index) * sourceSize.width,
                y: 0,
                width: sourceSize.width,
                height: sourceSize.height
            )
            let frame = NSImage(size: destinationSize)
            frame.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            sheet.draw(
                in: CGRect(origin: .zero, size: destinationSize),
                from: source,
                operation: .copy,
                fraction: 1
            )
            frame.unlockFocus()
            frames.append(frame)
        }
        return frames
    }

    /// `size` shrunk so its longest edge is at most `maxFrameSide`, aspect preserved.
    /// Returned unchanged when it already fits, so small art is never resampled.
    nonisolated private static func cappedToDrawnSize(_ size: CGSize,
                                                      maxFrameSide: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxFrameSide, longest > 0 else { return size }
        let scale = maxFrameSide / longest
        return CGSize(width: max(1, (size.width * scale).rounded()),
                      height: max(1, (size.height * scale).rounded()))
    }

    struct PackError: Error, Equatable {
        let message: String
        init(_ message: String) { self.message = message }
    }
}

// MARK: - Rendering

/// Draws the current frame of a sprite pack.
///
/// Sprite art carries its own expression, so this applies only the parts of a pose
/// the *engine* owns — position, facing, squash and lean, which are how the behaviour
/// engine moves the character around. Eye shape, mouth and accessories are ignored on
/// purpose: those belong to whoever drew the frames.
///
/// **Deliberately NOT `Equatable`, and this was measured rather than assumed.** Memoising
/// this view with `.equatable()` — the obvious next step after `SpriteBodyLayer` below — would
/// short-circuit exactly nothing, because `pose` and `elapsed` both change on every single
/// tick. Counted over 24 000 release-build ticks in each of four scenarios (resting with a
/// static cursor, cursor moving plus typing, recording against a live input level, and Reduce
/// Motion with the pet signals off), the number of ticks on which `(mood, pose, elapsed)`
/// equalled the previous tick's was **0 out of 24 000, in all four**. `pose.squash` is a
/// continuous sine even at rest (the resting breath) and `pose.eyeAim` is a spring that is
/// still settling; `elapsed` is a monotonic clock. There is no plateau to memoise.
///
/// The tempting version — an `==` that ignores `elapsed` — is a *correctness* bug, not an
/// optimisation. Under Reduce Motion with pet signals off, `(mood, pose)` alone matched the
/// previous tick on 23 990 of 24 000 ticks, so such an `==` would report "unchanged" and
/// freeze the sprite animation on one drawing: `elapsed` is the only thing that advances the
/// APNG frame. A memoised view with a wrong `==` drops frames, which is a worse defect than a
/// cheap view that redraws.
///
/// `@Environment(\.displayScale)` is the second reason: a hand-written `==` cannot see it, so
/// any conformance would silently ignore the one input that changes `renderedSize` when the
/// character is dragged between a Retina and a non-Retina display.
///
/// The memoisation that *does* pay is one level down, on `SpriteBodyLayer`, whose inputs
/// genuinely plateau at the pack's 5-12 fps.
struct SpritePackView: View {
    let pack: SpritePack
    let mood: CompanionMood
    let pose: CompanionPose
    let size: CGFloat
    /// Seconds the current mood has been showing, from the behaviour engine's clock.
    ///
    /// A *time*, not a frame index, because APNG frames have individual durations —
    /// an index would need a fixed frame rate to advance against, which is exactly
    /// the timing information the format exists to preserve. One clock for everything
    /// still holds: this is the engine's clock, not a timer of the view's own.
    let elapsed: Double

    /// Points-to-pixels for the screen this is drawn on: 2 on every Retina display, 1 on
    /// a non-Retina one. Read from the environment rather than from `NSScreen.main`,
    /// because the companion can be dragged to a second display with a different scale
    /// and the environment value follows the view while `NSScreen.main` follows the
    /// keyboard focus.
    @Environment(\.displayScale) private var displayScale

    /// The box the frame is actually drawn into.
    ///
    /// For everything except pixel art this is just `size`. Pixel art has to land on a
    /// whole-number scale factor, and the requested sizes do not divide evenly:
    /// the size ladder is 36/52/68/84pt, which on a 2x display is 72/104/136/168 device
    /// pixels, and the greatest common divisor of those four is 8. So no sprite canvas
    /// above 8px can scale integrally at all four sizes — a 32px cat at 52pt would run at
    /// 3.25x, and nearest-neighbour at 3.25x draws some source pixels 3 device pixels
    /// wide and others 4. The cat comes out visibly lumpy: uneven whisker widths, an ear
    /// one pixel taller on one side.
    ///
    /// So the box is snapped DOWN to the largest whole multiple that still fits. Down
    /// rather than nearest, because rounding up can exceed the size the panel sized its
    /// padding from, and a companion clipped by its own window is a worse bug than one
    /// drawn slightly small. Measured cost at 32px: the four sizes render 32/48/64/80pt,
    /// which is 5-11% under nominal. At the 64px the pixel cats are drawn at, the same rule
    /// gives 32/32/64/64pt — coarser, and the price of a canvas with room for articulated
    /// legs.
    ///
    /// The arithmetic is a `static` on `SpritePack` so it can be tested: it is the one part
    /// of this view that is pure, and it is also the part that had a live bug (see
    /// `SpritePack.snappedSide`).
    private var renderedSize: CGFloat {
        guard pack.pixelArt else { return size }
        // Code-rendered companions snap every rectangle to the display's device-pixel
        // grid themselves. Applying sprite-sheet integer scaling here would shrink the
        // 64-cell procedural canvas to 32pt at the default 52pt setting.
        if CodePixelCatStyle(rawValue: pack.id) != nil { return size }
        return SpritePack.snappedSide(
            box: size,
            canvas: max(pack.frameSize.width, pack.frameSize.height),
            displayScale: displayScale
        )
    }

    /// How far the eye layer moves for a full deflection, in points.
    ///
    /// `eyeTravel` is in source pixels, so it scales with however large the sprite is
    /// actually being drawn — two pixels of travel on a 32px cat is 2pt at 32pt and 5pt at
    /// 80pt, which keeps the eyes in their sockets at every size.
    private var eyeTravelPoints: CGFloat {
        pack.eyeTravel * sourcePixelInPoints
    }

    /// This mood's eye anchor, converted from source pixels to points.
    private var eyeAnchorPoints: CGVector {
        let anchor = pack.eyeAnchor(for: mood)
        let scale = sourcePixelInPoints
        return CGVector(dx: anchor.dx * scale, dy: anchor.dy * scale)
    }

    /// How many points one source pixel occupies at the size being drawn.
    private var sourcePixelInPoints: CGFloat {
        let side = max(pack.frameSize.width, pack.frameSize.height)
        guard side >= 1 else { return 0 }
        return renderedSize / side
    }

    /// How much of the flustered red is mixed in, 0...1.
    ///
    /// Capped at 0.9 rather than 1 so a trace of the coat survives at full heat — the
    /// character should look like *itself*, overheating, not like a red silhouette.
    private var heatMix: Double {
        Double(min(1, max(0, pose.heat))) * 0.9
    }

    /// The flustered red, painted over the character.
    ///
    /// **This replaces the colour rather than multiplying it, and that is the whole fix.**
    /// The first version used `.colorMultiply`, which cannot work on a dark character: the
    /// midnight coat's fill is #170000, and multiplying a near-black by any colour leaves it
    /// near-black. The only pixels that visibly changed were the ones that were already
    /// light — the edge ring and the eye whites — so the cat appeared to get a red *outline*
    /// while its body stayed black, which is exactly the wrong reading.
    ///
    /// `.sourceAtop` composites this colour only where the sprite is already opaque, so the
    /// shape is untouched and the fill is genuinely re-coloured. It works the same on a
    /// black coat and a cream one, which multiply never could.
    ///
    /// `fileprivate` rather than `private` so the memoised `SpriteBodyLayer` below — a
    /// separate type in this file — can paint with the same red.
    fileprivate static let heatRed = Color(red: 0.86, green: 0.20, blue: 0.18)

    var body: some View {
        // While walking, prefer the pack's walk cycle — but only if it has one; a pack
        // without `walk` frames falls back to the mood's animation, so nothing is obliged to
        // draw a walk. Everything else shows the mood's own frames, gaze and heat unchanged.
        let animation = pose.gait == .walking
            ? (pack.walkAnimation ?? pack.animation(for: mood))
            : pack.animation(for: mood)
        Group {
            if let style = CodePixelCatStyle(rawValue: pack.id) {
                CodePixelCatView(
                    style: style,
                    mood: mood,
                    pose: pose,
                    size: renderedSize,
                    elapsed: elapsed
                )
            } else if let animation, !animation.frames.isEmpty {
                // The body-and-heat layer is memoised (`.equatable()`): its pixels change
                // only when the drawn frame or the heat does, so on the ~3 of every 4 ticks
                // that land on the *same* APNG frame, SwiftUI skips rebuilding the image, its
                // interpolation and the heat composite and reuses the last render. The engine
                // still ticks at 30 Hz and this view is still re-evaluated 30 Hz — the squash
                // breath and the gaze are live every frame — but that per-tick work is now the
                // cheap layer transforms and the gaze offset, not a fresh sprite composite.
                //
                // The eyes stay OUTSIDE the memoised layer, deliberately and unchanged: they
                // track the cursor every frame, and they must sit on top of the heat tint and
                // stay dark (a flustered cat with red pupils reads as a different, more
                // alarming animal). Overlaying them here keeps that order — body+heat first,
                // pupils on top — exactly as before.
                SpriteBodyLayer(
                    image: animation.frames[animation.frameIndex(at: elapsed)],
                    pixelArt: pack.pixelArt,
                    heatMix: heatMix
                )
                .equatable()
                .overlay {
                    // No tracking eyes while walking, because the walk is drawn in profile.
                    //
                    // `eyes.png` is one shared overlay anchored to the front-on head: two eyes
                    // at rows 8-12 of the canvas. The pixel cats' walk cycle is a side view — a
                    // profile cat has *one* visible eye, further forward — so no anchor offset
                    // can place this correctly. The problem is the eye count, not the position,
                    // and `eyeAnchors` can only move the layer.
                    //
                    // So the walk frames bake their own eye and this layer stands down. The
                    // cost is cursor tracking for the length of a walk, which is the right
                    // thing to trade: an animal in motion looks where it is going. Every other
                    // state keeps the overlay untouched — including `knead`, where the pointer
                    // matters most and the anchor exists for exactly that reason.
                    //
                    // Keyed on the same condition that chose the animation above, so a pack
                    // *without* a walk cycle — which falls back to the mood's front-on frames —
                    // keeps its eyes. Only a pack that actually supplies `walk` gives them up.
                    let walking = pose.gait == .walking && pack.walkAnimation != nil
                    if let eyes = pack.eyeOverlay, !walking {
                        Image(nsImage: eyes)
                            .resizable()
                            .interpolation(pack.pixelArt ? .none : .high)
                            .aspectRatio(contentMode: .fit)
                            // Two offsets, and they mean different things. The anchor moves
                            // the eyes to wherever THIS pose put the head — a fixed, per-state
                            // correction. The aim is the live cursor tracking on top of it.
                            // Adding them lets a leaning pose keep tracking, which is the whole
                            // point of the anchor.
                            .offset(x: eyeAnchorPoints.dx + pose.eyeAim.dx * eyeTravelPoints,
                                    // Screen y grows up, SwiftUI's grows down — so the aim is
                                    // negated and the anchor, authored in image space, is not.
                                    y: eyeAnchorPoints.dy - pose.eyeAim.dy * eyeTravelPoints)
                    }
                }
            } else {
                // An installed-but-empty pack must not render as nothing at all,
                // or the user sees an invisible companion and no explanation.
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(Ink.secondary)
            }
        }
        // Sized to `renderedSize` but still *occupying* `size`, so snapping a pixel pack
        // down cannot shift the character off the spot the panel parked it on: the outer
        // frame keeps the layout, the inner one keeps the pixel grid.
        .frame(width: renderedSize, height: renderedSize)
        .frame(width: size, height: size)
        // Squash, lean and facing are layer transforms, so at rest (squash 1, lean 0,
        // facing 1) they are the identity and pixel art stays exactly on its grid. Only
        // while a transform is actually running — a hop, a stretch — does the layer get
        // resampled and soften for those few hundred milliseconds. Quantising the
        // transforms to whole pixels was considered and rejected: it makes a 0.5s hop
        // move in visible steps, which reads as dropped frames rather than as weight.
        .scaleEffect(x: 1 / pose.squash, y: pose.squash, anchor: .bottom)
        .rotationEffect(.degrees(pose.lean), anchor: .bottom)
        .scaleEffect(x: pose.facing, y: 1)
        .accessibilityHidden(true)
    }
}

/// The body sprite and its heat tint, isolated so it re-renders only when the pixels
/// actually change.
///
/// This is the memoisation the companion's continuous redraw needs. The behaviour engine
/// publishes a new pose on every one of its 30 ticks a second — the breath and the gaze
/// are genuinely continuous — so the parent `SpritePackView` is re-evaluated 30 Hz for as
/// long as the companion is on screen. But the *sprite frame* only changes at the pack's
/// own rate (5-12 fps), so on most ticks the image, its `.high` interpolation and the heat
/// composite would be rebuilt to produce a byte-for-byte identical result. `Equatable` lets
/// SwiftUI skip this subtree's `body` on every tick that lands on the same frame with the
/// same heat; the parent still layers the live squash, lean, facing and gaze on top, which
/// are cheap layer transforms rather than a re-composite.
///
/// Compared by frame *identity* (`===`): frames are stable objects held by the pack, so a
/// new frame index yields a different object and a mood change yields a different frames
/// array — both correctly force a redraw. `heatMix` changes tick-to-tick only while the
/// character is overheating, which is exactly when the tint should animate.
private struct SpriteBodyLayer: View, Equatable {
    let image: NSImage
    let pixelArt: Bool
    let heatMix: Double

    static func == (lhs: SpriteBodyLayer, rhs: SpriteBodyLayer) -> Bool {
        lhs.image === rhs.image && lhs.pixelArt == rhs.pixelArt && lhs.heatMix == rhs.heatMix
    }

    @ViewBuilder
    var body: some View {
        let base = Image(nsImage: image)
            .resizable()
            // `.none` is nearest-neighbour. On pixel art this is the whole point; on the
            // photo-derived packs it would alias badly when scaled down.
            .interpolation(pixelArt ? .none : .high)
            .aspectRatio(contentMode: .fit)

        // The heat tint, and the `compositingGroup` that scopes it, exist ONLY while the
        // character is flustered. Applied unconditionally they cost an offscreen composite
        // pass on every composited frame, for a tint that is fully transparent the vast
        // majority of the time. Gating both on `heatMix > 0` removes that pass in the
        // overwhelmingly common not-overheating case and reproduces the old rendering
        // exactly when it is warm — the group is only ever needed to isolate the blend.
        if heatMix > 0 {
            base
                .overlay {
                    SpritePackView.heatRed
                        .opacity(heatMix)
                        // Paints only where the sprite is already opaque, so the silhouette
                        // is untouched and the *fill* changes colour.
                        .blendMode(.sourceAtop)
                }
                // Scopes the blend to this image. Without it `.sourceAtop` composites against
                // whatever is behind the whole view — the desktop — and paints a red square
                // over the wallpaper.
                .compositingGroup()
        } else {
            base
        }
    }
}
