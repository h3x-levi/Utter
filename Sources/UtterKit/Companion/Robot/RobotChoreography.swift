import AppKit

/// The upstream component's actions, by their canonical names.
enum RobotState: CaseIterable {
    case idle, bored, waiting, waitingWrap, input, send, success, failure, warning, inspect
    case angry, blocked, error, surprise, love, random, sleep, wake

    /// Stays until the next `play`; every other state plays once and settles back to idle.
    var persists: Bool {
        switch self {
        case .waiting, .waitingWrap, .input, .sleep: return true
        default: return false
        }
    }

    /// Antenna flash period in seconds, for the states upstream flashes.
    var flashPeriod: Double? {
        switch self {
        case .input: return 1.2
        case .send, .warning: return 1
        case .success: return 1.1
        case .angry, .blocked: return 0.9
        case .error, .surprise: return 0.8
        default: return nil
        }
    }

    func isNoOp(whenShowing current: RobotState) -> Bool {
        switch self {
        case .wake: return current != .sleep
        case .sleep: return current == .sleep
        case .input: return current == .input
        default: return false
        }
    }
}

struct RobotPose: Equatable {
    var w: CGFloat
    var h: CGFloat
    var topY: CGFloat
    var bottomY: CGFloat
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0

    static let idle = RobotPose(w: 54, h: 58, topY: -36, bottomY: 36)

    func mixed(_ o: RobotPose, _ t: CGFloat) -> RobotPose {
        RobotPose(w: robotLerp(w, o.w, t), h: robotLerp(h, o.h, t), topY: robotLerp(topY, o.topY, t),
                  bottomY: robotLerp(bottomY, o.bottomY, t), topLeft: robotLerp(topLeft, o.topLeft, t),
                  topRight: robotLerp(topRight, o.topRight, t))
    }
}

enum RobotExpression: String {
    case idle, happy, sad, angry, sleepy, input, sleep, surprise

    var pose: RobotPose {
        switch self {
        case .idle: return .idle
        case .happy: return RobotPose(w: 58, h: 58, topY: -36, bottomY: 0)
        case .sad: return RobotPose(w: 58, h: 58, topY: -5, bottomY: 36, topLeft: -16, topRight: 16)
        case .angry: return RobotPose(w: 58, h: 58, topY: -5, bottomY: 36, topLeft: 16, topRight: -16)
        case .sleepy: return RobotPose(w: 58, h: 56, topY: 0, bottomY: 36)
        case .input: return RobotPose(w: 12, h: 78, topY: -44, bottomY: 44)
        case .sleep: return RobotPose(w: 62, h: 10, topY: -20, bottomY: 20)
        case .surprise: return RobotPose(w: 68, h: 68, topY: -40, bottomY: 40)
        }
    }
}

struct RobotHeadKey {
    var offset: Double
    var x: CGFloat = 0
    var y: CGFloat = 0
    var scale: CGFloat = 1
    var scaleY: CGFloat?
    var rotation: CGFloat = 0
    var ease: RobotEase?
}

/// A head keyframe animation with fill-forwards, like the upstream Web Animations calls.
/// With `css` set, each key's values come from that CSS transform list about `origin` instead.
struct RobotHeadMotion {
    var start: Double
    var duration: Double
    var keys: [RobotHeadKey]
    var ease: RobotEase
    var held: RobotHeadKey
    var css: [[RobotTransformFunction]] = []
    var origin = RobotGeometry.headCenter
    var iterations = 1

    func value(at t: Double) -> RobotHeadKey {
        guard t >= start, keys.count > 1 else { return held }
        let raw = (t - start) / max(1, duration)
        let p = Double(ease(CGFloat(raw >= Double(iterations) ? 1 : raw.truncatingRemainder(dividingBy: 1))))
        var i = 0
        while i < keys.count - 2, p > keys[i + 1].offset { i += 1 }
        let a = keys[i], b = keys[i + 1]
        var u = CGFloat(robotClamp((p - a.offset) / max(1e-9, b.offset - a.offset), 0, 1))
        if let e = a.ease { u = e(u) }
        if css.count == keys.count {
            let list = zip(css[i], css[i + 1]).map { $0.mixed($1, u) }
            var key = RobotGeometry.decompose(RobotGeometry.matrix(list, origin: origin))
            key.offset = p
            return key
        }
        return RobotHeadKey(offset: p, x: robotLerp(a.x, b.x, u), y: robotLerp(a.y, b.y, u), scale: robotLerp(a.scale, b.scale, u),
                            scaleY: a.scaleY == nil && b.scaleY == nil ? nil : robotLerp(a.scaleY ?? a.scale, b.scaleY ?? b.scale, u),
                            rotation: robotLerp(a.rotation, b.rotation, u))
    }
}

extension RobotHeadMotion {
    /// Web Animations keyframes: evenly spaced, `ease` on every segment, `iterations` repeats, then held.
    init?(css lists: [[RobotTransformFunction]], origin: CGPoint, start: Double, duration: Double, iterations: Int = 1,
          ease: RobotEase, held: RobotHeadKey) {
        guard lists.count > 1, duration > 0 else { return nil }
        let n = Double(lists.count - 1)
        self.init(start: start, duration: duration, keys: lists.indices.map { RobotHeadKey(offset: Double($0) / n, ease: ease) },
                  ease: .linear, held: held, css: lists, origin: origin, iterations: max(1, iterations))
    }
}

/// An eye-look routine like upstream's bored one: each target is held for its time, then the eyes rest.
struct RobotGaze {
    var targets: [(point: CGPoint, hold: Double)]
    var speed: CGFloat
    var index = 0
    var nextAt: Double
}

struct RobotPointer {
    var x: CGFloat
    var y: CGFloat
    var influence: CGFloat
    var lastMove: Double
}

/// Random blink times for one loop of the idle animation; reseeded each time a plan is built.
struct RobotBlinks {
    let period: Double
    let events: [(at: Double, duration: Double)]

    /// `rate` above 1 blinks more often: every gap is divided by it, as the time-of-day `blink` does upstream.
    init(random r: inout RobotRandom, count: Int = 6, rate: Double = 1) {
        var list: [(Double, Double)] = []
        var at = (1800 + Double(r.next()) * 1800) / rate
        for _ in 0..<count {
            let duration = 150 + Double(r.next()) * 70
            list.append((at, duration))
            at += duration + (1900 + Double(r.next()) * 2600) / rate
        }
        events = list
        // The next loop's first blink lands where a seventh would have, so every gap keeps upstream's spacing.
        period = RobotPlan.framed(at - list[0].0)
    }

    func value(at phase: Double) -> CGFloat {
        for e in events where phase >= e.at && phase < e.at + e.duration {
            let t = CGFloat((phase - e.at) / e.duration)
            return t < 0.5 ? robotLerp(1, 0.08, t * 2) : robotLerp(0.08, 1, t * 2 - 1)
        }
        return 1
    }
}

/// Idle eye drift: a loop of random look targets that starts and ends at rest.
struct RobotWander {
    let period: Double
    let events: [(at: Double, target: CGPoint)]

    init(random r: inout RobotRandom, count: Int = 10) {
        var list: [(Double, CGPoint)] = []
        // Starts after the intro's spill ends, so the hand-over to the loop happens while the eyes rest.
        var t = RobotPlan.settle + 400
        for _ in 0..<count {
            let ampX = 12 + r.next() * 13
            let ampY = 5 + r.next() * 9
            list.append((t, CGPoint(x: (r.next() * 2 - 1) * ampX, y: (r.next() * 2 - 1) * ampY)))
            t += 1150 + Double(r.next()) * 1900
        }
        list.append((t, .zero))
        events = list
        period = RobotPlan.framed(t + RobotPlan.settle + Double(r.next()) * 1450)
    }
}

