import Testing
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import UtterKit

/// Loading companion packs from disk.
///
/// These write real files and read them back through the real loader. A pack is
/// user-authored data arriving from the filesystem, so the cases that matter are the
/// malformed and hostile ones — a mocked loader would prove nothing about either.
///
/// Every test gets its own temporary directory, so they can run in any order and none
/// can see another's files.
@Suite("Sprite pack loading")
struct SpritePackLoadingTests {

    /// The frame cap these tests are asserting against.
    ///
    /// Named once rather than re-derived, and read from the same place `loadPack`'s
    /// default argument does: the cap is a function of the character's size now, and a
    /// test that read the *current* preference would pass or fail depending on how big
    /// the developer happens to like their companion.
    private static let cap = SpritePackStore.maxFrameSide(
        for: UserData.defaultCompanionSize.points
    )

    // MARK: Fixtures

    /// A frame with a genuinely anti-aliased edge, so alpha loss is measurable, and a
    /// marker whose position identifies the frame, so slicing order is verifiable.
    private static func frame(_ index: Int, side: Int = 64) -> CGImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = context
        // A fresh bitmap's buffer is not guaranteed zeroed, so clear it explicitly —
        // leftover bytes would render as an opaque background and hide the alpha.
        context.cgContext.clear(CGRect(x: 0, y: 0, width: side, height: side))
        context.shouldAntialias = true
        NSColor.systemPurple.setFill()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 3,
                                    width: Double(side - 6), height: Double(side - 6))).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 5 + Double(index) * Double(side - 16) / 4,
                                    y: Double(side) / 2 - 3, width: 6, height: 6)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }

    /// Write a real APNG with the given per-frame delays.
    private static func writeAPNG(to url: URL, frames: Int, delays: [Double], side: Int = 64) {
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, frames, nil
        )!
        CGImageDestinationSetProperties(
            destination,
            [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary
        )
        for index in 0..<frames {
            CGImageDestinationAddImage(
                destination, frame(index, side: side),
                [kCGImagePropertyPNGDictionary:
                    [kCGImagePropertyAPNGDelayTime: delays[index % delays.count]]] as CFDictionary
            )
        }
        #expect(CGImageDestinationFinalize(destination))
    }

    private static func writePNG(to url: URL, frameIndex: Int = 0, side: Int = 64) {
        let data = NSBitmapImageRep(cgImage: frame(frameIndex, side: side))
            .representation(using: .png, properties: [:])!
        try! data.write(to: url)
    }

    /// A horizontal strip of `count` frames, each `side` pixels wide.
    private static func writeStrip(to url: URL, count: Int, side: Int = 64) {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side * count, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = NSSize(width: side * count, height: side)
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: side * count, height: side))
        for index in 0..<count {
            context.cgContext.draw(
                frame(index, side: side),
                in: CGRect(x: index * side, y: 0, width: side, height: side)
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: url)
    }

    /// A fresh pack directory inside its own temporary root.
    private func makePack(_ name: String) -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UtterPackTests-\(UUID().uuidString)")
        let directory = root.appendingPathComponent(name)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: APNG — the recommended layout

    @Test("An APNG per state loads with no manifest, keeping its own timing")
    func apngByConvention() throws {
        let pack = makePack("panda")
        Self.writeAPNG(to: pack.appendingPathComponent("resting.png"),
                       frames: 4, delays: [0.5, 0.08, 0.08, 0.08])
        Self.writeAPNG(to: pack.appendingPathComponent("alert.png"), frames: 2, delays: [0.1])

        let loaded = try SpritePackStore.loadPack(from: pack)

        let resting = try #require(loaded.animations["resting"])
        #expect(resting.frames.count == 4)
        // The hold-then-snap shape survived, which is the entire point of APNG.
        #expect(abs(resting.delays[0] - 0.5) < 0.01)
        #expect(abs(resting.delays[1] - 0.08) < 0.01)
        #expect(resting.delays[0] > resting.delays[1] * 3)

        #expect(loaded.animations["alert"]?.frames.count == 2)
    }

    @Test("An APNG keeps 8-bit alpha, unlike a GIF")
    func apngPreservesAlpha() throws {
        let pack = makePack("soft")
        Self.writeAPNG(to: pack.appendingPathComponent("resting.png"), frames: 2, delays: [0.1])

        let loaded = try SpritePackStore.loadPack(from: pack)
        let first = try #require(loaded.animations["resting"]?.frames.first)
        let rep = NSBitmapImageRep(data: first.tiffRepresentation!)!

        var levels = Set<Int>()
        var partial = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y) else { continue }
                let alpha = Int((colour.alphaComponent * 255).rounded())
                levels.insert(alpha)
                if alpha > 0 && alpha < 255 { partial += 1 }
            }
        }
        // A GIF round-trip of the same art measures 2 levels and 0 partial pixels.
        #expect(levels.count > 16)
        #expect(partial > 50)
    }

    @Test("A missing state falls back to resting")
    func fallsBackToResting() throws {
        let pack = makePack("minimal")
        Self.writeAPNG(to: pack.appendingPathComponent("resting.png"), frames: 3, delays: [0.1])

        let loaded = try SpritePackStore.loadPack(from: pack)
        #expect(loaded.animation(for: .sleepy)?.frames.count == 3)
        #expect(loaded.animation(for: .startled)?.frames.count == 3)
    }

    @Test("A single still PNG is a valid one-frame state")
    func stillPNG() throws {
        let pack = makePack("still")
        Self.writePNG(to: pack.appendingPathComponent("resting.png"))

        let loaded = try SpritePackStore.loadPack(from: pack)
        let resting = try #require(loaded.animations["resting"])
        #expect(resting.frames.count == 1)
        #expect(resting.frameIndex(at: 99) == 0)
    }

    // MARK: Numbered frames

    @Test("Numbered frames sort naturally, so 2 precedes 10")
    func naturalSort() throws {
        let pack = makePack("numbered")
        let stateDirectory = pack.appendingPathComponent("resting")
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        // Written in an order that a plain string sort would get wrong.
        for (index, name) in ["10.png", "1.png", "2.png"].enumerated() {
            Self.writePNG(to: stateDirectory.appendingPathComponent(name), frameIndex: index)
        }

        let loaded = try SpritePackStore.loadPack(from: pack)
        let frames = try #require(loaded.animations["resting"]?.frames)
        #expect(frames.count == 3)

        // Prove the ORDER, not just the count.
        //
        // Compared by the marker's measured position rather than by re-encoded bytes:
        // a PNG round-trip is not byte-stable (the same pixels came back 12 bytes
        // different), so comparing encoded data tests the encoder, not the sort.
        //
        // "1.png" was written with marker 1, "2.png" with 2, "10.png" with 0 — so a
        // natural sort must yield markers 1, 2, 0 in that order. A plain string sort
        // would put "10.png" second and give 1, 0, 2.
        let markers = frames.map { Self.markerColumn(of: $0) }
        let expected = [1, 2, 0].map { Self.markerColumn(of: NSImage(cgImage: Self.frame($0),
                                                                    size: .zero)) }
        #expect(markers == expected)
    }

    /// The x-centre of the dark marker in a fixture frame, in pixels.
    ///
    /// Each fixture puts its marker at a position derived from the frame index, so this
    /// identifies *which* frame an image is without depending on encoded bytes.
    private static func markerColumn(of image: NSImage) -> Int {
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        var total = 0
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                // The marker is the only near-black, fully opaque region.
                if colour.alphaComponent > 0.9, colour.brightnessComponent < 0.2 {
                    total += x
                    count += 1
                }
            }
        }
        return count > 0 ? total / count : -1
    }

    // MARK: Strips

    @Test("A strip is sliced into distinct frames")
    func stripSlicing() throws {
        let pack = makePack("strip")
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: 4)
        try Self.writeManifest(pack, """
        {"name":"Strip","frameWidth":64,"frameHeight":64,"fps":10,
         "states":{"resting":{"file":"idle.png","frames":4}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let frames = try #require(loaded.animations["resting"]?.frames)
        #expect(frames.count == 4)
        #expect(frames[0].tiffRepresentation != frames[1].tiffRepresentation)
        // A strip carries no timing, so the manifest's fps sets an even cadence.
        #expect(abs((loaded.animations["resting"]?.delays[0] ?? 0) - 0.1) < 0.001)
    }

    @Test("A strip claiming more frames than it holds is clamped")
    func stripOverclaim() throws {
        let pack = makePack("overclaim")
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: 4)
        try Self.writeManifest(pack, """
        {"name":"Overclaim","frameWidth":64,"frameHeight":64,
         "states":{"resting":{"file":"idle.png","frames":99}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        #expect(loaded.animations["resting"]?.frames.count == 4)
    }

    @Test("A strip holding more frames than the ceiling is clamped, not rejected")
    func stripClampedToFrameCeiling() throws {
        // The strip path used to bypass the per-state cap the convention paths apply, so
        // a manifest could ask for — and get — an unbounded number of frames. Here the
        // file genuinely holds more than the ceiling and the manifest declares them all:
        // the loader must keep exactly `maxFramesPerState`, and must still load the pack
        // (small frames, so the size cap on the sheet decode does not shrink it away).
        let pack = makePack("many")
        let over = SpritePackStore.maxFramesPerState + 6
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: over, side: 8)
        try Self.writeManifest(pack, """
        {"name":"Many","frameWidth":8,"frameHeight":8,
         "states":{"resting":{"file":"idle.png","frames":\(over)}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        #expect(loaded.animations["resting"]?.frames.count == SpritePackStore.maxFramesPerState)
    }

    @Test("A manifest fps overrides an animated file's own timing")
    func fpsOverride() throws {
        let pack = makePack("retimed")
        Self.writeAPNG(to: pack.appendingPathComponent("idle.png"), frames: 4, delays: [0.5])
        try Self.writeManifest(pack, """
        {"name":"Retimed","frameWidth":64,"frameHeight":64,"fps":20,
         "states":{"resting":{"file":"idle.png","frames":4}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let delays = try #require(loaded.animations["resting"]?.delays)
        #expect(abs(delays[0] - 0.05) < 0.005)
    }

    // MARK: Per-state frame rates

    @Test("A per-state fps under \u{201C}animation\u{201D} is honoured")
    func perStateFPSFromAnimationBlock() throws {
        // The regression this pins. All three shipped packs declare their rates here —
        // `scripts/animate_pack.py` writes the block — and set no top-level `fps`. Only
        // the top-level key was read, so every state of every pack played at the 8 fps
        // fallback: `sleepy` 60% too fast, `delighted` and `startled` 33% too slow.
        let pack = makePack("rated")
        for state in ["resting", "sleepy"] {
            let directory = pack.appendingPathComponent(state)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for index in 0..<2 {
                Self.writePNG(to: directory.appendingPathComponent("0\(index + 1).png"),
                              frameIndex: index)
            }
        }
        try Self.writeManifest(pack, """
        {"name":"Rated","animation":{"resting":{"frames":2,"fps":12},
                                     "sleepy":{"frames":2,"fps":5}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let resting = try #require(loaded.animations["resting"])
        let sleepy = try #require(loaded.animations["sleepy"])
        #expect(abs(resting.delays[0] - 1.0 / 12.0) < 0.0001)
        #expect(abs(sleepy.delays[0] - 1.0 / 5.0) < 0.0001)
        // Each state keeps its own cadence rather than collapsing to one rate.
        #expect(sleepy.delays[0] > resting.delays[0] * 2)
    }

    @Test("A per-state fps beats a pack-wide one")
    func perStateFPSWinsOverPackWide() throws {
        let pack = makePack("mixed")
        let directory = pack.appendingPathComponent("resting")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<2 {
            Self.writePNG(to: directory.appendingPathComponent("0\(index + 1).png"), frameIndex: index)
        }
        try Self.writeManifest(pack, """
        {"name":"Mixed","fps":30,"animation":{"resting":{"frames":2,"fps":6}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        // A per-state rate is a deliberate choice; a pack-wide one is a default.
        #expect(abs((loaded.animations["resting"]?.delays[0] ?? 0) - 1.0 / 6.0) < 0.0001)
    }

    @Test("A per-state fps in a strip manifest is honoured")
    func perStateFPSInStripManifest() throws {
        let pack = makePack("strip-rated")
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: 2)
        try Self.writeManifest(pack, """
        {"name":"StripRated","frameWidth":64,"frameHeight":64,"fps":8,
         "states":{"resting":{"file":"idle.png","frames":2,"fps":20}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        #expect(abs((loaded.animations["resting"]?.delays[0] ?? 0) - 0.05) < 0.0001)
    }

    @Test("A nonsense fps cannot freeze a state")
    func nonsenseFPSIsIgnored() throws {
        // `min(max(nan, 1), 60)` is `nan`, which makes every delay `nan`, which makes
        // `frameIndex`'s comparisons all false — the state would stick on its last frame
        // forever. Out-of-range values clamp; non-finite ones are dropped.
        let pack = makePack("silly-fps")
        let directory = pack.appendingPathComponent("resting")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<3 {
            Self.writePNG(to: directory.appendingPathComponent("0\(index + 1).png"), frameIndex: index)
        }
        try Self.writeManifest(pack, """
        {"name":"Silly","animation":{"resting":{"frames":3,"fps":-4}}}
        """)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let resting = try #require(loaded.animations["resting"])
        #expect(resting.delays.allSatisfy { $0.isFinite && $0 > 0 })
        // A negative rate clamps to the 1 fps floor rather than inverting time.
        #expect(abs(resting.delays[0] - 1.0) < 0.0001)
        // And playback still advances through every frame.
        #expect(resting.frameIndex(at: 2.5) == 2)
    }

    // MARK: Frame size

    @Test("Frames larger than the character is drawn are scaled down on load")
    func oversizedFramesAreCapped() throws {
        // A decoded frame is held for as long as the pack is loaded, and the cost is
        // pixels. Measured on the three shipped packs before this cap: 144 frames
        // rasterised to 77.5 MB, 51.4 MB of it the one pack authored at 516px — all of
        // it to draw a 44pt character. Every pixel past `maxFrameSide` is discarded by
        // the renderer anyway, so it is discarded once here instead.
        let pack = makePack("huge")
        let cap = Int(Self.cap)
        let directory = pack.appendingPathComponent("resting")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<2 {
            Self.writePNG(to: directory.appendingPathComponent("0\(index + 1).png"),
                          frameIndex: index, side: 512)
        }

        let loaded = try SpritePackStore.loadPack(from: pack)
        let frames = try #require(loaded.animations["resting"]?.frames)
        #expect(frames.count == 2)
        for frame in frames {
            let image = try #require(frame.cgImage(forProposedRect: nil, context: nil, hints: nil))
            #expect(max(image.width, image.height) <= cap,
                    "frame kept at \(image.width)x\(image.height), cap \(cap)")
            // Not shrunk to nothing either — it is capped, not thumbnailed away.
            #expect(max(image.width, image.height) >= cap - 1)
        }
    }

    @Test("An APNG's frames are capped too, and keep their timing")
    func oversizedAnimatedFramesAreCapped() throws {
        let pack = makePack("huge-apng")
        Self.writeAPNG(to: pack.appendingPathComponent("resting.png"),
                       frames: 3, delays: [0.4, 0.1, 0.1], side: 512)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let resting = try #require(loaded.animations["resting"])
        #expect(resting.frames.count == 3)
        for frame in resting.frames {
            let image = try #require(frame.cgImage(forProposedRect: nil, context: nil, hints: nil))
            #expect(max(image.width, image.height) <= Int(Self.cap))
        }
        // Capping is a size change, not a retime — the hold-then-snap shape survives.
        #expect(abs(resting.delays[0] - 0.4) < 0.01)
        #expect(resting.delays[0] > resting.delays[1] * 3)
    }

    @Test("Art already small enough is left exactly as it is")
    func smallFramesAreNotResampled() throws {
        // The cap must never *up*scale: asking ImageIO for a 133px "thumbnail" of a
        // 64px frame would resample it for nothing and cost sharpness.
        let pack = makePack("small")
        Self.writePNG(to: pack.appendingPathComponent("resting.png"), side: 64)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let frame = try #require(loaded.animations["resting"]?.frames.first)
        let image = try #require(frame.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(image.width == 64)
        #expect(image.height == 64)
    }

    @Test("Scaling a frame down keeps its 8-bit alpha")
    func capPreservesAlpha() throws {
        // The alpha test above uses 64px art, which is under the cap and therefore
        // takes the plain decode path — so it says nothing about the scaled one. This
        // is the case that matters for the shipped packs, every frame of which is
        // scaled: if `CGImageSourceCreateThumbnailAtIndex` flattened alpha, the
        // character would render as a rectangle of background and the whole reason for
        // preferring APNG over GIF would be undone by the loader itself.
        let pack = makePack("big-soft")
        Self.writeAPNG(to: pack.appendingPathComponent("resting.png"),
                       frames: 2, delays: [0.1], side: 512)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let first = try #require(loaded.animations["resting"]?.frames.first)
        let cropped = try #require(first.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(max(cropped.width, cropped.height) <= Int(Self.cap))

        let rep = NSBitmapImageRep(cgImage: cropped)
        var levels = Set<Int>()
        var partial = 0
        var clear = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y) else { continue }
                let alpha = Int((colour.alphaComponent * 255).rounded())
                levels.insert(alpha)
                if alpha > 0 && alpha < 255 { partial += 1 }
                if alpha == 0 { clear += 1 }
            }
        }
        // Same thresholds as the un-scaled case: a 1-bit round-trip measures 2 levels
        // and 0 partial pixels.
        #expect(levels.count > 16)
        #expect(partial > 50)
        // And the corners are still fully transparent — a flattened image would have
        // filled them, which is the failure that would actually be visible on screen.
        #expect(clear > 0)
    }

    @Test("A capped frame keeps its aspect ratio")
    func capPreservesAspectRatio() throws {
        // The shipped packs are not square (260x288 for one state), so a cap that
        // squared everything off would distort the art.
        let pack = makePack("wide")
        let url = pack.appendingPathComponent("resting.png")
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 600, pixelsHigh: 300,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = NSSize(width: 600, height: 300)
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: 600, height: 300))
        NSColor.systemPurple.setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 10, width: 580, height: 280)).fill()
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: url)

        let loaded = try SpritePackStore.loadPack(from: pack)
        let frame = try #require(loaded.animations["resting"]?.frames.first)
        let image = try #require(frame.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(max(image.width, image.height) <= Int(Self.cap))
        // 2:1 in, 2:1 out.
        #expect(abs(Double(image.width) / Double(image.height) - 2.0) < 0.05)
    }

    // MARK: Rescanning

    @Test("An unchanged set of folders produces an unchanged signature")
    func signatureIsStableAndDetectsChange() throws {
        // `reload()` skips its work when this comparison says nothing moved, so the two
        // ways it can be wrong are both bad: always-equal means a pack the user just
        // installed never appears, and always-different means every visit to the
        // Companion pane re-decodes every frame (measured at 170-230 ms).
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UtterScanTests-\(UUID().uuidString)")
        let first = root.appendingPathComponent("one")
        try fm.createDirectory(at: first, withIntermediateDirectories: true)

        func entries() throws -> [URL] {
            try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [])
        }

        let before = SpritePackStore.signature(of: try entries())
        #expect(before.count == 1)
        // Read twice with nothing touched: identical, so the scan is skipped.
        #expect(SpritePackStore.signature(of: try entries()) == before)

        // A pack installed is a new folder, which the comparison must notice.
        try fm.createDirectory(at: root.appendingPathComponent("two"),
                               withIntermediateDirectories: true)
        let afterAdd = SpritePackStore.signature(of: try entries())
        #expect(afterAdd != before)
        #expect(afterAdd.count == 2)

        // And a pack removed, likewise.
        try fm.removeItem(at: first)
        #expect(SpritePackStore.signature(of: try entries()) != afterAdd)

        // A plain file among the folders is not a pack and must not register.
        try Data().write(to: root.appendingPathComponent("notes.txt"))
        #expect(SpritePackStore.signature(of: try entries()).count == 1)

        try? fm.removeItem(at: root)
    }

    // MARK: Rejection — untrusted input

    @Test("A relative path escaping the pack folder is rejected")
    func rejectsRelativeTraversal() throws {
        let pack = makePack("evil")
        try Self.writeManifest(pack, """
        {"name":"Evil","frameWidth":64,"frameHeight":64,
         "states":{"resting":{"file":"../../../etc/hosts","frames":1}}}
        """)
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("An absolute path outside the pack folder is rejected")
    func rejectsAbsolutePath() throws {
        let pack = makePack("evil-abs")
        try Self.writeManifest(pack, """
        {"name":"EvilAbs","frameWidth":64,"frameHeight":64,
         "states":{"resting":{"file":"/etc/hosts","frames":1}}}
        """)
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("Malformed JSON is reported, not ignored")
    func rejectsMalformedJSON() throws {
        let pack = makePack("broken")
        try Self.writeManifest(pack, "{not json at all")
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("A strip manifest without frame dimensions is rejected")
    func rejectsMissingDimensions() throws {
        let pack = makePack("no-dims")
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: 2)
        try Self.writeManifest(pack, """
        {"name":"NoDims","states":{"resting":{"file":"idle.png","frames":2}}}
        """)
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("A pack with no resting state is rejected")
    func rejectsMissingResting() throws {
        let pack = makePack("no-resting")
        Self.writeAPNG(to: pack.appendingPathComponent("alert.png"), frames: 2, delays: [0.1])
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("An empty folder is rejected with a useful message")
    func rejectsEmptyFolder() throws {
        let pack = makePack("empty")
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    @Test("A frame larger than the whole sheet is rejected")
    func rejectsOversizedFrame() throws {
        let pack = makePack("too-big")
        Self.writeStrip(to: pack.appendingPathComponent("idle.png"), count: 1, side: 32)
        try Self.writeManifest(pack, """
        {"name":"TooBig","frameWidth":4096,"frameHeight":4096,
         "states":{"resting":{"file":"idle.png","frames":1}}}
        """)
        #expect(throws: SpritePackStore.PackError.self) {
            _ = try SpritePackStore.loadPack(from: pack)
        }
    }

    // MARK: Helpers

    private static func writeManifest(_ directory: URL, _ json: String) throws {
        try json.data(using: .utf8)!.write(to: directory.appendingPathComponent("pack.json"))
    }
}
