import AppKit
import QuartzCore

/// The SVG subset companion-moments.json draws with, in the robot's y-down 240 user space.
enum RobotSVG {
    /// Absolute M L H V C Q Z; extra coordinates repeat the command, and after M they are lines.
    static func path(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let arity: [Character: Int] = ["M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "Q": 4]
        var command: Character = "M"
        var args: [CGFloat] = []
        for token in tokens(d) {
            guard let n = Double(token) else {
                command = Character(String(token))
                args = []
                if command == "Z" { path.closeSubpath() }
                continue
            }
            args.append(CGFloat(n))
            guard args.count == arity[command] else { continue }
            let p = { (i: Int) in CGPoint(x: args[i], y: args[i + 1]) }
            switch command {
            case "M": path.move(to: p(0)); command = "L"
            case "L": path.addLine(to: p(0))
            case "H": path.addLine(to: CGPoint(x: args[0], y: path.currentPoint.y))
            case "V": path.addLine(to: CGPoint(x: path.currentPoint.x, y: args[0]))
            case "C": path.addCurve(to: p(4), control1: p(0), control2: p(2))
            default: path.addQuadCurve(to: p(2), control: p(0))
            }
            args = []
        }
        return path
    }

    /// An SVG or CSS transform list: translate, translateX, translateY, rotate(a [cx cy]) and scale, applied left to right as SVG does.
    static func transform(_ list: String) -> CGAffineTransform {
        var m = CGAffineTransform.identity
        for function in list.split(separator: ")") {
            let parts = function.split(separator: "(", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let a = numbers(parts[1])
            guard let first = a.first else { continue }
            let second = a.count > 1 ? a[1] : nil
            switch parts[0].trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines)) {
            case "translate": m = m.translatedBy(x: first, y: second ?? 0)
            case "translateX": m = m.translatedBy(x: first, y: 0)
            case "translateY": m = m.translatedBy(x: 0, y: first)
            case "scale": m = m.scaledBy(x: first, y: second ?? first)
            case "rotate" where a.count == 3:
                m = m.translatedBy(x: a[1], y: a[2]).rotated(by: first * .pi / 180).translatedBy(x: -a[1], y: -a[2])
            case "rotate": m = m.rotated(by: first * .pi / 180)
            default: break
            }
        }
        return m
    }

    /// Numbers in a list, ignoring units and separators: "translate(0px, -7px)" args, "72 100", "50% 0%".
    static func numbers(_ s: some StringProtocol) -> [CGFloat] {
        tokens(String(s)).compactMap { Double($0).map { CGFloat($0) } }
    }

    private static let token = try! Regex(#"[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"#)

    private static func tokens(_ s: String) -> [Substring] {
        s.matches(of: token).map { s[$0.range] }
    }
}

/// Resolves a shape's colour token against the library palette and a finish, as companion-player.js does.
struct RobotColours {
    let library: RobotLibrary
    let finish: RobotFinish

    /// Light and dark come from the appearance the colour is resolved in; nil for "none" or an unknown token.
    func colour(_ token: String) -> NSColor? {
        switch token {
        case "none": return nil
        case "body": return Self.hex(finish.body)
        case "eyes": return Self.hex(finish.eyes)
        default:
            guard let swatch = library.palette[finish.swap?[token] ?? token],
                  let light = swatch.first.flatMap(Self.hex), let dark = swatch.last.flatMap(Self.hex) else { return Self.hex(token) }
            return NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light }
        }
    }

    static func hex(_ s: String) -> NSColor? {
        guard s.count == 7, s.hasPrefix("#"), let rgb = UInt32(s.dropFirst(), radix: 16) else { return nil }
        return .hex(rgb)
    }
}

/// Builds accessory and finish shapes as Core Animation layers in the robot's user space, with their
/// `anim` loops as keyframe animations and the player's enter and exit transitions.
///
/// Colours resolve in the current drawing appearance: call `layer`, `accessory` and `recolour` inside
/// `effectiveAppearance.performAsCurrentDrawingAppearance`.
enum RobotShapes {
    private static let loopsKey = "robotLoops", fillKey = "robotFill", strokeKey = "robotStroke", fillOpacityKey = "robotFillOpacity"