/// A port of the upstream per-frame update (morph, blink, look, head follow, draw), stepped offline
/// to build Core Animation keyframes and live while a gesture or the pointer drives the robot.
struct RobotSim {
    var now: Double = 0
    private var lastStep: Double = 0
    var reduced = false

    var expression = RobotExpression.idle
    var pose = RobotPose.idle
    private var fromPose = RobotPose.idle
    private var toPose = RobotPose.idle
    private var morphStart: Double = 0
    private var morphDuration: Double = 0
    private var morphEase = RobotEase.outQuint
    private var morphProgress: CGFloat = 1
    var lock = false
    var sleeping = false
    var headCenteringUntil: Double = 0

    var look = CGPoint.zero
    var wanderTarget = CGPoint.zero
    private var wander: [(at: Double, target: CGPoint)] = []
    private var wanderIndex = 0
    var boredStart: Double?
    var gaze: RobotGaze?
    /// Time-of-day eyelid drop, added to every top lid except while typing or asleep.
    var lid: CGFloat = 0
    var pointer: RobotPointer?
    var antennaGaze: CGPoint?
    var dragging = false

    var followX = RobotSpring()
    var followY = RobotSpring()
    var followRotation = RobotSpring()
    var head: RobotHeadMotion?

    private var blinks: RobotBlinks?
    private var blinkOrigin: Double = 0
    private var blinkStart: Double?
    private var blinkDuration: Double = 0
    private var lastBlinkPhase: Double = -1

    var nod: Double?
    var bob: (start: Double, duration: Double, amp: CGFloat)?
    var angryDrop: (start: Double, release: Double?)?
    var shake: (start: Double, duration: Double)?
    var wink: (start: Double, duration: Double)?
    var errorSweep: Double?
    var warning: Double?
    var waiting: (start: Double, wrap: Bool)?
    var inspect: Double?
    var failure: Double?
    var love: Double?
    var random: Double?

    mutating func setState(_ e: RobotExpression, _ duration: Double, ease: RobotEase = .outQuint, keepLock: Bool = false,
                           pose target: RobotPose? = nil) {
        expression = e
        sleeping = e == .sleep
        if e == .idle && !keepLock { release() }
        startMorph(target ?? e.pose, duration, ease)
    }

    mutating func blink(_ duration: Double) {
        blinkStart = now
        blinkDuration = duration
    }

    /// Eases the head transform back to rest about the motion's own origin, as CSS interpolates to `none`.
    mutating func homeHead(_ duration: Double) {
        guard let h = head, !reduced else { head = nil; return }
        let from = RobotGeometry.decompose(RobotGeometry.matrix(headValue), about: h.origin)
        let list = [RobotTransformFunction(name: "translate", args: [from.x, from.y]),
                    RobotTransformFunction(name: "rotate", args: [from.rotation]),
                    RobotTransformFunction(name: "scale", args: [from.scale, from.scaleY ?? from.scale])]
        let home = [RobotTransformFunction(name: "translate", args: [0, 0]), RobotTransformFunction(name: "rotate", args: [0]),
                    RobotTransformFunction(name: "scale", args: [1, 1])]
        head = RobotHeadMotion(css: [list, home], origin: h.origin, start: now, duration: duration, ease: .head, held: headValue)
    }

    mutating func startMorph(_ target: RobotPose, _ duration: Double, _ ease: RobotEase = .outQuint) {
        fromPose = pose
        toPose = target
        morphStart = now
        morphDuration = reduced ? 0 : duration
        morphEase = ease
    }

    mutating func release() {
        lock = false
        headCenteringUntil = 0
    }

    mutating func animateHead(_ keys: [RobotHeadKey], _ duration: Double, ease: RobotEase = .head, delay: Double = 0) {
        guard !reduced else { head = nil; return }
        head = RobotHeadMotion(start: now + delay, duration: duration, keys: keys, ease: ease, held: headValue)
    }

    mutating func holdHead(y: CGFloat) {
        guard !reduced else { return }
        let key = RobotHeadKey(offset: 0, y: y)
        head = RobotHeadMotion(start: now, duration: 1, keys: [key, key], ease: .linear, held: key)
    }

    var headValue: RobotHeadKey { head?.value(at: now) ?? RobotHeadKey(offset: 0) }

    mutating func startAmbient(wander w: RobotWander, blinks b: RobotBlinks, at t: Double) {
        wander = w.events.map { ($0.at + t, $0.target) }
        wanderIndex = 0
        wanderTarget = .zero
        blinks = b
        blinkOrigin = t
        lastBlinkPhase = -1
    }

    /// Upstream wanders whenever nothing locks the eyes, moments included; nil stops it.
    mutating func useWander(_ w: RobotWander?, from t: Double = 0) {
        wander = w?.events.map { ($0.at + t, $0.target) } ?? []
        wanderIndex = 0
    }

    mutating func useBlinks(_ b: RobotBlinks, from t: Double) {
        blinks = b
        blinkOrigin = t
        lastBlinkPhase = -1
    }

    mutating func advance(to t: Double) -> RobotFace {
        let dt = max(0, t - lastStep)
        lastStep = t
        now = t
        updateMorph()
        updateBlink()
        updateLook(dt)
        updateFollow(dt)
        return draw()
    }

    private mutating func updateMorph() {
        guard morphDuration > 0 else {
            pose = toPose
            morphProgress = 1
            return
        }
        let t = CGFloat(robotClamp((now - morphStart) / morphDuration, 0, 1))
        morphProgress = morphEase(t)
        pose = fromPose.mixed(toPose, morphProgress)
        if t >= 1 { morphDuration = 0 }
    }

    private mutating func updateBlink() {
        guard !reduced, !sleeping, expression != .input else {
            blinkStart = nil
            return
        }
        if let s = blinkStart, now - s >= blinkDuration { blinkStart = nil }
        guard let blinks else { return }
        let elapsed = now - blinkOrigin
        let phase = elapsed.truncatingRemainder(dividingBy: blinks.period)
        if blinkStart == nil, !lock {
            let wrapped = phase < lastBlinkPhase
            if let e = blinks.events.first(where: { wrapped ? ($0.at > lastBlinkPhase || $0.at <= phase) : ($0.at > lastBlinkPhase && $0.at <= phase) }) {
                let since = phase >= e.at ? phase - e.at : phase + blinks.period - e.at
                blinkStart = now - since
                blinkDuration = e.duration
            }
        }
        lastBlinkPhase = phase
    }

    private var blinkValue: CGFloat {
        guard let s = blinkStart else { return 1 }
        let t = CGFloat(robotClamp((now - s) / blinkDuration, 0, 1))
        return t < 0.5 ? robotLerp(1, 0.08, t * 2) : robotLerp(0.08, 1, t * 2 - 1)
    }

    private var pointerFresh: Bool { pointer.map { now - $0.lastMove < 900 } ?? false }

