import SwiftUI

/// The icon's seven bars and smile as a live view.
struct LivingMark: View {
    enum Phase: Equatable { case rest, listening, thinking, smile, flat }

    var phase: Phase = .rest
    /// 0...1 voice level while `.listening`.
    var level: Double = 0
    var tint: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dipped = false

    private var ticks: Bool { !reduceMotion && (phase == .listening || phase == .thinking) }
    private var smileOn: Bool {
        switch phase {
        case .rest: true
        case .smile: !dipped
        case .listening, .thinking, .flat: false
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !ticks)) { context in
            let heights = MarkGeometry.heights(phase: phase, level: level, dipped: dipped, reduceMotion: reduceMotion,
                                               time: ticks ? context.date.timeIntervalSinceReferenceDate : 0)
            ZStack {
                ForEach(0..<MarkGeometry.rest.count, id: \.self) { index in
                    MarkBar(index: index, height: heights[index])
                        .fill(tint)
                        .animation(barAnimation(index), value: heights[index])
                }
                MarkSmile(progress: smileOn ? 1 : 0)
                    .fill(tint)
                    .animation(reduceMotion ? nil : smileAnimation, value: smileOn)
                    .opacity(smileOn ? 1 : 0)
                    .animation(reduceMotion ? .easeInOut(duration: 0.15) : nil, value: smileOn)
            }
        }
        .aspectRatio(MarkGeometry.width / MarkGeometry.height, contentMode: .fit)
        .task(id: phase) {
            guard phase == .smile, !reduceMotion else {
                dipped = false
                return
            }
            dipped = true
            try? await Task.sleep(for: .milliseconds(150))
            if !Task.isCancelled { dipped = false }
        }
        .accessibilityHidden(true)
    }

    private var smileAnimation: Animation {
        smileOn ? .interpolatingSpring(mass: 1, stiffness: 70, damping: 2 * 70.0.squareRoot()) : .easeOut(duration: 0.12)
    }

    private func barAnimation(_ index: Int) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.15) }
        let (stiffness, ratio): (Double, Double) = switch phase {
        case .rest: (240, 0.66)
        case .listening: (520, 0.42)
        case .thinking: (320, 0.55)
        case .smile: dipped ? (900, 0.9) : (300, 0.5)
        case .flat: (260, 0.8)
        }
        let mass = MarkGeometry.mass[index]
        return .interpolatingSpring(mass: mass, stiffness: stiffness, damping: 2 * ratio * (stiffness * mass).squareRoot())
    }
}

/// Measured from AppIconSource.png; one unit is the spacing between bars.
enum MarkGeometry {
    static let rest: [CGFloat] = [6.7, 3.96, 1.98, 1.19, 1.98, 3.96, 6.7]
    static let mass: [Double] = [1.7, 1.25, 1, 0.8, 1, 1.25, 1.7]
    static let barWidth: CGFloat = 0.62
    static let dot: CGFloat = 0.62
    static let width: CGFloat = 6.72
    static let height: CGFloat = 7.8
    static let centreY: CGFloat = 0.5
    static let smileCentreY: CGFloat = 1.8
    static let smileRadius: CGFloat = 2.31
    static let smileStart = 2.746
    static let smileEnd = 0.395
    static let smileWidth: CGFloat = 0.5

    private static let bands: [Double] = [2.0, 3.3, 5.1, 7.6, 5.4, 3.0, 2.3]

    static func scale(in rect: CGRect) -> CGFloat { min(rect.width / width, rect.height / height) }

    static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        let u = scale(in: rect)
        return CGPoint(x: rect.midX + x * u, y: rect.midY + (y - centreY) * u)
    }

    static func heights(phase: LivingMark.Phase, level: Double, dipped: Bool, reduceMotion: Bool, time: Double) -> [CGFloat] {
        switch phase {
        case .rest: return rest
        case .smile: return dipped ? Array(repeating: dot, count: rest.count) : rest
        case .flat: return Array(repeating: dot, count: rest.count)
        case .listening:
            return (0..<rest.count).map { index in
                let edge = Double(abs(index - 3)) / 3
                let ceiling = 7.14 * (0.5 + 0.5 * edge)
                let wobble = reduceMotion ? 0.5 : noise(time * bands[index], seed: index)
                let energy = min(max(level * (0.45 + 1.05 * wobble), 0), 1)
                return dot + CGFloat((ceiling - Double(dot)) * energy)
            }
        case .thinking:
            let rate = reduceMotion ? 0.6 : 1.3
            return (0..<rest.count).map { index in
                let phase = reduceMotion ? 0.5 : 0.5 + 0.5 * sin((time - Double(index) * 0.045) * 2 * .pi * rate - Double(index) * 0.9 - .pi / 2)
                return dot + CGFloat(2.42 * pow(phase, reduceMotion ? 1 : 1.6))
            }
        }
    }

    static func noise(_ x: Double, seed: Int) -> Double {
        func value(_ n: Double) -> Double {
            let v = sin((n + Double(seed) * 17) * 12.9898) * 43758.5453
            return v - v.rounded(.down)
        }
        let cell = x.rounded(.down), fraction = x - cell
        let eased = fraction * fraction * (3 - 2 * fraction)
        return value(cell) + (value(cell + 1) - value(cell)) * eased
    }
}

private struct MarkBar: Shape {
    let index: Int
    var height: CGFloat

    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let u = MarkGeometry.scale(in: rect)
        let width = MarkGeometry.barWidth * u
        let origin = MarkGeometry.point(CGFloat(index - 3) - MarkGeometry.barWidth / 2, -height / 2, in: rect)
        return Path(roundedRect: CGRect(x: origin.x, y: origin.y, width: width, height: max(height, MarkGeometry.dot) * u),
                    cornerRadius: width / 2, style: .continuous)
    }
}

private struct MarkSmile: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0.001 else { return Path() }
        let sweep = (MarkGeometry.smileStart - MarkGeometry.smileEnd) * Double(min(progress, 1))
        let steps = max(2, Int(40 * progress))
        var arc = Path()
        for step in 0...steps {
            let angle = MarkGeometry.smileStart - sweep * Double(step) / Double(steps)
            let point = MarkGeometry.point(MarkGeometry.smileRadius * CGFloat(cos(angle)),
                                           MarkGeometry.smileCentreY + MarkGeometry.smileRadius * CGFloat(sin(angle)),
                                           in: rect)
            step == 0 ? arc.move(to: point) : arc.addLine(to: point)
        }
        let style = StrokeStyle(lineWidth: MarkGeometry.smileWidth * MarkGeometry.scale(in: rect), lineCap: .round, lineJoin: .round)
        return arc.strokedPath(style)
    }
}
