import Testing
import Foundation
@testable import UtterKit

@Suite("Code-rendered pixel cats")
struct CodePixelCatTests {
    @Test("Built-in cats keep their saved ids without bitmap animations")
    func builtInPacksAreCodeOnly() {
        let packs = CodePixelCatStyle.allCases.map(\.pack)
        #expect(packs.map(\.id).sorted() == ["pixel-cat-gray", "pixel-cat-orange"])
        for pack in packs {
            #expect(pack.frameSize == CGSize(width: 32, height: 32))
            #expect(pack.pixelArt)
            #expect(pack.animations.isEmpty)
            #expect(pack.eyeOverlay == nil)
        }
    }

    @Test("Walking alternates diagonal legs instead of sliding a seated body")
    func walkingArticulatesFourLegs() {
        let first = CodePixelCatFrame.resolve(
            mood: .resting,
            gait: .walking,
            travelSpeed: 64,
            elapsed: 0,
            reduceMotion: false
        )
        let opposite = CodePixelCatFrame.resolve(
            mood: .resting,
            gait: .walking,
            travelSpeed: 64,
            elapsed: 0.26,
            reduceMotion: false
        )

        #expect(first.legLifts.count == 4)
        #expect(first.legStrides.count == 4)
        #expect(first.legLifts == [2, 0, 0, 2])
        #expect(opposite.legLifts == [0, 2, 2, 0])
        #expect(first.legStrides != opposite.legStrides)
    }

    @Test("Reduce Motion freezes the gait and dragging visibly extends every leg")
    func accessibilityAndDragPose() {
        let frozen = CodePixelCatFrame.resolve(
            mood: .resting,
            gait: .walking,
            travelSpeed: 120,
            elapsed: 99,
            reduceMotion: true
        )
        let held = CodePixelCatFrame.resolve(
            mood: .held,
            gait: .idle,
            travelSpeed: 0,
            elapsed: 1,
            reduceMotion: false
        )

        #expect(frozen.phase == 0)
        #expect(frozen.legLifts == [2, 0, 0, 2])
        #expect(held.legLifts.count == 4)
        #expect(held.legExtension == 4)
    }
}
