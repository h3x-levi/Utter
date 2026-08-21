import Foundation
import AppKit
import ImageIO

// Render every frame of every state at the REAL 56px display size, over light and
// dark, so the pack can be judged as it will actually appear beside the pill.
// `Utter` must match `AppDirectory.name` and the output path in `pack.swift` — see the
// note there. Reading the old `AWSFlow` name here found nothing to render.
let root = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/Utter/Companions/panda")
let states = ["resting","alert","thinking","delighted","startled","sleepy"]
let display = 56, zoom = 3, pad = 8, labelH = 16
let cell = display*zoom

var rows: [(String, [CGImage])] = []
for s in states {
    let url = root.appendingPathComponent("\(s).png")
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { continue }
    var frames: [CGImage] = []
    for i in 0..<CGImageSourceGetCount(src) {
        if let cg = CGImageSourceCreateImageAtIndex(src, i, nil) { frames.append(cg) }
    }
    rows.append((s, frames))
}
let maxFrames = rows.map { $0.1.count }.max() ?? 1
let sheetW = pad + maxFrames*(cell+pad) + 110
let sheetH = pad + rows.count*(cell+pad+labelH)

let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: sheetW, pixelsHigh: sheetH*2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
out.size = NSSize(width: sheetW, height: sheetH*2)
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: out)!
NSGraphicsContext.current = ctx
ctx.cgContext.clear(CGRect(x: 0, y: 0, width: sheetW, height: sheetH*2))
ctx.imageInterpolation = .high

// Two bands: dark on top half, light on bottom (bitmap y is bottom-up).
NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1).setFill()
NSRect(x: 0, y: sheetH, width: sheetW, height: sheetH).fill()
NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

for (band, yBase) in [(0, 0), (1, sheetH)] {
    let ink = band == 0 ? NSColor.black : NSColor.white
    for (ri, row) in rows.enumerated() {
        // Rows top-down within the band.
        let rowY = yBase + sheetH - (ri+1)*(cell+pad+labelH)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: ink]
        NSAttributedString(string: row.0, attributes: attrs)
            .draw(at: NSPoint(x: pad, y: rowY + cell + 2))
        for (fi, cg) in row.1.enumerated() {
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            img.draw(in: NSRect(x: pad + fi*(cell+pad), y: rowY, width: cell, height: cell))
        }
    }
}
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "/tmp/panda/contact.png"))
print("wrote contact.png \(sheetW)x\(sheetH*2)")
