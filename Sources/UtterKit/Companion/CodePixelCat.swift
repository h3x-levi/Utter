import SwiftUI

/// Every built-in companion is drawn at runtime. Their ids stay compatible with existing
/// preferences, but no PNG frames are needed or loaded.
enum CodePixelCatStyle: String, CaseIterable {
    case gray = "pixel-cat-gray"
    case orange = "pixel-cat-orange"
    case dog
    case panda

    enum Species {
        case cat, dog, panda
    }

    var name: String {
        switch self {
        case .gray: "Charcoal Cat"
        case .orange: "Ginger Cat"
        case .dog: "Pixel Dog"
        case .panda: "Pixel Panda"
        }
    }

    var species: Species {
        switch self {
        case .gray, .orange: .cat
        case .dog: .dog
        case .panda: .panda
        }
    }

    var pack: SpritePack {
        SpritePack(
            id: rawValue,
            name: name,
            author: "Drawn in code by Utter",
            frameSize: CGSize(width: 64, height: 64),
            pixelArt: true,
            eyeOverlay: nil,
            eyeTravel: 0,
            eyeAnchors: [:],
            animations: [:]
        )
    }
}

/// Discrete articulation for one rendered tick. Keeping this pure makes the gait testable
/// without snapshotting pixels or introducing another animation clock.
struct CodePixelCatFrame: Equatable {
    let phase: Int
    let bodyY: Int
    let headY: Int
    let legLifts: [Int]
    let legStrides: [Int]
    let legExtension: Int
    let tailLift: Int
    let eyesClosed: Bool
    let steam: Bool

    static func resolve(
        mood: CompanionMood,
        gait: CompanionPose.Gait,
        travelSpeed: CGFloat,
        elapsed: Double,
        reduceMotion: Bool
    ) -> CodePixelCatFrame {
        let safeElapsed = max(0, elapsed)
        let phase: Int
        if reduceMotion {
            phase = 0
        } else if gait == .walking {
            let cadence = min(12, max(6, Double(abs(travelSpeed)) / 8))
            phase = Int(safeElapsed * cadence) % 4
        } else {
            phase = Int(safeElapsed * 8) % 24
        }

        if gait == .walking {
            let lifts = [
                [2, 0, 0, 2],
                [1, 0, 0, 1],
                [0, 2, 2, 0],
                [0, 1, 1, 0],
            ][phase % 4]
            let strides = [
                [-1, 1, 1, -1],
                [0, 1, 0, -1],
                [1, -1, -1, 1],
                [1, 0, -1, 0],
            ][phase % 4]
            return CodePixelCatFrame(
                phase: phase,
                bodyY: phase.isMultiple(of: 2) ? 0 : 1,
                headY: 0,
                legLifts: lifts,
                legStrides: strides,
                legExtension: 0,
                tailLift: phase.isMultiple(of: 2) ? 1 : 0,
                eyesClosed: false,
                steam: false
            )
        }

        var bodyY = 0
        var headY = 0
        var lifts = [0, 0, 0, 0]
        var legExtension = 0
        var tailLift = phase >= 12 ? 1 : 0
        var eyesClosed = phase >= 22
        var steam = false

        switch mood {
        case .resting:
            break
        case .alert:
            headY = -1
            tailLift = 3
            eyesClosed = false
        case .thinking:
            headY = -1
            tailLift = 2
            eyesClosed = false
        case .delighted:
            bodyY = reduceMotion ? -1 : -3
            headY = bodyY
            lifts = [2, 2, 2, 2]
            tailLift = 4
            eyesClosed = false
        case .startled:
            bodyY = -1
            headY = -2
            lifts = [1, 1, 1, 1]
            tailLift = 5
            eyesClosed = false
        case .sleepy:
            bodyY = 3
            headY = 3
            legExtension = -2
            tailLift = -1
            eyesClosed = true
        case .kneading:
            bodyY = 1
            headY = 1
            lifts[2 + (phase % 2)] = 2
            tailLift = 1
            eyesClosed = false
        case .overheating:
            bodyY = 1
            headY = 0
            lifts[2 + (phase % 2)] = 1
            tailLift = 2
            eyesClosed = false
            steam = true
        case .purring:
            bodyY = 1
            headY = 1
            tailLift = phase.isMultiple(of: 2) ? 2 : 1
            eyesClosed = true
        case .hunting:
            bodyY = 2
            headY = 1
            legExtension = -1
            tailLift = 2
            eyesClosed = false
        case .held:
            bodyY = -2
            headY = -1
            legExtension = 4
            tailLift = 1
            eyesClosed = false
        case .grooming:
            bodyY = 1
            headY = 1
            lifts[3] = 3
            eyesClosed = true
        case .rolling:
            bodyY = 3
            headY = 2
            lifts = [3, 3, 3, 3]
            tailLift = 2
            eyesClosed = false
        case .loaf:
            bodyY = 2
            headY = 2
            legExtension = -2
            tailLift = -1
            eyesClosed = true
        }

        return CodePixelCatFrame(
            phase: phase,
            bodyY: bodyY,
            headY: headY,
            legLifts: lifts,
            legStrides: [0, 0, 0, 0],
            legExtension: legExtension,
            tailLift: tailLift,
            eyesClosed: eyesClosed,
            steam: steam
        )
    }
}

enum CodeCompanionForm: Equatable {
    case seated
    case loaf
    case crouching
    case rolling
    case held
    case walking
}

/// Integer-pixel articulation shared by every code-rendered species.
///
/// The renderer draws these parts separately. No action is represented by translating a
/// completed character image: head, ears, paws, body and all three tail joints receive their
/// own offsets, while `form` selects genuinely different anatomy for actions that cannot be
/// expressed by offsets alone.
struct CodeCompanionArticulation: Equatable {
    var form: CodeCompanionForm = .seated
    var bodyY = 0
    var bodyCompression = 0
    var headX = 0
    var headY = 0
    var leftEarY = 0
    var rightEarY = 0
    var leftFrontPawX = 0
    var leftFrontPawY = 0
    var rightFrontPawX = 0
    var rightFrontPawY = 0
    var leftHindPawY = 0
    var rightHindPawY = 0
    var tailBaseY = 0
    var tailMiddleX = 0
    var tailMiddleY = 0
    var tailTipX = 0
    var tailTipY = 0
    var eyesClosed = false
    var eyesWide = false
    var mouthOpen = false

    static func resolve(
        mood: CompanionMood,
        gait: CompanionPose.Gait,
        phase: Int,
        objectPlay: CompanionObjectPlay?
    ) -> CodeCompanionArticulation {
        if gait == .walking {
            return CodeCompanionArticulation(form: .walking)
        }

        let beat = [0, 1, 2, 1][phase % 4]
        let alternate = phase.isMultiple(of: 2)
        var result = CodeCompanionArticulation()
        result.eyesClosed = phase >= 22
        result.bodyY = phase >= 12 ? 1 : 0
        result.headY = result.bodyY
        result.tailTipX = phase >= 12 ? 1 : -1

        switch mood {
        case .resting:
            result.bodyCompression = phase >= 12 ? 1 : 0
        case .alert:
            result.headY = -2 - min(1, beat)
            result.leftEarY = -2
            result.rightEarY = -2
            result.tailBaseY = -2
            result.tailMiddleY = -3
            result.tailTipY = -4 - beat
            result.eyesClosed = false
            result.eyesWide = true
        case .thinking:
            result.headX = 2
            result.headY = -1
            result.leftEarY = 2
            result.rightEarY = -1
            result.rightFrontPawX = 2
            result.rightFrontPawY = -6
            result.tailTipX = alternate ? 2 : -1
            result.eyesClosed = false
        case .delighted:
            result.bodyY = -2 - beat
            result.headY = -4 - beat
            result.leftEarY = -2
            result.rightEarY = -2
            result.leftFrontPawX = -2
            result.rightFrontPawX = 2
            result.leftFrontPawY = -5 - beat
            result.rightFrontPawY = -5 - beat
            result.leftHindPawY = -2
            result.rightHindPawY = -2
            result.tailBaseY = -2
            result.tailMiddleY = -4
            result.tailTipX = 2
            result.tailTipY = -6
            result.eyesClosed = false
            result.mouthOpen = true
        case .startled:
            result.bodyY = -1
            result.headY = -4
            result.headX = alternate ? -1 : 1
            result.leftEarY = -3 - min(1, beat)
            result.rightEarY = -3 + min(1, beat)
            result.leftFrontPawX = -2
            result.rightFrontPawX = 2
            result.leftFrontPawY = -3 - beat
            result.rightFrontPawY = -5 + beat
            result.tailMiddleY = -5
            result.tailTipX = alternate ? -2 : 2
            result.tailTipY = -8 - beat
            result.eyesClosed = false
            result.eyesWide = true
            result.mouthOpen = true
        case .sleepy:
            result.form = .loaf
            result.bodyY = phase >= 12 ? 1 : 0
            result.bodyCompression = phase >= 12 ? 2 : 1
            result.headY = phase >= 12 ? 2 : 1
            result.leftEarY = 2
            result.rightEarY = 2
            result.tailTipX = phase >= 12 ? 1 : -1
            result.leftFrontPawY = alternate ? 0 : 1
            result.rightFrontPawY = alternate ? 1 : 0
            result.eyesClosed = true
        case .kneading:
            result.bodyY = 1
            result.headY = beat == 2 ? 1 : 0
            result.leftFrontPawY = alternate ? -5 : 1
            result.rightFrontPawY = alternate ? 1 : -5
            result.leftFrontPawX = alternate ? 1 : -1
            result.rightFrontPawX = alternate ? 1 : -1
            result.tailTipX = alternate ? 2 : -2
            result.eyesClosed = false
        case .overheating:
            result.bodyY = 1
            result.bodyCompression = 1
            result.leftEarY = 2
            result.rightEarY = 2
            result.leftFrontPawY = alternate ? -3 : 0
            result.rightFrontPawY = alternate ? 0 : -3
            result.tailTipX = alternate ? 3 : -3
            result.eyesClosed = false
            result.mouthOpen = true
        case .purring:
            result.bodyY = beat >= 1 ? 1 : 0
            result.bodyCompression = beat >= 1 ? 1 : 0
            result.headY = result.bodyY
            result.leftFrontPawY = alternate ? -1 : 0
            result.rightFrontPawY = alternate ? 0 : -1
            result.tailTipX = alternate ? 2 : -2
            result.eyesClosed = true
        case .hunting:
            result.form = .crouching
            result.headX = 2 + beat
            result.headY = 1
            result.leftEarY = -1
            result.rightEarY = -1
            result.leftFrontPawX = alternate ? 3 : 0
            result.rightFrontPawX = alternate ? 0 : 3
            result.leftFrontPawY = alternate ? -2 : 0
            result.rightFrontPawY = alternate ? 0 : -2
            result.tailTipY = alternate ? -3 : 2
            result.eyesClosed = false
            result.eyesWide = true
        case .held:
            result.form = .held
            result.bodyY = beat == 2 ? 1 : 0
            result.bodyCompression = alternate ? 0 : 1
            result.headX = alternate ? -1 : 1
            result.headY = -1
            result.leftEarY = alternate ? 0 : 1
            result.rightEarY = alternate ? 1 : 0
            result.leftFrontPawX = -2
            result.rightFrontPawX = 2
            result.leftFrontPawY = 5 + beat
            result.rightFrontPawY = 5 + (2 - beat)
            result.leftHindPawY = 5 + (2 - beat)
            result.rightHindPawY = 5 + beat
            result.tailTipX = alternate ? 3 : -3
            result.eyesClosed = false
        case .grooming:
            result.headX = 2
            result.headY = 1
            result.leftEarY = 1
            result.rightFrontPawX = 3
            result.rightFrontPawY = -12 + beat
            result.leftFrontPawY = 1
            result.tailTipX = alternate ? 1 : -1
            result.eyesClosed = true
        case .rolling:
            result.form = .rolling
            result.headX = alternate ? -2 : 2
            result.leftFrontPawX = -2
            result.rightFrontPawX = 2
            result.leftFrontPawY = -5 - beat
            result.rightFrontPawY = -7 + beat
            result.leftHindPawY = -5 + beat
            result.rightHindPawY = -7 - beat
            result.tailTipX = alternate ? 4 : -4
            result.eyesClosed = false
        case .loaf:
            result.form = .loaf
            result.bodyY = phase >= 12 ? 1 : 0
            result.bodyCompression = phase >= 12 ? 2 : 1
            result.headY = beat >= 1 ? 1 : 0
            result.leftEarY = 1
            result.rightEarY = 1
            result.tailTipX = alternate ? 1 : -1
            result.eyesClosed = true
        }

        guard let play = objectPlay else { return result }
        let p = play.progress
        switch play.object {
        case .none:
            break
        case .ball:
            if play.characterIsRolling {
                result.form = .rolling
                result.leftFrontPawY = -8
                result.rightFrontPawY = -5
                result.leftHindPawY = -5
                result.rightHindPawY = -8
                result.tailTipX = alternate ? 5 : -5
            } else if p < 0.38 {
                result.form = .crouching
                result.headX = 3
                result.leftFrontPawX = 4
                result.leftFrontPawY = -3
                result.eyesWide = true
            }
        case .box:
            result.form = p > 0.22 ? .crouching : .seated
            result.headX = 3
            result.headY = 2 + beat
            result.leftFrontPawX = 4
            result.rightFrontPawX = 3
            result.leftFrontPawY = -4
            result.rightFrontPawY = -2
            result.tailTipY = -3
            result.eyesWide = true
        case .yarn:
            result.form = .crouching
            result.headX = 3
            result.leftFrontPawX = alternate ? 5 : 1
            result.rightFrontPawX = alternate ? 1 : 5
            result.leftFrontPawY = alternate ? -5 : 0
            result.rightFrontPawY = alternate ? 0 : -5
            result.tailTipY = alternate ? -5 : 3
            result.eyesWide = true
        case .cushion:
            result.form = .loaf
            result.bodyCompression = 2
            result.headY = 2
            result.eyesClosed = true
        }
        return result
    }
}

