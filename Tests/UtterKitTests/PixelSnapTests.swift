import Testing
import CoreGraphics
@testable import UtterKit

/// The pixel-art size snapping, which is the one piece of `SpritePackView` that is pure
/// arithmetic — and the piece that had a live bug nobody could see on a Retina display.
///
/// It is tested through `SpritePack.snappedSide` rather than through the view because
/// `renderedSize` reads `@Environment(\.displayScale)`, and the display scale is exactly the
/// input the bug depended on. A test that could not vary it would have agreed with the bug.
@Suite("Pixel-art size snapping")
struct PixelSnapTests {

    private let ladder = CompanionSize.allCases.map(\.points)   // 36, 52, 68, 84

    /// **The invariant the whole companion geometry rests on.**
    ///
    /// `CompanionGeometry` derives the panel, the roam range and the hop height from the
    /// *requested* character size, and a borderless panel clips its content — so a sprite
    /// drawn larger than the size it was asked for is sliced at the window edge as soon as
    /// it moves. The old code clamped the scale up to 1x when no whole multiple fit, which
    /// returned 64pt for a 36pt box.
    @Test("A snapped sprite never exceeds the box it was asked for",
          arguments: [1.0, 2.0, 3.0] as [CGFloat])
    func neverExceedsTheBox(displayScale: CGFloat) {
        for canvas in [8.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0, 128.0] as [CGFloat] {
            for box in ladder {
                let side = SpritePack.snappedSide(
                    box: box, canvas: canvas, displayScale: displayScale
                )
                #expect(side <= box,
                        "a \(Int(canvas))px canvas draws \(side)pt in a \(box)pt box at \(displayScale)x")
                #expect(side > 0, "a \(Int(canvas))px canvas vanished in a \(box)pt box")
            }
        }
    }

    /// The point of snapping: the scale factor has to be a whole number of device pixels per
    /// source pixel, or a whole number of source pixels per device pixel. Anything between
    /// draws some source pixels wider than others, which on pixel art reads as uneven
    /// whiskers and a lopsided ear rather than as smoothing.
    @Test("The scale is always a whole multiple or a whole divisor",
          arguments: [1.0, 2.0] as [CGFloat])
    func scaleIsWhole(displayScale: CGFloat) {
        for canvas in [16.0, 32.0, 64.0, 128.0] as [CGFloat] {
            for box in ladder {
                let devicePixels = SpritePack.snappedSide(
                    box: box, canvas: canvas, displayScale: displayScale
                ) * displayScale
                let up = devicePixels / canvas          // device pixels per source pixel
                let down = canvas / devicePixels        // source pixels per device pixel
                let whole = abs(up.rounded() - up) < 0.0001 || abs(down.rounded() - down) < 0.0001
                #expect(whole,
                        "a \(Int(canvas))px canvas in a \(box)pt box at \(displayScale)x scales by \(up)x")
            }
        }
    }

    /// The ladder the shipped pixel cats actually draw at, recorded rather than described.
    ///
    /// This is the cost of the 64px canvas, and it is worth pinning as a number: two of the
    /// four size settings collapse onto each other, so Small looks like Medium and Large
    /// looks like Huge. The 32px packs that preceded them gave four distinct steps. Nobody
    /// should be able to change the canvas size or the ladder without this failing.
    @Test("The shipped 64px canvas renders 32/32/64/64pt on a Retina display")
    func shippedLadderIsRecorded() {
        let rendered = ladder.map {
            SpritePack.snappedSide(box: $0, canvas: 64, displayScale: 2)
        }
        #expect(rendered == [32, 32, 64, 64])

        // On a non-Retina display it is flat 32/32/64/64 too, by the divisor branch for the
        // first two and 1x for the last two — which is the only reason the small sizes fit.
        let nonRetina = ladder.map {
            SpritePack.snappedSide(box: $0, canvas: 64, displayScale: 1)
        }
        #expect(nonRetina == [32, 32, 64, 64])

        // The 32px canvas the earlier packs used, for contrast: four distinct steps.
        let atThirtyTwo = ladder.map {
            SpritePack.snappedSide(box: $0, canvas: 32, displayScale: 2)
        }
        #expect(atThirtyTwo == [32, 48, 64, 80])
    }

    /// Degenerate inputs fall back to the box rather than dividing by zero and handing
    /// SwiftUI a NaN frame.
    @Test("A canvas or scale that cannot be divided by falls back to the box")
    func degenerateInputsFallBack() {
        #expect(SpritePack.snappedSide(box: 52, canvas: 0, displayScale: 2) == 52)
        #expect(SpritePack.snappedSide(box: 52, canvas: 64, displayScale: 0) == 52)
        #expect(SpritePack.snappedSide(box: 0, canvas: 64, displayScale: 2) == 0)
        for box in ladder {
            let side = SpritePack.snappedSide(box: box, canvas: 64, displayScale: 2)
            #expect(side.isFinite)
        }
    }
}
