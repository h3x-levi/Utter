import Testing
@testable import UtterKit

@Suite("Built-in companion distribution")
struct ShippedPackTests {
    @Test("Every built-in companion is code-rendered")
    func builtInsContainNoBitmapAnimations() {
        let packs = CodePixelCatStyle.allCases.map(\.pack)
        #expect(Set(packs.map(\.id)) == [
            "dog", "panda", "pixel-cat-gray", "pixel-cat-orange",
        ])
        for pack in packs {
            #expect(pack.pixelArt)
            #expect(pack.animations.isEmpty)
            #expect(pack.eyeOverlay == nil)
            #expect(pack.author == "Drawn in code by Utter")
        }
    }

    @Test("Built-in ids reserve their legacy image-pack names")
    func codeIdsCannotBeShadowedByPngPacks() {
        let reserved = Set(CodePixelCatStyle.allCases.map(\.rawValue))
        #expect(reserved == ["dog", "panda", "pixel-cat-gray", "pixel-cat-orange"])
        #expect(reserved.count == CodePixelCatStyle.allCases.count)
    }
}