struct CodePixelCatView: View {
    let style: CodePixelCatStyle
    let mood: CompanionMood
    let pose: CompanionPose
    let size: CGFloat
    let elapsed: Double

    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let frame = CodePixelCatFrame.resolve(
            mood: mood,
            gait: pose.gait,
            travelSpeed: pose.travelSpeed,
            elapsed: elapsed,
            reduceMotion: motion.reduceMotion
        )
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            CodePixelCatRenderer.draw(
                style: style,
                mood: mood,
                pose: pose,
                frame: frame,
                in: &context,
                canvasSize: canvasSize,
                displayScale: displayScale
            )
        }
        .frame(width: size, height: size)
    }
}

private enum CodePixelCatRenderer {
    private typealias Fill = (Int, Int, Int, Int, Color) -> Void
    private typealias FineFill = (Int, Int, Int, Int, Color) -> Void

    private struct Palette {
        let rim: Color
        let outline: Color
        let coat: Color
        let shadow: Color
        let marking: Color
        let ear: Color
        let eye: Color
        let nose: Color
        let key: Color
    }

    static func draw(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        pose: CompanionPose,
        frame: CodePixelCatFrame,
        in context: inout GraphicsContext,
        canvasSize: CGSize,
        displayScale: CGFloat
    ) {
        let palette = palette(for: style, heat: pose.heat)
        let articulation = CodeCompanionArticulation.resolve(
            mood: mood,
            gait: pose.gait,
            phase: frame.phase,
            objectPlay: pose.objectPlay
        )

        func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: Color) {
            guard width > 0, height > 0 else { return }
            let pixel = min(canvasSize.width, canvasSize.height) / 32
            let scale = max(1, displayScale)
            let left = (CGFloat(x) * pixel * scale).rounded() / scale
            let top = (CGFloat(y) * pixel * scale).rounded() / scale
            let right = (CGFloat(x + width) * pixel * scale).rounded() / scale
            let bottom = (CGFloat(y + height) * pixel * scale).rounded() / scale
            let rect = CGRect(
                x: left,
                y: top,
                width: max(1 / scale, right - left),
                height: max(1 / scale, bottom - top)
            )
            context.fill(Path(rect), with: .color(color))
        }

        func fine(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: Color) {
            guard width > 0, height > 0 else { return }
            let pixel = min(canvasSize.width, canvasSize.height) / 64
            let scale = max(1, displayScale)
            let left = (CGFloat(x) * pixel * scale).rounded() / scale
            let top = (CGFloat(y) * pixel * scale).rounded() / scale
            let right = (CGFloat(x + width) * pixel * scale).rounded() / scale
            let bottom = (CGFloat(y + height) * pixel * scale).rounded() / scale
            let rect = CGRect(
                x: left,
                y: top,
                width: max(1 / scale, right - left),
                height: max(1 / scale, bottom - top)
            )
            context.fill(Path(rect), with: .color(color))
        }

