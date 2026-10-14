import AppKit
import SwiftUI
import Testing

@testable import UtterKit

enum WCAG {
    static func luminance(_ color: NSColor) -> Double {
        let srgb = color.usingColorSpace(.sRGB)!
        func channel(_ raw: CGFloat) -> Double {
            let value = Double(raw)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent) + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }

    static func contrast(_ a: NSColor, _ b: NSColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Source-over in sRGB, so a translucent token is measured as it actually lands.
    static func over(_ top: NSColor, _ bottom: NSColor) -> NSColor {
        let t = top.usingColorSpace(.sRGB)!, b = bottom.usingColorSpace(.sRGB)!
        let a = t.alphaComponent
        func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x * a + y * (1 - a) }
        return NSColor(srgbRed: mix(t.redComponent, b.redComponent), green: mix(t.greenComponent, b.greenComponent),
                       blue: mix(t.blueComponent, b.blueComponent), alpha: 1)
    }
}

@Suite("Look motion")
struct LookMotionTests {
    @Test("Reduce Motion turns every motion into the same short cross-fade")
    func reducedMotion() {
        let reduced = Look.Motion.reduced.animation(reduceMotion: false)
        #expect(Look.Motion.allCases.allSatisfy { $0.animation(reduceMotion: true) == reduced })
        #expect(Look.Motion.settle.animation(reduceMotion: false) != reduced)
    }
}

@Suite("Mark geometry")
struct MarkGeometryTests {
    @Test("Rest is the icon: tall outer bars stepping down to the centre")
    func restShape() {
        let heights = MarkGeometry.rest
        #expect(heights == heights.reversed())
        #expect(heights[0] > heights[1] && heights[1] > heights[2] && heights[2] > heights[3])
    }
}
