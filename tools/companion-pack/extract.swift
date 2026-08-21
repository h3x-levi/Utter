import Foundation
import AppKit

// Segment the contact sheet into individual poses, then report each pose's tight
// bounding box and a suggested state assignment.
let path = CommandLine.arguments[1]
let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!
let W = rep.pixelsWide, H = rep.pixelsHigh

// Cache alpha + luminance once. colorAt() per pixel is slow; this is 1.5M pixels.
var alpha = [Float](repeating: 0, count: W*H)
var lum = [Float](repeating: 0, count: W*H)
for y in 0..<H {
    for x in 0..<W {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let i = y*W + x
        alpha[i] = Float(c.alphaComponent)
        lum[i] = Float(0.299*c.redComponent + 0.587*c.greenComponent + 0.114*c.blueComponent)
    }
}

// The character is the SOLID ink. The vignette is low-alpha and dark, so a solid
// threshold excludes it without needing to model the glow.
var mask = [Bool](repeating: false, count: W*H)
for i in 0..<(W*H) { mask[i] = alpha[i] > 0.55 }

// Connected components, iterative.
var label = [Int](repeating: 0, count: W*H)
var comps: [(id: Int, minX: Int, minY: Int, maxX: Int, maxY: Int, area: Int)] = []
var next = 0
for s in 0..<(W*H) where mask[s] && label[s] == 0 {
    next += 1
    var stack = [s]; label[s] = next
    var minX = W, maxX = 0, minY = H, maxY = 0, area = 0
    while let p = stack.popLast() {
        let x = p % W, y = p / W
        area += 1
        minX = min(minX,x); maxX = max(maxX,x); minY = min(minY,y); maxY = max(maxY,y)
        for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
            let nx = x+dx, ny = y+dy
            guard nx>=0, nx<W, ny>=0, ny<H else { continue }
            let q = ny*W+nx
            if mask[q], label[q]==0 { label[q]=next; stack.append(q) }
        }
    }
    comps.append((next, minX, minY, maxX, maxY, area))
}

// Merge small satellites (sparkles, hearts, motion ticks, a detached paw) into the
// big body they belong to: anything whose box is close to a large box.
let bodies = comps.filter { $0.area > 12_000 }
let bits = comps.filter { $0.area <= 12_000 && $0.area > 200 }
print("bodies: \(bodies.count)  loose bits: \(bits.count)")

struct Pose { var minX: Int; var minY: Int; var maxX: Int; var maxY: Int; var area: Int }
var poses = bodies.map { Pose(minX: $0.minX, minY: $0.minY, maxX: $0.maxX, maxY: $0.maxY, area: $0.area) }

for b in bits {
    // Attach to the nearest body whose box is within 40px.
    var best = -1; var bestDist = Int.max
    for (i, p) in poses.enumerated() {
        let dx = max(0, max(p.minX - b.maxX, b.minX - p.maxX))
        let dy = max(0, max(p.minY - b.maxY, b.minY - p.maxY))
        let d = dx*dx + dy*dy
        if d < bestDist { bestDist = d; best = i }
    }
    if best >= 0, bestDist < 40*40 {
        poses[best].minX = min(poses[best].minX, b.minX)
        poses[best].maxX = max(poses[best].maxX, b.maxX)
        poses[best].minY = min(poses[best].minY, b.minY)
        poses[best].maxY = max(poses[best].maxY, b.maxY)
    }
}

// Order top-to-bottom, then left-to-right.
poses.sort { a, b in
    let rowA = a.minY / 340, rowB = b.minY / 340
    return rowA != rowB ? rowA < rowB : a.minX < b.minX
}
print("\nPOSES (\(poses.count)) — y measured from TOP:")
for (i, p) in poses.enumerated() {
    print(String(format: "  %2d: x=%4d..%4d y=%4d..%4d  %3dx%-3d",
                 i+1, p.minX, p.maxX, p.minY, p.maxY, p.maxX-p.minX+1, p.maxY-p.minY+1))
}
// Emit as JSON for the packer to consume.
let json = poses.map { ["minX": $0.minX, "minY": $0.minY, "maxX": $0.maxX, "maxY": $0.maxY] }
try! JSONSerialization.data(withJSONObject: json)
    .write(to: URL(fileURLWithPath: "/tmp/panda/poses.json"))
print("\nwrote poses.json")