    private mutating func updateLook(_ dt: Double) {
        if let b = boredStart {
            let e = now - b
            if e >= 3120 {
                boredStart = nil
                wanderTarget = .zero
            } else {
                wanderTarget = e < 1400 ? CGPoint(x: -18, y: -16) : (e < 2800 ? CGPoint(x: 18, y: -16) : .zero)
            }
        }
        if var g = gaze, now >= g.nextAt {
            if g.index < g.targets.count {
                wanderTarget = g.targets[g.index].point
                g.nextAt = now + g.targets[g.index].hold
                g.index += 1
                gaze = g
            } else {
                gaze = nil
                wanderTarget = .zero
            }
        }
        if !lock, boredStart == nil, gaze == nil, !sleeping, expression != .input {
            while wanderIndex < wander.count, wander[wanderIndex].at <= now {
                wanderTarget = wander[wanderIndex].target
                wanderIndex += 1
            }
        }
        let gazeLocked = lock && antennaGaze == nil
        let mix: CGFloat
        if let p = pointer, !gazeLocked, boredStart == nil, gaze == nil, pointerFresh, p.influence > 0.001, !sleeping, expression != .input {
            mix = pow(p.influence, 1.6)
        } else {
            mix = 0
        }
        let target: CGPoint
        if let gaze = antennaGaze {
            target = gaze
        } else if gazeLocked {
            target = .zero
        } else {
            let p = pointer.map { CGPoint(x: $0.x, y: $0.y) } ?? .zero
            target = CGPoint(x: robotLerp(wanderTarget.x, p.x, mix), y: robotLerp(wanderTarget.y, p.y, mix))
        }
        let speed: CGFloat = antennaGaze != nil ? 0.42 : (gazeLocked ? 0.40 : (dragging ? 0.42 : (boredStart != nil ? 0.5
            : (gaze?.speed ?? (mix > 0.05 ? 0.28 : 0.16)))))
        let k = 1 - pow(1 - robotClamp(speed, 0.02, 0.9), CGFloat(dt / 16.67))
        look.x += (target.x - look.x) * k
        look.y += (target.y - look.y) * k
        if sleeping {
            let decay = pow(0.92, CGFloat(dt / 33.3))
            look.x *= decay
            look.y *= decay
        }
        if reduced {
            look = .zero
            wanderTarget = .zero
            boredStart = nil
        } else if let s = errorSweep {
            let t = robotClamp((now - s) / 980, 0, 1)
            look = CGPoint(x: Self.errorEyeSweep(CGFloat(t)) * 30, y: 0)
            if t >= 1 { errorSweep = nil }
        }
    }

    private mutating func updateFollow(_ dt: Double) {
        if reduced {
            followX = RobotSpring()
            followY = RobotSpring()
            followRotation = RobotSpring()
            return
        }
        let inRange = pointerFresh && (pointer?.influence ?? 0) > 0.03
        let follow = inRange && !dragging && !sleeping && boredStart == nil && gaze == nil && now >= headCenteringUntil && !lock
        let source = follow ? CGPoint(x: pointer?.x ?? 0, y: pointer?.y ?? 0) : look
        let nx = robotClamp(source.x / 48, -1, 1), ny = robotClamp(source.y / 34, -1, 1)
        let seconds = min(dt, 34) / 1000
        followRotation.step(toward: robotClamp(nx * ny, -1, 1) * 8, stiffness: follow ? 70 : 56, damping: follow ? 15 : 13, seconds: seconds)
        followX.step(toward: follow ? nx * 4.2 : 0, stiffness: follow ? 95 : 80, damping: follow ? 16 : 14, seconds: seconds)
        followY.step(toward: follow ? ny * 4.2 : 0, stiffness: follow ? 95 : 80, damping: follow ? 16 : 14, seconds: seconds)
        if !follow {
            for key in [\RobotSim.followX, \.followY, \.followRotation] where abs(self[keyPath: key].value) < 0.01 && abs(self[keyPath: key].velocity) < 0.01 {
                self[keyPath: key] = RobotSpring()
            }
        }
    }

    static func errorEyeSweep(_ t: CGFloat) -> CGFloat {
        func segment(_ a: CGFloat, _ b: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
            t <= a ? from : (t >= b ? to : robotLerp(from, to, RobotEase.smooth((t - a) / (b - a))))
        }
        if t < 0.16 { return segment(0, 0.16, 0, -1) }
        if t < 0.40 { return segment(0.16, 0.40, -1, 1) }
        if t < 0.64 { return segment(0.40, 0.64, 1, -0.88) }
        if t < 0.84 { return segment(0.64, 0.84, -0.88, 0.58) }
        return segment(0.84, 1, 0.58, 0)
    }

    func draw() -> RobotFace {
        var face = RobotFace()
        let p = pose
        var nodY: CGFloat = 0, nodScale: CGFloat = 1
        if let start = nod {
            let e = now - start
            let depth = e < 150 ? e / 150 : (e < 300 ? 1 - (e - 150) / 150 : (e < 450 ? (e - 300) / 150 : (e < 760 ? 1 - (e - 450) / 310 : 0)))
            let d = CGFloat(robotClamp(depth, 0, 1))
            nodY = 31 * d
            nodScale = 1 - 0.3 * d
        }
        var dropY: CGFloat = 0
        if let drop = angryDrop {
            let t = CGFloat(robotClamp((now - drop.start) / 680, 0, 1))
            dropY = t >= 1 ? 4.8 : 4.8 * (1 - exp(-5.2 * t) * cos(8.6 * t))
            if let r = drop.release { dropY *= 1 - RobotEase.outQuint(CGFloat(robotClamp((now - r) / 500, 0, 1))) }
        }
        var bobY: CGFloat = 0
        if let b = bob {
            let t = CGFloat(robotClamp((now - b.start) / b.duration, 0, 1))
            bobY = sin(t * .pi * 4) * b.amp * (1 - 0.38 * t)
        }
        var surpriseScale: CGFloat = 1
        if let s = shake {
            let t = CGFloat(robotClamp((now - s.start) / s.duration, 0, 1))
            surpriseScale = 1 + 0.022 * sin(t * .pi * 8) * (1 - 0.18 * t)
        }
        let eyeHeight = max(2.6, p.h * nodScale * surpriseScale)
        let merge = expression == .input ? morphProgress : 0
        let spread = expression == .surprise ? 3.4 * RobotEase.outQuint(robotClamp((p.w - 34) / 34, 0, 1)) : 0

        func eye(left: Bool) -> RobotEyeFace {
            let cx = robotLerp(left ? 86 - spread : 154 + spread, 120, merge)
            let squash = RobotGeometry.edgeSquash(projectedX: cx + look.x, left: left)
            let baseW = p.w * surpriseScale
            let w = baseW * (1 - 0.22 * squash)
            let shift = (baseW - w) * 0.58 * (left ? 1 : -1) * (1 - merge)
            var e = RobotEyeFace(x: cx + look.x + shift, y: 126 + look.y + nodY + dropY + bobY)
            e.width = w
            e.height = eyeHeight * (1 - 0.08 * squash)
            e.caret = merge
            e.caretWidth = p.w
            e.caretHeight = p.h
            e.topY = p.topY
            e.topAngle = left ? p.topLeft : p.topRight
            e.bottomY = p.bottomY
            return e
        }
        face.left = eye(left: true)
        face.right = eye(left: false)

        let h = headValue
        let r = followRotation.value * .pi / 180
        face.headX = followX.value + h.x * cos(r) - h.y * sin(r)
        face.headY = followY.value + h.x * sin(r) + h.y * cos(r)
        face.headRotation = followRotation.value + h.rotation
        face.headScaleX = h.scale
        face.headScaleY = h.scaleY ?? h.scale
        face.blink = blinkValue

        drawWarning(&face)
        drawWaiting(&face)
        drawInspect(&face)
        drawFailure(&face)
        drawLove(&face)
        drawRandom(&face)
        if reduced { drawReduced(&face) }
        if let w = wink, now < w.start + w.duration {
            face.right.scaleY *= 1 - 0.92 * sin(.pi * CGFloat(robotClamp((now - w.start) / w.duration, 0, 1)))
        }
        if lid != 0, expression != .input, expression != .sleep {
            face.left.topY += lid
            face.right.topY += lid
        }
        return face
    }

