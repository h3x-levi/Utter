import AppKit
import Testing
@testable import UtterKit

@Suite("Robot snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_ROBOT_SNAPSHOTS"] == "1"))
@MainActor
struct RobotSnapshotTests {
    /// Seconds into each state's plan where its expression is fully formed.
    private static let moments: [(RobotState, Double)] = [
        (.idle, 0), (.bored, 1.5), (.waiting, 0.32), (.waitingWrap, 1.0), (.input, 1.0), (.send, 0.65),
        (.success, 0.85), (.failure, 1.66), (.warning, 1.78), (.inspect, 1.88), (.angry, 1.3), (.blocked, 1.3),
        (.error, 0.67), (.surprise, 0.96), (.love, 1.02), (.random, 0.88), (.sleep, 4.0), (.wake, 0.3),
    ]

    @Test("Render each state's resting pose to .build/robot-snapshots")
    func renderStates() throws {
        let directory = try SnapshotCanvas.directory("robot-snapshots")

        let view = RobotView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        view.layout()
        let sleeping = RobotPlan.make(.sleep, from: RobotFace(), reduced: false, seed: 1, resting: true, withLoop: false)
        for (state, moment) in Self.moments {
            let start = state == .wake ? sleeping.frames[sleeping.frames.count - 1] : RobotFace()
            view.showStill(RobotPlan.make(state, from: start, reduced: false, seed: 7).face(at: moment))
            try png(of: view).write(to: directory.appendingPathComponent("\(state).png"))
        }
        for roundness in [CGFloat(0), 100] {
            view.roundness = roundness
            view.showStill(RobotFace())
            try png(of: view).write(to: directory.appendingPathComponent("roundness-\(Int(roundness)).png"))
        }
    }

    private func png(of view: RobotView) throws -> Data {
        let scale: CGFloat = 2
        guard let layer = view.layer,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * scale),
                                         pixelsHigh: Int(view.bounds.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { throw RenderError.noContext }
        context.setFillColor(NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
        context.scaleBy(x: scale, y: scale)
        layer.render(in: context)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw RenderError.noContext }
        return data
    }

    private enum RenderError: Error { case noContext }
}
