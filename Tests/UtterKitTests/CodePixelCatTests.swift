import Testing
import Foundation
@testable import UtterKit

@Suite("Code-rendered pixel companions")
struct CodePixelCatTests {
    @Test("Built-in companions keep their saved ids without bitmap animations")
    func builtInPacksAreCodeOnly() {
        let packs = CodePixelCatStyle.allCases.map(\.pack)
        #expect(packs.map(\.id).sorted() == [
            "dog", "panda", "pixel-cat-gray", "pixel-cat-orange",
        ])
        for pack in packs {
            #expect(pack.frameSize == CGSize(width: 64, height: 64))
            #expect(pack.pixelArt)
            #expect(pack.animations.isEmpty)
            #expect(pack.eyeOverlay == nil)
        }
    }

    @Test("Every built-in species has a distinct code-rendered identity")
    func builtInSpeciesAreDistinct() {
        #expect(CodePixelCatStyle.gray.species == .cat)
        #expect(CodePixelCatStyle.orange.species == .cat)
        #expect(CodePixelCatStyle.dog.species == .dog)
        #expect(CodePixelCatStyle.panda.species == .panda)
        #expect(Set(CodePixelCatStyle.allCases.map(\.name)).count == 4)
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

    @Test("Every action resolves to articulated body-part movement")
    func actionsArticulateInsteadOfFloatingAFlatSprite() {
        let resting = CodeCompanionArticulation.resolve(
            mood: .resting, gait: .idle, phase: 0, objectPlay: nil
        )
        let moods: [CompanionMood] = [
            .alert, .thinking, .delighted, .startled, .sleepy, .kneading,
            .overheating, .purring, .hunting, .held, .grooming, .rolling, .loaf,
        ]
        for mood in moods {
            let pose = CodeCompanionArticulation.resolve(
                mood: mood, gait: .idle, phase: 2, objectPlay: nil
            )
            #expect(pose != resting, "\(mood) must articulate the body")
        }
        #expect(CodeCompanionArticulation.resolve(
            mood: .sleepy, gait: .idle, phase: 2, objectPlay: nil
        ).form == .loaf)
        #expect(CodeCompanionArticulation.resolve(
            mood: .rolling, gait: .idle, phase: 2, objectPlay: nil
        ).form == .rolling)
        #expect(CodeCompanionArticulation.resolve(
            mood: .held, gait: .idle, phase: 2, objectPlay: nil
        ).form == .held)
    }

    @Test("Every idle action changes anatomy across its animation cycle")
    func everyActionHasMultipleAnatomicalFrames() {
        let moods: [CompanionMood] = [
            .resting, .alert, .thinking, .delighted, .startled, .sleepy,
            .kneading, .overheating, .purring, .hunting, .held, .grooming,
            .rolling, .loaf,
        ]
        for mood in moods {
            let frames = [0, 1, 12].map {
                CodeCompanionArticulation.resolve(
                    mood: mood, gait: .idle, phase: $0, objectPlay: nil
                )
            }
            #expect(
                frames.dropFirst().contains { $0 != frames[0] },
                "\(mood) must not be a translated static pose"
            )
        }
    }

    @Test("Object play selects real body forms and moving paws")
    func objectPlayIsArticulated() {
        let ball = CodeCompanionArticulation.resolve(
            mood: .delighted,
            gait: .idle,
            phase: 2,
            objectPlay: CompanionObjectPlay(object: .ball, progress: 0.6)
        )
        let yarn = CodeCompanionArticulation.resolve(
            mood: .hunting,
            gait: .idle,
            phase: 2,
            objectPlay: CompanionObjectPlay(object: .yarn, progress: 0.55)
        )
        let cushion = CodeCompanionArticulation.resolve(
            mood: .loaf,
            gait: .idle,
            phase: 2,
            objectPlay: CompanionObjectPlay(object: .cushion, progress: 0.55)
        )
        #expect(ball.form == .rolling)
        #expect(yarn.form == .crouching)
        #expect(yarn.leftFrontPawX != yarn.rightFrontPawX)
        #expect(cushion.form == .loaf)
    }
}
