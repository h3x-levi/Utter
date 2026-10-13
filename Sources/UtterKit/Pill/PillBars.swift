import AppKit
import Combine
import QuartzCore
import SwiftUI

/// What the seven bars are doing. Each pill look picks one.
enum PillBarMode: Equatable {
    case hidden, rest, voice, thinking, flat
}

/// The icon's seven bars at pill size, in points. Proportions come from `MarkGeometry`. Width and
/// spacing are fixed at the listening height, so a morph only ever changes the heights.
enum PillBarGeometry {
    static let count = MarkGeometry.rest.count
    private static let bands: [Double] = [2.0, 3.3, 5.1, 7.6, 5.4, 3.0, 2.3]

    static let width: CGFloat = (PillMetrics.capsuleHeight * 0.09 * 2).rounded() / 2
    static let spacing: CGFloat = PillMetrics.capsuleHeight * 0.16
    static let span: CGFloat = spacing * CGFloat(count - 1) + width
    /// Smaller changes than this are not sent, so a quiet mic stops costing commits.
    static let noiseFloor: CGFloat = 0.3

    static func tallest(height: CGFloat) -> CGFloat { max(height - 6, width) }

    static func centres(in width: CGFloat) -> [CGFloat] {
        (0..<count).map { width / 2 + CGFloat($0 - count / 2) * spacing }
    }

    /// The icon's shape: outer bars tallest.
    static func rest(height: CGFloat) -> [CGFloat] {
        let top = MarkGeometry.rest.max() ?? 1
        return MarkGeometry.rest.map { max($0 / top * tallest(height: height), width) }
    }

    static func flat(height: CGFloat) -> [CGFloat] {
        Array(repeating: width, count: count)
    }

    /// The voice: outer bars reach highest, each with its own wobble so the row never moves as one.
    static func voice(level: Float, time: Double, height: CGFloat, reduceMotion: Bool) -> [CGFloat] {
        let top = tallest(height: height)
        return (0..<count).map { index in
            let ceiling = Double(top) * (0.5 + 0.5 * edge(index))
            let wobble = reduceMotion ? 0.5 : MarkGeometry.noise(time * bands[index], seed: index)
            let energy = min(max(Double(level) * (0.45 + 1.05 * wobble), 0), 1)
            return width + CGFloat((ceiling - Double(width)) * energy)
        }
    }

    /// One period of the thinking wave for a bar, its phase set by its place in the row.
    static func wave(index: Int, height: CGFloat, samples: Int = 24) -> [CGFloat] {
        let peak = tallest(height: height) * 0.7
        return (0...samples).map { step in
            let t = Double(step) / Double(samples)
            let v = pow(0.5 + 0.5 * sin(t * 2 * .pi - Double(index) * 0.9 - .pi / 2), 1.6)
            return width + (peak - width) * CGFloat(v)
        }
    }

    static let wavePeriod: CFTimeInterval = 1 / 1.3
    static let waveStagger: CFTimeInterval = 0.045

    /// 0 for the centre bar, 1 for the outer ones.
    static func edge(_ index: Int) -> Double { Double(abs(index - count / 2)) / Double(count / 2) }

    /// The voice spring per bar: the centre quickest, the heavier outer bars a touch slower.
    static func voiceResponse(_ index: Int) -> Double { 0.18 + 0.08 * edge(index) }
    static let voiceBounce = 0.2
}

/// Seven white `CALayer` bars. Each change hands the render server one additive spring per bar, so a
/// spring still in flight keeps its velocity, main does nothing between mic updates, and nothing
/// runs at rest.
final class PillBarsView: NSView {
    private let bars: [CALayer] = (0..<PillBarGeometry.count).map { _ in CALayer() }
    private var mode = PillBarMode.hidden
    private var height: CGFloat = PillMetrics.capsuleHeight
    private var reduceMotion = false
    private var serial = 0
    private let levels: PillLevelSignal?
    private var levelWatch: AnyCancellable?