    // MARK: Upstream extension draws

    private static let warningPhases: [Double] = [0, 400, 1000, 1200, 1500, 1700, 2200, 2300, 3100, 3327]

    private func drawWarning(_ face: inout RobotFace) {
        guard let start = warning else { return }
        let ph = Self.warningPhases
        let el = robotClamp(now - start, 0, ph[9])
        func segment(_ a: Double, _ b: Double, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
            el <= a ? from : (el >= b ? to : robotLerp(from, to, RobotEase.smooth(CGFloat((el - a) / (b - a)))))
        }
        let release = el > ph[8] ? 1 - RobotEase.smooth(CGFloat((el - ph[8]) / 227)) : 1
        let proximity = (el < ph[1] ? RobotEase.smooth(CGFloat(el / 400)) : 1) * release
        let lids = proximity
        let press: CGFloat = 4.2
        var lidShift: CGFloat = 0, farLow: CGFloat = 0, farDeep: CGFloat = 0
        switch el {
        case ph[1]..<ph[2]: lidShift = el < ph[1] + 120 ? segment(ph[1], ph[1] + 120, 0, press) : press
        case ph[2]..<ph[3]:
            lidShift = segment(ph[2], ph[3], press, 20.5)
            farLow = segment(ph[2], ph[3], 0, 2.4)
            farDeep = segment(ph[2], ph[3], 0, 3.5)
        case ph[3]..<ph[4]:
            lidShift = 20.5
            farLow = 2.4
            farDeep = 3.5
        case ph[4]..<ph[5]:
            lidShift = segment(ph[4], ph[5], 20.5, -6.5)
            farLow = segment(ph[4], ph[5], 2.4, 0)
            farDeep = segment(ph[4], ph[5], 3.5, 0)
        case ph[5]..<ph[6]: lidShift = -6.5
        case ph[6]..<ph[7]: lidShift = segment(ph[6], ph[7], -6.5, press)
        case ph[7]..<ph[8]: lidShift = press
        case ph[8]...: lidShift = press * release
        default: break
        }
        face.left.x = robotLerp(86, 102, proximity)
        face.left.y = robotLerp(126, 125.5, proximity)
        face.left.rotation = robotLerp(0, -6.5, proximity)
        face.left.scaleX = robotLerp(1, 1.37, proximity)
        face.left.scaleY = robotLerp(1, 1.40, proximity)
        face.right.x = robotLerp(154, 174.5, proximity)
        face.right.y = robotLerp(126, 133.5, proximity) + farLow
        face.right.rotation = robotLerp(0, 7.5, proximity)
        face.right.scaleX = robotLerp(1, 0.68, proximity)
        face.right.scaleY = robotLerp(1, 0.99, proximity)
        face.left.topY = robotLerp(-36, -8, lids) + lidShift
        face.left.topAngle = robotLerp(0, 25, lids)
        face.right.topY = robotLerp(-36, -10, lids) + lidShift * 0.95 + farDeep
        face.right.topAngle = robotLerp(0, -17, lids)
        face.left.bottomY = robotLerp(36, 35.3, lids)
        face.right.bottomY = robotLerp(36, 35.6, lids)
        face.left.bottomAngle = 0
        face.right.bottomAngle = 0
    }

    private func drawWaiting(_ face: inout RobotFace) {
        guard let w = waiting else { return }
        let elapsed = max(0, now - w.start)
        if w.wrap {
            let pose = RobotWrap.pose(at: elapsed.truncatingRemainder(dividingBy: RobotWrap.cycle))
            for (key, eye) in [(\RobotFace.left, pose[0]), (\RobotFace.right, pose[1])] {
                face[keyPath: key].x = eye.x
                face[keyPath: key].y = 126
                face[keyPath: key].width = eye.width
                face[keyPath: key].height = eye.height
            }
            return
        }
        let angle = CGFloat(elapsed.truncatingRemainder(dividingBy: 3200) / 3200) * .pi * 4
        let c = cos(angle), s = sin(angle)
        let foreshorten = 0.72 + 0.28 * abs(c)
        face.left.x = 120 - 34 * c
        face.right.x = 120 + 34 * c
        face.left.scaleX = foreshorten * (1 + 0.08 * s)
        face.left.scaleY = 1 + 0.08 * s
        face.right.scaleX = foreshorten * (1 - 0.08 * s)
        face.right.scaleY = 1 - 0.08 * s
        face.left.rotation = 0
        face.right.rotation = 0
    }

    private func drawInspect(_ face: inout RobotFace) {
        guard let start = inspect else { return }
        let el = robotClamp(now - start, 0, 6560)
        func move(_ a: Double, _ b: Double, _ from: CGFloat, _ to: CGFloat) -> CGFloat {
            robotLerp(from, to, RobotEase.smooth(CGFloat((el - a) / (b - a))))
        }
        let blend = el < 220 ? RobotEase.smooth(CGFloat(el / 220)) : (el >= 6300 ? 1 - RobotEase.smooth(CGFloat((el - 6300) / 260)) : 1)
        let shift: CGFloat
        switch el {
        case ..<1100: shift = 0
        case ..<1500: shift = move(1100, 1500, 0, 16)
        case ..<2060: shift = 16
        case ..<2220: shift = move(2060, 2220, 16, -16)
        case ..<2800: shift = -16
        case ..<2940: shift = move(2800, 2940, -16, 0)
        case ..<3700: shift = 0
        case ..<3840: shift = move(3700, 3840, 0, 16)
        case ..<4460: shift = 16
        case ..<4640: shift = move(4460, 4640, 16, 0)
        default: shift = 0
        }
        for (key, x) in [(\RobotFace.left, CGFloat(86)), (\RobotFace.right, CGFloat(154))] {
            face[keyPath: key].x = x
            face[keyPath: key].y = 126 + shift
            face[keyPath: key].rotation = 0
            face[keyPath: key].scaleX = 1
            face[keyPath: key].scaleY = 1
            face[keyPath: key].topY = robotLerp(-36, -8, blend)
            face[keyPath: key].bottomY = robotLerp(36, 8, blend)
            face[keyPath: key].topAngle = 0
            face[keyPath: key].bottomAngle = 0
        }
    }

    private func drawFailure(_ face: inout RobotFace) {
        guard let start = failure else { return }
        let e = max(0, now - start)
        let drop: CGFloat
        if e < 720 {
            drop = 4.8 * RobotEase.smooth(CGFloat(e / 720))
        } else if e < 1440 {
            drop = 4.8
        } else {
            drop = 4.8 * (1 - RobotEase.smooth(CGFloat((e - 1440) / 520)))
        }
        face.left.y += drop
        face.right.y += drop
    }

