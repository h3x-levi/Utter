import AppKit
import Combine

struct RobotLook: Equatable {
    var finish = "ink"
    var worn: String? = nil
    var time = "day"
}

/// CX ArtLab's agent-robot-avatar, drawn with Core Animation.
///
/// Every state is precomputed into keyframes that the render server plays, so an idle robot costs
/// no main-thread work. A display link runs only while a gesture is live or the pointer is moving
/// near the robot, and stops the moment that motion settles.
final class RobotView: NSView {
    var palette = RobotPalette.utter {
        didSet { applyPalette() }
    }

    /// Unknown finish or time ids fall back to the library defaults; an unknown or unwearable accessory wears nothing.
    var look = RobotLook() {
        didSet { if look != oldValue { applyLook() } }
    }

    var library = RobotLibrary.shared {
        didSet { applyLook() }
    }

    /// Called when a moment runs to its end, or a pause or Reduce Motion change skips or cuts it; never for `stopMoment`.
    var onMomentEnd: ((String) -> Void)?
    /// The pointer came close, unless the robot was napping.
    var onNear: (() -> Void)?

    var isPlayingMoment: Bool { moment != nil }
    var isNapping: Bool { state == .sleep }

    /// 0 is squarest, 100 roundest; 50 is the upstream head.
    var roundness = RobotGeometry.defaultRoundness {
        didSet {
            roundness = robotClamp(roundness, 0, 100)
            headPoints = RobotGeometry.head(roundness: roundness)
            withoutActions { applyHeadPath(headPoints) }
        }
    }

    /// Microphone level, 0...1. Only the `input` state reads it; cheap to set at 30 Hz.
    var inputLevel: Float = 0 {
        didSet { levelChanged() }
    }

    /// Upstream's optional status flash of the antenna during actions; off by default, as upstream.
    var antennaFlashes = false

    /// Seconds without a play, a press or the pointer near before the robot sleeps; nil never naps.
    /// Asleep, nothing animates, so an idle robot composites nothing.
    var napDelay: TimeInterval? = 30 {
        didSet { noteActivity() }
    }

    /// Asleep until cleared: the pointer no longer wakes it, and a press dozes off again soon after.
    var isQuiet = false {
        didSet {
            guard isQuiet != oldValue else { return }
            play(isQuiet ? .sleep : .wake)
        }
    }

    var state: RobotState { logicalState(at: CACurrentMediaTime()) }

    var isHoldingAntenna: Bool {
        if case .antenna = gesture { return true }
        return false
    }

    private let canvas = CALayer()
    private let dragLayer = CALayer()
    private let headLayer = CALayer()
    private let headShape = CAShapeLayer()
    private let faceLayer = CALayer()
    private let faceMask = CAShapeLayer()
    private let antennaLayer = CAShapeLayer()
    private let behindLayer = CALayer()
    private let finishLayer = CALayer()
    private let finishMask = CAShapeLayer()
    private let headAccessories = CALayer()
    private let frontLayer = CALayer()
    private let eyes = [RobotEyeLayers(), RobotEyeLayers()]
    private var tracks: [Track] = []
    private var applied: [[CGFloat]?] = []

    private var headPoints = RobotGeometry.defaultHead
    private var plan: RobotPlan
    private var planStart: CFTimeInterval = 0
    private var shownState = RobotState.idle
    private var shownUntil: CFTimeInterval = 0

    private var pauseReasons: RobotPauseReasons = [.offscreen]
    private var link: CADisplayLink?
    private lazy var linkTarget = RobotLinkTarget(view: self)
    private var lastTick: CFTimeInterval = 0
    private var monitors: [Any] = []
    private var motionObserver: AnyCancellable?
    private weak var observedWindow: NSWindow?

    private var live: Live?
    private var pendingPointer: (x: CGFloat, y: CGFloat, influence: CGFloat)?
    private var gesture: Gesture?
    private var gestureStart = CGPoint.zero
    private var gestureClock: CFTimeInterval = 0
    private var dragPoint: CGPoint?
    private var liveFace: RobotFace?
    private var takeover: (face: RobotFace, at: CFTimeInterval)?

    private var level: CGFloat = 0
    private var appliedLevel: CGFloat = 0
    private var lastLoud: CFTimeInterval = 0

    private var lastActivity: CFTimeInterval = 0
    private var napTimer: Timer?

    private var moment: (id: String, mine: [String])?
    private var momentToken = 0
    private(set) var shown: [String: CALayer] = [:]
    private var wasNear = false

    private struct Live {
        var sim: RobotSim
        var antenna: RobotAntenna
        var start: CFTimeInterval
        var quietTicks = 0
    }

    private enum Gesture {
        case jelly(RobotJelly)
        case squeeze(RobotSqueeze)
        case antenna(RobotAntennaDrag, RobotSim)
    }

    private struct Track {
        let layer: CALayer
        let keyPath: String
        let isBlink: Bool
        let params: (RobotFace) -> [CGFloat]
        let value: ([CGFloat]) -> Any
    }

