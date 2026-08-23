import SwiftUI

/// The two built-in cats are drawn at runtime. Their ids stay compatible with existing
/// preferences, but no PNG frames are needed or loaded.
enum CodePixelCatStyle: String, CaseIterable {
    case gray = "pixel-cat-gray"
    case orange = "pixel-cat-orange"

    var name: String {
        switch self {
        case .gray: "Charcoal Cat"
        case .orange: "Ginger Cat"
        }
    }

    var pack: SpritePack {
        SpritePack(
            id: rawValue,
            name: name,
            author: "Built into Utter",
            frameSize: CGSize(width: 32, height: 32),
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
            phase = Int(safeElapsed * 5) % 24
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

struct CodePixelCatView: View {
    let style: CodePixelCatStyle
    let mood: CompanionMood
    let pose: CompanionPose
    let size: CGFloat
    let elapsed: Double

    @ObservedObject private var motion = MotionPreference.shared

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
                canvasSize: canvasSize
            )
        }
        .frame(width: size, height: size)
    }
}

private enum CodePixelCatRenderer {
    private typealias Fill = (Int, Int, Int, Int, Color) -> Void

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
        canvasSize: CGSize
    ) {
        let palette = palette(for: style, heat: pose.heat)

        func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: Color) {
            guard width > 0, height > 0 else { return }
            let pixel = min(canvasSize.width, canvasSize.height) / 32
            let rect = CGRect(
                x: CGFloat(x) * pixel,
                y: CGFloat(y) * pixel,
                width: CGFloat(width) * pixel,
                height: CGFloat(height) * pixel
            )
            context.fill(Path(rect), with: .color(color))
        }

        switch (pose.gait, mood) {
        case (_, .sleepy):
            drawSleeping(frame: frame, palette: palette, fill: fill)
        case (_, .held):
            drawHeld(frame: frame, pose: pose, palette: palette, fill: fill)
        case (.walking, _):
            drawWalking(frame: frame, palette: palette, fill: fill)
        case (_, .hunting):
            drawHunting(frame: frame, pose: pose, palette: palette, fill: fill)
        default:
            drawSeated(mood: mood, frame: frame, pose: pose, palette: palette, fill: fill)
        }
    }

    private static func drawSeated(
        mood: CompanionMood,
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
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
            y: 4 + headY,
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
        y: Int,
        eyesClosed: Bool,
        wideEyes: Bool,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        fill(7, y + 2, 18, 12, palette.rim)
        fill(8, y, 6, 6, palette.rim)
        fill(19, y, 6, 6, palette.rim)
        fill(8, y + 3, 16, 10, palette.outline)
        fill(9, y + 1, 4, 5, palette.outline)
        fill(20, y + 1, 4, 5, palette.outline)
        fill(9, y + 4, 14, 8, palette.coat)
        fill(10, y + 2, 3, 4, palette.coat)
        fill(20, y + 2, 3, 4, palette.coat)
        fill(11, y + 3, 1, 2, palette.ear)
        fill(21, y + 3, 1, 2, palette.ear)
        fill(13, y + 9, 7, 4, palette.marking)

        if eyesClosed {
            fill(11, y + 7, 4, 1, palette.outline)
            fill(18, y + 7, 4, 1, palette.outline)
        } else {
            let eyeHeight = wideEyes ? 4 : 3
            fill(11, y + 6, 4, eyeHeight, Color.white)
            fill(18, y + 6, 4, eyeHeight, Color.white)
            let gazeX = max(-1, min(1, Int(pose.eyeAim.dx.rounded())))
            let gazeY = max(-1, min(1, -Int(pose.eyeAim.dy.rounded())))
            fill(12 + gazeX, y + 7 + gazeY, 2, 2, palette.eye)
            fill(19 + gazeX, y + 7 + gazeY, 2, 2, palette.eye)
        }
        fill(16, y + 10, 2, 1, palette.nose)
        fill(15, y + 11, 1, 1, palette.outline)
        fill(18, y + 11, 1, 1, palette.outline)
    }

    private static func drawWalking(
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
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
        fill(21, y - 8, 5, 6, palette.rim)
        fill(27, y - 7, 4, 6, palette.rim)
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
    }

    private static func drawHunting(
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
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

    private static func drawHeld(
        frame: CodePixelCatFrame,
        pose: CompanionPose,
        palette: Palette,
        fill: Fill
    ) {
        let wobble = frame.phase % 4 == 1 ? -1 : (frame.phase % 4 == 3 ? 1 : 0)
        let stretch = frame.legExtension

        // Head stays near the pointer while the soft body stretches beneath it.
        drawFrontHead(
            y: 2,
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
        frame: CodePixelCatFrame,
        palette: Palette,
        fill: Fill
    ) {
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
        }
        let coat = Color(
            red: base.0 * (1 - amount) + 0.88 * amount,
            green: base.1 * (1 - amount) + 0.20 * amount,
            blue: base.2 * (1 - amount) + 0.16 * amount
        )
        return Palette(
            rim: Color(red: 0.96, green: 0.94, blue: 0.88),
            outline: Color(red: 0.08, green: 0.075, blue: 0.07),
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
