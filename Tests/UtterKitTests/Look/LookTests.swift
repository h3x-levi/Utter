import AppKit
import SwiftUI
import Testing

@testable import UtterKit

struct LookMode: Sendable, CustomTestStringConvertible {
    let dark: Bool
    let increased: Bool

    var testDescription: String { (dark ? "dark" : "light") + (increased ? ", increased contrast" : "") }

    static let all = [LookMode(dark: false, increased: false), LookMode(dark: true, increased: false),
                      LookMode(dark: false, increased: true), LookMode(dark: true, increased: true)]
}

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

@Suite("Look palette")
struct LookPaletteTests {
    typealias P = Look.Palette

    private static let grounds: [(dark: Bool, increased: Bool, hex: UInt32)] = [
        (false, false, 0xFFFFFF), (false, false, 0xECECEC), (true, false, 0x1E1E1E), (true, false, 0x323232),
    ]

    @Test("The brand tint reads as text on the system window grounds", arguments: LookMode.all)
    func tintText(mode: LookMode) {
        for ground in Self.grounds where ground.dark == mode.dark {
            let value = WCAG.contrast(P.tint.resolved(dark: mode.dark, increasedContrast: mode.increased), .hex(ground.hex))
            #expect(value >= 4.5, "tint on \(String(ground.hex, radix: 16)): \(value)")
        }
    }

    @Test("The mic colour clears the 3:1 non-text floor on the system window grounds", arguments: LookMode.all)
    func micDot(mode: LookMode) {
        for ground in Self.grounds where ground.dark == mode.dark {
            let value = WCAG.contrast(P.mic.resolved(dark: mode.dark, increasedContrast: mode.increased), .hex(ground.hex))
            #expect(value >= 3, "mic on \(String(ground.hex, radix: 16)): \(value)")
        }
    }

    @Test("The SwiftUI tokens resolve through the dynamic provider")
    func bridged() {
        let increased = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let pairs: [(SwiftUI.Color, Look.Swatch)] = [(Look.Color.tint, P.tint), (Look.Color.mic, P.mic)]
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            for (color, swatch) in pairs {
                var resolved = NSColor.clear
                appearance.performAsCurrentDrawingAppearance { resolved = NSColor(color).usingColorSpace(.sRGB)! }
                #expect(resolved == swatch.resolved(dark: dark, increasedContrast: increased).usingColorSpace(.sRGB)!)
            }
        }
    }

    @Test("Secondary ink reads as text on the Moonlight ground; tertiary clears the 3:1 meta floor", arguments: LookMode.all)
    func inkLadder(mode: LookMode) {
        for ground in [P.groundTop, P.groundBottom] {
            let base = ground.resolved(dark: mode.dark, increasedContrast: mode.increased)
            let card = WCAG.over(P.fill.resolved(dark: mode.dark, increasedContrast: mode.increased), base)
            for under in [base, card] {
                let ink2 = WCAG.contrast(WCAG.over(P.ink2.resolved(dark: mode.dark, increasedContrast: mode.increased), under), under)
                let ink3 = WCAG.contrast(WCAG.over(P.ink3.resolved(dark: mode.dark, increasedContrast: mode.increased), under), under)
                #expect(ink2 >= 4.5, "ink2: \(ink2)")
                #expect(ink3 >= 3, "ink3: \(ink3)")
            }
        }
    }

    @Test("Reduce Motion turns every motion into the same short cross-fade")
    func reducedMotion() {
        let reduced = Look.Motion.reduced.animation(reduceMotion: false)
        #expect(Look.Motion.allCases.allSatisfy { $0.animation(reduceMotion: true) == reduced })
        #expect(Look.Motion.settle.animation(reduceMotion: false) != reduced)
    }
}

@Suite("Living mark")
struct LivingMarkTests {
    typealias G = MarkGeometry

    @Test("Rest is the icon: tall outer bars stepping down to the centre")
    func restShape() {
        let heights = G.heights(phase: .rest, level: 1, dipped: false, reduceMotion: false, time: 3)
        #expect(heights == G.rest)
        #expect(heights == heights.reversed())
        #expect(heights[0] > heights[1] && heights[1] > heights[2] && heights[2] > heights[3])
    }

    @Test("Listening follows the level, and silence leaves dots")
    func listening() {
        let silent = G.heights(phase: .listening, level: 0, dipped: false, reduceMotion: false, time: 1)
        #expect(silent.allSatisfy { $0 == G.dot })
        let loud = G.heights(phase: .listening, level: 1, dipped: false, reduceMotion: false, time: 1)
        let quiet = G.heights(phase: .listening, level: 0.3, dipped: false, reduceMotion: false, time: 1)
        #expect(zip(loud, quiet).allSatisfy { $0 >= $1 })
        #expect(loud[0] > loud[3])
    }

    @Test("Thinking travels: bars are out of step with their neighbours")
    func thinking() {
        let frame = G.heights(phase: .thinking, level: 0, dipped: false, reduceMotion: false, time: 0.4)
        #expect(Set(frame).count > 1)
        #expect(frame.allSatisfy { $0 >= G.dot && $0 <= G.dot + 2.5 })
    }

    @Test("Smile dips the bars, flat is a row of dots, Reduce Motion holds still")
    func otherPhases() {
        #expect(G.heights(phase: .smile, level: 0, dipped: true, reduceMotion: false, time: 0).allSatisfy { $0 == G.dot })
        #expect(G.heights(phase: .smile, level: 0, dipped: false, reduceMotion: false, time: 0) == G.rest)
        #expect(G.heights(phase: .flat, level: 1, dipped: false, reduceMotion: false, time: 9).allSatisfy { $0 == G.dot })
        let a = G.heights(phase: .thinking, level: 0, dipped: false, reduceMotion: true, time: 0)
        let b = G.heights(phase: .thinking, level: 0, dipped: false, reduceMotion: true, time: 7)
        #expect(a == b)
    }

    @Test("The mark keeps its proportions from 24 to 240 points")
    func scaling() {
        for height in [24.0, 240.0] {
            let rect = CGRect(x: 0, y: 0, width: height * G.width / G.height, height: height)
            let u = G.scale(in: rect)
            #expect(abs(u * G.height - height) < 0.001)
            let left = G.point(-G.width / 2, 0, in: rect), right = G.point(G.width / 2, 0, in: rect)
            #expect(abs(left.x) < 0.001 && abs(right.x - rect.width) < 0.001)
        }
    }

    @MainActor
    @Test("The mark renders at both ends of its size range")
    func renders() {
        for height in [24.0, 240.0] {
            for phase in [LivingMark.Phase.rest, .listening, .thinking, .smile, .flat] {
                let image = ImageRenderer(content: LivingMark(phase: phase, level: 0.6).frame(height: height)).nsImage
                #expect(image != nil)
            }
        }
    }
}
