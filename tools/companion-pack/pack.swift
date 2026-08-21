import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// Build a Utter companion pack from the contact sheet:
//   1. cut each pose out on its measured box
//   2. DROP the baked vignette (keep only ink that belongs to the character)
//   3. centre each pose on a square transparent canvas, scaled to a common size
//   4. write one APNG per state, with hand-chosen per-frame timing
//
// Output: ~/Library/Application Support/Utter/Companions/panda/
//
// `Utter`, not `AWSFlow` — the app's data folder was renamed and this path has to follow
// `AppDirectory.name` (Sources/UtterKit/Model/AppDirectory.swift), which is what
// `SpritePackStore.directory` resolves through. Writing to the old name installed the pack
// somewhere the app no longer scans, and it stayed invisible: `AppDirectory` migrates the
// legacy folder only when the new one is *absent*, so on any current install the pack was
// orphaned rather than picked up late.

let sheetPath = CommandLine.arguments[1]
let outRoot = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/Utter/Companions/panda")
try? FileManager.default.createDirectory(at: outRoot, withIntermediateDirectories: true)

let sheetRep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: sheetPath)))!
let W = sheetRep.pixelsWide, H = sheetRep.pixelsHigh

// ── Read every pixel once into RGBA arrays.
var R = [Float](repeating: 0, count: W*H), G = R, B = R, A = R
for y in 0..<H {
    for x in 0..<W {
        guard let c = sheetRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let i = y*W+x
        R[i] = Float(c.redComponent); G[i] = Float(c.greenComponent)
        B[i] = Float(c.blueComponent); A[i] = Float(c.alphaComponent)
    }
}

// ── Vignette removal.
//
// The sheet carries a dark background glow baked into low-alpha pixels. Simply
// thresholding alpha would also chop the character's own anti-aliased edge and its
// drop shadow, so instead: keep a pixel if it is solid, OR if it is soft but sits
// adjacent to solid ink (a real edge). Anything else is background haze and goes.
var solid = [Bool](repeating: false, count: W*H)
for i in 0..<(W*H) { solid[i] = A[i] > 0.55 }

/// Distance-limited dilation of the solid mask: which soft pixels are edge pixels.
var nearSolid = [Bool](repeating: false, count: W*H)
let edgeReach = 3
for y in 0..<H {
    for x in 0..<W {
        let i = y*W+x
        guard A[i] > 0.02, !solid[i] else { continue }
        var found = false
        var dy = -edgeReach
        while dy <= edgeReach && !found {
            var dx = -edgeReach
            while dx <= edgeReach {
                let nx = x+dx, ny = y+dy
                if nx >= 0, nx < W, ny >= 0, ny < H, solid[ny*W+nx] { found = true; break }
                dx += 1
            }
            dy += 1
        }
        nearSolid[i] = found
    }
}
var kept = 0, dropped = 0
for i in 0..<(W*H) {
    if solid[i] || nearSolid[i] { kept += 1 } else if A[i] > 0.02 { A[i] = 0; dropped += 1 }
}
print("vignette pass: kept \(kept) ink px, cleared \(dropped) haze px")

// ── Cut a pose out, centred on a square canvas.
struct Box: Decodable { let minX: Int; let minY: Int; let maxX: Int; let maxY: Int }
let boxes = try JSONDecoder().decode([Box].self,
    from: Data(contentsOf: URL(fileURLWithPath: "/tmp/panda/poses.json")))

let canvas = 128          // output frame size in px
let margin: CGFloat = 6   // breathing room inside the canvas