    override init(frame: NSRect) {
        plan = RobotPlan.make(.idle, from: RobotFace(), reduced: false, seed: 0, resting: true, withLoop: false)
        super.init(frame: frame)
        wantsLayer = true
        buildLayers()
        tracks = makeTracks()
        applied = Array(repeating: nil, count: tracks.count)
        withoutActions {
            applyHeadPath(headPoints)
            applyPalette()
            applyLook()
            applyFace(plan.frames[plan.frames.count - 1])
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Robot companion")

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(displaysSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displaysWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        motionObserver = MotionPreference.shared.$reduceMotion.dropFirst().removeDuplicates().sink { [weak self] reduce in
            MainActor.assumeIsolated {
                self?.reduceMotion = reduce
                self?.restart()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
            link?.invalidate()
            napTimer?.invalidate()
            monitors.forEach(NSEvent.removeMonitor)
        }
    }

    // MARK: Public control

    func play(_ state: RobotState) {
        let now = CACurrentMediaTime()
        if state != .sleep { noteActivity() }
        guard !state.isNoOp(whenShowing: logicalState(at: now)) else { return }
        guard pauseReasons.isEmpty else {
            shownState = state
            shownUntil = now
            return
        }
        let (face, velocity) = currentFace(at: now)
        endInteraction()
        install(RobotPlan.make(state, from: face, antennaVelocity: velocity, reduced: reduceMotion, seed: .random(in: 0...UInt64.max),
                               time: time), at: now)
    }

    func play(moment id: String, loop: Bool, hold: Bool) {
        guard let spec = library?.moments[id], let time else { return }
        let now = CACurrentMediaTime()
        noteActivity()
        endMoment(instant: true)
        momentToken += 1
        guard pauseReasons.isEmpty else {
            shownState = hold ? .input : .idle
            shownUntil = now
            return after(0) { $0.onMomentEnd?(id) }
        }
        let (face, velocity) = currentFace(at: now)
        endInteraction()
        let made = RobotPlan.make(moment: spec, from: face, antennaVelocity: velocity, reduced: reduceMotion, time: time,
                                  seed: .random(in: 0...UInt64.max), loop: loop, hold: hold)
        install(made.plan, at: now)
        moment = (id, spec.accessories)
        withoutActions { syncWorn(enter: true) }
        for cue in made.cues { after(cue.at / 1000) { $0.run(cue) } }
        guard !loop else { return }
        let waits = (reduceMotion ? spec.reduced : spec.steps).compactMap(\.wait).reduce(0, +)
        after(waits / time.speed / 1000) { $0.finishMoment() }
    }

    /// Eases the head home and settles to idle; the caller then plays whatever state should show.
    func stopMoment() {
        guard moment != nil else { return }
        let now = CACurrentMediaTime()
        let (face, velocity) = currentFace(at: now)
        install(RobotPlan.make(.idle, from: face, antennaVelocity: velocity, reduced: reduceMotion,
                               seed: .random(in: 0...UInt64.max), time: time), at: now)
    }

    func pause() { setPaused(.manual, true) }
    func resume() { setPaused(.manual, false) }

    /// Shows one frame with no animation, wearing exactly `accessories`; used to render snapshots.
    func showStill(_ face: RobotFace, accessories: [String] = []) {
        endMoment(instant: true)
        withoutActions {
            removePlanAnimations(keepBlink: false)
            applyFace(face)
            for id in shown.keys { hide(id, instant: true) }
            for id in accessories { show(id, enter: false) }
        }
    }

    // MARK: Layers

    private func buildLayers() {
        guard let root = layer else { return }
        root.masksToBounds = false
        canvas.bounds = CGRect(x: 0, y: 0, width: 240, height: 240)
        canvas.isGeometryFlipped = true
        root.addSublayer(canvas)

        for l in [dragLayer, headLayer, faceLayer, behindLayer, finishLayer, headAccessories, frontLayer] {
            l.bounds = canvas.bounds
            l.position = CGPoint(x: 120, y: 120)
        }
        canvas.addSublayer(behindLayer)
        canvas.addSublayer(dragLayer)
        dragLayer.addSublayer(headLayer)
        headLayer.addSublayer(headShape)
        headLayer.addSublayer(finishLayer)
        headLayer.addSublayer(faceLayer)
        headLayer.addSublayer(headAccessories)
        canvas.addSublayer(frontLayer)
        finishLayer.mask = finishMask
        faceLayer.mask = faceMask
        for mask in [faceMask, finishMask] { mask.fillColor = NSColor.black.cgColor }

        for eye in eyes { eye.install(in: faceLayer) }

        antennaLayer.path = CGPath(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30), transform: nil)
        antennaLayer.position = RobotGeometry.antennaHome
        canvas.addSublayer(antennaLayer)
    }

    private func makeTracks() -> [Track] {
        func transform(_ p: [CGFloat]) -> Any {
            NSValue(caTransform3D: RobotGeometry.affine(x: p[0], y: p[1], degrees: p[2], sx: p[3], sy: p[4]))
        }
        func lid(_ p: [CGFloat]) -> Any { NSValue(caTransform3D: RobotGeometry.affine(y: p[0], degrees: p[1])) }
        var list = [
            Track(layer: headLayer, keyPath: "transform", isBlink: false,
                  params: { [$0.headX, $0.headY, $0.headRotation, $0.headScaleX, $0.headScaleY] }, value: transform),
            Track(layer: antennaLayer, keyPath: "position", isBlink: false,
                  params: { [$0.antennaX, $0.antennaY] }, value: { NSValue(point: CGPoint(x: $0[0], y: $0[1])) }),
            Track(layer: faceLayer, keyPath: "opacity", isBlink: false,
                  params: { [$0.eyesOpacity] }, value: { NSNumber(value: Float($0[0])) }),
        ]
        for (eye, key) in zip(eyes, [\RobotFace.left, \RobotFace.right]) {
            list += [
                Track(layer: eye.group, keyPath: "transform", isBlink: false, params: {
                    let e = $0[keyPath: key]
                    return [e.x, e.y, e.rotation, e.scaleX, e.scaleY]
                }, value: transform),
                Track(layer: eye.blink, keyPath: "transform", isBlink: true, params: { [$0.blink] },
                      value: { NSValue(caTransform3D: CATransform3DMakeScale(1, $0[0], 1)) }),
                Track(layer: eye.base, keyPath: "path", isBlink: false, params: {
                    let e = $0[keyPath: key]
                    return [e.width, e.height, e.centerY]
                }, value: { RobotGeometry.ellipse(width: $0[0], height: $0[1], centerY: $0[2]) }),
                Track(layer: eye.base, keyPath: "opacity", isBlink: false, params: { [1 - $0[keyPath: key].caret] },
                      value: { NSNumber(value: Float($0[0])) }),
                Track(layer: eye.caret, keyPath: "path", isBlink: false, params: {
                    let e = $0[keyPath: key]
                    return [e.caretWidth, e.caretHeight]
                }, value: { RobotGeometry.caret(width: $0[0], height: $0[1]) }),
                Track(layer: eye.caret, keyPath: "opacity", isBlink: false, params: { [$0[keyPath: key].caret] },
                      value: { NSNumber(value: Float($0[0])) }),
                Track(layer: eye.top, keyPath: "transform", isBlink: false, params: {
                    let e = $0[keyPath: key]
                    return [e.topY, e.topAngle]
                }, value: lid),
                Track(layer: eye.bottom, keyPath: "transform", isBlink: false, params: {
                    let e = $0[keyPath: key]
                    return [e.bottomY, e.bottomAngle]
                }, value: lid),
            ]
        }
        return list
    }

    override func layout() {
        super.layout()
        withoutActions {
            let scale = min(bounds.width, bounds.height) / 240
            canvas.position = CGPoint(x: bounds.midX, y: bounds.midY)
            canvas.transform = CATransform3DMakeScale(scale, scale, 1)
            updateContentsScale()
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        withoutActions { updateContentsScale() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private var layerScale: CGFloat { (window?.backingScaleFactor ?? 2) * max(1, min(bounds.width, bounds.height) / 240) }

    private func updateContentsScale() {
        let scale = layerScale
        for l in [headShape, faceMask, finishMask, antennaLayer] + eyes.flatMap({ [$0.base, $0.caret] }) { l.contentsScale = scale }
        for l in [behindLayer, finishLayer, headAccessories, frontLayer] { RobotShapes.walk(l) { $0.contentsScale = scale } }
    }

    private func applyPalette() {
        withoutActions {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                headShape.fillColor = palette.body.cgColor
                antennaLayer.fillColor = palette.accent.cgColor
                for l in [headShape, antennaLayer] {
                    l.strokeColor = palette.rim?.cgColor
                    l.lineWidth = palette.rim == nil ? 0 : 5
                }
                for eye in eyes {
                    eye.base.fillColor = palette.eye.cgColor
                    eye.caret.fillColor = palette.eye.cgColor
                    eye.top.backgroundColor = palette.face.cgColor
                    eye.bottom.backgroundColor = palette.face.cgColor
                }
                guard let colours else { return }
                for l in finishLayer.sublayers ?? [] { RobotShapes.recolour(l, colours: colours) }
                for root in shown.values { RobotShapes.recolour(root, colours: colours) }
            }
        }
    }

    private func applyHeadPath(_ points: [CGPoint]) {
        let path = RobotGeometry.headPath(points)
        headShape.path = path
        faceMask.path = path
        finishMask.path = path
    }

    // MARK: Look and accessories

    private var finish: RobotFinish? {
        guard let library else { return nil }
        return library.finishes[look.finish] ?? library.defaults["finish"].flatMap { library.finishes[$0] }
    }

    private var time: RobotTime? {
        guard let library else { return nil }
        return library.times[look.time] ?? library.defaults["time"].flatMap { library.times[$0] }
    }

    private var worn: String? {
        guard let id = look.worn, library?.accessories[id]?.wear == true else { return nil }
        return id
    }

    private var colours: RobotColours? {
        guard let library, let finish else { return nil }
        return RobotColours(library: library, finish: finish)
    }

    private static let rims = ["dark": NSColor(white: 1, alpha: 0.32), "light": NSColor(srgbRed: 28 / 255, green: 42 / 255, blue: 94 / 255, alpha: 0.3)]

    private func applyLook() {
        guard let finish, let colours else { return }
        withoutActions {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                finishLayer.sublayers = (finish.shapes ?? []).map { RobotShapes.layer($0, colours: colours) }
            }
            updateContentsScale()
            let body = colours.colour("body") ?? palette.body
            var next = RobotPalette(body: body, face: body, eye: colours.colour("eyes") ?? palette.eye, accent: body)
            if let outline = finish.outline, let rim = Self.rims[outline] {
                next.rim = NSColor(name: nil) { ($0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? "dark" : "light") == outline ? rim : .clear }
            }
            palette = next
            syncWorn(enter: false)
        }
    }

    /// The worn accessory stays on unless the playing moment needs its slot or already wears two.
    private func syncWorn(enter: Bool) {
        guard let library else { return }
        let worn = self.worn, mine = moment?.mine ?? []
        for id in shown.keys where id != worn && !mine.contains(id) { hide(id, instant: !enter) }
        guard let worn, let slot = library.accessories[worn]?.slot else { return }
        if mine.contains(worn) || (mine.count < 2 && !mine.contains { library.accessories[$0]?.slot == slot }) {
            show(worn, enter: enter)
        } else {
            hide(worn, instant: false)
        }
    }

    private func show(_ id: String, enter: Bool) {
        guard shown[id] == nil, let library, let spec = library.accessories[id], let colours else { return }
        for other in shown.keys where library.accessories[other]?.slot == spec.slot { hide(other, instant: true) }
        var made: CALayer?
        effectiveAppearance.performAsCurrentDrawingAppearance { made = RobotShapes.accessory(id, colours: colours) }
        guard let root = made else { return }
        let scale = layerScale
        RobotShapes.walk(root) { $0.contentsScale = scale }
        (spec.layer == "behind" ? behindLayer : spec.layer == "head" ? headAccessories : frontLayer).addSublayer(root)
        shown[id] = root
        if enter && !reduceMotion { RobotShapes.enter(root, spec.enter) }
    }

    private func hide(_ id: String, instant: Bool, exit: String? = nil) {
        guard let root = shown.removeValue(forKey: id) else { return }
        RobotShapes.stopLoops(root)
        guard !instant, !reduceMotion, let spec = library?.accessories[id] else { return root.removeFromSuperlayer() }
        RobotShapes.exit(root, exit ?? spec.enter) { [weak root] in root?.removeFromSuperlayer() }
    }

    // MARK: Moments

    /// Runs `body` after `seconds` unless a moment started or ended in between.
    private func after(_ seconds: Double, _ body: @escaping (RobotView) -> Void) {
        let token = momentToken
        let timer = Timer(timeInterval: max(0, seconds), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.momentToken == token else { return }
                body(self)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func run(_ cue: RobotMomentCue) {
        withoutActions {
            if let on = cue.on {
                show(on, enter: !cue.instant)
                if let root = shown[on], !reduceMotion { RobotShapes.startLoops(root) }
            }
            if let off = cue.off {
                if off == worn, let root = shown[off] { RobotShapes.stopLoops(root) } else { hide(off, instant: false, exit: cue.exit) }
            }
        }
    }

    private func endMoment(instant: Bool) {
        guard let ended = moment else { return }
        momentToken += 1
        moment = nil
        withoutActions {
            if let worn, ended.mine.contains(worn), let root = shown[worn] { RobotShapes.stopLoops(root) }
            syncWorn(enter: !instant)
        }
    }

    private func finishMoment() {
        guard let id = moment?.id else { return }
        endMoment(instant: false)
        noteActivity()
        onMomentEnd?(id)
    }

    /// For cuts nobody asked for; the caller learns of them as an end, so it can show its state again.
    private func cutMoment() {
        guard let id = moment?.id else { return }
        endMoment(instant: true)
        after(0) { $0.onMomentEnd?(id) }
    }

    private func withoutActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    // MARK: Plans

    // `@Published` fires before its value changes, so keep the value the sink delivers.
    private var reduceMotion = MotionPreference.shared.reduceMotion

    private func logicalState(at now: CFTimeInterval) -> RobotState {
        shownState.persists || now < shownUntil ? shownState : .idle
    }

    private func isIdleRest(at now: CFTimeInterval) -> Bool {
        logicalState(at: now) == .idle && takeover == nil && moment == nil
    }

    private func currentFace(at now: CFTimeInterval) -> (RobotFace, CGVector) {
        if let liveFace {
            let velocity = live.map { CGVector(dx: $0.antenna.x.velocity, dy: $0.antenna.y.velocity) } ?? .zero
            return (liveFace, velocity)
        }
        let t = now - planStart
        let a = plan.face(at: t), b = plan.face(at: max(0, t - 1 / RobotPlan.frameRate))
        return (a, CGVector(dx: (a.antennaX - b.antennaX) * RobotPlan.frameRate, dy: (a.antennaY - b.antennaY) * RobotPlan.frameRate))
    }

    private func install(_ next: RobotPlan, at start: CFTimeInterval) {
        if !next.isMoment { endMoment(instant: false) }
        plan = next
        planStart = start
        shownState = next.state
        shownUntil = next.state.persists ? .infinity : start + next.introDuration
        withoutActions {
            for (i, track) in tracks.enumerated() {
                track.layer.removeAnimation(forKey: "intro." + track.keyPath)
                track.layer.removeAnimation(forKey: "loop." + track.keyPath)
                let intro = next.frames.map(track.params)
                let last = intro[intro.count - 1]
                track.layer.setValue(track.value(last), forKeyPath: track.keyPath)
                applied[i] = last
                let loop = track.isBlink ? next.blinkLoop.map { [$0] } : next.loop.map(track.params)
                if let a = keyframes(track, loop) {
                    a.beginTime = start + next.introDuration
                    a.repeatCount = .infinity
                    a.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                    track.layer.add(a, forKey: "loop." + track.keyPath)
                }
                if let a = keyframes(track, intro) {
                    a.beginTime = start
                    track.layer.add(a, forKey: "intro." + track.keyPath)
                }
            }
            installFlash(at: start)
            installCaret()
        }
    }

    private func keyframes(_ track: Track, _ params: [[CGFloat]]) -> CAKeyframeAnimation? {
        guard params.count > 1, params.contains(where: { $0 != params[0] }) else { return nil }
        var keep = [0]
        for i in 1..<(params.count - 1) {
            let a = params[i - 1], b = params[i], c = params[i + 1]
            if a.indices.contains(where: { abs(a[$0] - 2 * b[$0] + c[$0]) > 1e-4 }) { keep.append(i) }
        }
        keep.append(params.count - 1)
        let span = Double(params.count - 1)
        let animation = CAKeyframeAnimation(keyPath: track.keyPath)
        animation.values = keep.map { track.value(params[$0]) }
        animation.keyTimes = keep.map { NSNumber(value: Double($0) / span) }
        animation.duration = span / RobotPlan.frameRate
        animation.calculationMode = .linear
        return animation
    }

    private func installFlash(at start: CFTimeInterval) {
        antennaLayer.removeAnimation(forKey: "flash")
        guard antennaFlashes, !reduceMotion, let period = plan.state.flashPeriod else { return }
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1, 0]
        flash.keyTimes = [0, 0.8, 1]
        flash.calculationMode = .discrete
        flash.duration = period
        flash.beginTime = start
        flash.repeatDuration = plan.state.persists ? .infinity : plan.introDuration
        antennaLayer.add(flash, forKey: "flash")
    }

    private func installCaret() {
        level = 0
        appliedLevel = 0
        for eye in eyes {
            eye.caretHolder.removeAllAnimations()
            eye.caretHolder.transform = CATransform3DIdentity
        }
        setCaretBlinking(plan.caretBlinks)
    }

    private func setCaretBlinking(_ on: Bool) {
        for eye in eyes {
            guard on else {
                eye.caretHolder.removeAnimation(forKey: "caretBlink")
                continue
            }
            guard eye.caretHolder.animation(forKey: "caretBlink") == nil else { continue }
            let blink = CAKeyframeAnimation(keyPath: "opacity")
            blink.values = [1, 0]
            blink.keyTimes = [0, 0.5, 1]
            blink.calculationMode = .discrete
            blink.duration = 0.53
            blink.repeatCount = .infinity
            eye.caretHolder.add(blink, forKey: "caretBlink")
        }
    }

    private func applyFace(_ face: RobotFace, includeBlink: Bool = true) {
        for (i, track) in tracks.enumerated() where includeBlink || !track.isBlink {
            let params = track.params(face)
            guard applied[i] != params else { continue }
            applied[i] = params
            track.layer.setValue(track.value(params), forKeyPath: track.keyPath)
        }
    }

    private func removePlanAnimations(keepBlink: Bool) {
        for track in tracks where !(keepBlink && track.isBlink) {
            track.layer.removeAnimation(forKey: "intro." + track.keyPath)
            track.layer.removeAnimation(forKey: "loop." + track.keyPath)
        }
        antennaLayer.removeAnimation(forKey: "flash")
    }

    // MARK: Input level

    private func levelChanged() {
        let now = CACurrentMediaTime()
        guard pauseReasons.isEmpty, !reduceMotion, logicalState(at: now) == .input else { return }
        let target = CGFloat(robotClamp(inputLevel, 0, 1))
        level = target > level ? target : level * 0.8 + target * 0.2
        if level > 0.08 {
            lastLoud = now
            setCaretBlinking(false)
        } else if now - lastLoud > 0.6 {
            setCaretBlinking(true)
        }
        guard abs(level - appliedLevel) > 0.02 || (level < 0.02 && appliedLevel != 0) else { return }
        appliedLevel = level < 0.02 ? 0 : level
        let transform = CATransform3DMakeScale(1 + 0.35 * appliedLevel, 1 + 0.10 * appliedLevel, 1)
        for eye in eyes {
            let swell = CABasicAnimation(keyPath: "transform")
            swell.fromValue = eye.caretHolder.presentation()?.transform ?? eye.caretHolder.transform
            swell.toValue = NSValue(caTransform3D: transform)
            swell.duration = 0.1
            swell.timingFunction = CAMediaTimingFunction(name: .easeOut)
            withoutActions {
                eye.caretHolder.transform = transform
                eye.caretHolder.add(swell, forKey: "level")
            }
        }
    }

    // MARK: Pausing

    private func setPaused(_ reason: RobotPauseReasons, _ on: Bool) {
        let wasRunning = pauseReasons.isEmpty
        if on { pauseReasons.insert(reason) } else { pauseReasons.remove(reason) }
        if wasRunning && !pauseReasons.isEmpty { suspend() } else if !wasRunning && pauseReasons.isEmpty { restart() }
    }

    private func suspend() {
        let now = CACurrentMediaTime()
        cutMoment()
        endInteraction()
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        let rest = RobotPlan.make(logicalState(at: now), from: RobotFace(), reduced: reduceMotion, seed: 0, resting: true, withLoop: false,
                                  time: time)
        withoutActions {
            removePlanAnimations(keepBlink: false)
            for eye in eyes { eye.caretHolder.removeAllAnimations() }
            applyFace(rest.frames[rest.frames.count - 1])
        }
        plan = rest
        planStart = now
    }

    private func restart() {
        guard pauseReasons.isEmpty else { return }
        let now = CACurrentMediaTime()
        cutMoment()
        endInteraction()
        install(RobotPlan.make(logicalState(at: now), from: RobotFace(), reduced: reduceMotion, seed: .random(in: 0...UInt64.max), resting: true,
                               time: time), at: now)
        guard monitors.isEmpty else { return }
        let moved: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.pointerMoved() } }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: moved) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { moved($0); return $0 }) { monitors.append(local) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: observedWindow)
        }
        observedWindow = window
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
        withoutActions { updateContentsScale() }
        if window != nil { noteActivity() }
        setPaused(.hidden, isHiddenOrHasHiddenAncestor)
        setPaused(.occluded, !(window?.occlusionState.contains(.visible) ?? false))
        setPaused(.offscreen, window == nil)
    }

    override func viewDidHide() {
        super.viewDidHide()
        setPaused(.hidden, true)
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        setPaused(.hidden, isHiddenOrHasHiddenAncestor)
    }

    @objc private func occlusionChanged() { setPaused(.occluded, !(window?.occlusionState.contains(.visible) ?? false)) }
    @objc private func displaysSlept() { setPaused(.displaysAsleep, true) }
    @objc private func displaysWoke() { setPaused(.displaysAsleep, false) }
    @objc private func sessionResigned() { setPaused(.sessionInactive, true) }
    @objc private func sessionBecameActive() { setPaused(.sessionInactive, false) }
    @objc private func screenLocked() { setPaused(.screenLocked, true) }
    @objc private func screenUnlocked() { setPaused(.screenLocked, false) }

    // MARK: Napping

    private func noteActivity() {
        lastActivity = CACurrentMediaTime()
        if napTimer == nil, let delay = napDelayNow { scheduleNap(after: delay) }
    }

    private var napDelayNow: TimeInterval? { isQuiet ? 5 : napDelay }

    private func scheduleNap(after delay: TimeInterval) {
        napTimer?.invalidate()
        let timer = Timer(timeInterval: max(0.01, delay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.napDue() }
        }
        timer.tolerance = min(2, delay / 4)
        RunLoop.main.add(timer, forMode: .common)
        napTimer = timer
    }

    private func napDue() {
        napTimer = nil
        guard let delay = napDelayNow else { return }
        let quiet = CACurrentMediaTime() - lastActivity
        if moment != nil { return scheduleNap(after: delay) }
        if quiet < delay - 0.05 { return scheduleNap(after: delay - quiet) }
        switch state {
        case .input, .waiting, .waitingWrap, .sleep: return
        default: play(.sleep)
        }
    }

    // MARK: Display link

    private func startLink() {
        guard link == nil, window != nil else { return }
        let l = displayLink(target: linkTarget, selector: #selector(RobotLinkTarget.tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        lastTick = CACurrentMediaTime()
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    fileprivate func tick() {
        let now = CACurrentMediaTime()
        let dt = robotClamp(now - lastTick, 0, 1.0 / 30)
        lastTick = now
        withoutActions {
            if gesture != nil { stepGesture(now: now, dt: dt) }
            if live != nil { stepLive(now: now, dt: dt) }
        }
        if gesture == nil && live == nil { stopLink() }
    }

    private func endInteraction() {
        if gesture != nil { withoutActions { restoreDragVisuals() } }
        gesture = nil
        live = nil
        liveFace = nil
        takeover = nil
        pendingPointer = nil
        dragPoint = nil
        stopLink()
    }

    // MARK: Pointer follow

    private func pointerMoved(dragging: Bool = false) {
        guard pauseReasons.isEmpty, let window else { return }
        let mouse = NSEvent.mouseLocation
        let center = window.convertPoint(toScreen: convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil))
        let dx = mouse.x - center.x, dy = center.y - mouse.y
        let influence = robotClamp(1 - hypot(dx, dy) / max(1, max(bounds.width, bounds.height) * 2.55), 0, 1)
        let now = CACurrentMediaTime()
        if influence > 0.65, !wasNear, logicalState(at: now) != .sleep { onNear?() }
        wasNear = influence > 0.65
        if influence > 0.65 {
            noteActivity()
            switch logicalState(at: now) {
            case .bored: play(.idle)
            case .sleep where !isQuiet: play(.wake)
            default: break
            }
        }
        guard !reduceMotion else { return }
        if live == nil {
            guard influence > 0.001, gesture == nil || dragging else { return }
            guard isIdleRest(at: now) else { return }
            beginLive(at: now)
        }
        pendingPointer = (robotClamp(dx * 0.42, -48, 48), robotClamp(dy * 0.38, -34, 34), influence)
    }

    private func beginLive(at now: CFTimeInterval) {
        let (face, velocity) = currentFace(at: now)
        var sim = RobotSim()
        sim.lid = CGFloat(time?.lid ?? 0)
        sim.look = CGPoint(x: (face.left.x + face.right.x) / 2 - 120, y: (face.left.y + face.right.y) / 2 - 126)
        sim.wanderTarget = sim.look
        sim.followX = RobotSpring(value: face.headX)
        sim.followY = RobotSpring(value: face.headY)
        sim.followRotation = RobotSpring(value: face.headRotation)
        let antenna = RobotAntenna(x: RobotSpring(value: face.antennaX, velocity: velocity.dx),
                                   y: RobotSpring(value: face.antennaY, velocity: velocity.dy))
        live = Live(sim: sim, antenna: antenna, start: now)
        liveFace = face
        withoutActions {
            removePlanAnimations(keepBlink: true)
            applyFace(face, includeBlink: false)
        }
        startLink()
    }

    private func stepLive(now: CFTimeInterval, dt: Double) {
        guard var l = live else { return }
        let t = (now - l.start) * 1000
        if let p = pendingPointer {
            l.sim.pointer = RobotPointer(x: p.x, y: p.y, influence: p.influence, lastMove: t)
            l.quietTicks = 0
            pendingPointer = nil
        } else {
            l.quietTicks += 1
        }
        var face = l.sim.advance(to: t)
        l.antenna.follow(face.antennaTarget, seconds: dt, reduced: false)
        face.antennaX = l.antenna.x.value
        face.antennaY = l.antenna.y.value
        applyFace(face, includeBlink: false)
        liveFace = face
        live = l
        guard l.quietTicks >= 6, gesture == nil else { return }
        let settle = RobotPlan.settle(from: l.sim, antenna: l.antenna, seed: .random(in: 0...UInt64.max), time: time)
        live = nil
        liveFace = nil
        install(settle, at: now)
    }

    // MARK: Gestures

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var viewSize: CGFloat { max(1, min(bounds.width, bounds.height)) }

    private func toCanvas(_ p: CGPoint) -> CGPoint {
        let scale = viewSize / 240
        return CGPoint(x: 120 + (p.x - bounds.midX) / scale, y: 120 - (p.y - bounds.midY) / scale)
    }

    override func mouseDown(with event: NSEvent) {
        noteActivity()
        guard pauseReasons.isEmpty, gesture == nil else { return }
        let now = CACurrentMediaTime()
        let p = convert(event.locationInWindow, from: nil)
        let point = toCanvas(p)
        let (face, _) = currentFace(at: now)
        let scale = viewSize / 240
        gestureStart = p
        gestureClock = now
        dragPoint = nil
        if hypot(point.x - face.antennaX, point.y - face.antennaY) * scale <= max(10, RobotGeometry.antennaRadius * scale + 3) {
            takeOver(face: face, at: now)
            var sim = RobotSim()
            sim.reduced = reduceMotion
            sim.lid = CGFloat(time?.lid ?? 0)
            sim.lock = true
            sim.look = CGPoint(x: (face.left.x + face.right.x) / 2 - 120, y: (face.left.y + face.right.y) / 2 - 126)
            sim.antennaGaze = gaze(at: p)
            gesture = .antenna(RobotAntennaDrag(home: CGPoint(x: face.antennaX, y: face.antennaY), viewSize: viewSize), sim)
        } else {
            let nx = (p.x - bounds.midX) / max(1, bounds.width), ny = (p.y - bounds.midY) / max(1, bounds.height)
            if nx * nx + ny * ny <= 0.32 * 0.32 {
                gesture = .squeeze(RobotSqueeze())
            } else {
                startJelly(at: now)
            }
        }
        startLink()
    }

    override func mouseDragged(with event: NSEvent) {
        dragPoint = convert(event.locationInWindow, from: nil)
        if live != nil { pointerMoved(dragging: true) }
    }

    override func mouseUp(with event: NSEvent) {
        switch gesture {
        case var .squeeze(s):
            if s.age < RobotSqueeze.holdBeforeCommit {
                gesture = nil
            } else {
                s.release()
                gesture = .squeeze(s)
            }
        case var .jelly(j):
            if let p = dragPoint { j.track(dx: p.x - gestureStart.x, dy: gestureStart.y - p.y, viewSize: viewSize) }
            j.release()
            gesture = .jelly(j)
        case .antenna(var drag, let sim):
            drag.release()
            gesture = .antenna(drag, sim)
        case nil:
            break
        }
        dragPoint = nil
    }

    private func gaze(at p: CGPoint) -> CGPoint {
        CGPoint(x: robotClamp((p.x - bounds.midX) * 0.42, -48, 48), y: robotClamp((bounds.midY - p.y) * 0.38, -34, 34))
    }

    private func startJelly(at now: CFTimeInterval) {
        let point = toCanvas(gestureStart)
        if live == nil, isIdleRest(at: now), !reduceMotion { beginLive(at: now) }
        live?.sim.dragging = true
        gesture = .jelly(RobotJelly(hot: CGPoint(x: robotClamp(point.x, 0, 240), y: robotClamp(point.y, 0, 240)), viewSize: viewSize))
    }

    /// Squeeze and antenna drag own the whole face, as upstream's gesture commit resets the robot.
    private func takeOver(face: RobotFace, at now: CFTimeInterval) {
        endMoment(instant: false)
        live = nil
        takeover = (face, now)
        shownState = .idle
        shownUntil = 0
        withoutActions {
            removePlanAnimations(keepBlink: false)
            applyFace(face)
        }
    }

    private func takeoverBlend(_ face: RobotFace, at now: CFTimeInterval) -> RobotFace {
        guard let takeover else { return face }
        let t = CGFloat(robotClamp((now - takeover.at) / 0.12, 0, 1))
        return t >= 1 ? face : takeover.face.mixed(face, RobotEase.outQuint(t))
    }

    private func stepGesture(now: CFTimeInterval, dt: Double) {
        switch gesture {
        case var .squeeze(s):
            if let p = dragPoint, hypot(p.x - gestureStart.x, p.y - gestureStart.y) > 4 {
                gesture = nil
                if takeover != nil { finishGesture(reaction: nil, at: now) }
                startJelly(at: now)
                stepGesture(now: now, dt: dt)
                return
            }
            let done = s.step(seconds: dt, reduced: reduceMotion)
            gesture = .squeeze(s)
            guard s.age >= RobotSqueeze.holdBeforeCommit || !s.held else { return }
            if takeover == nil { takeOver(face: currentFace(at: now).0, at: now) }
            let face = takeoverBlend(s.face(reduced: reduceMotion), at: now)
            applyFace(face)
            liveFace = face
            if done {
                gesture = nil
                finishGesture(reaction: nil, at: now)
            }
        case .jelly(var j):
            if let p = dragPoint { j.track(dx: p.x - gestureStart.x, dy: gestureStart.y - p.y, viewSize: viewSize) }
            let result = j.step(ms: dt * 1000, reduced: reduceMotion)
            gesture = .jelly(j)
            applyJelly(j)
            if let finished = result {
                gesture = nil
                live?.sim.dragging = false
                finishGesture(reaction: finished, at: now)
            }
        case .antenna(var drag, var sim):
            if let p = dragPoint {
                drag.track(dx: p.x - gestureStart.x, dy: gestureStart.y - p.y, viewSize: viewSize)
                sim.antennaGaze = gaze(at: p)
            }
            let done = drag.step(seconds: dt, reduced: reduceMotion)
            var face = sim.advance(to: (now - gestureClock) * 1000)
            face.headX = drag.tug.x * 0.12
            face.headY = drag.tug.y * 0.12
            face.headRotation = drag.tug.x * 0.08
            face.antennaX = drag.home.x + drag.dot.x
            face.antennaY = drag.home.y + drag.dot.y
            face = takeoverBlend(face, at: now)
            gesture = .antenna(drag, sim)
            applyFace(face)
            liveFace = face
            let hot = CGPoint(x: drag.home.x, y: robotClamp(drag.home.y, 20, 220))
            applyHeadPath(RobotGeometry.deformed(headPoints, hot: hot, pull: drag.pull))
            antennaLayer.transform = CATransform3DMakeScale(1 + drag.stretch, 1 - drag.stretch, 1)
            if done {
                gesture = nil
                finishGesture(reaction: drag.reacts ? .angry : nil, at: now)
            }
        case nil:
            break
        }
    }

    private func applyJelly(_ j: RobotJelly) {
        dragLayer.anchorPoint = CGPoint(x: j.anchor.x / 100, y: j.anchor.y / 100)
        dragLayer.position = CGPoint(x: j.anchor.x * 2.4, y: j.anchor.y * 2.4)
        dragLayer.transform = j.transform
        applyHeadPath(RobotGeometry.deformed(headPoints, hot: j.hot, pull: j.pull))
        for (eye, x) in zip(eyes, [CGFloat(86), 154]) {
            let o = RobotGeometry.jellyEyeOffset(eyeCenter: CGPoint(x: x, y: 126), hot: j.hot, pull: j.pull)
            eye.jelly.transform = CATransform3DMakeTranslation(o.dx, o.dy, 0)
        }
    }

    private func restoreDragVisuals() {
        dragLayer.transform = CATransform3DIdentity
        dragLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dragLayer.position = CGPoint(x: 120, y: 120)
        applyHeadPath(headPoints)
        antennaLayer.transform = CATransform3DIdentity
        for eye in eyes { eye.jelly.transform = CATransform3DIdentity }
    }

    private func finishGesture(reaction: RobotReaction?, at now: CFTimeInterval) {
        restoreDragVisuals()
        let wasTakeover = takeover != nil
        let (face, velocity) = currentFace(at: now)
        takeover = nil
        if let reaction, isIdleRest(at: now) {
            live = nil
            liveFace = nil
            install(RobotPlan.make(reaction == .angry ? .angry : .success, from: face, antennaVelocity: velocity,
                                   reduced: reduceMotion, seed: .random(in: 0...UInt64.max), fromDrag: true, time: time), at: now)
        } else if wasTakeover {
            liveFace = nil
            install(RobotPlan.make(.idle, from: face, antennaVelocity: velocity, reduced: reduceMotion, seed: .random(in: 0...UInt64.max),
                                   time: time), at: now)
        }
    }
}

