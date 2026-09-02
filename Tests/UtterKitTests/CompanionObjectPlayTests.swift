import Testing
@testable import UtterKit

@Suite("Companion object play")
struct CompanionObjectPlayTests {
    @Test("Every prop sequence starts and finishes with the character at rest")
    func sequencesReturnHome() {
        for object in CompanionObject.allCases where object != .none {
            let start = CompanionObjectPlay(object: object, progress: 0)
            let end = CompanionObjectPlay(object: object, progress: 1)
            #expect(start.characterOffset == .zero, "\(object) starts displaced")
            #expect(end.characterOffset == .zero, "\(object) finishes displaced")
            #expect(end.propOffset == .zero, "\(object) prop finishes displaced")
            #expect(end.characterRotation.truncatingRemainder(dividingBy: 360) == 0)
            #expect(end.propRotation.truncatingRemainder(dividingBy: 360) == 0)
        }
    }

    @Test("Ball play moves both the companion and the ball and includes a roll")
    func ballIsARealSharedSequence() {
        let bat = CompanionObjectPlay(object: .ball, progress: 0.28)
        let roll = CompanionObjectPlay(object: .ball, progress: 0.60)
        #expect(bat.characterOffset != .zero)
        #expect(bat.propOffset != .zero)
        #expect(roll.characterIsRolling)
        #expect(roll.characterRotation > 0)
    }

    @Test("Box, yarn, and cushion each have a different physical response")
    func remainingPropsAreDistinct() {
        let box = CompanionObjectPlay(object: .box, progress: 0.55)
        let yarn = CompanionObjectPlay(object: .yarn, progress: 0.55)
        let cushion = CompanionObjectPlay(object: .cushion, progress: 0.55)

        #expect(box.characterScale < 1)
        #expect(box.propRotation < 0)
        #expect(yarn.propOffset != .zero)
        #expect(yarn.characterRotation != 0)
        #expect(cushion.propScaleY < 1)
        #expect(cushion.objectSitsBehindCharacter)
    }
}
