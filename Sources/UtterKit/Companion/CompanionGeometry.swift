import CoreGraphics
import UtterCore

/// The companion panel: the robot in the middle, a bubble's room above and below it.
struct CompanionGeometry: Equatable {
    /// The robot fills 213 of its 240-unit canvas from antenna top to chin.
    static let canvasPerDrawnHeight: CGFloat = 240.0 / 213.0
    static let bubbleWidth: CGFloat = 220
    static let bubbleRoom: CGFloat = 64

    let robotSide: CGFloat

    init(_ size: CompanionSize) { robotSide = size.points * Self.canvasPerDrawnHeight }

    var panelSize: CGSize {
        CGSize(width: max(Self.bubbleWidth, robotSide), height: robotSide + Self.bubbleRoom * 2)
    }

    /// The robot's square, in the panel's own coordinates.
    var robotFrameInPanel: CGRect {
        CGRect(x: (panelSize.width - robotSide) / 2, y: Self.bubbleRoom, width: robotSide, height: robotSide)
    }

    func panelOrigin(robotCentre c: CGPoint) -> CGPoint {
        CGPoint(x: c.x - panelSize.width / 2, y: c.y - panelSize.height / 2)
    }

    /// `origin`, moved as little as possible to keep the robot itself on screen; the empty panel may hang off.
    func clamped(_ origin: CGPoint, in visible: CGRect) -> CGPoint {
        let robot = robotFrameInPanel.offsetBy(dx: origin.x, dy: origin.y)
        let x = robotClamp(robot.minX, visible.minX, max(visible.minX, visible.maxX - robotSide))
        let y = robotClamp(robot.minY, visible.minY, max(visible.minY, visible.maxY - robotSide))
        return CGPoint(x: origin.x + (x - robot.minX), y: origin.y + (y - robot.minY))
    }

    /// Below when the screen has no room above the robot.
    func bubbleBelow(panelOrigin o: CGPoint, visible: CGRect) -> Bool {
        o.y + robotFrameInPanel.maxY + Self.bubbleRoom > visible.maxY
    }

    /// How much of the panel hangs off each side of the screen, so the bubble can stay on it.
    func bubbleInsets(panelOrigin o: CGPoint, visible: CGRect) -> (leading: CGFloat, trailing: CGFloat) {
        (max(0, visible.minX - o.x), max(0, o.x + panelSize.width - visible.maxX))
    }

    /// The robot's centre as a fraction of the visible frame, so a saved spot survives a display change.
    static func fraction(ofCentre centre: CGPoint, in visible: CGRect) -> CGPoint {
        CGPoint(x: (centre.x - visible.minX) / max(visible.width, 1),
                y: (centre.y - visible.minY) / max(visible.height, 1))
    }

    func panelOrigin(forCentreFraction f: CGPoint, in visible: CGRect) -> CGPoint {
        let centre = CGPoint(x: visible.minX + f.x * visible.width, y: visible.minY + f.y * visible.height)
        return clamped(panelOrigin(robotCentre: centre), in: visible)
    }
}
