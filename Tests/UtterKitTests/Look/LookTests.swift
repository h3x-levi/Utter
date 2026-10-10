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

    private static let contentGrounds: [(String, Look.Swatch)] = [("ground", P.ground), ("well", P.well), ("wellRaised", P.wellRaised)]
    private static let contentInks: [(String, Look.Swatch)] = [("ink", P.ink), ("inkSecondary", P.inkSecondary),
                                                               ("inkTertiary", P.inkTertiary), ("ok", P.ok), ("warn", P.warn)]
    private static let plateInks: [(String, Look.Swatch)] = [("plateInk", P.plateInk),
                                                             ("plateInkSecondary", P.plateInkSecondary), ("live", P.live)]

    private func ratio(_ ink: Look.Swatch, on ground: NSColor, _ mode: LookMode) -> Double {
        WCAG.contrast(WCAG.over(ink.resolved(dark: mode.dark, increasedContrast: mode.increased), ground), ground)
    }

    private func plate(over ground: Look.Swatch, _ mode: LookMode) -> NSColor {
        WCAG.over(P.plate.resolved(dark: mode.dark, increasedContrast: mode.increased),
                  ground.resolved(dark: mode.dark, increasedContrast: mode.increased))
    }

    @Test("Every content ink clears 4.5:1 on every content ground", arguments: LookMode.all)
    func contentInks(mode: LookMode) {
        for (groundName, ground) in Self.contentGrounds {
            let base = ground.resolved(dark: mode.dark, increasedContrast: mode.increased)
            for (inkName, ink) in Self.contentInks {
                let value = ratio(ink, on: base, mode)
                #expect(value >= 4.5, "\(inkName) on \(groundName): \(value)")
            }
        }
    }

    @Test("Every plate ink clears 4.5:1 on the plate, over both grounds", arguments: LookMode.all)
    func plateInks(mode: LookMode) {
        for ground in [P.ground, P.well] {
            let surface = plate(over: ground, mode)
            for (inkName, ink) in Self.plateInks {
                let value = ratio(ink, on: surface, mode)
                #expect(value >= 4.5, "\(inkName) on plate: \(value)")
            }
        }
    }

    @Test("The mic dot clears the 3:1 non-text floor wherever it sits", arguments: LookMode.all)
    func micDot(mode: LookMode) {
        let surfaces = [P.ground.resolved(dark: mode.dark, increasedContrast: mode.increased),
                        P.well.resolved(dark: mode.dark, increasedContrast: mode.increased),
                        plate(over: P.ground, mode)]
        for surface in surfaces {
            let value = ratio(P.mic, on: surface, mode)
            #expect(value >= 3, "mic: \(value)")
        }
    }

    @Test("The three inks stay a hierarchy, not one grey", arguments: LookMode.all)
    func inkOrder(mode: LookMode) {
        let well = P.well.resolved(dark: mode.dark, increasedContrast: mode.increased)
        let levels = [P.ink, P.inkSecondary, P.inkTertiary].map { ratio($0, on: well, mode) }
        #expect(levels[0] > levels[1] && levels[1] > levels[2], "\(levels)")
    }

    @Test("The SwiftUI tokens resolve through the dynamic provider")
    func bridged() {
        let increased = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let pairs: [(SwiftUI.Color, Look.Swatch)] = [
            (Look.Color.ground, P.ground), (Look.Color.well, P.well), (Look.Color.ink, P.ink),
            (Look.Color.inkTertiary, P.inkTertiary), (Look.Color.hairline, P.hairline), (Look.Color.plate, P.plate),
            (Look.Color.live, P.live), (Look.Color.mic, P.mic), (Look.Color.warn, P.warn),
        ]
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            for (color, swatch) in pairs {
                var resolved = NSColor.clear
                appearance.performAsCurrentDrawingAppearance { resolved = NSColor(color).usingColorSpace(.sRGB)! }
                #expect(resolved == swatch.resolved(dark: dark, increasedContrast: increased).usingColorSpace(.sRGB)!)
            }
        }
    }
}

@Suite("Look caption and cues")
struct LookCaptionTests {
    @Test("A new word adds one cell and cools the old live one, keeping every id")
    func wordIdentity() {
        let text = (1...100).map { "w\($0)" }.joined(separator: " ")
        let before = Look.CaptionWords(text: text, liveWord: "go")
        let after = Look.CaptionWords(text: text + " go", liveWord: "through")

        #expect(before.items.count == Look.CaptionWords.tail)
        #expect(before.liveID == 100 && before.items.last?.word == "go")
        #expect(after.liveID == 101 && after.items.last?.word == "through")
        let shared = Set(before.items.map(\.id)).intersection(after.items.map(\.id))
        for id in shared {
            #expect(before.items.first { $0.id == id }?.word == after.items.first { $0.id == id }?.word)
        }
        #expect(after.spoken.hasSuffix("w100 go through"))
    }

    @Test("Idle text has no live word")
    func idle() {
        let words = Look.CaptionWords(text: "Hold fn and talk.", liveWord: nil)
        #expect(words.liveID == nil && words.items.map(\.word) == ["Hold", "fn", "and", "talk."])
        #expect(Look.CaptionWords(text: "", liveWord: " hi ").spoken == "hi")
    }

    @Test("Lines break greedily and an over-long word gets its own line")
    func lineBreaks() {
        #expect(Look.CaptionFlow.lines(widths: [50, 50, 50, 50], maxWidth: 160, spacing: 10) == [0..<2, 2..<4])
        #expect(Look.CaptionFlow.lines(widths: [40, 300, 40], maxWidth: 100, spacing: 10) == [0..<1, 1..<2, 2..<3])
        #expect(Look.CaptionFlow.lines(widths: [], maxWidth: 100, spacing: 10).isEmpty)
    }

    @MainActor
    @Test("The plate is the same size with one word and with forty")
    func fixedPlate() {
        func size(_ text: String, _ plateSize: Look.PlateSize) -> CGSize? {
            ImageRenderer(content: Look.CaptionPlate(text: text, liveWord: "go", caret: true, size: plateSize)
                .frame(width: 520)).nsImage?.size
        }
        let long = Array(repeating: "Thursday", count: 40).joined(separator: " ")
        for plateSize in [Look.PlateSize.hero, .pill] {
            let short = size("I", plateSize)
            #expect(short != nil && short == size(long, plateSize))
        }
    }

    @Test("Cue lines keep their columns whatever the app is called")
    func cueColumns() {
        let time = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9, minute: 31, second: 4))!
        let line = Look.CueRow.cueLine(number: 214, time: time, app: "Mail", words: 38)
        #expect(line == "214   09:31:04  Mail      38 words")
        let lengths = ["Mail", "Safari", "Messages", "Visual Studio Code"].map {
            Look.CueRow.cueLine(number: 214, time: time, app: $0, words: 38).count
        }
        #expect(Set(lengths).count == 1, "\(lengths)")
        #expect(Look.CueRow.cueLine(number: 9, time: time, app: "Notes", words: 1).hasSuffix("  1 word"))
    }

    @Test("Reduce Motion turns every motion into the same short cross-fade")
    func reducedMotion() {
        let reduced = Look.Motion.reduced.animation(reduceMotion: false)
        #expect(Look.Motion.allCases.allSatisfy { $0.animation(reduceMotion: true) == reduced })
        #expect(Look.Motion.plate.animation(reduceMotion: false) != reduced)
    }
}