        var usesFineBase = false
        switch articulation.form {
        case .walking:
            drawWalking(style: style, frame: frame, palette: palette, fill: fill)
        case .held where style.species == .cat:
            usesFineBase = true
            drawArticulatedCatHeld(
                style: style, articulation: articulation, pose: pose,
                palette: palette, fine: fine
            )
        case .held:
            drawHeld(style: style, frame: frame, pose: pose, palette: palette, fill: fill)
        case .crouching where style.species == .cat:
            usesFineBase = true
            drawArticulatedCatCrouching(
                style: style, articulation: articulation, pose: pose,
                palette: palette, fine: fine
            )
        case .crouching:
            drawHunting(style: style, frame: frame, pose: pose, palette: palette, fill: fill)
        case .loaf where style.species == .cat:
            usesFineBase = true
            drawArticulatedCatLoaf(
                style: style,
                articulation: articulation,
                pose: pose,
                palette: palette,
                fine: fine
            )
        case .rolling where style.species == .cat:
            usesFineBase = true
            drawArticulatedCatRolling(
                style: style,
                articulation: articulation,
                pose: pose,
                palette: palette,
                fine: fine
            )
        case .loaf, .rolling:
            drawSleeping(style: style, frame: frame, palette: palette, fill: fill)
        case .seated:
            usesFineBase = true
            drawHighFidelitySeated(
                style: style,
                mood: mood,
                frame: frame,
                articulation: articulation,
                pose: pose,
                palette: palette,
                fine: fine
            )
        }
        if !usesFineBase {
            drawTexture(style: style, mood: mood, frame: frame, pose: pose,
                        palette: palette, fine: fine)
        }
    }

    private static func drawHighFidelitySeated(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        switch style.species {
        case .cat:
            drawMappedCatSeated(
                style: style,
                mood: mood,
                frame: frame,
                articulation: articulation,
                pose: pose,
                palette: palette,
                fine: fine
            )
        case .dog:
            drawHighFidelityDog(
                mood: mood,
                frame: frame,
                pose: pose,
                palette: palette,
                fine: fine
            )
        case .panda:
            drawHighFidelityPanda(
                mood: mood,
                frame: frame,
                pose: pose,
                palette: palette,
                fine: fine
            )
        }
    }

    private static func drawMappedCatSeated(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.86, blue: 0.61)
            : Color(red: 0.91, green: 0.89, blue: 0.82)
        let stripe = style == .orange
            ? Color(red: 0.30, green: 0.22, blue: 0.22)
            : Color(red: 0.07, green: 0.08, blue: 0.10)
        let highlight = style == .orange
            ? Color(red: 0.94, green: 0.58, blue: 0.24)
            : Color(red: 0.39, green: 0.42, blue: 0.47)
        let mid = style == .orange
            ? Color(red: 0.66, green: 0.48, blue: 0.43)
            : Color(red: 0.46, green: 0.48, blue: 0.50)
        let pink = Color(red: 0.92, green: 0.48, blue: 0.52)
        let colors: [Character: Color] = [
            "K": outline, "O": coat, "D": stripe, "H": highlight,
            "C": cream, "P": pink, "E": Color.black, "W": Color.white,
        ]
        let hx = articulation.headX
        let hy = articulation.headY
        let by = articulation.bodyY + articulation.bodyCompression

        fine(8, 59, 49, 2, Color.black.opacity(0.22))

        // Tail stays behind the torso and moves through three independent joints.
        fine(47, 42 + by + articulation.tailBaseY, 9, 16, outline)
        fine(52 + articulation.tailMiddleX, 34 + by + articulation.tailMiddleY, 8, 13, outline)
        fine(54 + articulation.tailTipX, 28 + by + articulation.tailTipY, 7, 10, outline)
        fine(49, 43 + by + articulation.tailBaseY, 5, 13, coat)
        fine(54 + articulation.tailMiddleX, 36 + by + articulation.tailMiddleY, 4, 9, coat)
        fine(56 + articulation.tailTipX, 30 + by + articulation.tailTipY, 3, 6, cream)
        fine(49, 48 + by + articulation.tailBaseY, 6, 3, stripe)
        fine(54 + articulation.tailMiddleX, 39 + by + articulation.tailMiddleY, 5, 3, stripe)

        // The torso is a code-defined pixel map, not an image. It stops before the
        // tail and paws so those parts can animate independently.
        let torsoRows = detailedCatSprite[18...27].map { String($0.prefix(25)) }
        drawSprite(
            torsoRows,
            originX: 0,
            originY: 36 + by,
            scale: 2,
            colors: colors,
            fine: fine
        )
        fine(22, 38 + by, 20, 4, mid)
        fine(25, 42 + by, 14, 4, cream)
        fine(27, 46 + by, 10, 10, cream)

        // Front legs and toes move separately for typing, grooming and celebrations.
        let lx = articulation.leftFrontPawX
        let ly = articulation.leftFrontPawY
        let rx = articulation.rightFrontPawX
        let ry = articulation.rightFrontPawY
        fine(17 + lx, 43 + by + ly, 12, 13, outline)
        fine(35 + rx, 43 + by + ry, 12, 13, outline)
        fine(19 + lx, 44 + by + ly, 8, 10, coat)
        fine(37 + rx, 44 + by + ry, 8, 10, coat)
        fine(16 + lx, 54 + by + ly, 14, 6, outline)
        fine(34 + rx, 54 + by + ry, 14, 6, outline)
        fine(18 + lx, 54 + by + ly, 10, 4, cream)
        fine(36 + rx, 54 + by + ry, 10, 4, cream)
        for x in [21, 25] { fine(x + lx, 56 + by + ly, 1, 3, outline) }
        for x in [39, 43] { fine(x + rx, 56 + by + ry, 1, 3, outline) }

        // Ears are separate from the face map so each one can twitch.
        let ley = articulation.leftEarY
        let rey = articulation.rightEarY
        fine(16 + hx, 3 + hy + ley, 6, 3, outline)
        fine(13 + hx, 6 + hy + ley, 11, 5, outline)
        fine(11 + hx, 11 + hy + ley, 14, 11, outline)
        fine(42 + hx, 3 + hy + rey, 6, 3, outline)
        fine(40 + hx, 6 + hy + rey, 11, 5, outline)
        fine(39 + hx, 11 + hy + rey, 14, 11, outline)
        fine(16 + hx, 7 + hy + ley, 5, 10, coat)
        fine(43 + hx, 7 + hy + rey, 5, 10, coat)
        fine(17 + hx, 9 + hy + ley, 3, 8, pink)
        fine(44 + hx, 9 + hy + rey, 3, 8, pink)

        // Dense face rows are drawn independently from both body and ears.
        fine(19 + hx, 10 + hy, 26, 6, outline)
        fine(21 + hx, 12 + hy, 22, 5, stripe)
        fine(25 + hx, 12 + hy, 3, 4, highlight)
        fine(31 + hx, 12 + hy, 3, 5, highlight)
        fine(37 + hx, 12 + hy, 3, 4, highlight)
        let faceRows = Array(detailedCatSprite[6...17])
        drawSprite(
            faceRows,
            originX: hx,
            originY: 12 + hy,
            scale: 2,
            colors: colors,
            fine: fine
        )

        if articulation.eyesClosed {
            fine(18 + hx, 23 + hy, 11, 3, cream)
            fine(35 + hx, 23 + hy, 11, 3, cream)
            fine(19 + hx, 24 + hy, 9, 2, outline)
            fine(36 + hx, 24 + hy, 9, 2, outline)
        }
        if articulation.eyesWide {
            fine(19 + hx, 19 + hy, 9, 1, Color.white)
            fine(36 + hx, 19 + hy, 9, 1, Color.white)
        }
        if articulation.mouthOpen {
            fine(28 + hx, 31 + hy, 9, 6, outline)
            fine(31 + hx, 34 + hy, 4, 2, pink)
        }

        if mood == .thinking {
            fine(54, 9, 2, 2, outline)
            fine(58, 6, 2, 2, outline)
        } else if frame.steam {
            fine(52, 5, 4, 3, Color.white.opacity(0.82))
            fine(57, 2, 3, 5, Color.white.opacity(0.72))
        }
    }

    private static func drawReferenceCatSeated(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.87, blue: 0.64)
            : Color(red: 0.91, green: 0.90, blue: 0.85)
        let stripe = style == .orange
            ? Color(red: 0.31, green: 0.16, blue: 0.13)
            : Color(red: 0.07, green: 0.08, blue: 0.10)
        let highlight = style == .orange
            ? Color(red: 0.96, green: 0.56, blue: 0.19)
            : Color(red: 0.34, green: 0.37, blue: 0.41)
        let mid = style == .orange
            ? Color(red: 0.66, green: 0.48, blue: 0.43)
            : Color(red: 0.46, green: 0.48, blue: 0.50)
        let pink = Color(red: 0.92, green: 0.48, blue: 0.52)
        let hx = articulation.headX
        let hy = articulation.headY
        let by = articulation.bodyY + articulation.bodyCompression

        fine(8, 59, 49, 2, Color.black.opacity(0.22))

        // Curled tail, three separately animated joints.
        fine(46, 39 + by + articulation.tailBaseY, 8, 18, outline)
        fine(50 + articulation.tailMiddleX, 31 + by + articulation.tailMiddleY,
             8, 13, outline)
        fine(54 + articulation.tailTipX, 26 + by + articulation.tailTipY,
             7, 10, outline)
        fine(48, 40 + by + articulation.tailBaseY, 4, 15, coat)
        fine(52 + articulation.tailMiddleX, 33 + by + articulation.tailMiddleY,
             4, 9, coat)
        fine(56 + articulation.tailTipX, 28 + by + articulation.tailTipY,
             3, 6, cream)
        fine(48, 46 + by + articulation.tailBaseY, 5, 3, stripe)
        fine(52 + articulation.tailMiddleX, 36 + by + articulation.tailMiddleY,
             5, 3, stripe)

        // Rounded shoulders, broad haunches and a tapered belly match the supplied
        // seated-tabby silhouette without storing a sprite.
        fine(23, 29 + by, 18, 3, outline)
        fine(18, 32 + by, 28, 4, outline)
        fine(14, 36 + by, 36, 6, outline)
        fine(10, 42 + by, 44, 8, outline)
        fine(8, 48 + by, 48, 8, outline)
        fine(12, 56 + by, 40, 4, outline)
        fine(24, 31 + by, 16, 3, highlight)
        fine(20, 34 + by, 24, 4, coat)
        fine(16, 38 + by, 32, 6, coat)
        fine(12, 44 + by, 40, 7, coat)
        fine(10, 50 + by, 44, 5, coat)
        fine(14, 55 + by, 36, 3, coat)

        // The muted neck ruff separates head and torso, as in the supplied tabby.
        fine(20, 34 + by, 24, 3, mid)
        fine(17, 37 + by, 30, 4, mid)
        fine(21, 40 + by, 22, 3, mid)

        // Layered bib and belly: stepped edges keep the fur soft rather than box-shaped.
        fine(29, 33 + by, 6, 4, cream)
        fine(26, 37 + by, 12, 5, cream)
        fine(23, 42 + by, 18, 7, cream)
        fine(21, 49 + by, 22, 5, cream)
        fine(25, 54 + by, 14, 4, cream)

        // Shoulder and haunch striping.
        fine(14, 40 + by, 9, 2, stripe)
        fine(41, 40 + by, 9, 2, stripe)
        fine(11, 45 + by, 10, 3, stripe)
        fine(43, 45 + by, 10, 3, stripe)
        fine(10, 51 + by, 9, 3, stripe)
        fine(45, 51 + by, 9, 3, stripe)

        // Independently moving front legs and detailed cream paws.
        let lx = articulation.leftFrontPawX
        let ly = articulation.leftFrontPawY
        let rx = articulation.rightFrontPawX
        let ry = articulation.rightFrontPawY
        fine(16 + lx, 43 + by + ly, 12, 13, outline)
        fine(36 + rx, 43 + by + ry, 12, 13, outline)
        fine(18 + lx, 44 + by + ly, 8, 10, coat)
        fine(38 + rx, 44 + by + ry, 8, 10, coat)
        fine(15 + lx, 54 + by + ly, 14, 6, outline)
        fine(35 + rx, 54 + by + ry, 14, 6, outline)
        fine(17 + lx, 54 + by + ly, 10, 4, cream)
        fine(37 + rx, 54 + by + ry, 10, 4, cream)
        for x in [20, 24] { fine(x + lx, 56 + by + ly, 1, 3, outline) }
        for x in [40, 44] { fine(x + rx, 56 + by + ry, 1, 3, outline) }

        // Pointed stepped ears with sloped outer and inner edges.
        let ley = articulation.leftEarY
        let rey = articulation.rightEarY
        fine(16 + hx, 4 + hy + ley, 5, 3, outline)
        fine(14 + hx, 7 + hy + ley, 9, 4, outline)
        fine(12 + hx, 11 + hy + ley, 13, 6, outline)
        fine(11 + hx, 17 + hy + ley, 11, 7, outline)
        fine(43 + hx, 4 + hy + rey, 5, 3, outline)
        fine(41 + hx, 7 + hy + rey, 9, 4, outline)
        fine(39 + hx, 11 + hy + rey, 13, 6, outline)
        fine(42 + hx, 17 + hy + rey, 11, 7, outline)
        fine(17 + hx, 7 + hy + ley, 3, 3, coat)
        fine(15 + hx, 10 + hy + ley, 7, 5, coat)
        fine(14 + hx, 15 + hy + ley, 7, 6, coat)
        fine(44 + hx, 7 + hy + rey, 3, 3, coat)
        fine(42 + hx, 10 + hy + rey, 7, 5, coat)
        fine(43 + hx, 15 + hy + rey, 7, 6, coat)
        fine(17 + hx, 9 + hy + ley, 3, 7, pink)
        fine(44 + hx, 9 + hy + rey, 3, 7, pink)

        // Broad crown, rounded cheeks and a narrower jaw.
        fine(20 + hx, 10 + hy, 24, 3, outline)
        fine(16 + hx, 13 + hy, 32, 4, outline)
        fine(13 + hx, 17 + hy, 38, 6, outline)
        fine(10 + hx, 23 + hy, 44, 7, outline)
        fine(13 + hx, 30 + hy, 38, 5, outline)
        fine(18 + hx, 35 + hy, 28, 3, outline)
        fine(21 + hx, 12 + hy, 22, 3, coat)
        fine(18 + hx, 15 + hy, 28, 4, coat)
        fine(15 + hx, 19 + hy, 34, 6, coat)
        fine(12 + hx, 25 + hy, 40, 4, coat)
        fine(15 + hx, 29 + hy, 34, 5, coat)
        fine(20 + hx, 34 + hy, 24, 2, cream)

        // Broad dark tabby cap with three orange breaks, rather than isolated bars.
        fine(22 + hx, 12 + hy, 20, 6, stripe)
        fine(25 + hx, 12 + hy, 3, 4, highlight)
        fine(31 + hx, 12 + hy, 3, 5, highlight)
        fine(37 + hx, 12 + hy, 3, 4, highlight)
        fine(26 + hx, 18 + hy, 4, 3, stripe)
        fine(34 + hx, 18 + hy, 4, 3, stripe)
        fine(12 + hx, 22 + hy, 9, 2, stripe)
        fine(11 + hx, 26 + hy, 10, 2, stripe)
        fine(43 + hx, 22 + hy, 9, 2, stripe)
        fine(43 + hx, 26 + hy, 10, 2, stripe)

        // Large rounded eyes, not rectangular sockets.
        if articulation.eyesClosed {
            fine(19 + hx, 24 + hy, 10, 2, outline)
            fine(35 + hx, 24 + hy, 10, 2, outline)
        } else {
            let eyeBottom = articulation.eyesWide ? 30 : 29
            for baseX in [19, 35] {
                fine(baseX + 2 + hx, 19 + hy, 6, 2, outline)
                fine(baseX + hx, 21 + hy, 10, eyeBottom - 21, outline)
                fine(baseX + 2 + hx, eyeBottom + hy, 6, 2, outline)
                fine(baseX + 2 + hx, 21 + hy, 6, eyeBottom - 21, mid)
                fine(baseX + 3 + hx, 22 + hy, 4, eyeBottom - 23, Color.black)
            }
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gy = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fine(22 + hx + gx, 21 + hy + gy, 3, 3, Color.white)
            fine(38 + hx + gx, 21 + hy + gy, 3, 3, Color.white)
            fine(26 + hx, 26 + hy, 1, 1, Color.white.opacity(0.72))
            fine(42 + hx, 26 + hy, 1, 1, Color.white.opacity(0.72))
        }

        // Cream cheeks, tiny nose, mouth and whiskers.
        fine(23 + hx, 27 + hy, 18, 3, cream)
        fine(19 + hx, 30 + hy, 26, 4, cream)
        fine(22 + hx, 34 + hy, 20, 3, cream)
        fine(30 + hx, 29 + hy, 5, 3, pink)
        fine(32 + hx, 32 + hy, 1, 3, outline)
        if articulation.mouthOpen {
            fine(28 + hx, 34 + hy, 10, 5, outline)
            fine(31 + hx, 36 + hy, 4, 2, pink)
        } else {
            fine(27 + hx, 34 + hy, 5, 2, outline)
            fine(33 + hx, 34 + hy, 5, 2, outline)
        }
        fine(4 + hx, 25 + hy, 9, 1, outline)
        fine(5 + hx, 29 + hy, 8, 1, outline)
        fine(7 + hx, 33 + hy, 8, 1, outline)
        fine(51 + hx, 25 + hy, 9, 1, outline)
        fine(51 + hx, 29 + hy, 8, 1, outline)
        fine(49 + hx, 33 + hy, 8, 1, outline)

        if mood == .thinking {
            fine(54, 9, 2, 2, outline)
            fine(58, 6, 2, 2, outline)
        } else if frame.steam {
            fine(52, 5, 4, 3, Color.white.opacity(0.82))
            fine(57, 2, 3, 5, Color.white.opacity(0.72))
        }
    }

    private static func drawDetailedSprite(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let rows: [String]
        let colors: [Character: Color]

        switch style.species {
        case .cat:
            rows = detailedCatSprite
            colors = [
                "K": palette.outline,
                "O": palette.coat,
                "D": style == .orange
                    ? Color(red: 0.38, green: 0.17, blue: 0.10)
                    : Color(red: 0.08, green: 0.09, blue: 0.11),
                "H": style == .orange
                    ? Color(red: 1.00, green: 0.64, blue: 0.24)
                    : Color(red: 0.40, green: 0.43, blue: 0.48),
                "C": style == .orange
                    ? Color(red: 0.99, green: 0.86, blue: 0.61)
                    : Color(red: 0.91, green: 0.89, blue: 0.82),
                "P": Color(red: 0.91, green: 0.48, blue: 0.51),
                "E": Color(red: 0.10, green: 0.07, blue: 0.06),
                "W": .white,
            ]
        case .dog:
            rows = detailedDogSprite
            colors = [
                "K": palette.outline,
                "O": palette.coat,
                "D": Color(red: 0.28, green: 0.14, blue: 0.06),
                "H": Color(red: 0.96, green: 0.58, blue: 0.18),
                "C": Color(red: 0.99, green: 0.84, blue: 0.53),
                "R": Color(red: 0.76, green: 0.08, blue: 0.11),
                "P": Color(red: 0.91, green: 0.43, blue: 0.44),
                "E": Color(red: 0.10, green: 0.07, blue: 0.04),
                "W": .white,
            ]
        case .panda:
            rows = detailedPandaSprite
            colors = [
                "K": palette.outline,
                "C": Color(red: 0.96, green: 0.95, blue: 0.90),
                "S": Color(red: 0.69, green: 0.70, blue: 0.69),
                "P": Color(red: 0.90, green: 0.47, blue: 0.50),
                "E": Color(red: 0.05, green: 0.06, blue: 0.07),
                "W": .white,
            ]
        }

        fine(7, 60, 50, 2, Color.black.opacity(0.22))
        drawSprite(
            rows,
            originX: 0,
            originY: max(0, frame.bodyY),
            scale: 2,
            colors: colors,
            fine: fine
        )

        if frame.eyesClosed {
            let y = style.species == .panda ? 19 : 18
            fine(18, y, 10, 2, palette.outline)
            fine(38, y, 10, 2, palette.outline)
        }
        if mood == .thinking {
            fine(55, 5, 2, 2, palette.outline)
            fine(59, 2, 2, 2, palette.outline)
        } else if frame.steam {
            fine(53, 4, 4, 3, Color.white.opacity(0.82))
            fine(58, 1, 3, 5, Color.white.opacity(0.72))
        }
    }

    private static func drawSprite(
        _ rows: [String],
        originX: Int,
        originY: Int,
        scale: Int,
        colors: [Character: Color],
        fine: FineFill
    ) {
        let pixels = rows.map(Array.init)
        func isSolid(_ row: Int, _ column: Int) -> Bool {
            guard pixels.indices.contains(row), pixels[row].indices.contains(column) else {
                return false
            }
            return colors[pixels[row][column]] != nil
        }

        for (rowIndex, row) in rows.enumerated() {
            for (column, key) in row.enumerated() {
                guard let color = colors[key] else {
                    continue
                }

                let x = originX + column * scale
                let y = originY + rowIndex * scale
                guard scale == 2 else {
                    fine(x, y, scale, scale, color)
                    continue
                }

                let top = isSolid(rowIndex - 1, column)
                let bottom = isSolid(rowIndex + 1, column)
                let left = isSolid(rowIndex, column - 1)
                let right = isSolid(rowIndex, column + 1)
                let quadrants = [
                    (0, 0, top || left),
                    (1, 0, top || right),
                    (0, 1, bottom || left),
                    (1, 1, bottom || right),
                ]
                for (dx, dy, visible) in quadrants where visible {
                    fine(x + dx, y + dy, 1, 1, color)
                }
            }
        }
    }

    private static let detailedCatSprite = [
        "                                ",
        "       KK            KK       ",
        "      KOHK          KHOK      ",
        "     KOOOKKKKKKKKKKKOOOOK     ",
        "    KOPOOOOOOOOOOOOOOPOK     ",
        "    KOOOOODDDDDDOOOOOOOK     ",
        "   KOOOODDOOOODDOOOOOOOOK    ",
        "   KOOOOOOOOOOOOOOOOOOOOK    ",
        "  KOOOOOEEEOOOOEEEOOOOOOK    ",
        "  KOOOOEWWEEOOEWWEEOOOOOK    ",
        "  KOOOOOEEEOOOOEEEOOOOOOK    ",
        "  KOOODDOOCCCCCOODDOOOOOK    ",
        " KOOODDDCCCCCCCCCDDDDOOOOK   ",
        " KOOOOODCCCPPPCCCDOOOOOOOK   ",
        " KOOOOOCCCCKCKCCCCOOOOOOOK   ",
        "  KOOOOCCCCKKKCCCCOOOOOOK    ",
        "   KOOOCCCCCCCCCCCOOOOOK     ",
        "    KKOOOOOOOOOOOOOOOKK      ",
        "     KDDOOOOOOOOOODDK   KKK  ",
        "    KDOOOOCCCCCCOOOODK KCCK ",
        "   KDOOOOCCCCCCCCOOOODKKCOK ",
        "  KDOOOOCCCCCCCCCCOOOODKODK ",
        " KDOOOOCCCCCCCCCCCCOOOODKODK",
        " KDOOOOCCCOOCCOOCCCOOOODKODK",
        " KDOOOOCCCOOCCOOCCCOOOODKODK",
        " KDOOOOCCCOOCCOOCCCOOOODKODK",
        " KDOOOOCCCOOCCOOCCCOOOODKODK",
        "  KDDOOCCCOOCCOOCCCOODDKODK ",
        "  KOOOCCCCOOCCOOCCCCOOOKCCK ",
        "   KCCCCKKKCCCCKKKCCCCKKKK  ",
        "    KCCK  KCCK  KCCK        ",
        "     KK    KK    KK          ",
    ]

    private static let detailedDogSprite = [
        "                                ",
        "      KKK              KKK     ",
        "    KKDDDKKKKKKKKKKKKKDDDKK   ",
        "   KDDDDOOOOOOOOOOOODDDDDDK   ",
        "  KDDDOOOOOOHHHOOOOOODDDDDDK  ",
        "  KDDOOOOOOHHCHHOOOOOODDDDDK  ",
        "  KDDOOOOOOOOOOOOOOOOOODDDDK  ",
        "  KDDOOOOEEEOOOEEEOOOOODDDDK  ",
        "  KDDOOOEWWEOOEWWEOOOOODDDK  ",
        "  KDDOOOOEEEOOOEEEOOOOODDDK  ",
        "   KOOOOOCCCCCCCCCOOOOOOOOK   ",
        "   KOOOOCCCDDDDCCCOOOOOOOOK   ",
        "    KOOOCCCDDDCCCCOOOOOOOK    ",
        "     KOOCCCCPCCCCOOOOOOOK     ",
        "      KOOOCCCCCCOOOOOOK       ",
        "       KKKOORRRROOKKK         ",
        "       KOOOORRRROOOOK         ",
        "      KOOOOCCCCOOOOOOK        ",
        "     KOOOOCCCCCCOOOOOOK  KKK  ",
        "    KOOOOCCCCCCCCOOOOOOK KHHK ",
        "   KOOOOOCCCCCCCCOOOOOOKKHOHK ",
        "  KOOOOOOCCCCCCCCOOOOOOOKHOK ",
        "  KOOOOOOCCCCCCCCOOOOOOOKHOK ",
        "  KOOOOOCCCCCCCCCCOOOOOOKHOK ",
        "  KOOOOOCCCOOCCCOOOOOOOKHHK  ",
        "  KOOOOOCCCOOCCCOOOOOOOKKK   ",
        "  KOOOOOCCCOOCCCOOOOOOOK     ",
        "   KOOOOCCCOOCCCOOOOOOK      ",
        "    KOOCCCCOOCCCCOOOOK       ",
        "     KCCCKKCCKKCCCKK         ",
        "      KCK  KK  KCK           ",
        "       K        K             ",
    ]

    private static let detailedPandaSprite = [
        "                                ",
        "      KKKK          KKKK      ",
        "    KKKKKKKK      KKKKKKKK    ",
        "   KKKKCCCCKKKKKKKKCCCCKKKK   ",
        "  KKKCCCCCCCCCCCCCCCCCCCCKKK  ",
        "  KKCCCCCCCCCCCCCCCCCCCCCCKK  ",
        " KKKCCCKKKKKCCCCKKKKKCCCCKKK ",
        " KKKCCKKEEEKKCCKKEEEKKCCCKKK ",
        " KKKCCKEWWEEKKKKEWWEEKCCCKKK ",
        " KKKCCKEEEEKKCCKKEEEEKCCCKKK ",
        " KKKCCCCKKKCCCCCCKKKCCCCCKKK ",
        "  KKCCCCCCCCCCCCCCCCCCCCCCKK  ",
        "  KKKCCCCCCCKKKKCCCCCCCCKKK  ",
        "   KKCCCCCCKPPPPKCCCCCCCKK   ",
        "    KCCCCCCCKKKKCCCCCCCCK    ",
        "     KKCCCCCCCCCCCCCCCKK     ",
        "       KKKKKKKKKKKKKK       ",
        "       KKKCCCCCCCCKKK       ",
        "      KKKCCCCCCCCCCKKK      ",
        "     KKKCCCCCCCCCCCCKKK     ",
        "    KKKKCCCCCCCCCCCCKKKK    ",
        "   KKKKKCCCCCCCCCCCCKKKKK   ",
        "  KKKKKKCCCCCCCCCCCCKKKKKK  ",
        "  KKKKKCCCCCCCCCCCCCCKKKKK  ",
        "  KKKKKCCCCCCCCCCCCCCKKKKK  ",
        "  KKKKKCCCCCCCCCCCCCCKKKKK  ",
        "   KKKKCCCCCCCCCCCCCCKKKK   ",
        "    KKKCCCCCCCCCCCCCCKKK    ",
        "     KKCCCCKKKKCCCCCCKK     ",
        "      KCCCKK  KKCCCCK       ",
        "      KSSK      KSSK        ",
        "       KK        KK         ",
    ]

    private static func drawHighFidelityCat(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let by = articulation.bodyY + articulation.bodyCompression
        let hy = articulation.headY
        let hx = articulation.headX
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.86, blue: 0.61)
            : Color(red: 0.91, green: 0.89, blue: 0.82)
        let stripe = style == .orange
            ? Color(red: 0.38, green: 0.17, blue: 0.10)
            : Color(red: 0.08, green: 0.09, blue: 0.11)
        let highlight = style == .orange
            ? Color(red: 1.00, green: 0.63, blue: 0.24)
            : Color(red: 0.39, green: 0.42, blue: 0.47)
        let pink = Color(red: 0.91, green: 0.48, blue: 0.51)
        let eyeBrown = Color(red: 0.30, green: 0.18, blue: 0.12)

        fine(9, 59, 47, 2, Color.black.opacity(0.22))

        // A curled, tapered tail behind the body.
        fine(45, 37 + by + articulation.tailBaseY, 9, 20, outline)
        fine(49 + articulation.tailMiddleX,
             30 + by + articulation.tailMiddleY, 9, 13, outline)
        fine(54 + articulation.tailTipX,
             25 + by + articulation.tailTipY, 7, 11, outline)
        fine(47, 38 + by + articulation.tailBaseY, 5, 17, coat)
        fine(51 + articulation.tailMiddleX,
             32 + by + articulation.tailMiddleY, 5, 10, coat)
        fine(56 + articulation.tailTipX,
             27 + by + articulation.tailTipY, 3, 8, cream)
        fine(48, 44 + by + articulation.tailBaseY, 5, 3, stripe)
        fine(51 + articulation.tailMiddleX,
             35 + by + articulation.tailMiddleY, 6, 3, stripe)

        // Rounded haunches and a tapered chest avoid the old rectangular silhouette.
        fine(20, 29 + by, 24, 3, outline)
        fine(16, 32 + by, 32, 6, outline)
        fine(13, 38 + by, 38, 16, outline)
        fine(16, 54 + by, 32, 6, outline)
        fine(18, 32 + by, 28, 5, coat)
        fine(15, 38 + by, 34, 15, coat)
        fine(18, 53 + by, 28, 5, coat)
        fine(25, 31 + by, 14, 25, cream)
        fine(28, 31 + by, 8, 7, highlight)
        fine(15, 41 + by, 8, 3, stripe)
        fine(41, 41 + by, 8, 3, stripe)
        fine(14, 48 + by, 9, 3, stripe)
        fine(41, 48 + by, 9, 3, stripe)

        // Long front legs, separated paws, and tiny toes.
        let leftPawX = articulation.leftFrontPawX
        let leftPawY = articulation.leftFrontPawY
        let rightPawX = articulation.rightFrontPawX
        let rightPawY = articulation.rightFrontPawY
        fine(19 + leftPawX, 42 + by + leftPawY, 10, 17, outline)
        fine(35 + rightPawX, 42 + by + rightPawY, 10, 17, outline)
        fine(21 + leftPawX, 42 + by + leftPawY, 6, 14, coat)
        fine(37 + rightPawX, 42 + by + rightPawY, 6, 14, coat)
        fine(20 + leftPawX, 54 + by + leftPawY, 9, 5, cream)
        fine(35 + rightPawX, 54 + by + rightPawY, 9, 5, cream)
        for x in [22, 26] {
            fine(x + leftPawX, 56 + by + leftPawY, 1, 3, outline)
        }
        for x in [37, 41] {
            fine(x + rightPawX, 56 + by + rightPawY, 1, 3, outline)
        }

        // Stepped ears and a broad rounded head, drawn as narrow bands for a
        // noticeably denser pixel silhouette.
        let leftEarY = articulation.leftEarY
        let rightEarY = articulation.rightEarY
        fine(17 + hx, 5 + hy + leftEarY, 9, 4, outline)
        fine(14 + hx, 8 + hy + leftEarY, 14, 9, outline)
        fine(12 + hx, 12 + hy + leftEarY, 8, 14, outline)
        fine(38 + hx, 8 + hy + rightEarY, 14, 9, outline)
        fine(40 + hx, 5 + hy + rightEarY, 9, 4, outline)
        fine(46 + hx, 12 + hy + rightEarY, 8, 14, outline)
        fine(18 + hx, 7 + hy + leftEarY, 6, 8, coat)
        fine(15 + hx, 10 + hy + leftEarY, 9, 12, coat)
        fine(42 + hx, 7 + hy + rightEarY, 5, 8, coat)
        fine(42 + hx, 10 + hy + rightEarY, 9, 12, coat)
        fine(18 + hx, 9 + hy + leftEarY, 3, 8, pink)
        fine(44 + hx, 9 + hy + rightEarY, 3, 8, pink)
        fine(18 + hx, 11 + hy, 28, 3, outline)
        fine(15 + hx, 14 + hy, 34, 5, outline)
        fine(13 + hx, 19 + hy, 38, 10, outline)
        fine(16 + hx, 29 + hy, 32, 7, outline)
        fine(20 + hx, 12 + hy, 24, 3, coat)
        fine(17 + hx, 15 + hy, 30, 5, coat)
        fine(15 + hx, 20 + hy, 34, 9, coat)
        fine(18 + hx, 29 + hy, 28, 5, cream)

        // Tabby crown and cheek bands.
        fine(27 + hx, 12 + hy, 3, 7, stripe)
        fine(31 + hx, 11 + hy, 3, 9, stripe)
        fine(35 + hx, 12 + hy, 3, 7, stripe)
        fine(15 + hx, 22 + hy, 6, 2, stripe)
        fine(16 + hx, 26 + hy, 6, 2, stripe)
        fine(44 + hx, 22 + hy, 6, 2, stripe)
        fine(43 + hx, 26 + hy, 6, 2, stripe)

        if articulation.eyesClosed {
            fine(20 + hx, 22 + hy, 9, 2, outline)
            fine(36 + hx, 22 + hy, 9, 2, outline)
        } else {
            let eyeHeight = articulation.eyesWide ? 11 : 9
            fine(19 + hx, 17 + hy, 11, eyeHeight, outline)
            fine(35 + hx, 17 + hy, 11, eyeHeight, outline)
            fine(21 + hx, 18 + hy, 8, eyeHeight - 2, eyeBrown)
            fine(37 + hx, 18 + hy, 8, eyeHeight - 2, eyeBrown)
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gy = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fine(21 + hx + gx, 18 + hy + gy, 3, 3, Color.white)
            fine(37 + hx + gx, 18 + hy + gy, 3, 3, Color.white)
            fine(27 + hx, 23 + hy, 1, 2, Color.white.opacity(0.78))
            fine(43 + hx, 23 + hy, 1, 2, Color.white.opacity(0.78))
        }

        // Layered muzzle and whiskers.
        fine(23 + hx, 25 + hy, 19, 8, cream)
        fine(27 + hx, 23 + hy, 11, 9, cream)
        fine(30 + hx, 25 + hy, 5, 3, pink)
        fine(32 + hx, 28 + hy, 1, 3, outline)
        if articulation.mouthOpen {
            fine(28 + hx, 30 + hy, 10, 5, outline)
            fine(31 + hx, 32 + hy, 4, 2, pink)
        } else {
            fine(27 + hx, 30 + hy, 5, 2, outline)
            fine(33 + hx, 30 + hy, 5, 2, outline)
        }
        fine(7 + hx, 24 + hy, 11, 1, outline)
        fine(8 + hx, 28 + hy, 10, 1, outline)
        fine(47 + hx, 24 + hy, 11, 1, outline)
        fine(47 + hx, 28 + hy, 10, 1, outline)

        if mood == .thinking {
            fine(51, 10, 2, 2, outline)
            fine(55, 7, 2, 2, outline)
            fine(59, 10, 2, 2, outline)
        } else if frame.steam {
            fine(49, 4, 4, 3, Color.white.opacity(0.82))
            fine(54, 1, 3, 5, Color.white.opacity(0.72))
        }
    }

    private static func drawArticulatedCatLoaf(
        style: CodePixelCatStyle,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.86, blue: 0.61)
            : Color(red: 0.91, green: 0.89, blue: 0.82)
        let stripe = style == .orange
            ? Color(red: 0.38, green: 0.17, blue: 0.10)
            : Color(red: 0.08, green: 0.09, blue: 0.11)
        let hx = articulation.headX
        let hy = articulation.headY

        fine(3, 57, 58, 3, Color.black.opacity(0.22))

        // Long arched back and deep tucked belly, matching the supplied loaf reference.
        fine(9, 22, 28, 3, outline)
        fine(6, 25, 35, 5, outline)
        fine(3, 30, 42, 8, outline)
        fine(2, 38, 46, 11, outline)
        fine(5, 49, 45, 7, outline)
        fine(10, 56, 35, 2, outline)
        fine(10, 24, 27, 3, coat)
        fine(8, 27, 31, 5, coat)
        fine(5, 32, 38, 8, coat)
        fine(4, 40, 42, 8, coat)
        fine(7, 48, 40, 6, coat)
        fine(12, 54, 31, 2, coat)

        // Dense back pattern and warm highlights make the flank read as fur, not a block.
        fine(10, 26, 8, 8, cream)
        fine(12, 24, 5, 5, cream)
        fine(22, 24, 7, 12, cream)
        fine(31, 28, 7, 12, stripe)
        fine(6, 35, 8, 3, stripe)
        fine(5, 41, 10, 3, stripe)
        fine(7, 47, 9, 3, stripe)
        fine(18, 30, 4, 15, palette.shadow)
        fine(27, 27, 4, 18, palette.shadow)

        // The tail wraps along the foreground in three independently moving sections.
        fine(4, 47 + articulation.tailBaseY, 22, 10, outline)
        fine(18 + articulation.tailMiddleX, 49 + articulation.tailMiddleY, 18, 9, outline)
        fine(31 + articulation.tailTipX, 48 + articulation.tailTipY, 12, 9, outline)
        fine(6, 49 + articulation.tailBaseY, 18, 6, coat)
        fine(20 + articulation.tailMiddleX, 51 + articulation.tailMiddleY, 14, 5, cream)
        fine(33 + articulation.tailTipX, 50 + articulation.tailTipY, 8, 5, coat)
        fine(12, 49 + articulation.tailBaseY, 5, 6, cream)
        fine(25 + articulation.tailMiddleX, 51 + articulation.tailMiddleY, 4, 5, stripe)

        // Oversized rounded head and expressive face, kept independent from the body.
        fine(35 + hx, 8 + hy + articulation.leftEarY, 5, 3, outline)
        fine(32 + hx, 11 + hy + articulation.leftEarY, 10, 5, outline)
        fine(30 + hx, 16 + hy + articulation.leftEarY, 12, 8, outline)
        fine(53 + hx, 7 + hy + articulation.rightEarY, 5, 3, outline)
        fine(50 + hx, 10 + hy + articulation.rightEarY, 10, 5, outline)
        fine(50 + hx, 15 + hy + articulation.rightEarY, 12, 9, outline)
        fine(36 + hx, 11 + hy + articulation.leftEarY, 3, 3, coat)
        fine(34 + hx, 14 + hy + articulation.leftEarY, 6, 6, coat)
        fine(54 + hx, 10 + hy + articulation.rightEarY, 3, 3, coat)
        fine(52 + hx, 13 + hy + articulation.rightEarY, 6, 7, coat)
        fine(35 + hx, 14 + hy + articulation.leftEarY, 3, 5, Color(red: 0.92, green: 0.48, blue: 0.52))
        fine(54 + hx, 13 + hy + articulation.rightEarY, 3, 6, Color(red: 0.92, green: 0.48, blue: 0.52))

        fine(36 + hx, 13 + hy, 20, 3, outline)
        fine(32 + hx, 16 + hy, 28, 5, outline)
        fine(29 + hx, 21 + hy, 34, 10, outline)
        fine(30 + hx, 31 + hy, 32, 8, outline)
        fine(34 + hx, 39 + hy, 24, 5, outline)
        fine(37 + hx, 15 + hy, 18, 3, coat)
        fine(34 + hx, 18 + hy, 24, 5, coat)
        fine(31 + hx, 23 + hy, 30, 8, coat)
        fine(32 + hx, 31 + hy, 28, 6, coat)
        fine(36 + hx, 37 + hy, 20, 5, cream)

        // Crown and cheek tabby bands.
        fine(40 + hx, 16 + hy, 3, 7, stripe)
        fine(45 + hx, 15 + hy, 3, 9, stripe)
        fine(50 + hx, 16 + hy, 3, 7, stripe)
        fine(29 + hx, 27 + hy, 6, 2, stripe)
        fine(58 + hx, 27 + hy, 5, 2, stripe)
        if articulation.eyesClosed {
            fine(34 + hx, 27 + hy, 10, 2, outline)
            fine(49 + hx, 27 + hy, 10, 2, outline)
        } else {
            for baseX in [33, 48] {
                fine(baseX + 2 + hx, 22 + hy, 8, 2, outline)
                fine(baseX + hx, 24 + hy, 12, 8, outline)
                fine(baseX + 2 + hx, 32 + hy, 8, 2, outline)
                fine(baseX + 2 + hx, 24 + hy, 8, 8, Color.white)
            }
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            fine(38 + hx + gx, 25 + hy, 5, 7, Color.black)
            fine(53 + hx + gx, 25 + hy, 5, 7, Color.black)
            fine(38 + hx + gx, 25 + hy, 2, 2, Color.white)
            fine(53 + hx + gx, 25 + hy, 2, 2, Color.white)
        }
        fine(35 + hx, 32 + hy, 24, 4, cream)
        fine(32 + hx, 36 + hy, 30, 5, cream)
        fine(37 + hx, 41 + hy, 20, 3, cream)
        fine(45 + hx, 34 + hy, 5, 3, palette.nose)
        fine(47 + hx, 37 + hy, 1, 3, outline)
        fine(42 + hx, 39 + hy, 5, 2, outline)
        fine(48 + hx, 39 + hy, 5, 2, outline)
        fine(24 + hx, 31 + hy, 7, 1, outline)
        fine(62 + hx, 31 + hy, 2, 1, outline)
        // Tucked paws still knead independently during cushion/purr states.
        fine(33 + articulation.leftFrontPawX, 44 + articulation.leftFrontPawY, 14, 12, outline)
        fine(47 + articulation.rightFrontPawX, 44 + articulation.rightFrontPawY, 14, 12, outline)
        fine(35 + articulation.leftFrontPawX, 45 + articulation.leftFrontPawY, 10, 9, cream)
        fine(49 + articulation.rightFrontPawX, 45 + articulation.rightFrontPawY, 10, 9, cream)
        for x in [38, 42] {
            fine(x + articulation.leftFrontPawX, 51 + articulation.leftFrontPawY, 1, 4, outline)
        }
        for x in [52, 56] {
            fine(x + articulation.rightFrontPawX, 51 + articulation.rightFrontPawY, 1, 4, outline)
        }
    }

    private static func drawArticulatedCatCrouching(
        style: CodePixelCatStyle,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.87, blue: 0.64)
            : Color(red: 0.91, green: 0.90, blue: 0.85)
        let stripe = style == .orange
            ? Color(red: 0.31, green: 0.16, blue: 0.13)
            : Color(red: 0.07, green: 0.08, blue: 0.10)
        let hx = articulation.headX
        let hy = articulation.headY

        fine(4, 54, 55, 2, Color.black.opacity(0.20))
        // Twitching tail behind a low, elongated spine.
        fine(3, 29 + articulation.tailBaseY, 12, 8, outline)
        fine(1 + articulation.tailMiddleX, 24 + articulation.tailMiddleY, 9, 8, outline)
        fine(4 + articulation.tailTipX, 18 + articulation.tailTipY, 7, 9, outline)
        fine(5, 31 + articulation.tailBaseY, 9, 4, coat)
        fine(3 + articulation.tailMiddleX, 26 + articulation.tailMiddleY, 6, 4, coat)
        fine(6 + articulation.tailTipX, 20 + articulation.tailTipY, 3, 5, cream)

        fine(8, 29, 37, 22, outline)
        fine(5, 37, 43, 14, outline)
        fine(10, 31, 33, 17, coat)
        fine(7, 39, 39, 10, coat)
        fine(13, 32, 6, 15, cream)
        fine(23, 31, 5, 17, cream)
        fine(8, 40, 9, 3, stripe)
        fine(19, 35, 8, 3, stripe)
        fine(29, 39, 9, 3, stripe)

        // Front paws reach independently toward the target.
        let lx = articulation.leftFrontPawX
        let ly = articulation.leftFrontPawY
        let rx = articulation.rightFrontPawX
        let ry = articulation.rightFrontPawY
        fine(31 + lx, 43 + ly, 13, 10, outline)
        fine(43 + rx, 43 + ry, 13, 10, outline)
        fine(33 + lx, 45 + ly, 9, 6, cream)
        fine(45 + rx, 45 + ry, 9, 6, cream)
        for x in [35, 39] { fine(x + lx, 49 + ly, 1, 3, outline) }
        for x in [47, 51] { fine(x + rx, 49 + ry, 1, 3, outline) }

        // Forward-loaded head, independently aiming and bobbing.
        fine(34 + hx, 12 + hy, 25, 27, outline)
        fine(36 + hx, 9 + hy + articulation.leftEarY, 8, 10, outline)
        fine(51 + hx, 9 + hy + articulation.rightEarY, 8, 10, outline)
        fine(36 + hx, 15 + hy, 21, 21, coat)
        fine(38 + hx, 11 + hy + articulation.leftEarY, 4, 7, coat)
        fine(53 + hx, 11 + hy + articulation.rightEarY, 4, 7, coat)
        fine(41 + hx, 15 + hy, 3, 7, stripe)
        fine(47 + hx, 14 + hy, 3, 8, stripe)
        fine(52 + hx, 15 + hy, 3, 7, stripe)
        if articulation.eyesClosed {
            fine(38 + hx, 24 + hy, 7, 2, outline)
            fine(49 + hx, 24 + hy, 7, 2, outline)
        } else {
            fine(37 + hx, 20 + hy, 9, 10, outline)
            fine(48 + hx, 20 + hy, 9, 10, outline)
            fine(39 + hx, 21 + hy, 6, 7, Color.black)
            fine(50 + hx, 21 + hy, 6, 7, Color.black)
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            fine(39 + hx + gx, 21 + hy, 2, 2, Color.white)
            fine(50 + hx + gx, 21 + hy, 2, 2, Color.white)
        }
        fine(39 + hx, 29 + hy, 16, 7, cream)
        fine(45 + hx, 29 + hy, 4, 3, palette.nose)
        fine(43 + hx, 34 + hy, 4, 2, outline)
        fine(49 + hx, 34 + hy, 4, 2, outline)
        fine(29 + hx, 28 + hy, 7, 1, outline)
        fine(57 + hx, 28 + hy, 6, 1, outline)
    }

    private static func drawArticulatedCatHeld(
        style: CodePixelCatStyle,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.87, blue: 0.64)
            : Color(red: 0.91, green: 0.90, blue: 0.85)
        let stripe = style == .orange
            ? Color(red: 0.31, green: 0.16, blue: 0.13)
            : Color(red: 0.07, green: 0.08, blue: 0.10)
        let hx = articulation.headX
        let hy = articulation.headY

        // Suspended torso stretches while every paw hangs on its own beat.
        fine(20, 25, 25, 26, outline)
        fine(22, 27, 21, 22, coat)
        fine(28, 27, 9, 23, cream)
        fine(21, 33, 7, 3, stripe)
        fine(37, 37, 7, 3, stripe)

        for (x, y) in [
            (14 + articulation.leftFrontPawX, 29 + articulation.leftFrontPawY),
            (42 + articulation.rightFrontPawX, 29 + articulation.rightFrontPawY),
            (19, 43 + articulation.leftHindPawY),
            (38, 43 + articulation.rightHindPawY),
        ] {
            fine(x, y, 10, 15, outline)
            fine(x + 2, y + 1, 6, 11, coat)
            fine(x + 1, y + 11, 8, 4, cream)
        }

        fine(42, 33 + articulation.tailBaseY, 9, 18, outline)
        fine(48 + articulation.tailMiddleX, 27 + articulation.tailMiddleY, 8, 12, outline)
        fine(52 + articulation.tailTipX, 21 + articulation.tailTipY, 7, 10, outline)
        fine(45, 35 + articulation.tailBaseY, 4, 14, coat)
        fine(51 + articulation.tailMiddleX, 29 + articulation.tailMiddleY, 3, 9, coat)

        fine(14 + hx, 7 + hy, 36, 24, outline)
        fine(17 + hx, 10 + hy, 30, 18, coat)
        fine(17 + hx, 4 + hy + articulation.leftEarY, 10, 12, outline)
        fine(38 + hx, 4 + hy + articulation.rightEarY, 10, 12, outline)
        fine(20 + hx, 7 + hy + articulation.leftEarY, 5, 8, coat)
        fine(40 + hx, 7 + hy + articulation.rightEarY, 5, 8, coat)
        fine(27 + hx, 10 + hy, 3, 7, stripe)
        fine(32 + hx, 9 + hy, 3, 9, stripe)
        fine(37 + hx, 10 + hy, 3, 7, stripe)
        fine(19 + hx, 16 + hy, 10, 9, outline)
        fine(35 + hx, 16 + hy, 10, 9, outline)
        fine(21 + hx, 17 + hy, 7, 6, Color.black)
        fine(37 + hx, 17 + hy, 7, 6, Color.black)
        fine(21 + hx, 17 + hy, 2, 2, Color.white)
        fine(37 + hx, 17 + hy, 2, 2, Color.white)
        fine(23 + hx, 23 + hy, 19, 7, cream)
        fine(30 + hx, 23 + hy, 5, 3, palette.nose)
        fine(28 + hx, 28 + hy, 4, 2, outline)
        fine(34 + hx, 28 + hy, 4, 2, outline)
    }

    private static func drawArticulatedCatRolling(
        style: CodePixelCatStyle,
        articulation: CodeCompanionArticulation,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let outline = palette.outline
        let coat = palette.coat
        let cream = style == .orange
            ? Color(red: 0.99, green: 0.86, blue: 0.61)
            : Color(red: 0.91, green: 0.89, blue: 0.82)
        fine(7, 56, 50, 3, Color.black.opacity(0.20))
        fine(10, 25, 44, 29, outline)
        fine(13, 27, 38, 25, coat)
        fine(23, 29, 18, 20, cream)
        fine(8 + articulation.headX, 20 + articulation.headY, 24, 23, outline)
        fine(11 + articulation.headX, 22 + articulation.headY, 19, 18, coat)
        fine(12 + articulation.headX, 18 + articulation.headY + articulation.leftEarY, 7, 10, outline)
        fine(23 + articulation.headX, 18 + articulation.headY + articulation.rightEarY, 7, 10, outline)
        fine(15 + articulation.headX, 28 + articulation.headY, 6, 7, Color.white)
        fine(23 + articulation.headX, 28 + articulation.headY, 6, 7, Color.white)
        fine(18 + articulation.headX, 30 + articulation.headY, 3, 4, Color.black)
        fine(26 + articulation.headX, 30 + articulation.headY, 3, 4, Color.black)
        fine(20 + articulation.headX, 35 + articulation.headY, 5, 3, palette.nose)
        for (x, y) in [
            (14 + articulation.leftFrontPawX, 20 + articulation.leftFrontPawY),
            (39 + articulation.rightFrontPawX, 20 + articulation.rightFrontPawY),
            (15, 43 + articulation.leftHindPawY),
            (40, 43 + articulation.rightHindPawY),
        ] {
            fine(x, y, 11, 10, outline)
            fine(x + 2, y + 1, 7, 7, cream)
        }
        fine(46, 31 + articulation.tailBaseY, 10, 19, outline)
        fine(50 + articulation.tailMiddleX, 24 + articulation.tailMiddleY, 8, 13, outline)
        fine(53 + articulation.tailTipX, 19 + articulation.tailTipY, 7, 10, outline)
        fine(49, 33 + articulation.tailBaseY, 5, 15, coat)
        fine(53 + articulation.tailMiddleX, 26 + articulation.tailMiddleY, 3, 10, coat)
    }

    private static func drawHighFidelityDog(
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let by = frame.bodyY * 2
        let hy = frame.headY * 2
        let outline = palette.outline
        let coat = palette.coat
        let dark = Color(red: 0.28, green: 0.14, blue: 0.06)
        let cream = Color(red: 0.98, green: 0.82, blue: 0.49)
        let gold = Color(red: 0.95, green: 0.58, blue: 0.18)

        fine(11, 58, 43, 3, Color.black.opacity(0.22))
        fine(16, 28 + by, 33, 29, outline)
        fine(12, 40 + by, 13, 17, outline)
        fine(40, 40 + by, 13, 17, outline)
        fine(18, 30 + by, 29, 25, coat)
        fine(14, 41 + by, 10, 14, coat)
        fine(41, 41 + by, 10, 14, coat)
        fine(26, 32 + by, 13, 23, cream)
        fine(17, 35 + by, 7, 4, gold)
        fine(41, 35 + by, 7, 4, gold)
        fine(20, 48 + by, 8, 10, outline)
        fine(37, 48 + by, 8, 10, outline)
        fine(21, 50 + by, 6, 7, coat)
        fine(38, 50 + by, 6, 7, coat)
        fine(20, 55 + by, 8, 3, cream)
        fine(37, 55 + by, 8, 3, cream)

        // Wagging tail.
        fine(47, 33 + by, 10, 8, outline)
        fine(52, 27 + by, 8, 10, outline)
        fine(49, 34 + by, 6, 5, coat)
        fine(54, 29 + by, 4, 7, gold)

        // Rounded head with long floppy ears.
        fine(15, 11 + hy, 35, 22, outline)
        fine(8, 14 + hy, 12, 22, outline)
        fine(45, 14 + hy, 12, 22, outline)
        fine(10, 16 + hy, 8, 18, dark)
        fine(47, 16 + hy, 8, 18, dark)
        fine(17, 13 + hy, 31, 18, coat)
        fine(23, 14 + hy, 19, 5, gold)
        fine(29, 13 + hy, 7, 8, cream)

        if frame.eyesClosed {
            fine(22, 22 + hy, 8, 2, outline)
            fine(36, 22 + hy, 8, 2, outline)
        } else {
            fine(21, 18 + hy, 10, 10, outline)
            fine(35, 18 + hy, 10, 10, outline)
            fine(23, 19 + hy, 7, 8, Color(red: 0.16, green: 0.10, blue: 0.06))
            fine(37, 19 + hy, 7, 8, Color(red: 0.16, green: 0.10, blue: 0.06))
            fine(23, 19 + hy, 3, 3, Color.white)
            fine(37, 19 + hy, 3, 3, Color.white)
        }
        fine(23, 25 + hy, 20, 8, cream)
        fine(30, 24 + hy, 6, 4, dark)
        fine(32, 28 + hy, 2, 3, outline)
        fine(27, 31 + hy, 5, 2, outline)
        fine(34, 31 + hy, 5, 2, outline)
        fine(18, 32 + by, 29, 3, Color(red: 0.72, green: 0.10, blue: 0.12))
    }

    private static func drawHighFidelityPanda(
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        let by = frame.bodyY * 2
        let hy = frame.headY * 2
        let black = palette.outline
        let white = Color(red: 0.96, green: 0.95, blue: 0.90)
        let gray = Color(red: 0.70, green: 0.70, blue: 0.68)

        fine(11, 58, 43, 3, Color.black.opacity(0.22))
        fine(15, 29 + by, 35, 28, black)
        fine(18, 31 + by, 29, 24, white)
        fine(11, 40 + by, 14, 17, black)
        fine(40, 40 + by, 14, 17, black)
        fine(22, 35 + by, 21, 20, white)
        fine(20, 50 + by, 10, 8, black)
        fine(35, 50 + by, 10, 8, black)
        fine(22, 54 + by, 6, 2, gray)
        fine(37, 54 + by, 6, 2, gray)

        // Round ears and head.
        fine(12, 7 + hy, 13, 13, black)
        fine(40, 7 + hy, 13, 13, black)
        fine(14, 12 + hy, 37, 22, black)
        fine(17, 14 + hy, 31, 18, white)
        fine(19, 18 + hy, 12, 11, black)
        fine(34, 18 + hy, 12, 11, black)
        if frame.eyesClosed {
            fine(22, 23 + hy, 7, 2, white)
            fine(37, 23 + hy, 7, 2, white)
        } else {
            fine(22, 20 + hy, 7, 8, Color.white)
            fine(37, 20 + hy, 7, 8, Color.white)
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gy = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fine(24 + gx, 21 + hy + gy, 4, 5, black)
            fine(39 + gx, 21 + hy + gy, 4, 5, black)
            fine(24 + gx, 21 + hy + gy, 2, 2, Color.white)
            fine(39 + gx, 21 + hy + gy, 2, 2, Color.white)
        }
        fine(25, 26 + hy, 17, 7, white)
        fine(31, 25 + hy, 5, 4, black)
        fine(33, 29 + hy, 1, 3, black)
        fine(28, 31 + hy, 5, 2, black)
        fine(34, 31 + hy, 5, 2, black)
    }

    private static func drawSeated(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        switch style.species {
        case .dog:
            drawDogSeated(mood: mood, frame: frame, pose: pose, palette: palette, fill: fill)
            return
        case .panda:
            drawPandaSeated(mood: mood, frame: frame, pose: pose, palette: palette, fill: fill)
            return
        case .cat:
            break
        }
        let bodyY = frame.bodyY
        let headY = frame.headY
        let pawBeat = frame.phase % 2

        // Curled tail and broad haunches make the neutral silhouette read as a seated cat.
        fill(23, 17 + bodyY, 5, 11, palette.rim)
        fill(26, 21 + bodyY, 4, 7, palette.rim)
        fill(23, 24 + bodyY, 6, 5, palette.rim)
        fill(24, 18 + bodyY, 3, 9, palette.outline)
        fill(27, 22 + bodyY, 2, 5, palette.outline)
        fill(24, 25 + bodyY, 4, 3, palette.coat)

        fill(7, 14 + bodyY, 18, 13, palette.rim)
        fill(5, 20 + bodyY, 8, 8, palette.rim)
        fill(19, 20 + bodyY, 8, 8, palette.rim)
        fill(8, 15 + bodyY, 16, 11, palette.outline)
        fill(6, 21 + bodyY, 7, 6, palette.outline)
        fill(19, 21 + bodyY, 7, 6, palette.outline)
        fill(9, 16 + bodyY, 14, 9, palette.coat)
        fill(7, 22 + bodyY, 6, 4, palette.shadow)
        fill(19, 22 + bodyY, 6, 4, palette.shadow)
        fill(13, 18 + bodyY, 6, 7, palette.marking)
        fill(9, 17 + bodyY, 4, 2, palette.shadow)
        fill(8, 20 + bodyY, 5, 2, palette.shadow)
        fill(20, 17 + bodyY, 4, 2, palette.shadow)
        fill(20, 20 + bodyY, 5, 2, palette.shadow)
        fill(14, 17 + bodyY, 4, 2, palette.marking.opacity(0.86))

        // Front paws. Typing alternates them over two small key pads.
        if mood == .kneading || mood == .overheating {
            fill(8, 27, 7, 3, palette.key)
            fill(17, 27, 7, 3, palette.key)
            fill(10, 23 + bodyY - (pawBeat == 0 ? 2 : 0), 5, 5, palette.rim)
            fill(17, 23 + bodyY - (pawBeat == 1 ? 2 : 0), 5, 5, palette.rim)
        } else {
            fill(10, 23 + bodyY, 5, 6, palette.rim)
            fill(17, 23 + bodyY, 5, 6, palette.rim)
        }
        fill(11, 23 + bodyY - ((mood == .kneading || mood == .overheating) && pawBeat == 0 ? 2 : 0),
             3, 5, palette.coat)
        fill(18, 23 + bodyY - ((mood == .kneading || mood == .overheating) && pawBeat == 1 ? 2 : 0),
             3, 5, palette.coat)
        fill(11, 27 + bodyY, 3, 1, palette.marking)
        fill(18, 27 + bodyY, 3, 1, palette.marking)

        drawFrontHead(
            style: style,
            y: 2 + headY,
            eyesClosed: frame.eyesClosed,
            wideEyes: mood == .alert || mood == .startled,
            pose: pose,
            palette: palette,
            fill: fill
        )

        if mood == .thinking {
            fill(22, 18 + bodyY, 4, 5, palette.rim)
            fill(22, 19 + bodyY, 3, 3, palette.coat)
            fill(25, 4, 1, 1, palette.outline)
            fill(28, 2, 1, 1, palette.outline)
            fill(30, 4, 1, 1, palette.outline)
        } else if mood == .purring {
            fill(25, 5, 2, 2, palette.nose)
            fill(27, 4, 2, 2, palette.nose)
            fill(26, 7, 2, 2, palette.nose)
        } else if mood == .delighted {
            fill(26, 3, 1, 5, palette.marking)
            fill(24, 5, 5, 1, palette.marking)
        } else if frame.steam {
            fill(23, 2, 2, 2, Color.white.opacity(0.9))
            fill(25, 0, 2, 3, Color.white.opacity(0.82))
            fill(28, 1, 2, 3, Color.white.opacity(0.72))
        }
    }

    private static func drawFrontHead(
        style: CodePixelCatStyle,
        y: Int,
        eyesClosed: Bool,
        wideEyes: Bool,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        switch style.species {
        case .dog:
            drawDogHead(y: y, eyesClosed: eyesClosed, wideEyes: wideEyes,
                        pose: pose, palette: palette, fill: fill)
            return
        case .panda:
            drawPandaHead(y: y, eyesClosed: eyesClosed, wideEyes: wideEyes,
                          pose: pose, palette: palette, fill: fill)
            return
        case .cat:
            break
        }
        // Tall stepped ears, broad cheeks, a small muzzle and whiskers make the front
        // silhouette unmistakably feline at every integer scale.
        fill(6, y + 3, 20, 12, palette.rim)
        fill(7, y + 1, 7, 7, palette.rim)
        fill(8, y, 3, 4, palette.rim)
        fill(19, y + 1, 7, 7, palette.rim)
        fill(22, y, 3, 4, palette.rim)

        fill(7, y + 4, 18, 10, palette.outline)
        fill(8, y + 2, 5, 6, palette.outline)
        fill(9, y + 1, 2, 4, palette.outline)
        fill(20, y + 2, 5, 6, palette.outline)
        fill(22, y + 1, 2, 4, palette.outline)

        fill(8, y + 5, 16, 8, palette.coat)
        fill(9, y + 3, 3, 5, palette.coat)
        fill(21, y + 3, 3, 5, palette.coat)
        fill(10, y + 3, 1, 3, palette.ear)
        fill(22, y + 3, 1, 3, palette.ear)
        fill(14, y + 10, 5, 4, palette.marking)
        fill(14, y + 4, 1, 4, palette.shadow)
        fill(17, y + 4, 1, 4, palette.shadow)
        fill(9, y + 10, 3, 1, palette.shadow)
        fill(21, y + 10, 3, 1, palette.shadow)

        if eyesClosed {
            fill(10, y + 8, 4, 1, palette.outline)
            fill(19, y + 8, 4, 1, palette.outline)
        } else {
            let eyeHeight = wideEyes ? 5 : 4
            fill(9, y + 6, 6, eyeHeight + 1, palette.outline)
            fill(18, y + 6, 6, eyeHeight + 1, palette.outline)
            fill(10, y + 7, 4, eyeHeight - 1, Color.white)
            fill(19, y + 7, 4, eyeHeight - 1, Color.white)
            let gazeX = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gazeY = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fill(11 + gazeX, y + 7 + gazeY, 3, 3, palette.eye)
            fill(20 + gazeX, y + 7 + gazeY, 3, 3, palette.eye)
            fill(11 + gazeX, y + 7 + gazeY, 1, 1, Color.white)
            fill(20 + gazeX, y + 7 + gazeY, 1, 1, Color.white)
        }

        fill(12, y + 10, 9, 4, palette.marking)
        fill(15, y + 11, 3, 2, palette.nose)
        fill(16, y + 13, 1, 1, palette.outline)
        fill(14, y + 13, 2, 1, palette.outline)
        fill(17, y + 13, 2, 1, palette.outline)
        fill(3, y + 10, 5, 1, palette.rim)
        fill(4, y + 12, 4, 1, palette.rim)
        fill(25, y + 10, 5, 1, palette.rim)
        fill(25, y + 12, 4, 1, palette.rim)
        fill(4, y + 10, 4, 1, palette.outline)
        fill(5, y + 12, 3, 1, palette.outline)
        fill(25, y + 10, 4, 1, palette.outline)
        fill(25, y + 12, 3, 1, palette.outline)
    }

    private static func drawDogSeated(
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        let y = frame.bodyY
        fill(5, 28, 23, 2, Color.black.opacity(0.20))
        fill(23, 16 + y, 7, 10, palette.rim)
        fill(25, 13 + y, 5, 8, palette.rim)
        fill(24, 16 + y, 4, 9, palette.outline)
        fill(26, 14 + y, 3, 6, palette.coat)

        fill(7, 14 + y, 19, 13, palette.rim)
        fill(8, 15 + y, 17, 11, palette.outline)
        fill(9, 16 + y, 15, 9, palette.coat)
        fill(12, 17 + y, 8, 9, palette.marking)
        fill(7, 21 + y, 7, 7, palette.rim)
        fill(19, 21 + y, 7, 7, palette.rim)
        fill(8, 22 + y, 6, 5, palette.coat)
        fill(19, 22 + y, 6, 5, palette.coat)
        fill(9, 26 + y, 5, 2, palette.marking)
        fill(19, 26 + y, 5, 2, palette.marking)
        fill(10, 18 + y, 3, 2, palette.shadow)
        fill(21, 18 + y, 3, 2, palette.shadow)

        drawDogHead(y: 2 + frame.headY, eyesClosed: frame.eyesClosed,
                    wideEyes: mood == .alert || mood == .startled,
                    pose: pose, palette: palette, fill: fill)
        if frame.steam {
            fill(25, 1, 2, 2, Color.white.opacity(0.85))
            fill(27, 0, 2, 2, Color.white.opacity(0.72))
        }
    }

    private static func drawPandaSeated(
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        let y = frame.bodyY
        fill(5, 28, 23, 2, Color.black.opacity(0.20))
        fill(6, 14 + y, 20, 13, palette.outline)
        fill(8, 15 + y, 16, 11, palette.coat)
        fill(11, 17 + y, 10, 9, palette.marking)
        fill(5, 20 + y, 8, 8, palette.outline)
        fill(20, 20 + y, 8, 8, palette.outline)
        fill(7, 25 + y, 6, 3, palette.shadow)
        fill(20, 25 + y, 6, 3, palette.shadow)
        fill(14, 18 + y, 5, 7, Color.white.opacity(0.82))

        drawPandaHead(y: 2 + frame.headY, eyesClosed: frame.eyesClosed,
                      wideEyes: mood == .alert || mood == .startled,
                      pose: pose, palette: palette, fill: fill)
        if mood == .delighted {
            fill(27, 3, 2, 2, palette.nose)
            fill(29, 1, 1, 4, palette.nose)
        }
    }

    private static func drawDogHead(
        y: Int,
        eyesClosed: Bool,
        wideEyes: Bool,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        fill(3, y + 4, 7, 11, palette.rim)
        fill(23, y + 4, 7, 11, palette.rim)
        fill(4, y + 5, 5, 9, palette.shadow)
        fill(24, y + 5, 5, 9, palette.shadow)
        fill(7, y + 2, 19, 13, palette.rim)
        fill(8, y + 3, 17, 11, palette.outline)
        fill(9, y + 4, 15, 9, palette.coat)
        fill(14, y + 4, 5, 4, palette.marking.opacity(0.76))

        if eyesClosed {
            fill(10, y + 8, 4, 1, palette.outline)
            fill(19, y + 8, 4, 1, palette.outline)
        } else {
            let eyeHeight = wideEyes ? 5 : 4
            fill(9, y + 6, 6, eyeHeight + 1, palette.outline)
            fill(18, y + 6, 6, eyeHeight + 1, palette.outline)
            fill(10, y + 7, 4, eyeHeight - 1, Color.white)
            fill(19, y + 7, 4, eyeHeight - 1, Color.white)
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gy = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fill(11 + gx, y + 7 + gy, 3, 3, palette.eye)
            fill(20 + gx, y + 7 + gy, 3, 3, palette.eye)
            fill(11 + gx, y + 7 + gy, 1, 1, Color.white)
            fill(20 + gx, y + 7 + gy, 1, 1, Color.white)
        }

        fill(11, y + 10, 11, 5, palette.marking)
        fill(15, y + 10, 4, 3, palette.outline)
        fill(16, y + 10, 2, 1, Color.white.opacity(0.55))
        fill(14, y + 13, 2, 1, palette.outline)
        fill(18, y + 13, 2, 1, palette.outline)
    }

    private static func drawPandaHead(
        y: Int,
        eyesClosed: Bool,
        wideEyes: Bool,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        fill(5, y, 7, 7, palette.outline)
        fill(21, y, 7, 7, palette.outline)
        fill(6, y + 3, 21, 13, palette.outline)
        fill(7, y + 4, 19, 11, palette.coat)
        fill(9, y + 6, 7, 7, palette.shadow)
        fill(18, y + 6, 7, 7, palette.shadow)

        if eyesClosed {
            fill(10, y + 9, 4, 1, palette.marking)
            fill(20, y + 9, 4, 1, palette.marking)
        } else {
            let gx = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gy = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            let height = wideEyes ? 4 : 3
            fill(11, y + 8, 4, height, Color.white)
            fill(20, y + 8, 4, height, Color.white)
            fill(12 + gx, y + 8 + gy, 2, 2, palette.eye)
            fill(21 + gx, y + 8 + gy, 2, 2, palette.eye)
            fill(12 + gx, y + 8 + gy, 1, 1, Color.white)
            fill(21 + gx, y + 8 + gy, 1, 1, Color.white)
        }

        fill(12, y + 11, 10, 4, palette.marking)
        fill(16, y + 11, 3, 2, palette.outline)
        fill(15, y + 13, 2, 1, palette.outline)
        fill(19, y + 13, 2, 1, palette.outline)
    }

    private static func drawWalking(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
        if style.species != .cat {
            drawOtherWalking(style: style, frame: frame, palette: palette, fill: fill)
            return
        }
        let y = 10 + frame.bodyY

        // Upright tail.
        fill(3, y - 5 - frame.tailLift, 4, 11, palette.rim)
        fill(5, y - 7 - frame.tailLift, 5, 4, palette.rim)
        fill(4, y - 4 - frame.tailLift, 2, 9, palette.outline)
        fill(6, y - 6 - frame.tailLift, 3, 2, palette.outline)

        // Compact back and chest; short proportions avoid the previous horse silhouette.
        fill(6, y, 18, 12, palette.rim)
        fill(8, y - 2, 13, 4, palette.rim)
        fill(7, y + 1, 16, 10, palette.outline)
        fill(9, y - 1, 11, 3, palette.outline)
        fill(8, y + 2, 14, 8, palette.coat)
        fill(8, y + 8, 14, 3, palette.shadow)

        // Four visible feet, alternating diagonally with travel cadence.
        for index in 0..<4 {
            let baseX = [8, 12, 17, 21][index]
            let x = baseX + frame.legStrides[index]
            let lift = frame.legLifts[index]
            let legY = y + 9
            let length = max(4, 8 - lift)
            fill(x, legY, 4, length, palette.rim)
            fill(x + 1, legY, 2, length - 1, index.isMultiple(of: 2) ? palette.shadow : palette.coat)
            fill(x, legY + length - 2, 5, 2, palette.marking)
        }

        // Round profile head with two ears and one clear forward eye.
        fill(20, y - 5, 11, 12, palette.rim)
        fill(21, y - 9, 5, 7, palette.rim)
        fill(22, y - 10, 2, 3, palette.rim)
        fill(27, y - 8, 4, 7, palette.rim)
        fill(29, y - 9, 2, 3, palette.rim)
        fill(21, y - 4, 9, 10, palette.outline)
        fill(22, y - 7, 3, 5, palette.outline)
        fill(28, y - 6, 2, 4, palette.outline)
        fill(22, y - 3, 7, 8, palette.coat)
        fill(23, y - 6, 2, 3, palette.coat)
        fill(28, y - 5, 1, 3, palette.coat)
        fill(24, y, 3, 3, Color.white)
        fill(26, y + 1, 1, 1, palette.eye)
        fill(28, y + 3, 3, 3, palette.marking)
        fill(30, y + 4, 1, 1, palette.nose)
        fill(27, y + 5, 4, 1, palette.outline)
    }

    private static func drawHunting(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        if style.species != .cat {
            drawOtherHunting(style: style, frame: frame, pose: pose,
                             palette: palette, fill: fill)
            return
        }
        // Low, forward-loaded crouch. The whole silhouette points at the cursor.
        fill(3, 15, 8, 4, palette.rim)
        fill(1, 13, 5, 3, palette.rim)
        fill(4, 16, 6, 2, palette.outline)
        fill(2, 14, 4, 1, palette.outline)
        fill(7, 14, 17, 10, palette.rim)
        fill(8, 15, 15, 8, palette.outline)
        fill(9, 16, 13, 6, palette.coat)
        fill(9, 21, 14, 3, palette.shadow)
        fill(7, 22, 8, 5, palette.rim)
        fill(18, 22, 9, 5, palette.rim)
        fill(8, 23, 7, 3, palette.marking)
        fill(19, 23, 7, 3, palette.marking)

        fill(19, 8, 12, 13, palette.rim)
        fill(20, 5, 5, 6, palette.rim)
        fill(27, 6, 4, 6, palette.rim)
        fill(20, 9, 10, 11, palette.outline)
        fill(21, 6, 3, 5, palette.outline)
        fill(28, 7, 2, 4, palette.outline)
        fill(21, 10, 8, 9, palette.coat)
        fill(22, 7, 2, 4, palette.coat)
        fill(28, 8, 1, 3, palette.coat)
        let gazeY = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
        fill(23, 12, 3, 4, Color.white)
        fill(25, 13 + gazeY, 1, 2, palette.eye)
        fill(28, 16, 3, 3, palette.marking)
        fill(30, 17, 1, 1, palette.nose)
    }

    private static func drawOtherWalking(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
        let y = 10 + frame.bodyY
        fill(5, 28, 24, 2, Color.black.opacity(0.18))

        if style.species == .dog {
            fill(3, y - 4 - frame.tailLift, 4, 10, palette.rim)
            fill(4, y - 6 - frame.tailLift, 4, 5, palette.outline)
            fill(5, y - 5 - frame.tailLift, 2, 4, palette.coat)
        } else {
            fill(4, y + 4, 5, 5, palette.outline)
        }

        fill(6, y, 19, 11, palette.rim)
        fill(7, y + 1, 17, 9, palette.outline)
        fill(8, y + 2, 15, 7, palette.coat)
        if style.species == .panda {
            fill(9, y + 4, 13, 5, palette.marking)
        } else {
            fill(9, y + 3, 5, 2, palette.marking.opacity(0.78))
            fill(16, y + 5, 5, 2, palette.shadow)
        }

        for index in 0..<4 {
            let baseX = [8, 12, 17, 21][index]
            let x = baseX + frame.legStrides[index]
            let lift = frame.legLifts[index]
            let legY = y + 8
            let length = max(4, 8 - lift)
            let legColor = style.species == .panda ? palette.outline
                : (index.isMultiple(of: 2) ? palette.shadow : palette.coat)
            fill(x, legY, 4, length, palette.rim)
            fill(x + 1, legY, 2, length - 1, legColor)
            fill(x, legY + length - 2, 5, 2,
                 style.species == .panda ? palette.outline : palette.marking)
        }

        if style.species == .dog {
            fill(20, y - 5, 11, 12, palette.rim)
            fill(19, y - 3, 5, 9, palette.shadow)
            fill(21, y - 4, 9, 10, palette.outline)
            fill(22, y - 3, 7, 8, palette.coat)
            fill(23, y, 3, 3, Color.white)
            fill(25, y + 1, 1, 1, palette.eye)
            fill(27, y + 2, 4, 4, palette.marking)
            fill(29, y + 3, 2, 2, palette.outline)
        } else {
            fill(20, y - 6, 11, 12, palette.outline)
            fill(20, y - 9, 5, 5, palette.outline)
            fill(27, y - 8, 4, 5, palette.outline)
            fill(21, y - 5, 9, 10, palette.coat)
            fill(22, y - 2, 5, 5, palette.shadow)
            fill(23, y - 1, 3, 3, Color.white)
            fill(25, y, 1, 1, palette.eye)
            fill(27, y + 2, 4, 3, palette.marking)
            fill(29, y + 3, 2, 1, palette.outline)
        }
    }

    private static func drawOtherHunting(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        fill(4, 27, 25, 2, Color.black.opacity(0.18))
        fill(5, 15, 20, 10, palette.rim)
        fill(6, 16, 18, 8, palette.outline)
        fill(7, 17, 16, 6, palette.coat)
        fill(6, 22, 8, 5, style.species == .panda ? palette.outline : palette.shadow)
        fill(18, 22, 9, 5, style.species == .panda ? palette.outline : palette.marking)
        if style.species == .dog {
            drawDogHead(y: 5, eyesClosed: false, wideEyes: true,
                        pose: pose, palette: palette, fill: fill)
        } else {
            drawPandaHead(y: 5, eyesClosed: false, wideEyes: true,
                          pose: pose, palette: palette, fill: fill)
        }
    }

    private static func drawHeld(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        let wobble = frame.phase % 4 == 1 ? -1 : (frame.phase % 4 == 3 ? 1 : 0)
        let stretch = frame.legExtension

        // Head stays near the pointer while the soft body stretches beneath it.
        drawFrontHead(
            style: style,
            y: 0,
            eyesClosed: false,
            wideEyes: true,
            pose: pose,
            palette: palette,
            fill: fill
        )
        fill(10 + wobble, 14, 13, 10 + stretch, palette.rim)
        fill(11 + wobble, 14, 11, 9 + stretch, palette.outline)
        fill(12 + wobble, 14, 9, 8 + stretch, palette.coat)
        fill(14 + wobble, 16, 5, 7 + stretch, palette.marking)

        fill(8 + wobble, 20 + stretch, 8, 6, palette.rim)
        fill(17 + wobble, 20 + stretch, 8, 6, palette.rim)
        fill(9 + wobble, 21 + stretch, 6, 4, palette.coat)
        fill(18 + wobble, 21 + stretch, 6, 4, palette.coat)
        fill(9 + wobble, 24 + stretch, 6, 1, palette.marking)
        fill(18 + wobble, 24 + stretch, 6, 1, palette.marking)

        fill(22 + wobble, 16, 5, 10, palette.rim)
        fill(23 + wobble, 17, 3, 8, palette.outline)
        fill(24 + wobble, 18, 1, 6, palette.coat)
    }

    private static func drawSleeping(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
        if style.species != .cat {
            drawOtherSleeping(style: style, frame: frame, palette: palette, fill: fill)
            return
        }
        let y = frame.bodyY
        fill(5, 13 + y, 23, 15, palette.rim)
        fill(3, 17 + y, 9, 10, palette.rim)
        fill(6, 14 + y, 21, 13, palette.outline)
        fill(4, 18 + y, 8, 8, palette.outline)
        fill(7, 15 + y, 19, 11, palette.coat)
        fill(5, 19 + y, 7, 6, palette.shadow)
        fill(11, 20 + y, 13, 5, palette.marking)

        // Tucked head and a tail wrapped around the face.
        fill(7, 11 + y, 14, 12, palette.rim)
        fill(8, 9 + y, 5, 6, palette.rim)
        fill(16, 10 + y, 5, 6, palette.rim)
        fill(8, 12 + y, 12, 10, palette.outline)
        fill(9, 10 + y, 3, 5, palette.outline)
        fill(17, 11 + y, 3, 4, palette.outline)
        fill(9, 13 + y, 10, 8, palette.coat)
        fill(10, 16 + y, 4, 1, palette.outline)
        fill(15, 16 + y, 4, 1, palette.outline)
        fill(13, 18 + y, 3, 2, palette.marking)
        fill(21, 19 + y, 8, 6, palette.rim)
        fill(22, 20 + y, 6, 4, palette.outline)
        fill(22, 21 + y, 5, 2, palette.coat)
    }

    private static func drawOtherSleeping(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
        let y = frame.bodyY
        fill(4, 27, 25, 2, Color.black.opacity(0.18))
        fill(4, 13 + y, 24, 14, palette.rim)
        fill(5, 14 + y, 22, 12, palette.outline)
        fill(6, 15 + y, 20, 10, palette.coat)

        if style.species == .dog {
            fill(7, 18 + y, 12, 7, palette.marking)
            fill(18, 17 + y, 9, 8, palette.shadow)
            fill(6, 11 + y, 15, 12, palette.rim)
            fill(7, 12 + y, 13, 10, palette.outline)
            fill(8, 13 + y, 11, 8, palette.coat)
            fill(4, 14 + y, 5, 8, palette.shadow)
            fill(10, 17 + y, 4, 1, palette.outline)
            fill(15, 17 + y, 4, 1, palette.outline)
            fill(13, 19 + y, 3, 2, palette.outline)
        } else {
            fill(6, 18 + y, 8, 7, palette.outline)
            fill(20, 18 + y, 7, 7, palette.outline)
            fill(10, 17 + y, 13, 8, palette.marking)
            fill(7, 10 + y, 15, 13, palette.outline)
            fill(8, 12 + y, 13, 10, palette.coat)
            fill(7, 9 + y, 5, 5, palette.outline)
            fill(17, 9 + y, 5, 5, palette.outline)
            fill(9, 14 + y, 5, 5, palette.shadow)
            fill(16, 14 + y, 5, 5, palette.shadow)
            fill(10, 16 + y, 3, 1, palette.marking)
            fill(17, 16 + y, 3, 1, palette.marking)
            fill(14, 18 + y, 3, 2, palette.outline)
        }
    }

    private static func drawTexture(
        style: CodePixelCatStyle,
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fine: FineFill
    ) {
        if pose.gait == .walking {
            drawWalkingTexture(style: style, frame: frame, palette: palette, fine: fine)
            return
        }
        if mood == .sleepy {
            drawSleepingTexture(style: style, frame: frame, palette: palette, fine: fine)
            return
        }

        let bodyY = frame.bodyY * 2
        let headY = frame.headY * 2
        switch style {
        case .gray, .orange:
            let stripe = style == .orange
                ? Color(red: 0.36, green: 0.20, blue: 0.17)
                : Color(red: 0.09, green: 0.10, blue: 0.12)
            let highlight = style == .orange
                ? Color(red: 0.94, green: 0.57, blue: 0.20)
                : Color(red: 0.34, green: 0.37, blue: 0.40)
            let cream = Color(red: 0.98, green: 0.87, blue: 0.63)

            // Stepped ear fur and inner-ear depth.
            fine(17, 5 + headY, 4, 7, highlight)
            fine(43, 5 + headY, 4, 7, highlight)
            fine(19, 8 + headY, 2, 7, Color(red: 0.92, green: 0.52, blue: 0.52))
            fine(43, 8 + headY, 2, 7, Color(red: 0.92, green: 0.52, blue: 0.52))

            // Tabby crown and cheek bands.
            fine(27, 9 + headY, 3, 8, stripe)
            fine(33, 8 + headY, 3, 10, stripe)
            fine(39, 9 + headY, 3, 8, stripe)
            fine(18, 20 + headY, 7, 2, stripe)
            fine(19, 24 + headY, 6, 2, stripe)
            fine(43, 20 + headY, 7, 2, stripe)
            fine(43, 24 + headY, 6, 2, stripe)

            // Glossy eyes: coloured lower iris plus two-point catchlight.
            fine(21, 17 + headY, 6, 5, Color(red: 0.20, green: 0.14, blue: 0.10))
            fine(39, 17 + headY, 6, 5, Color(red: 0.20, green: 0.14, blue: 0.10))
            fine(22, 16 + headY, 2, 2, Color.white)
            fine(40, 16 + headY, 2, 2, Color.white)
            fine(25, 22 + headY, 1, 1, Color.white.opacity(0.8))
            fine(43, 22 + headY, 1, 1, Color.white.opacity(0.8))

            // Cream muzzle, chin and individual whisker roots.
            fine(25, 23 + headY, 16, 6, cream)
            fine(29, 28 + headY, 10, 2, cream)
            fine(27, 26 + headY, 1, 1, stripe)
            fine(41, 26 + headY, 1, 1, stripe)
            fine(22, 27 + headY, 2, 1, cream)
            fine(45, 27 + headY, 2, 1, cream)

            // Layered shoulder, flank and tail markings.
            fine(18, 35 + bodyY, 7, 3, stripe)
            fine(16, 41 + bodyY, 8, 3, stripe)
            fine(17, 47 + bodyY, 7, 3, stripe)
            fine(43, 35 + bodyY, 7, 3, stripe)
            fine(44, 41 + bodyY, 8, 3, stripe)
            fine(44, 47 + bodyY, 7, 3, stripe)
            fine(29, 34 + bodyY, 10, 4, cream)
            fine(27, 39 + bodyY, 14, 15, cream.opacity(0.92))
            fine(50, 39 + bodyY, 5, 3, stripe)
            fine(53, 46 + bodyY, 5, 3, stripe)
            fine(50, 52 + bodyY, 6, 3, cream)

            // Toes and tiny claws keep the feet readable at Huge.
            for x in [21, 25, 37, 41] {
                fine(x, 55 + bodyY, 1, 3, stripe)
            }

        case .dog:
            let dark = Color(red: 0.29, green: 0.15, blue: 0.07)
            let gold = Color(red: 0.95, green: 0.64, blue: 0.25)
            let cream = Color(red: 0.98, green: 0.86, blue: 0.58)
            fine(9, 15 + headY, 6, 13, dark)
            fine(51, 15 + headY, 6, 13, dark)
            fine(15, 11 + headY, 8, 3, gold)
            fine(43, 11 + headY, 8, 3, gold)
            fine(27, 10 + headY, 12, 5, cream)
            fine(21, 17 + headY, 2, 2, Color.white)
            fine(41, 17 + headY, 2, 2, Color.white)
            fine(25, 24 + headY, 16, 7, cream)
            fine(31, 23 + headY, 6, 4, dark)
            fine(24, 31 + bodyY, 20, 3, Color(red: 0.72, green: 0.10, blue: 0.12))
            fine(29, 34 + bodyY, 11, 18, cream)
            fine(17, 38 + bodyY, 7, 3, gold)
            fine(44, 38 + bodyY, 7, 3, gold)
            fine(18, 47 + bodyY, 6, 3, dark)
            fine(44, 47 + bodyY, 6, 3, dark)
            for x in [19, 23, 43, 47] {
                fine(x, 55 + bodyY, 1, 3, dark)
            }

        case .panda:
            let black = Color(red: 0.045, green: 0.045, blue: 0.05)
            let white = Color(red: 0.97, green: 0.96, blue: 0.91)
            let gray = Color(red: 0.72, green: 0.72, blue: 0.70)
            fine(13, 8 + headY, 8, 7, black)
            fine(47, 8 + headY, 8, 7, black)
            fine(21, 15 + headY, 9, 11, black)
            fine(39, 15 + headY, 9, 11, black)
            fine(23, 17 + headY, 2, 2, Color.white)
            fine(41, 17 + headY, 2, 2, Color.white)
            fine(27, 24 + headY, 14, 6, white)
            fine(32, 23 + headY, 5, 3, black)
            fine(29, 34 + bodyY, 12, 18, white)
            fine(30, 39 + bodyY, 10, 4, gray.opacity(0.65))
            fine(12, 43 + bodyY, 10, 9, black)
            fine(46, 43 + bodyY, 10, 9, black)
            fine(14, 52 + bodyY, 7, 2, gray)
            fine(47, 52 + bodyY, 7, 2, gray)
        }
    }

    private static func drawWalkingTexture(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fine: FineFill
    ) {
        let y = 20 + frame.bodyY * 2
        switch style {
        case .gray, .orange:
            let stripe = style == .orange
                ? Color(red: 0.36, green: 0.20, blue: 0.17)
                : Color(red: 0.09, green: 0.10, blue: 0.12)
            fine(18, y + 4, 5, 3, stripe)
            fine(28, y + 3, 5, 3, stripe)
            fine(38, y + 5, 5, 3, stripe)
            fine(48, y + 1, 2, 2, Color.white)
            fine(11, y - 6, 4, 3, stripe)
        case .dog:
            fine(20, y + 4, 8, 3, Color(red: 0.98, green: 0.80, blue: 0.46))
            fine(47, y + 1, 2, 2, Color.white)
            fine(40, y + 9, 8, 3, Color(red: 0.72, green: 0.10, blue: 0.12))
        case .panda:
            fine(18, y + 4, 18, 7, Color(red: 0.97, green: 0.96, blue: 0.91))
            fine(47, y, 2, 2, Color.white)
        }
    }

    private static func drawSleepingTexture(
        style: CodePixelCatStyle,
        frame: CodePixelCatFrame,
        palette: Palette,
        fine: FineFill
    ) {
        let y = frame.bodyY * 2
        switch style {
        case .gray, .orange:
            let stripe = style == .orange
                ? Color(red: 0.36, green: 0.20, blue: 0.17)
                : Color(red: 0.09, green: 0.10, blue: 0.12)
            fine(27, 30 + y, 14, 4, Color(red: 0.98, green: 0.87, blue: 0.63))
            fine(39, 43 + y, 12, 3, stripe)
            fine(44, 49 + y, 10, 3, stripe)
            fine(20, 31 + y, 6, 2, stripe)
        case .dog:
            fine(17, 29 + y, 12, 4, Color(red: 0.98, green: 0.82, blue: 0.50))
            fine(37, 41 + y, 13, 4, Color(red: 0.35, green: 0.19, blue: 0.08))
            fine(24, 34 + y, 18, 3, Color(red: 0.72, green: 0.10, blue: 0.12))
        case .panda:
            fine(22, 29 + y, 19, 5, Color(red: 0.97, green: 0.96, blue: 0.90))
            fine(14, 37 + y, 10, 8, Color(red: 0.06, green: 0.06, blue: 0.07))
            fine(42, 38 + y, 10, 8, Color(red: 0.06, green: 0.06, blue: 0.07))
        }
    }

    private static func palette(for style: CodePixelCatStyle, heat: CGFloat) -> Palette {
        let amount = min(0.72, max(0, heat) * 0.72)
        let base: (CGFloat, CGFloat, CGFloat)
        let shadow: Color
        let marking: Color
        switch style {
        case .gray:
            base = (0.20, 0.22, 0.24)
            shadow = Color(red: 0.12, green: 0.13, blue: 0.15)
            marking = Color(red: 0.78, green: 0.76, blue: 0.70)
        case .orange:
            base = (0.78, 0.40, 0.13)
            shadow = Color(red: 0.49, green: 0.22, blue: 0.08)
            marking = Color(red: 0.98, green: 0.78, blue: 0.48)
        case .dog:
            base = (0.72, 0.43, 0.16)
            shadow = Color(red: 0.35, green: 0.19, blue: 0.08)
            marking = Color(red: 0.98, green: 0.82, blue: 0.50)
        case .panda:
            base = (0.88, 0.87, 0.82)
            shadow = Color(red: 0.11, green: 0.11, blue: 0.12)
            marking = Color(red: 0.97, green: 0.96, blue: 0.90)
        }
        let coat = Color(
            red: base.0 * (1 - amount) + 0.88 * amount,
            green: base.1 * (1 - amount) + 0.20 * amount,
            blue: base.2 * (1 - amount) + 0.16 * amount
        )
        return Palette(
            rim: Color(red: 0.07, green: 0.065, blue: 0.075),
            outline: Color(red: 0.025, green: 0.022, blue: 0.03),
            coat: coat,
            shadow: shadow,
            marking: marking,
            ear: Color(red: 0.88, green: 0.46, blue: 0.49),
            eye: Color(red: 0.05, green: 0.05, blue: 0.04),
            nose: Color(red: 0.85, green: 0.36, blue: 0.42),
            key: Color(red: 0.30, green: 0.32, blue: 0.36)
        )
    }
}