    private func drawLove(_ face: inout RobotFace) {
        guard let start = love else { return }
        let el = robotClamp(now - start, 0, 2880)
        let holdEnd = 240.0 + 760 * 3
        let morph: CGFloat = reduced ? 1 : (el < 240 ? RobotEase.smooth(CGFloat(el / 240)) : (el > holdEnd ? 1 - RobotEase.smooth(CGFloat((el - holdEnd) / 360)) : 1))
        var pulse: CGFloat = 0
        if !reduced, el >= 240, el <= holdEnd {
            let phase = CGFloat((el - 240).truncatingRemainder(dividingBy: 760) / 760)
            func swell(_ c: CGFloat, _ w: CGFloat) -> CGFloat { max(0, 1 - abs(phase - c) / w) }
            pulse = max(RobotEase.smooth(swell(0.12, 0.12)), 0.6 * RobotEase.smooth(swell(0.36, 0.12)))
        }
        let scale = 1 + 0.155 * pulse
        let tilt: CGFloat = 42
        let baseY = 126 + 40 * cos(tilt * .pi / 180)
        for (key, restX, side) in [(\RobotFace.left, CGFloat(86), CGFloat(-1)), (\RobotFace.right, CGFloat(154), CGFloat(1))] {
            let x = robotLerp(restX, 120 - side * 13, morph)
            let y = robotLerp(126, baseY, morph)
            face[keyPath: key].x = 120 + scale * (x - 120)
            face[keyPath: key].y = 126 + scale * (y - 126)
            face[keyPath: key].rotation = side * tilt * morph
            face[keyPath: key].scaleX = scale
            face[keyPath: key].scaleY = scale
            face[keyPath: key].centerY = robotLerp(0, -40, morph)
            face[keyPath: key].width = 2 * robotLerp(27, 28, morph)
            face[keyPath: key].height = 2 * robotLerp(29, 43, morph)
            face[keyPath: key].topY = robotLerp(-36, -150, morph)
            face[keyPath: key].bottomY = robotLerp(36, 150, morph)
            face[keyPath: key].topAngle = 0
            face[keyPath: key].bottomAngle = 0
        }
    }

    private func drawRandom(_ face: inout RobotFace) {
        guard let start = random else { return }
        let el = now - start
        let p = RobotReel.period, r = RobotReel.radius, half = Double.pi * Double(r) / 2
        for (key, reel) in [(\RobotFace.left, RobotReel.pair[0]), (\RobotFace.right, RobotReel.pair[1])] where el < reel.endTime {
            let position = reduced ? p * 0.3 : reel.position(at: el)
            var offset = (position.truncatingRemainder(dividingBy: p) + p).truncatingRemainder(dividingBy: p)
            if offset > p / 2 { offset -= p }
            let visible = abs(offset) < half
            let angle = visible ? CGFloat(offset) / r : (offset < 0 ? -.pi / 2 : .pi / 2)
            let front = visible ? cos(angle) : 0
            let side = 1 - front
            let sign: CGFloat = angle > 0 ? 1 : (angle < 0 ? -1 : 0)
            face[keyPath: key].centerY = r * sin(angle) + sign * 6 * side * side * side
            face[keyPath: key].width = 54 - RobotReel.squeeze * RobotEase.smooth(side)
            face[keyPath: key].height = 2 * 29 * front
            face[keyPath: key].topY = -150
            face[keyPath: key].bottomY = 150
            face[keyPath: key].topAngle = 0
            face[keyPath: key].bottomAngle = 0
        }
    }

    private func drawReduced(_ face: inout RobotFace) {
        func place(_ key: WritableKeyPath<RobotFace, RobotEyeFace>, x: CGFloat, y: CGFloat = 126, sx: CGFloat = 1, sy: CGFloat = 1) {
            face[keyPath: key].x = x
            face[keyPath: key].y = y
            face[keyPath: key].rotation = 0
            face[keyPath: key].scaleX = sx
            face[keyPath: key].scaleY = sy
        }
        func lids(_ key: WritableKeyPath<RobotFace, RobotEyeFace>, top: CGFloat, bottom: CGFloat, angle: CGFloat = 0) {
            face[keyPath: key].topY = top
            face[keyPath: key].bottomY = bottom
            face[keyPath: key].topAngle = angle
            face[keyPath: key].bottomAngle = 0
        }
        if waiting != nil {
            place(\.left, x: 100, sx: 0.92)
            place(\.right, x: 140, sx: 0.92)
            for key in [\RobotFace.left, \.right] {
                face[keyPath: key].width = 54
                face[keyPath: key].height = 58
            }
        } else if inspect != nil {
            place(\.left, x: 86)
            place(\.right, x: 154)
            lids(\.left, top: -8, bottom: 8)
            lids(\.right, top: -8, bottom: 8)
        } else if warning != nil {
            place(\.left, x: 100, sx: 1.16, sy: 1.10)
            place(\.right, x: 172, y: 132, sx: 0.84, sy: 0.96)
            lids(\.left, top: -18, bottom: 35, angle: 8)
            lids(\.right, top: -20, bottom: 36, angle: -7)
        } else if errorSweep != nil {
            lids(\.left, top: -5, bottom: 36, angle: -15)
            lids(\.right, top: -5, bottom: 36, angle: 15)
        }
    }
}

enum RobotTail {
    case ambient
    case loop(Double)
    case hold
    /// A script that repeats from the end of the intro until replaced: a moment's loop section.
    case pass(RobotScript)
}

/// The upstream async action bodies, flattened into timed steps.
struct RobotScript {
    private(set) var steps: [(at: Double, run: (inout RobotSim) -> Void)] = []
    private(set) var cursor: Double = 0

    mutating func run(_ step: @escaping (inout RobotSim) -> Void) { steps.append((cursor, step)) }
    mutating func wait(_ ms: Double) { cursor += ms }

    mutating func prepare(_ duration: Double, pause: Double) {
        run { sim in
            sim.lock = true
            sim.wanderTarget = .zero
            sim.headCenteringUntil = sim.now + duration + pause
            if sim.expression != .idle { sim.setState(.idle, min(140, duration), keepLock: true) }
        }
        wait(duration + pause)
    }

    mutating func lockFromDrag() {
        run { sim in
            sim.lock = true
            sim.look = .zero
            sim.wanderTarget = .zero
            sim.headCenteringUntil = sim.now + 120
        }
    }

    mutating func returnToIdle(_ duration: Double, ease: RobotEase = .outQuint) {
        run { sim in
            sim.setState(.idle, duration, ease: ease, keepLock: true)
            sim.headCenteringUntil = max(sim.headCenteringUntil, sim.now + duration)
        }
        wait(duration)
        run { sim in if sim.expression == .idle { sim.release() } }
    }

