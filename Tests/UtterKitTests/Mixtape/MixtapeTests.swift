import AppKit
import Testing

@testable import UtterKit

@Suite("Mixtape")
struct MixtapeTests {
    typealias P = Mixtape.Palette

    @Test("The tape fills toward the goal, rescales once past it, and never overflows the track")
    func tapeWidths() {
        #expect(Mixtape.tapeWidths([100, 50], goal: 500, track: 302) == [60, 30])
        let over = Mixtape.tapeWidths([400, 200], goal: 500, track: 302)
        #expect(over == [200, 100])
        #expect(over.reduce(0, +) + 2 <= 302)
        #expect(Mixtape.tapeWidths([5], goal: 0, track: 10) == [10])
        #expect(Mixtape.tapeWidths([], goal: 500, track: 100).isEmpty)
    }

    @Test("Ink reads on paper, and Increase Contrast strengthens the rules and tertiary ink", arguments: [false, true])
    func contrast(dark: Bool) {
        let paper = P.paper.resolved(dark: dark, increasedContrast: false)
        func onPaper(_ swatch: Look.Swatch, increased: Bool) -> Double {
            WCAG.contrast(WCAG.over(swatch.resolved(dark: dark, increasedContrast: increased), paper), paper)
        }
        #expect(onPaper(P.ink, increased: false) >= 7)
        #expect(onPaper(P.ink2, increased: false) >= 4.5)
        #expect(onPaper(P.ink3, increased: false) >= 3)
        #expect(onPaper(P.ink3, increased: true) >= 4.5)
        for swatch in [P.rule, P.rule2, P.ink3, P.edge] {
            #expect(onPaper(swatch, increased: true) > onPaper(swatch, increased: false))
        }
    }
}