func poseImage(_ box: Box) -> CGImage {
    let bw = box.maxX - box.minX + 1
    let bh = box.maxY - box.minY + 1

    // Source patch with the cleaned alpha.
    let patch = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: bw, pixelsHigh: bh,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    patch.size = NSSize(width: bw, height: bh)
    for y in 0..<bh {
        for x in 0..<bw {
            let src = (box.minY + y)*W + (box.minX + x)
            patch.setColor(NSColor(deviceRed: CGFloat(R[src]), green: CGFloat(G[src]),
                                   blue: CGFloat(B[src]), alpha: CGFloat(A[src])),
                           atX: x, y: y)
        }
    }

    // Scale to fit the canvas, preserving aspect, and centre horizontally. Bottom-
    // aligned rather than centred vertically: these are characters standing on a
    // surface, and centring a tall jumping pose against a squat sitting one makes
    // them bob relative to each other between states.
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    out.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: out)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    ctx.imageInterpolation = .high
    let avail = CGFloat(canvas) - margin*2
    let scale = min(avail / CGFloat(bw), avail / CGFloat(bh))
    let dw = CGFloat(bw)*scale, dh = CGFloat(bh)*scale
    patch.draw(in: NSRect(x: (CGFloat(canvas)-dw)/2, y: margin, width: dw, height: dh))
    NSGraphicsContext.restoreGraphicsState()
    return out.cgImage!
}

let poses = boxes.map(poseImage)
print("cut \(poses.count) poses at \(canvas)x\(canvas)")

// ── Assemble the states.
//
// Frame choices come from what each pose actually depicts on the sheet:
//   row 1 (0-3): four head-and-shoulders expressions — open eyes, wink, eyes closed, happy
//   row 2 (4-7): a walk/run cycle
//   row 3 (8-10): sitting, eating bamboo, lying content
//   row 4 (11-14): jumping and cheering
//
// Timings are hand-set per state, which is the reason for APNG: a resting idle holds
// a long beat then blinks, while a celebration runs fast and even.
struct State { let name: String; let frames: [Int]; let delays: [Double] }
let states: [State] = [
    // Idle: hold the neutral face, blink (eyes closed), hold again. The long holds are
    // what make it read as breathing rather than flickering.
    State(name: "resting", frames: [0, 0, 2, 0], delays: [1.6, 0.9, 0.12, 2.2]),
    // Mic live: alert and attentive — the wide-eyed pose, with a small bright beat.
    State(name: "alert", frames: [0, 3], delays: [0.5, 0.5]),
    // Working: the walk cycle reads as "busy" better than any static pose.
    State(name: "thinking", frames: [4, 5, 6, 7], delays: [0.14, 0.14, 0.14, 0.14]),
    // Done: the cheer/jump poses, fast and bouncy.
    State(name: "delighted", frames: [11, 12, 13, 12], delays: [0.10, 0.10, 0.10, 0.10]),
    // Error: a startle should read as "oh no", and this sheet has no distressed face —
    // so it is built from MOTION instead of expression: a fast shake between the two
    // most wide-eyed poses. Holding a *contented* pose here (the obvious pick, since
    // the closed-eye pose looks like a wince at a glance) actually reads as the
    // character being pleased that something failed.
    State(name: "startled", frames: [0, 3, 0, 3], delays: [0.09, 0.09, 0.09, 0.55]),
    // Long idle: the eyes-closed poses only. Pose 9 (eating bamboo) and pose 10
    // (lying down with a heart) are both plainly AWAKE, and a companion that "sleeps"
    // by having a snack is just wrong — the sitting pose with shut eyes is the only
    // honest option on the sheet.
    State(name: "sleepy", frames: [2, 2], delays: [3.0, 3.0]),
]

for state in states {
    let url = outRoot.appendingPathComponent("\(state.name).png")
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, state.frames.count, nil)!
    CGImageDestinationSetProperties(dest,
        [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary)
    for (n, frameIndex) in state.frames.enumerated() {
        CGImageDestinationAddImage(dest, poses[frameIndex],
            [kCGImagePropertyPNGDictionary:
                [kCGImagePropertyAPNGDelayTime: state.delays[n]]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(dest) else { fatalError("failed \(state.name)") }
    let bytes = (try? Data(contentsOf: url).count) ?? 0
    print("  \(state.name).png: \(state.frames.count) frames, \(bytes/1024)KB")
}

// A manifest purely for the name and credit — the layout needs none.
try! #"""
{
  "name": "Panda",
  "author": "generated from a reference sheet"
}
"""#.data(using: .utf8)!.write(to: outRoot.appendingPathComponent("pack.json"))
print("\nwrote pack to \(outRoot.path)")