    init(levels: PillLevelSignal?) {
        self.levels = levels
        super.init(frame: .zero)
        wantsLayer = true
        let side = PillBarGeometry.width
        for bar in bars {
            bar.opacity = 0
            bar.bounds.size = CGSize(width: side, height: side)
            bar.cornerRadius = side / 2
            bar.backgroundColor = NSColor.white.cgColor
            layer?.addSublayer(bar)
        }
        levelWatch = levels?.$value.sink { [weak self] in self?.voice($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (bar, x) in zip(bars, PillBarGeometry.centres(in: bounds.width)) {
            bar.position = CGPoint(x: x, y: bounds.midY)
        }
        CATransaction.commit()
    }

    /// `height` is the capsule's, which sets how tall the bars may stand.
    func update(_ next: PillBarMode, height nextHeight: CGFloat, reduceMotion: Bool, level: Float = 0) {
        self.reduceMotion = reduceMotion
        guard next != mode || nextHeight != height else {
            if next == .voice, levels == nil { voice(level) }
            return
        }
        let previous = mode
        mode = next
        height = nextHeight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if previous == .thinking || next == .thinking || next == .hidden { freeze() }
        if next == .hidden {
            fade(to: 0, delay: 0, duration: 0.1)
        } else if previous == .hidden {
            fade(to: 1, delay: 0.06, duration: 0.12)
        }
        CATransaction.commit()
        switch next {
        case .hidden: break
        case .rest: spring(to: PillBarGeometry.rest(height: height), response: { _ in 0.3 }, bounce: 0.15)
        case .voice: voice(levels?.value ?? level, force: true)
        case .thinking: think()
        case .flat: spring(to: PillBarGeometry.flat(height: height), response: { _ in 0.26 }, bounce: 0)
        }
    }

    private func voice(_ level: Float, force: Bool = false) {
        guard mode == .voice else { return }
        let heights = PillBarGeometry.voice(level: level, time: CACurrentMediaTime(), height: height,
                                            reduceMotion: reduceMotion)
        guard force || zip(heights, bars).contains(where: { abs($0 - $1.bounds.size.height) > PillBarGeometry.noiseFloor })
        else { return }
        spring(to: heights, response: PillBarGeometry.voiceResponse, bounce: PillBarGeometry.voiceBounce)
    }

    private func think() {
        guard !reduceMotion else {
            spring(to: PillBarGeometry.rest(height: height).map { $0 * 0.6 }, response: { _ in 0 }, bounce: 0)
            return
        }
        let now = CACurrentMediaTime()
        serial &+= 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let values = PillBarGeometry.wave(index: index, height: height)
            let shown = bar.bounds.size.height
            bar.bounds.size.height = values[0]
            let wave = CAKeyframeAnimation(keyPath: "bounds.size.height")
            wave.values = values
            wave.duration = PillBarGeometry.wavePeriod
            wave.repeatCount = .infinity
            wave.beginTime = now + Double(index) * PillBarGeometry.waveStagger
            wave.fillMode = .backwards
            bar.add(wave, forKey: "wave")
            // Added after the wave, so it sums on top: the wave starts from where the bar stood.
            add(offset: shown - values[0], to: bar, response: 0.3, bounce: 0)
        }
        CATransaction.commit()
    }

    /// Springs each bar to `heights` from wherever it is on screen, velocity included: the model
    /// jumps to the target and an additive offset from the old target decays to zero on top of
    /// whatever is still running. A response of 0 or Reduce Motion eases instead.
    private func spring(to heights: [CGFloat], response: (Int) -> Double, bounce: Double) {
        serial &+= 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let from = bar.bounds.size.height
            bar.bounds.size.height = heights[index]
            add(offset: from - heights[index], to: bar, response: response(index), bounce: bounce)
        }
        CATransaction.commit()
    }

    private func add(offset: CGFloat, to bar: CALayer, response: Double, bounce: Double) {
        guard abs(offset) > 0.01 else { return }
        let animation: CABasicAnimation
        if response > 0, !reduceMotion {
            let spring = CASpringAnimation(perceptualDuration: response, bounce: bounce)
            spring.duration = spring.settlingDuration
            animation = spring
        } else {
            animation = CABasicAnimation()
            animation.duration = 0.15
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }
        animation.keyPath = "bounds.size.height"
        animation.isAdditive = true
        animation.fromValue = offset
        animation.toValue = 0
        bar.add(animation, forKey: "h\(serial)")
    }

    /// Pins each bar's model to what is on screen and drops its height animations, so the next
    /// spring starts from there. Used where the non-additive wave starts or stops, or the bars go away.
    private func freeze() {
        for bar in bars {
            let shown = bar.presentation()?.bounds.size.height ?? bar.bounds.size.height
            for key in bar.animationKeys() ?? [] where key == "wave" || key.hasPrefix("h") {
                bar.removeAnimation(forKey: key)
            }
            bar.bounds.size.height = shown
        }
    }

    private func fade(to opacity: Float, delay: CFTimeInterval, duration: CFTimeInterval) {
        for bar in bars {
            let from = bar.presentation()?.opacity ?? bar.opacity
            bar.opacity = opacity
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = from
            fade.toValue = opacity
            fade.duration = duration
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            bar.add(fade, forKey: "fade")
        }
    }
}

/// The bars in SwiftUI. Live mic levels arrive through `levels`; the onboarding demo passes `level`.
struct PillBars: NSViewRepresentable {
    let mode: PillBarMode
    let height: CGFloat
    var levels: PillLevelSignal?
    var level: Float = 0
    let reduceMotion: Bool

    func makeNSView(context: Context) -> PillBarsView { PillBarsView(levels: levels) }

    func updateNSView(_ view: PillBarsView, context: Context) {
        view.update(mode, height: height, reduceMotion: reduceMotion, level: level)
    }
}