    static func make(_ state: RobotState, fromDrag: Bool, resting: Bool) -> (RobotScript, RobotTail) {
        var s = RobotScript()
        let bezierIn = RobotEase.bezier(0.38, 0, 0.25, 1), bezierOut = RobotEase.bezier(0.35, 0, 0.22, 1)
        if resting {
            switch state {
            case .waiting, .waitingWrap:
                s.run { $0.lock = true; $0.waiting = ($0.now, state == .waitingWrap) }
                return (s, .loop(state == .waitingWrap ? RobotWrap.cycle : 3200))
            case .input:
                s.run { $0.lock = true; $0.setState(.input, 0, keepLock: true) }
                return (s, .hold)
            case .sleep:
                s.run { $0.lock = true; $0.setState(.sleep, 0, keepLock: true); $0.holdHead(y: 4) }
                return (s, .hold)
            default:
                return (s, .ambient)
            }
        }
        switch state {
        case .idle:
            return (s, .ambient)
        case .bored:
            s.prepare(180, pause: 620)
            s.run { $0.release(); $0.look = .zero; $0.boredStart = $0.now }
            s.wait(3120)
        case .waiting, .waitingWrap:
            s.prepare(120, pause: 0)
            s.run { $0.lock = true; $0.look = .zero; $0.waiting = ($0.now, state == .waitingWrap) }
            return (s, .loop(state == .waitingWrap ? RobotWrap.cycle : 3200))
        case .input:
            s.prepare(140, pause: 320)
            s.run { $0.setState(.input, 210, keepLock: true) }
            s.wait(210)
            return (s, .hold)
        case .send:
            s.prepare(180, pause: 320)
            s.run {
                $0.nod = $0.now
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 0.52, y: 5), RobotHeadKey(offset: 1)], 920)
            }
            s.wait(860)
            s.run { $0.nod = nil; $0.release() }
        case .success:
            if fromDrag { s.lockFromDrag() } else { s.prepare(180, pause: 320) }
            s.run {
                $0.setState(.happy, fromDrag ? 180 : 220, keepLock: true)
                $0.bob = ($0.now, 620, 8)
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 0.42, y: -2.4), RobotHeadKey(offset: 1)], 760)
            }
            s.wait(980)
            s.run { $0.bob = nil }
            s.returnToIdle(520)
        case .failure:
            let drop = RobotEase.bezier(0.32, 0, 0.24, 1)
            s.prepare(180, pause: 260)
            s.run { $0.setState(.sad, 320, keepLock: true) }
            s.wait(320)
            s.run {
                $0.failure = $0.now
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 1, y: 5.5)], 720, ease: drop)
            }
            s.wait(1440)
            s.run { $0.animateHead([RobotHeadKey(offset: 0, y: 5.5), RobotHeadKey(offset: 1)], 520, ease: drop) }
            s.returnToIdle(520)
            s.run { $0.failure = nil }
        case .warning:
            let d = 3327.0
            s.prepare(200, pause: 280)
            s.run {
                $0.warning = $0.now
                $0.animateHead([
                    RobotHeadKey(offset: 0),
                    RobotHeadKey(offset: 1000 / d, ease: bezierIn),
                    RobotHeadKey(offset: 1200 / d, y: 5, ease: bezierOut),
                    RobotHeadKey(offset: 1500 / d, y: 5, ease: bezierOut),
                    RobotHeadKey(offset: 1700 / d, y: -4),
                    RobotHeadKey(offset: 2200 / d, y: -4, ease: bezierOut),
                    RobotHeadKey(offset: 2300 / d),
                    RobotHeadKey(offset: 1),
                ], d, ease: .linear)
            }
            s.wait(d + 40)
            s.run { $0.warning = nil; $0.look = .zero; $0.release() }
        case .inspect:
            let d = 1840.0
            s.prepare(160, pause: 120)
            s.run {
                $0.lock = true
                $0.look = .zero
                $0.inspect = $0.now
                $0.animateHead([
                    RobotHeadKey(offset: 0, ease: bezierIn),
                    RobotHeadKey(offset: 400 / d, y: 5),
                    RobotHeadKey(offset: 960 / d, y: 5, ease: bezierOut),
                    RobotHeadKey(offset: 1120 / d, y: -4),
                    RobotHeadKey(offset: 1700 / d, y: -4, ease: bezierOut),
                    RobotHeadKey(offset: 1),
                ], d, ease: .linear, delay: 1100)
            }
            s.wait(6590)
            s.run { $0.inspect = nil; $0.look = .zero; $0.release() }
        case .angry, .blocked:
            if fromDrag { s.lockFromDrag() } else { s.prepare(180, pause: 320) }
            s.run {
                $0.setState(.angry, fromDrag ? 180 : 280, keepLock: true)
                $0.angryDrop = ($0.now, nil)
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 0.46, y: 2.6), RobotHeadKey(offset: 1)], 820)
            }
            s.wait(980)
            s.run { $0.angryDrop?.release = $0.now }
            s.returnToIdle(500)
            s.run { $0.angryDrop = nil }
        case .error:
            s.prepare(180, pause: 240)
            s.run {
                $0.errorSweep = $0.now
                $0.animateHead([
                    RobotHeadKey(offset: 0, ease: .bezier(0.38, 0, 0.28, 1)),
                    RobotHeadKey(offset: 0.34, x: -4, ease: bezierOut),
                    RobotHeadKey(offset: 0.72, x: 4, ease: bezierOut),
                    RobotHeadKey(offset: 1),
                ], 1380, ease: .linear)
            }
            s.wait(1420)
            s.run { $0.errorSweep = nil; $0.look = .zero; $0.release() }
        case .surprise:
            s.prepare(180, pause: 320)
            s.run { $0.shake = nil; $0.startMorph(RobotPose(w: 34, h: 36, topY: -36, bottomY: 36), 235, .inOutCubic) }
            s.wait(235)
            s.run {
                $0.setState(.surprise, 175, keepLock: true)
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 1, scale: 1.035)], 175)
            }
            s.wait(175)
            s.run { $0.shake = ($0.now, 420) }
            s.wait(420)
            s.run {
                $0.shake = nil
                $0.animateHead([RobotHeadKey(offset: 0, scale: 1.035), RobotHeadKey(offset: 1)], 430)
            }
            s.returnToIdle(430, ease: .inOutCubic)
        case .love:
            s.prepare(160, pause: 120)
            s.run {
                $0.lock = true
                $0.look = .zero
                $0.love = $0.now
                $0.animateHead([
                    RobotHeadKey(offset: 0, ease: bezierIn),
                    RobotHeadKey(offset: 0.3, y: -2, ease: bezierOut),
                    RobotHeadKey(offset: 0.68, y: -1, ease: bezierOut),
                    RobotHeadKey(offset: 1),
                ], 2880, ease: .linear)
            }
            s.wait(2910)
            s.run { $0.love = nil; $0.look = .zero; $0.release() }
        case .random:
            s.prepare(160, pause: 120)
            s.run { $0.lock = true; $0.look = .zero; $0.random = $0.now }
            s.wait(RobotReel.duration + 30)
            s.run { $0.random = nil; $0.look = .zero; $0.release() }
        case .sleep:
            s.prepare(160, pause: 320)
            s.run { $0.setState(.sleepy, 940, ease: .inOutCubic, keepLock: true) }
            s.wait(980)
            s.run { $0.startMorph(RobotPose(w: 54, h: 58, topY: -22, bottomY: 36), 105) }
            s.wait(120)
            s.run { $0.setState(.sleepy, 820, ease: .inOutCubic, keepLock: true) }
            s.wait(990)
            s.run {
                $0.animateHead([RobotHeadKey(offset: 0), RobotHeadKey(offset: 1, y: 4)], 980)
                $0.startMorph(RobotExpression.sleep.pose, 980, .inOutCubic)
                $0.expression = .sleep
                $0.sleeping = true
            }
            s.wait(980)
            return (s, .hold)
        case .wake:
            s.run {
                $0.lock = true
                $0.pose = RobotExpression.sleep.pose
                $0.animateHead([RobotHeadKey(offset: 0, y: 4), RobotHeadKey(offset: 0.55, y: -2, scale: 1.015), RobotHeadKey(offset: 1)], 500)
                $0.setState(.sleepy, 240, keepLock: true)
            }
            s.wait(260)
            s.run { $0.setState(.surprise, 120, keepLock: true) }
            s.wait(190)
            s.returnToIdle(300)
        }
        return (s, .ambient)
    }
}

/// Precomputed frames for one `play`: an intro, then a loop or a held pose.
struct RobotPlan {
    static let frameRate = 60.0
    static let frameMs = 1000 / frameRate
    /// Spill past the intro so trailing springs (the antenna) settle before the loop takes over.
    static let settle = 1600.0

    static func framed(_ ms: Double) -> Double { (ms / frameMs).rounded(.up) * frameMs }

    let state: RobotState
    let frames: [RobotFace]
    let introDuration: Double
    let loop: [RobotFace]
    let blinkLoop: [CGFloat]
    let caretBlinks: Bool
    let isMoment: Bool