    /// Position and anchor 0, so the layer's space is its parent's SVG user space. An element whose
    /// `anim` has an origin instead gets bounds = its fill box and anchor = that origin, like CSS `fill-box`.
    static func layer(_ spec: RobotShapeSpec, colours: RobotColours) -> CALayer {
        let a = spec.attributes
        let layer: CALayer
        if spec.el == "g" {
            layer = CALayer()
            for kid in spec.kids { layer.addSublayer(self.layer(kid, colours: colours)) }
        } else {
            let shape = CAShapeLayer()
            shape.path = geometry(spec)
            shape.lineWidth = number(a, "stroke-width") ?? 1
            shape.miterLimit = 4
            if let cap = string(a, "stroke-linecap") { shape.lineCap = CAShapeLayerLineCap(rawValue: cap) }
            if let join = string(a, "stroke-linejoin") { shape.lineJoin = CAShapeLayerLineJoin(rawValue: join) }
            shape.strokeEnd = dashEnd(a, offset: 0) ?? 1
            shape.setValue(string(a, "fill") ?? "#000000", forKey: fillKey)
            shape.setValue(string(a, "stroke"), forKey: strokeKey)
            shape.setValue(number(a, "fill-opacity") ?? 1, forKey: fillOpacityKey)
            paint(shape, colours)
            layer = shape
        }
        layer.anchorPoint = .zero
        layer.opacity = Float(number(a, "opacity") ?? 1)
        if let t = string(a, "transform") { layer.transform = CATransform3DMakeAffineTransform(RobotSVG.transform(t)) }
        guard let anim = spec.anim else { return layer }
        if let origin = anim.origin {
            let box = bounds(spec), f = RobotSVG.numbers(origin).map { $0 / 100 } + [0, 0]
            layer.bounds = box
            layer.anchorPoint = CGPoint(x: f[0], y: f[1])
            layer.position = CGPoint(x: box.minX + f[0] * box.width, y: box.minY + f[1] * box.height)
        }
        layer.setValue(loops(anim, a, layer), forKey: loopsKey)
        return layer
    }

    /// The root is anchored at the centre of the accessory's fill box, where enter and exit scale from.
    static func accessory(_ id: String, colours: RobotColours) -> CALayer? {
        guard let spec = colours.library.accessories[id] else { return nil }
        let root = CALayer()
        root.name = id
        root.bounds = finite(union(spec.shapes))
        root.position = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        for shape in spec.shapes { root.addSublayer(layer(shape, colours: colours)) }
        return root
    }

    /// Idempotent; a shape's loop runs until `stopLoops`, a `once` loop holds its last frame.
    static func startLoops(_ root: CALayer) {
        walk(root) { layer in
            guard let loops = layer.value(forKey: loopsKey) as? [CAAnimation] else { return }
            let now = layer.convertTime(CACurrentMediaTime(), from: nil)
            for (i, loop) in loops.enumerated() where layer.animation(forKey: "\(loopsKey)\(i)") == nil {
                let animation = loop.copy() as! CAAnimation
                if animation.beginTime > 0 { animation.beginTime += now }
                layer.add(animation, forKey: "\(loopsKey)\(i)")
            }
        }
    }

    static func stopLoops(_ root: CALayer) {
        walk(root) { layer in
            guard let loops = layer.value(forKey: loopsKey) as? [CAAnimation] else { return }
            for i in loops.indices { layer.removeAnimation(forKey: "\(loopsKey)\(i)") }
        }
    }

    /// pop, drop, rise or fade, as companion-player.js ENTER.
    static func enter(_ root: CALayer, _ style: String) {
        let (from, ms, ease): (CATransform3D?, Double, String) = switch style {
        case "drop": (CATransform3DMakeTranslation(0, -26, 0), 360, "back")
        case "rise": (CATransform3DMakeTranslation(0, 18, 0), 320, "out")
        case "fade": (nil, 260, "out")
        default: (CATransform3DMakeScale(0.4, 0.4, 1), 280, "back")
        }
        transition(root, "robotEnter", opacity: (0, 1), transform: from.map { ($0, CATransform3DIdentity) },
                   ms: ms, curve: curve(ease), hold: false)
    }