struct RobotPauseReasons: OptionSet {
    let rawValue: Int
    static let manual = RobotPauseReasons(rawValue: 1 << 0)
    static let offscreen = RobotPauseReasons(rawValue: 1 << 1)
    static let hidden = RobotPauseReasons(rawValue: 1 << 2)
    static let occluded = RobotPauseReasons(rawValue: 1 << 3)
    static let screenLocked = RobotPauseReasons(rawValue: 1 << 4)
    static let displaysAsleep = RobotPauseReasons(rawValue: 1 << 5)
    static let sessionInactive = RobotPauseReasons(rawValue: 1 << 6)
}

/// Keeps the display link from retaining the view.
@MainActor
private final class RobotLinkTarget: NSObject {
    weak var view: RobotView?

    init(view: RobotView) { self.view = view }

    @objc func tick(_ link: CADisplayLink) {
        guard let view else {
            link.invalidate()
            return
        }
        view.tick()
    }
}

/// One eye: jelly offset > placement > blink squash > (ellipse, caret), plus clipped eyelids.
private final class RobotEyeLayers {
    let jelly = CALayer()
    let group = CALayer()
    let blink = CALayer()
    let base = CAShapeLayer()
    let caretHolder = CALayer()
    let caret = CAShapeLayer()
    let lidClip = CALayer()
    let top = CALayer()
    let bottom = CALayer()

    func install(in parent: CALayer) {
        parent.addSublayer(jelly)
        jelly.addSublayer(group)
        group.addSublayer(blink)
        blink.addSublayer(base)
        blink.addSublayer(caretHolder)
        caretHolder.addSublayer(caret)
        group.addSublayer(lidClip)
        lidClip.bounds = CGRect(x: -40, y: -54, width: 80, height: 108)
        lidClip.masksToBounds = true
        for lid in [top, bottom] {
            lid.bounds = CGRect(x: 0, y: 0, width: 140, height: 90)
            lidClip.addSublayer(lid)
        }
        top.anchorPoint = CGPoint(x: 0.5, y: 1)
        bottom.anchorPoint = CGPoint(x: 0.5, y: 0)
        for l in [jelly, group, blink, base, caretHolder, caret, lidClip, top, bottom] { l.position = .zero }
    }
}