    var loopPeriod: Double { Double(max(0, loop.count - 1)) / Self.frameRate }
    var blinkPeriod: Double { Double(max(0, blinkLoop.count - 1)) / Self.frameRate }
    var introSpan: Double { Double(max(0, frames.count - 1)) / Self.frameRate }

    func face(at t: Double) -> RobotFace {
        if t < introSpan || loop.isEmpty {
            return Self.sample(frames, at: min(t, introSpan))
        }
        let phase = (t - introDuration).truncatingRemainder(dividingBy: loopPeriod)
        var face = Self.sample(loop, at: phase)
        if !blinkLoop.isEmpty {
            let x = (t - introDuration).truncatingRemainder(dividingBy: blinkPeriod) * Self.frameRate
            let i = min(Int(x), blinkLoop.count - 2)
            face.blink = robotLerp(blinkLoop[i], blinkLoop[i + 1], CGFloat(x - Double(i)))
        }
        return face
    }

    private static func sample(_ list: [RobotFace], at t: Double) -> RobotFace {
        guard list.count > 1 else { return list.first ?? RobotFace() }
        let x = max(0, t) * frameRate
        let i = min(Int(x), list.count - 2)
        return list[i].mixed(list[i + 1], CGFloat(min(1, x - Double(i))))
    }

    static func make(_ state: RobotState, from start: RobotFace, antennaVelocity: CGVector = .zero,
                     reduced: Bool, seed: UInt64, fromDrag: Bool = false, resting: Bool = false,
                     withLoop: Bool = true, time: RobotTime? = nil) -> RobotPlan {
        var sim = RobotSim()
        sim.reduced = reduced
        let (script, tail) = RobotScript.make(state, fromDrag: fromDrag, resting: resting)
        let blend: Double = resting || reduced ? 0 : (state == .idle ? 320 : (fromDrag ? 180 : (state == .wake ? 120 : 140)))
        var antenna = RobotAntenna(x: RobotSpring(value: start.antennaX, velocity: antennaVelocity.dx),
                                   y: RobotSpring(value: start.antennaY, velocity: antennaVelocity.dy))
        if resting { antenna = RobotAntenna(x: RobotSpring(value: 120), y: RobotSpring(value: 12)) }
        return build(state: state, sim: sim, script: script, tail: withLoop ? tail : .hold, origin: 0,
                     start: resting ? nil : start, blend: blend, antenna: antenna, reduced: reduced, seed: seed, time: time)
    }

    /// Hands a live pointer-follow simulation to Core Animation once the pointer stops.
    static func settle(from live: RobotSim, antenna: RobotAntenna, seed: UInt64, time: RobotTime? = nil) -> RobotPlan {
        var script = RobotScript()
        script.wait(max(0, (live.pointer?.lastMove ?? live.now) + 900 - live.now))
        return build(state: .idle, sim: live, script: script, tail: .ambient, origin: live.now, start: nil,
                     blend: 0, antenna: antenna, reduced: live.reduced, seed: seed, time: time)
    }

    private static func build(state: RobotState, sim initial: RobotSim, script: RobotScript, tail: RobotTail,
                              origin: Double, start: RobotFace?, blend: Double, antenna initialAntenna: RobotAntenna,
                              reduced: Bool, seed: UInt64, time: RobotTime? = nil, moment: Bool = false,
                              caret: Bool = false) -> RobotPlan {
        var random = RobotRandom(seed: seed)
        let blinks = RobotBlinks(random: &random, rate: time.map { $0.blink > 0 ? $0.blink : 1 } ?? 1)
        let wander = RobotWander(random: &random)
        var sim = initial
        if let time { sim.lid = CGFloat(time.lid) }
        if state == .bored || moment { sim.useBlinks(blinks, from: origin) }
        if moment { sim.useWander(wander, from: origin - (wander.events.first?.at ?? 0)) }
        let introEnd = script.cursor
        var steps = script.steps
        if case let .pass(pass) = tail, pass.cursor >= frameMs {
            var at = introEnd
            while at < introEnd + settle {
                steps += pass.steps.map { (at + $0.at, $0.run) }
                at += pass.cursor
            }
        }
        var frames: [RobotFace] = []
        var loopSim: RobotSim?
        var next = 0
        var ambientStarted = false
        let count = Int(((introEnd + settle) / frameMs).rounded(.up)) + 1
        for i in 0..<count {
            let t = Double(i) * frameMs
            while next < steps.count, steps[next].at <= t + 1e-6 {
                if next == script.steps.count, loopSim == nil, case .pass = tail {
                    sim.useBlinks(blinks, from: origin + introEnd)
                    loopSim = sim
                }
                sim.now = origin + steps[next].at
                steps[next].run(&sim)
                next += 1
            }
            if next == script.steps.count, loopSim == nil, case .loop = tail { loopSim = sim }
            if case .ambient = tail, !ambientStarted, t + 1e-6 >= introEnd {
                if !reduced { sim.startAmbient(wander: wander, blinks: blinks, at: origin + introEnd) }
                ambientStarted = true
            }
            frames.append(sim.advance(to: origin + t))
        }

        if let start, blend > 0 {
            for i in frames.indices where Double(i) * frameMs < blend {
                frames[i] = start.mixed(frames[i], RobotEase.outQuint(CGFloat(Double(i) * frameMs / blend)))
            }
        }
        var antenna = initialAntenna
        for i in frames.indices {
            antenna.follow(frames[i].antennaTarget, seconds: i == 0 ? 0 : 1 / frameRate, reduced: reduced)
            frames[i].antennaX = antenna.x.value
            frames[i].antennaY = antenna.y.value
        }

        var loop: [RobotFace] = []
        var blinkLoop: [CGFloat] = []
        func blinkCycle() -> [CGFloat] {
            let b = Int((blinks.period / frameMs).rounded())
            var cycle = (0...b).map { blinks.value(at: Double($0) * frameMs) }
            cycle[b] = cycle[0]
            return cycle
        }
        switch tail {
        case let .loop(period):
            if var looping = loopSim {
                let start = looping.now
                let n = Int((period / frameMs).rounded())
                loop = (0...n).map { looping.advance(to: start + Double($0) * period / Double(n)) }
            }
        case let .pass(pass):
            if var looping = loopSim {
                let start = origin + introEnd, period = pass.cursor
                let n = max(1, Int((period / frameMs).rounded()))
                var k = 0
                loop = (0...n).map { j in
                    let t = Double(j) * period / Double(n)
                    while k < pass.steps.count, pass.steps[k].at <= t + 1e-6 {
                        looping.now = start + pass.steps[k].at
                        pass.steps[k].run(&looping)
                        k += 1
                    }
                    return looping.advance(to: start + t)
                }
                if !reduced, !looping.lock, !looping.sleeping, looping.expression != .input { blinkLoop = blinkCycle() }
            }
        case .ambient where !reduced:
            var looping = RobotSim()
            looping.lid = sim.lid
            looping.startAmbient(wander: wander, blinks: blinks, at: 0)
            let n = Int((wander.period / frameMs).rounded())
            loop = (0...n).map { looping.advance(to: Double($0) * frameMs) }
            blinkLoop = blinkCycle()
        default:
            break
        }
        if !loop.isEmpty {
            var a = RobotAntenna(x: RobotSpring(value: loop[0].antennaTarget.x), y: RobotSpring(value: loop[0].antennaTarget.y))
            for pass in 0..<2 {
                for i in loop.indices {
                    a.follow(loop[i].antennaTarget, seconds: 1 / frameRate, reduced: reduced)
                    if pass == 1 {
                        loop[i].antennaX = a.x.value
                        loop[i].antennaY = a.y.value
                    }
                }
            }
            loop[loop.count - 1] = loop[0]
        }

        var introDuration = introEnd / 1000
        if reduced, let start { introDuration += dissolve(&frames, from: start) }
        return RobotPlan(state: state, frames: frames, introDuration: introDuration, loop: loop, blinkLoop: blinkLoop,
                         caretBlinks: (state == .input || caret) && !reduced, isMoment: moment)
    }