    /// lift, pop or fade, as companion-player.js EXIT; any other style pops, so passing the accessory's
    /// `enter` when a step names no exit matches the player's default. Stops loops; `done` runs at the end.
    static func exit(_ root: CALayer, _ style: String, done: @escaping () -> Void) {
        let (to, ms): (CATransform3D?, Double) = switch style {
        case "lift": (CATransform3DMakeTranslation(0, -34, 0), 420)
        case "fade": (nil, 200)
        default: (CATransform3DMakeScale(0.6, 0.6, 1), 180)
        }
        stopLoops(root)
        CATransaction.begin()
        CATransaction.setCompletionBlock(done)
        transition(root, "robotExit", opacity: (1, 0), transform: to.map { (CATransform3DIdentity, $0) },
                   ms: ms, curve: CAMediaTimingFunction(name: .easeIn), hold: true)
        CATransaction.commit()
    }

    /// For a finish or appearance change; shapes keep the tokens they were built with.
    static func recolour(_ root: CALayer, colours: RobotColours) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        walk(root) { if let shape = $0 as? CAShapeLayer { paint(shape, colours) } }
        CATransaction.commit()
    }

    /// SVG fill box: geometry without stroke, before the element's own transform.
    static func bounds(_ spec: RobotShapeSpec) -> CGRect {
        finite(spec.el == "g" ? union(spec.kids) : geometry(spec).boundingBoxOfPath)
    }

    static func walk(_ layer: CALayer, _ body: (CALayer) -> Void) {
        body(layer)
        for sublayer in layer.sublayers ?? [] { walk(sublayer, body) }
    }

    static func curve(_ ease: String) -> CAMediaTimingFunction {
        switch ease {
        case "out": CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        case "inOut": CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1)
        case "back": CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
        default: CAMediaTimingFunction(name: .linear)
        }
    }

    // MARK: Building

    private static func geometry(_ spec: RobotShapeSpec) -> CGPath {
        let a = spec.attributes
        let n = { (key: String) in number(a, key) ?? 0 }
        let rx = number(a, "rx") ?? number(a, "ry") ?? 0, ry = number(a, "ry") ?? rx
        switch spec.el {
        case "path": return RobotSVG.path(string(a, "d") ?? "")
        case "circle":
            return CGPath(ellipseIn: CGRect(x: n("cx") - n("r"), y: n("cy") - n("r"), width: 2 * n("r"), height: 2 * n("r")), transform: nil)
        case "ellipse": return CGPath(ellipseIn: CGRect(x: n("cx") - rx, y: n("cy") - ry, width: 2 * rx, height: 2 * ry), transform: nil)
        case "rect":
            let r = CGRect(x: n("x"), y: n("y"), width: n("width"), height: n("height"))
            let cw = min(rx, r.width / 2), ch = min(ry, r.height / 2)
            // ponytail: CG starts a rounded rect at 3 o'clock, SVG on the top edge; only a dashed one would show it.
            return cw > 0 && ch > 0 ? CGPath(roundedRect: r, cornerWidth: cw, cornerHeight: ch, transform: nil) : CGPath(rect: r, transform: nil)
        default: return CGMutablePath()
        }
    }

    private static func union(_ specs: [RobotShapeSpec]) -> CGRect {
        specs.reduce(CGRect.null) { box, spec in
            let own = string(spec.attributes, "transform").map(RobotSVG.transform) ?? .identity
            return box.union(bounds(spec).applying(own))
        }
    }

    private static func finite(_ r: CGRect) -> CGRect { r.isNull || r.isInfinite ? .zero : r }

    /// A single dash over `pathLength` (dash + gap ≥ pathLength) is a stroke end.
    private static func dashEnd(_ a: [String: RobotValue], offset: CGFloat) -> CGFloat? {
        guard let length = number(a, "pathLength"), length > 0,
              let dash = string(a, "stroke-dasharray").flatMap({ RobotSVG.numbers($0).first }) else { return nil }
        return min(max((dash - offset) / length, 0), 1)
    }

    private static func paint(_ shape: CAShapeLayer, _ colours: RobotColours) {
        if let fill = shape.value(forKey: fillKey) as? String {
            let alpha = shape.value(forKey: fillOpacityKey) as? CGFloat ?? 1
            shape.fillColor = colours.colour(fill).flatMap { let c = $0.cgColor; return c.copy(alpha: c.alpha * alpha) }
        }
        shape.strokeColor = (shape.value(forKey: strokeKey) as? String).flatMap { colours.colour($0)?.cgColor }
    }

    /// One keyframe track per animated property, WAAPI style: missing offsets spread evenly, a property
    /// absent at either end uses the static value there, and every segment eases with the anim's curve.
    private static func loops(_ anim: RobotAnim, _ a: [String: RobotValue], _ layer: CALayer) -> [CAAnimation] {
        let offsets = keyTimes(anim.frames.map(\.offset))
        let segment = curve(anim.ease ?? "inOut")
        func track(_ keyPath: String, rest: Any, _ value: (RobotAnimFrame) -> Any?) -> CAAnimation? {
            var times: [Double] = [], values: [Any] = []
            for (frame, t) in zip(anim.frames, offsets) {
                guard let v = value(frame) else { continue }
                times.append(t)
                values.append(v)
            }
            guard let first = times.first, let last = times.last else { return nil }
            if first > 0 { times.insert(0, at: 0); values.insert(rest, at: 0) }
            if last < 1 { times.append(1); values.append(rest) }
            let k = CAKeyframeAnimation(keyPath: keyPath)
            k.values = values
            k.keyTimes = times.map { NSNumber(value: $0) }
            k.timingFunctions = Array(repeating: segment, count: values.count - 1)
            k.duration = anim.ms / 1000
            if anim.once == true {
                k.fillMode = .both
                k.isRemovedOnCompletion = false
            } else {
                k.repeatCount = .infinity
            }
            let delay = (anim.delay ?? 0) / 1000
            if delay < 0 { k.timeOffset = -delay } else { k.beginTime = delay }
            return k
        }
        let strokeEnd = (layer as? CAShapeLayer)?.strokeEnd ?? 1
        return [
            track("transform", rest: NSValue(caTransform3D: layer.transform)) { frame in
                frame.transform.map { NSValue(caTransform3D: CATransform3DMakeAffineTransform(RobotSVG.transform($0))) }
            },
            track("opacity", rest: NSNumber(value: layer.opacity)) { $0.opacity.map { NSNumber(value: $0) } },
            track("strokeEnd", rest: NSNumber(value: Double(strokeEnd))) { frame in
                frame.strokeDashoffset.flatMap { dashEnd(a, offset: CGFloat($0)) }.map { NSNumber(value: Double($0)) }
            },
        ].compactMap { $0 }
    }

    private static func keyTimes(_ given: [Double?]) -> [Double] {
        var o = given
        guard o.count > 1 else { return o.map { $0 ?? 1 } }
        o[0] = o[0] ?? 0
        o[o.count - 1] = o[o.count - 1] ?? 1
        var known = 0
        for j in 1..<o.count {
            guard let end = o[j], let start = o[known] else { continue }
            for k in known + 1 ..< j { o[k] = start + (end - start) * Double(k - known) / Double(j - known) }
            known = j
        }
        return o.map { $0 ?? 0 }
    }

    private static func transition(_ root: CALayer, _ name: String, opacity: (Float, Float),
                                   transform: (CATransform3D, CATransform3D)?, ms: Double,
                                   curve: CAMediaTimingFunction, hold: Bool) {
        var tracks: [(String, Any, Any)] = [("opacity", NSNumber(value: opacity.0), NSNumber(value: opacity.1))]
        if let (from, to) = transform { tracks.append(("transform", NSValue(caTransform3D: from), NSValue(caTransform3D: to))) }
        for (keyPath, from, to) in tracks {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = ms / 1000
            animation.timingFunction = curve
            if hold {
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
            }
            root.add(animation, forKey: "\(name).\(keyPath)")
        }
    }

    private static func number(_ a: [String: RobotValue], _ key: String) -> CGFloat? {
        switch a[key] {
        case .number(let v): CGFloat(v)
        case .string(let s): Double(s).map { CGFloat($0) }
        default: nil
        }
    }

    private static func string(_ a: [String: RobotValue], _ key: String) -> String? {
        switch a[key] {
        case .string(let s): s
        case .number(let v): String(v)
        default: nil
        }
    }
}