    private static let dissolveFrames = 6

    /// Reduce Motion: no morphs, so every pose change becomes a brief dip of the eyes instead.
    @discardableResult
    private static func dissolve(_ frames: inout [RobotFace], from start: RobotFace) -> Double {
        var added = 0.0
        if let first = frames.first, start.distance(to: first) > 0.5 {
            frames.insert(contentsOf: Array(repeating: start, count: dissolveFrames), at: 0)
            added = Double(dissolveFrames) / frameRate
        }
        var jumps: [Int] = []
        if added > 0 { jumps.append(dissolveFrames) }
        for i in frames.indices.dropFirst() where frames[i].distance(to: frames[i - 1]) > 0.5 && !jumps.contains(i) {
            jumps.append(i)
        }
        for j in jumps {
            for i in max(0, j - dissolveFrames)...min(frames.count - 1, j + dissolveFrames - 1) {
                let o = CGFloat(min(1, abs(Double(i) - (Double(j) - 0.5)) / Double(dissolveFrames)))
                frames[i].eyesOpacity = min(frames[i].eyesOpacity, o)
            }
        }
        return added
    }
}

/// An accessory change due `at` ms after the plan starts.
struct RobotMomentCue { let at: Double; let on: String?; let off: String?; let instant: Bool; let exit: String? }

extension RobotScript {
    private static let poseKeys: [String: WritableKeyPath<RobotPose, CGFloat>] = [
        "w": \.w, "h": \.h, "topY": \.topY, "bottomY": \.bottomY, "topAL": \.topLeft, "topAR": \.topRight,
    ]

    /// A moment's steps as the web player runs them, every duration divided by the time of day's `speed`.
    mutating func add(_ steps: ArraySlice<RobotStep>, speed: Double, reduced: Bool, cues: inout [RobotMomentCue]) {
        for s in steps {
            if let ms = s.wait {
                wait(ms / speed)
                continue
            }
            if s.lock == true { run { $0.gaze = nil; $0.lock = true; $0.wanderTarget = .zero } }
            if s.unlock == true { run { $0.release() } }
            if let name = s.pose, let e = RobotExpression(rawValue: name) {
                var target = e.pose
                for (key, value) in s.set ?? [:] { if let path = Self.poseKeys[key] { target[keyPath: path] = CGFloat(value) } }
                let ms = (s.ms ?? 320) / speed, ease = RobotEase.pose(s.ease)
                run { $0.setState(e, ms, ease: ease, keepLock: true, pose: target) }
            }
            if let list = s.gaze {
                let targets = list.filter { $0.count >= 3 }.map { (point: CGPoint(x: $0[0], y: $0[1]), hold: $0[2] / speed) }
                let look = CGFloat(s.speed ?? 0.3)
                run { $0.lock = false; $0.gaze = RobotGaze(targets: targets, speed: look, nextAt: $0.now) }
            }
            if let frames = s.head, !reduced {
                let lists = frames.map(RobotTransformFunction.parse), origin = RobotGeometry.point(s.origin)
                let ms = (s.ms ?? 0) / speed, times = s.times ?? 1, ease = RobotEase.curve(s.ease)
                run { sim in
                    sim.head = RobotHeadMotion(css: lists, origin: origin, start: sim.now, duration: ms, iterations: times,
                                               ease: ease, held: sim.headValue) ?? sim.head
                }
            }
            if let fx = s.fx, !reduced {
                let ms = (s.ms ?? 0) / speed, amp = CGFloat(s.amp ?? 0)
                run { sim in
                    switch fx {
                    case "nod": sim.nod = sim.now
                    case "bob": sim.bob = (sim.now, ms > 0 ? ms : 620, amp != 0 ? amp : 7)
                    case "shake": sim.shake = (sim.now, 420 / speed)
                    case "blink": sim.blink(170)
                    case "wink": sim.wink = (sim.now, ms > 0 ? ms : 420)
                    default: break
                    }
                }
            }
            if s.on != nil || s.off != nil {
                cues.append(RobotMomentCue(at: cursor, on: s.on, off: s.off, instant: s.instant ?? false, exit: s.exit))
            }
        }
    }

    /// The player's settle: head home, routines and effects cleared, then idle unless the pose is held.
    mutating func finishMoment(hold: Bool) {
        run { sim in
            sim.homeHead(320)
            sim.gaze = nil
            sim.useWander(nil)
            sim.wanderTarget = .zero
            sim.nod = nil
            sim.bob = nil
            sim.shake = nil
            sim.angryDrop = nil
            sim.wink = nil
            if !hold { sim.setState(.idle, 360) }
        }
        wait(hold ? 320 : 360)
    }
}

extension RobotPlan {
    /// `loop` repeats from `loopFrom` (the whole list when reduced) until replaced; `hold` ends on the input
    /// pose with the plan reporting `.input`; otherwise the moment settles to idle. Cues fire at `at` ms.
    static func make(moment: RobotMoment, from start: RobotFace, antennaVelocity: CGVector, reduced: Bool, time: RobotTime,
                     seed: UInt64, loop: Bool, hold: Bool) -> (plan: RobotPlan, cues: [RobotMomentCue]) {
        let steps = reduced ? moment.reduced : moment.steps
        let speed = time.speed > 0 ? time.speed : 1
        var cues: [RobotMomentCue] = []
        var script = RobotScript()
        script.add(steps[...], speed: speed, reduced: reduced, cues: &cues)
        var pass = RobotScript()
        if loop {
            var ignored: [RobotMomentCue] = []
            pass.add(steps[min(steps.count, reduced ? 0 : moment.loopFrom ?? 0)...], speed: speed, reduced: reduced, cues: &ignored)
        }
        let tail: RobotTail
        if pass.cursor >= frameMs {
            tail = .pass(pass)
        } else {
            var worn: [String] = []
            for c in cues {
                if let id = c.on, !worn.contains(id) { worn.append(id) }
                if let id = c.off { worn.removeAll { $0 == id } }
            }
            cues += worn.map { RobotMomentCue(at: script.cursor, on: nil, off: $0, instant: false, exit: nil) }
            script.finishMoment(hold: hold)
            tail = hold ? .hold : .ambient
        }
        var sim = RobotSim()
        sim.reduced = reduced
        let antenna = RobotAntenna(x: RobotSpring(value: start.antennaX, velocity: antennaVelocity.dx),
                                   y: RobotSpring(value: start.antennaY, velocity: antennaVelocity.dy))
        let plan = build(state: hold ? .input : .idle, sim: sim, script: script, tail: tail, origin: 0, start: start,
                         blend: reduced ? 0 : 320, antenna: antenna, reduced: reduced, seed: seed, time: time,
                         moment: true, caret: steps.contains { $0.pose == "input" })
        let shift = plan.introDuration * 1000 - script.cursor
        return (plan, cues.map { RobotMomentCue(at: $0.at + shift, on: $0.on, off: $0.off, instant: $0.instant, exit: $0.exit) })
    }
}
