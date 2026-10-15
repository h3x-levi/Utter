import AppKit

// Port of CX ArtLab's agent-robot-avatar (MIT, see THIRD_PARTY_NOTICES.md).
// All geometry is in the upstream SVG's 240 x 240 view box, y pointing down.

struct RobotPalette: Equatable {
    var body: NSColor
    /// The eyelid shapes that close over the eyes; upstream they match `body`.
    var face: NSColor
    var eye: NSColor
    /// The antenna tip.
    var accent: NSColor
    /// An outline for the head and antenna; nil draws none, as upstream.
    var rim: NSColor? = nil

    static let upstream: RobotPalette = {
        let ink = NSColor(srgbRed: 8 / 255, green: 9 / 255, blue: 11 / 255, alpha: 1)
        return RobotPalette(body: ink, face: ink, eye: .white, accent: ink)
    }()

    /// Upstream, plus a faint light rim in dark appearance so the ink head stays visible on dark backdrops.
    static let utter: RobotPalette = {
        var palette = upstream
        palette.rim = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(white: 1, alpha: 0.32) : .clear
        }
        return palette
    }()
}

struct RobotEyeFace: Equatable {
    var x: CGFloat
    var y: CGFloat = 126
    var rotation: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var width: CGFloat = 54
    var height: CGFloat = 58
    var centerY: CGFloat = 0
    var caret: CGFloat = 0
    var caretWidth: CGFloat = 54
    var caretHeight: CGFloat = 58
    var topY: CGFloat = -36
    var topAngle: CGFloat = 0
    var bottomY: CGFloat = 36
    var bottomAngle: CGFloat = 0

    static let scalars: [WritableKeyPath<RobotEyeFace, CGFloat>] = [
        \.x, \.y, \.rotation, \.scaleX, \.scaleY, \.width, \.height, \.centerY,
        \.caret, \.caretWidth, \.caretHeight, \.topY, \.topAngle, \.bottomY, \.bottomAngle,
    ]
}

/// Everything the layers show at one instant.
struct RobotFace: Equatable {
    var left = RobotEyeFace(x: 86)
    var right = RobotEyeFace(x: 154)
    var headX: CGFloat = 0
    var headY: CGFloat = 0
    var headRotation: CGFloat = 0
    var headScaleX: CGFloat = 1
    var headScaleY: CGFloat = 1
    var blink: CGFloat = 1
    var eyesOpacity: CGFloat = 1
    var antennaX: CGFloat = 120
    var antennaY: CGFloat = 12

    static let scalars: [WritableKeyPath<RobotFace, CGFloat>] = [
        \.headX, \.headY, \.headRotation, \.headScaleX, \.headScaleY,
        \.blink, \.eyesOpacity, \.antennaX, \.antennaY,
    ]

    func mixed(_ other: RobotFace, _ t: CGFloat) -> RobotFace {
        var out = self
        for key in Self.scalars { out[keyPath: key] += (other[keyPath: key] - self[keyPath: key]) * t }
        for key in RobotEyeFace.scalars {
            out.left[keyPath: key] += (other.left[keyPath: key] - left[keyPath: key]) * t
            out.right[keyPath: key] += (other.right[keyPath: key] - right[keyPath: key]) * t
        }
        return out
    }

    func distance(to other: RobotFace) -> CGFloat {
        var most: CGFloat = 0
        for key in Self.scalars { most = max(most, abs(self[keyPath: key] - other[keyPath: key])) }
        for key in RobotEyeFace.scalars {
            most = max(most, abs(left[keyPath: key] - other.left[keyPath: key]),
                       abs(right[keyPath: key] - other.right[keyPath: key]))
        }
        return most
    }

    /// The antenna's home point carried by the head transform; the dot springs toward it.
    var antennaTarget: CGPoint {
        let r = headRotation * .pi / 180
        let y = (RobotGeometry.antennaHome.y - 120) * headScaleY
        return CGPoint(x: 120 + headX - y * sin(r), y: 120 + headY + y * cos(r))
    }
}

enum RobotEase {
    case linear, outQuint, inOutCubic, smooth
    case bezier(CGFloat, CGFloat, CGFloat, CGFloat)

    static let head = RobotEase.bezier(0.16, 1, 0.3, 1)

    /// The moment library's easing names: poses use `pose`, head keyframes use `curve`.
    static func pose(_ name: String?) -> RobotEase {
        switch name {
        case "inOut": return .inOutCubic
        case "linear": return .linear
        default: return .outQuint
        }
    }

    static func curve(_ name: String?) -> RobotEase {
        switch name {
        case "out": return .head
        case "linear": return .linear
        case "back": return .bezier(0.34, 1.56, 0.64, 1)
        default: return .bezier(0.65, 0, 0.35, 1)
        }
    }

    func callAsFunction(_ t: CGFloat) -> CGFloat {
        switch self {
        case .linear: return t
        case .outQuint: return 1 - pow(1 - t, 5)
        case .inOutCubic: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        case .smooth:
            let c = min(1, max(0, t))
            return c * c * (3 - 2 * c)
        case let .bezier(x1, y1, x2, y2):
            guard t > 0, t < 1 else { return t }
            func b(_ s: CGFloat, _ a: CGFloat, _ z: CGFloat) -> CGFloat {
                3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * z + s * s * s
            }
            var lo: CGFloat = 0, hi: CGFloat = 1
            for _ in 0..<24 {
                let mid = (lo + hi) / 2
                if b(mid, x1, x2) < t { lo = mid } else { hi = mid }
            }
            return b((lo + hi) / 2, y1, y2)
        }
    }
}

func robotClamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(hi, max(lo, v)) }
func robotLerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

/// Unit-mass damped spring, integrated with semi-implicit Euler in 240 Hz substeps.
struct RobotSpring: Equatable {
    var value: CGFloat = 0
    var velocity: CGFloat = 0

    mutating func step(toward target: CGFloat, stiffness: CGFloat, damping: CGFloat, seconds: Double) {
        var remaining = seconds
        while remaining > 1e-9 {
            let h = CGFloat(min(1.0 / 240, remaining))
            remaining -= Double(h)
            velocity += ((target - value) * stiffness - velocity * damping) * h
            value += velocity * h
        }
    }
}

/// The antenna dot: a bouncy spring that trails the head (upstream stiffness 180, damping 5.6).
struct RobotAntenna: Equatable {
    var x = RobotSpring(value: 120)
    var y = RobotSpring(value: 12)

    mutating func follow(_ target: CGPoint, seconds: Double, reduced: Bool) {
        if reduced {
            self = RobotAntenna(x: RobotSpring(value: target.x), y: RobotSpring(value: target.y))
            return
        }
        x.step(toward: target.x, stiffness: 180, damping: 5.6, seconds: seconds)
        y.step(toward: target.y, stiffness: 180, damping: 5.6, seconds: seconds)
    }
}

enum RobotGeometry {
    static let antennaHome = CGPoint(x: 120, y: 12)
    static let antennaRadius: CGFloat = 15
    static let defaultRoundness: CGFloat = 50

    static let upstreamHeadPath = "M 120.00 20.00 L 132.80 20.05 L 139.87 20.20 L 145.68 20.44 L 150.79 20.78 L 155.43 21.22 L 159.71 21.76 L 163.69 22.40 L 167.44 23.14 L 170.99 23.97 L 174.34 24.90 L 177.53 25.93 L 180.57 27.07 L 183.46 28.30 L 186.22 29.63 L 188.85 31.06 L 191.36 32.59 L 193.75 34.22 L 196.03 35.96 L 198.19 37.80 L 200.25 39.75 L 202.20 41.81 L 204.04 43.97 L 205.78 46.25 L 207.41 48.64 L 208.94 51.15 L 210.37 53.78 L 211.70 56.54 L 212.93 59.43 L 214.07 62.47 L 215.10 65.66 L 216.03 69.01 L 216.86 72.56 L 217.60 76.31 L 218.24 80.29 L 218.78 84.57 L 219.22 89.21 L 219.56 94.32 L 219.80 100.13 L 219.95 107.20 L 220.00 120.00 L 219.95 132.80 L 219.80 139.87 L 219.56 145.68 L 219.22 150.79 L 218.78 155.43 L 218.24 159.71 L 217.60 163.69 L 216.86 167.44 L 216.03 170.99 L 215.10 174.34 L 214.07 177.53 L 212.93 180.57 L 211.70 183.46 L 210.37 186.22 L 208.94 188.85 L 207.41 191.36 L 205.78 193.75 L 204.04 196.03 L 202.20 198.19 L 200.25 200.25 L 198.19 202.20 L 196.03 204.04 L 193.75 205.78 L 191.36 207.41 L 188.85 208.94 L 186.22 210.37 L 183.46 211.70 L 180.57 212.93 L 177.53 214.07 L 174.34 215.10 L 170.99 216.03 L 167.44 216.86 L 163.69 217.60 L 159.71 218.24 L 155.43 218.78 L 150.79 219.22 L 145.68 219.56 L 139.87 219.80 L 132.80 219.95 L 120.00 220.00 L 107.20 219.95 L 100.13 219.80 L 94.32 219.56 L 89.21 219.22 L 84.57 218.78 L 80.29 218.24 L 76.31 217.60 L 72.56 216.86 L 69.01 216.03 L 65.66 215.10 L 62.47 214.07 L 59.43 212.93 L 56.54 211.70 L 53.78 210.37 L 51.15 208.94 L 48.64 207.41 L 46.25 205.78 L 43.97 204.04 L 41.81 202.20 L 39.75 200.25 L 37.80 198.19 L 35.96 196.03 L 34.22 193.75 L 32.59 191.36 L 31.06 188.85 L 29.63 186.22 L 28.30 183.46 L 27.07 180.57 L 25.93 177.53 L 24.90 174.34 L 23.97 170.99 L 23.14 167.44 L 22.40 163.69 L 21.76 159.71 L 21.22 155.43 L 20.78 150.79 L 20.44 145.68 L 20.20 139.87 L 20.05 132.80 L 20.00 120.00 L 20.05 107.20 L 20.20 100.13 L 20.44 94.32 L 20.78 89.21 L 21.22 84.57 L 21.76 80.29 L 22.40 76.31 L 23.14 72.56 L 23.97 69.01 L 24.90 65.66 L 25.93 62.47 L 27.07 59.43 L 28.30 56.54 L 29.63 53.78 L 31.06 51.15 L 32.59 48.64 L 34.22 46.25 L 35.96 43.97 L 37.80 41.81 L 39.75 39.75 L 41.81 37.80 L 43.97 35.96 L 46.25 34.22 L 48.64 32.59 L 51.15 31.06 L 53.78 29.63 L 56.54 28.30 L 59.43 27.07 L 62.47 25.93 L 65.66 24.90 L 69.01 23.97 L 72.56 23.14 L 76.31 22.40 L 80.29 21.76 L 84.57 21.22 L 89.21 20.78 L 94.32 20.44 L 100.13 20.20 L 107.20 20.05 Z"

    static let upstreamHead: [CGPoint] = {
        let numbers = upstreamHeadPath.split(separator: " ").compactMap { Double($0) }
        return stride(from: 0, to: numbers.count - 1, by: 2).map { CGPoint(x: numbers[$0], y: numbers[$0 + 1]) }
    }()

    static let defaultHead = flattened(upstreamHead)

    static func flattened(_ points: [CGPoint], heightScale: CGFloat = 0.9) -> [CGPoint] {
        guard let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(), maxY > minY else { return points }
        let height = maxY - minY
        let inset = height * (1 - robotClamp(heightScale, 0.1, 1)) / 2
        let centerY = (minY + maxY) / 2
        let upperLock = minY + height * 0.4
        let lowerLock = maxY - height * 0.4
        return points.map { p in
            var shift: CGFloat = 0
            if p.y <= upperLock {
                shift = inset
            } else if p.y < centerY {
                shift = inset * RobotEase.smooth((centerY - p.y) / max(0.001, centerY - upperLock))
            } else if p.y >= lowerLock {
                shift = -inset
            } else if p.y > centerY {
                shift = -inset * RobotEase.smooth((p.y - centerY) / max(0.001, lowerLock - centerY))
            }
            return CGPoint(x: p.x, y: p.y + shift)
        }
    }

    static func head(roundness: CGFloat) -> [CGPoint] {
        let r = robotClamp(roundness, 0, 100)
        let base = defaultHead
        if r < defaultRoundness { return mix(base, superellipse(base, exponent: 10), (defaultRoundness - r) / defaultRoundness) }
        if r > defaultRoundness { return mix(base, superellipse(base, exponent: 2.2), (r - defaultRoundness) / defaultRoundness) }
        return base
    }

    static func superellipse(_ points: [CGPoint], exponent n: CGFloat) -> [CGPoint] {
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0, minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let halfW = max(0.001, (maxX - minX) / 2), halfH = max(0.001, (maxY - minY) / 2)
        return points.map { p in
            let angle = atan2(p.y - cy, p.x - cx)
            let c = cos(angle), s = sin(angle)
            let denom = pow(pow(abs(c) / halfW, n) + pow(abs(s) / halfH, n), 1 / n)
            let radius = denom > 0 ? 1 / denom : 0
            return CGPoint(x: cx + c * radius, y: cy + s * radius)
        }
    }

    static func mix(_ a: [CGPoint], _ b: [CGPoint], _ t: CGFloat) -> [CGPoint] {
        let k = robotClamp(t, 0, 1)
        return zip(a, b).map { CGPoint(x: $0.x + ($1.x - $0.x) * k, y: $0.y + ($1.y - $0.y) * k) }
    }

    /// Gaussian pull around the grab point: the jelly deformation.
    static func deformed(_ points: [CGPoint], hot: CGPoint, pull: CGVector) -> [CGPoint] {
        let amount = hypot(pull.dx, pull.dy)
        guard amount >= 0.015 else { return points }
        let radius = (50 + amount * 0.8) * 0.92
        return points.map { p in
            let dx = p.x - hot.x, dy = p.y - hot.y
            let w = exp(-(dx * dx + dy * dy) / (2 * radius * radius))
            return CGPoint(x: p.x + pull.dx * w, y: p.y + pull.dy * w)
        }
    }

    static func jellyEyeOffset(eyeCenter: CGPoint, hot: CGPoint, pull: CGVector) -> CGVector {
        let amount = hypot(pull.dx, pull.dy)
        guard amount >= 0.05 else { return .zero }
        let radius = (50 + amount * 0.8) * 0.92
        let dx = eyeCenter.x - hot.x, dy = eyeCenter.y - hot.y
        let w = exp(-(dx * dx + dy * dy) / (2 * radius * radius)) * 0.24
        return CGVector(dx: pull.dx * w, dy: pull.dy * w)
    }

    /// Upstream draws the head through `translate(7.2 7.2) scale(.94)`.
    static func headPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        for (i, p) in points.enumerated() {
            let q = CGPoint(x: 7.2 + p.x * 0.94, y: 7.2 + p.y * 0.94)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }

    // Hand-built so every frame has the same elements and Core Animation can interpolate them.
    static func ellipse(width: CGFloat, height: CGFloat, centerY cy: CGFloat) -> CGPath {
        let rx = max(width / 2, 0.01), ry = max(height / 2, 0.01), k: CGFloat = 0.5522847498
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rx, y: cy))
        path.addCurve(to: CGPoint(x: 0, y: cy + ry), control1: CGPoint(x: rx, y: cy + k * ry), control2: CGPoint(x: k * rx, y: cy + ry))
        path.addCurve(to: CGPoint(x: -rx, y: cy), control1: CGPoint(x: -k * rx, y: cy + ry), control2: CGPoint(x: -rx, y: cy + k * ry))
        path.addCurve(to: CGPoint(x: 0, y: cy - ry), control1: CGPoint(x: -rx, y: cy - k * ry), control2: CGPoint(x: -k * rx, y: cy - ry))
        path.addCurve(to: CGPoint(x: rx, y: cy), control1: CGPoint(x: k * rx, y: cy - ry), control2: CGPoint(x: rx, y: cy - k * ry))
        path.closeSubpath()
        return path
    }

    static func caret(width: CGFloat, height: CGFloat) -> CGPath {
        let w = max(width, 0.02), h = max(height, 0.02)
        let r = min(3, w / 2, h / 2), k = 0.5522847498 * r
        let x0 = -w / 2, x1 = w / 2, y0 = -h / 2, y1 = h / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0 + r, y: y0))
        path.addLine(to: CGPoint(x: x1 - r, y: y0))
        path.addCurve(to: CGPoint(x: x1, y: y0 + r), control1: CGPoint(x: x1 - r + k, y: y0), control2: CGPoint(x: x1, y: y0 + r - k))
        path.addLine(to: CGPoint(x: x1, y: y1 - r))
        path.addCurve(to: CGPoint(x: x1 - r, y: y1), control1: CGPoint(x: x1, y: y1 - r + k), control2: CGPoint(x: x1 - r + k, y: y1))
        path.addLine(to: CGPoint(x: x0 + r, y: y1))
        path.addCurve(to: CGPoint(x: x0, y: y1 - r), control1: CGPoint(x: x0 + r - k, y: y1), control2: CGPoint(x: x0, y: y1 - r + k))
        path.addLine(to: CGPoint(x: x0, y: y0 + r))
        path.addCurve(to: CGPoint(x: x0 + r, y: y0), control1: CGPoint(x: x0, y: y0 + r - k), control2: CGPoint(x: x0 + r - k, y: y0))
        path.closeSubpath()
        return path
    }

    /// How much an eye narrows as it looks toward the head's edge (squared edge factor).
    static func edgeSquash(projectedX: CGFloat, left: Bool) -> CGFloat {
        let distance = left ? projectedX - 32 : 208 - projectedX
        let f = robotClamp(1 - distance / 58, 0, 1)
        return f * f
    }

    static func affine(x: CGFloat = 0, y: CGFloat = 0, degrees: CGFloat = 0, sx: CGFloat = 1, sy: CGFloat = 1) -> CATransform3D {
        CATransform3DMakeAffineTransform(
            CGAffineTransform(scaleX: sx, y: sy)
                .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
                .concatenating(CGAffineTransform(translationX: x, y: y)))
    }

    static let headCenter = CGPoint(x: 120, y: 120)

    /// A CSS `transform-origin` such as "120px 204px"; anything else is the head's centre.
    static func point(_ css: String?) -> CGPoint {
        let v = (css ?? "").split(separator: " ").compactMap { Double($0.trimmingCharacters(in: .letters)) }
        return v.count == 2 ? CGPoint(x: v[0], y: v[1]) : headCenter
    }

    /// A CSS transform list applied about `origin`, as `transform-box: view-box` does.
    static func matrix(_ list: [RobotTransformFunction], origin: CGPoint) -> CGAffineTransform {
        list.reversed().reduce(CGAffineTransform(translationX: -origin.x, y: -origin.y)) { $0.concatenating($1.matrix) }
            .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
    }

    static func matrix(_ k: RobotHeadKey, about c: CGPoint = headCenter) -> CGAffineTransform {
        CGAffineTransform(translationX: -c.x, y: -c.y)
            .concatenating(CGAffineTransform(scaleX: k.scale, y: k.scaleY ?? k.scale))
            .concatenating(CGAffineTransform(rotationAngle: k.rotation * .pi / 180))
            .concatenating(CGAffineTransform(translationX: c.x + k.x, y: c.y + k.y))
    }

    /// Splits a skew-free transform into translate, rotate (degrees) and scale about `c`.
    static func decompose(_ m: CGAffineTransform, about c: CGPoint = headCenter) -> RobotHeadKey {
        let sx = hypot(m.a, m.b), p = c.applying(m)
        return RobotHeadKey(offset: 0, x: p.x - c.x, y: p.y - c.y, scale: sx,
                            scaleY: sx > 0 ? (m.a * m.d - m.b * m.c) / sx : 0, rotation: atan2(m.b, m.a) * 180 / .pi)
    }
}

/// One function of a CSS transform list: translateX, translateY, translate, rotate (deg) or scale.
struct RobotTransformFunction: Equatable {
    var name: String
    var args: [CGFloat]

    static func parse(_ css: String) -> [RobotTransformFunction] {
        css.split(separator: ")").compactMap { part in
            let pieces = part.split(separator: "(", maxSplits: 1)
            guard pieces.count == 2 else { return nil }
            let name = pieces[0].trimmingCharacters(in: .whitespaces)
            var args = pieces[1].split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0.trimmingCharacters(in: .letters)) }.map { CGFloat($0) }
            guard !args.isEmpty else { return nil }
            if name == "translate", args.count == 1 { args.append(0) }
            if name == "scale", args.count == 1 { args.append(args[0]) }
            return RobotTransformFunction(name: name, args: args)
        }
    }

    var matrix: CGAffineTransform {
        let a = args[0], b = args.count > 1 ? args[1] : 0
        switch name {
        case "translateX": return CGAffineTransform(translationX: a, y: 0)
        case "translateY": return CGAffineTransform(translationX: 0, y: a)
        case "translate": return CGAffineTransform(translationX: a, y: b)
        case "rotate": return CGAffineTransform(rotationAngle: a * .pi / 180)
        case "scale": return CGAffineTransform(scaleX: a, y: b)
        default: return .identity
        }
    }

    func mixed(_ o: RobotTransformFunction, _ t: CGFloat) -> RobotTransformFunction {
        guard o.name == name, o.args.count == args.count else { return t < 0.5 ? self : o }
        return RobotTransformFunction(name: name, args: zip(args, o.args).map { robotLerp($0, $1, t) })
    }
}

/// Eyes on a turning drum for the wrap variant of waiting.
enum RobotWrap {
    static let cycle: Double = 2400
    private static let radius: CGFloat = 85
    private static let eyeAngle = asin(34.0 / 85)
    private static let halfWidth = 27 / cos(eyeAngle)
    private static let frames: [(time: Double, angle: CGFloat, ease: RobotEase?)] = [
        (0, 0, nil),
        (834, -.pi / 2 + eyeAngle, .bezier(0.6123122262631361, 0, 0.8763337613684284, 0.3403039133642485)),
        (996, -.pi / 2 - eyeAngle, nil),
        (1260, -3 * .pi / 2 + eyeAngle, nil),
        (1390, -3 * .pi / 2 - eyeAngle, nil),
        (2400, -2 * .pi, .bezier(0.16771539711108435, 0.7245980352977247, 0.32366613843706765, 1)),
    ]

    static func eyeHeight(width: CGFloat) -> CGFloat {
        let side = robotClamp(1 - width / 54, 0, 1)
        return 58 - 18 * side * side * (3 - 2 * side)
    }

    static func eyeX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let side = robotClamp(1 - width / 54, 0, 1)
        let sign: CGFloat = x > 120 ? 1 : (x < 120 ? -1 : 0)
        return x + sign * 9 * side * side * side
    }

    static func pose(at elapsed: Double) -> [(x: CGFloat, width: CGFloat, height: CGFloat)] {
        let time = robotClamp(elapsed, 0, cycle)
        let index = max(1, frames.firstIndex { $0.time >= time } ?? 1)
        let a = frames[index - 1], b = frames[index]
        var t = CGFloat((time - a.time) / (b.time - a.time))
        if let ease = b.ease { t = ease(t) }
        let angle = a.angle + (b.angle - a.angle) * t
        return [-eyeAngle, eyeAngle].map { offset in
            let front = cos(angle + offset)
            let width = front > 1e-10 ? 2 * halfWidth * front : 0
            return (eyeX(120 + radius * sin(angle + offset), width: width), width, eyeHeight(width: width))
        }
    }
}

/// One slot-machine reel for the `random` state: ramp, spin, Hermite slow-down, damped bounce.
struct RobotReel {
    static let radius: CGFloat = 50
    static let squeeze: CGFloat = 12.5
    static let period = Double.pi * 50
    private static let speed = 0.6, ramp = 220.0, slowDistance = 40.0, overshoot = 8.0
    private static let bouncePeriod = 200.0, damping = 0.3

    let target: Double
    let stopTime: Double
    let landTime: Double
    let endTime: Double
    private let stopPosition: Double
    private let decay: Double
    private let bounceOmega: Double

    init(slowAt: Double) {
        let v = Self.speed, p = Self.period, l = Self.slowDistance, o = Self.overshoot
        let rampEnd = v * Self.ramp / 2
        var n = max(1, ((Self.spinPosition(slowAt) + l - o) / p).rounded())
        while n * p + o - l < rampEnd { n += 1 }
        target = n * p
        stopPosition = target + o - l
        stopTime = stopPosition / v + Self.ramp / 2
        landTime = stopTime + 2 * l / v
        bounceOmega = 2 * .pi / Self.bouncePeriod
        decay = Self.damping * bounceOmega / (1 - Self.damping * Self.damping).squareRoot()
        endTime = landTime + (o > 0.1 ? log(o / 0.1) / decay : 0)
    }

    private static func spinPosition(_ t: Double) -> Double {
        t < ramp ? speed * t * t / (2 * ramp) : speed * (t - ramp / 2)
    }

    func position(at t: Double) -> Double {
        if t < stopTime { return Self.spinPosition(t) }
        if t < landTime {
            let u = (t - stopTime) / (landTime - stopTime)
            let h10 = u * u * u - 2 * u * u + u, h01 = -2 * u * u * u + 3 * u * u
            return stopPosition + Self.slowDistance * (2 * h10 + h01)
        }
        if t >= endTime { return target }
        let tau = t - landTime
        return target + Self.overshoot * exp(-decay * tau) * (cos(bounceOmega * tau) + decay / bounceOmega * sin(bounceOmega * tau))
    }

    static let pair = [RobotReel(slowAt: 1000), RobotReel(slowAt: 1420)]
    static var duration: Double { pair.map(\.endTime).max() ?? 0 }
}

/// Deterministic generator so a seeded plan always looks the same.
struct RobotRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(1 << 53)
    }
}

// MARK: - Gestures (stepped by the display link only while a pointer is down or settling)

enum RobotReaction { case angry, success }

/// Jelly drag: the head stretches toward the grab point and springs back with the release velocity.
struct RobotJelly {
    let hot: CGPoint
    private let threshold: CGFloat
    private let reactionThreshold: CGFloat
    private(set) var active = true
    private(set) var maxDistance: CGFloat = 0
    private(set) var pendingReaction: RobotReaction?
    private var intent = RobotReaction.angry
    private(set) var x = RobotSpring(), y = RobotSpring()
    private(set) var stretch = RobotSpring(), shear = RobotSpring()
    private(set) var pullX = RobotSpring(), pullY = RobotSpring()
    private var target = (x: CGFloat(0), y: CGFloat(0), stretch: CGFloat(0), shear: CGFloat(0), pullX: CGFloat(0), pullY: CGFloat(0))
    private(set) var angle: CGFloat = 0
    private(set) var anchor = CGPoint(x: 50, y: 50)

    init(hot: CGPoint, viewSize: CGFloat) {
        self.hot = hot
        threshold = robotClamp(viewSize * 0.40, 24, 46)
        reactionThreshold = max(threshold * 0.76, 22)
    }

    var pull: CGVector { CGVector(dx: pullX.value, dy: pullY.value) }

    /// `dx`/`dy`: pointer travel since the press in points, y down.
    mutating func track(dx: CGFloat, dy: CGFloat, viewSize: CGFloat) {
        let distance = hypot(dx, dy)
        maxDistance = max(maxDistance, distance)
        let scale = 240 / max(1, viewSize)
        let pdx = dx * scale, pdy = dy * scale
        let rx = hot.x - 120, ry = hot.y - 120, rl = max(1, hypot(rx, ry))
        let rux = rx / rl, ruy = ry / rl
        let radial = pdx * rux + pdy * ruy
        let tangent = -pdx * ruy + pdy * rux
        let length = max(1, hypot(pdx, pdy))
        angle = atan2(pdy / length, pdx / length)
        intent = radial < -6 ? .success : .angry
        let gain: CGFloat = distance > threshold * 0.6 ? 0.24 : 0.19
        target = (robotClamp(dx * 0.065, -5.2, 5.2), robotClamp(dy * 0.065, -5.2, 5.2),
                  robotClamp(radial / 240 * 0.08, -0.028, 0.052), robotClamp(tangent / 240 * 0.05, -0.022, 0.022),
                  robotClamp(pdx * gain, -25, 25), robotClamp(pdy * gain, -25, 25))
        anchor = CGPoint(x: robotClamp(50 - rux * 31, 15, 85), y: robotClamp(50 - ruy * 31, 15, 85))
    }

    mutating func release() {
        guard active else { return }
        active = false
        pendingReaction = maxDistance >= reactionThreshold ? intent : nil
        target = (0, 0, 0, 0, 0, 0)
    }

    /// Non-nil once finished: the reaction due after visual recovery, or `.some(nil)` when it settled without one.
    mutating func step(ms dt: Double, reduced: Bool) -> RobotReaction?? {
        let seconds = min(dt, 34) / 1000
        if active {
            let k = reduced ? 1 : 0.36 + 0.30 * CGFloat(min(1, dt / 14))
            func chase(_ s: inout RobotSpring, _ to: CGFloat, _ f: CGFloat) {
                let old = s.value
                s.value = robotLerp(s.value, to, min(1, k * f))
                s.velocity = seconds > 0 ? (s.value - old) / CGFloat(seconds) : 0
            }
            chase(&x, target.x, 1)
            chase(&y, target.y, 1)
            chase(&stretch, target.stretch, 0.85)
            chase(&shear, target.shear, 0.80)
            chase(&pullX, target.pullX, 0.95)
            chase(&pullY, target.pullY, 0.95)
        } else {
            if reduced { return .some(pendingReaction) }
            x.step(toward: 0, stiffness: 135, damping: 8.2, seconds: seconds)
            y.step(toward: 0, stiffness: 135, damping: 8.2, seconds: seconds)
            stretch.step(toward: 0, stiffness: 128, damping: 7.5, seconds: seconds)
            shear.step(toward: 0, stiffness: 118, damping: 7.2, seconds: seconds)
            pullX.step(toward: 0, stiffness: 118, damping: 7.1, seconds: seconds)
            pullY.step(toward: 0, stiffness: 118, damping: 7.1, seconds: seconds)
        }
        stretch.value = robotClamp(stretch.value, -0.035, 0.055)
        shear.value = robotClamp(shear.value, -0.026, 0.026)
        pullX.value = robotClamp(pullX.value, -26, 26)
        pullY.value = robotClamp(pullY.value, -26, 26)
        guard !active else { return nil }
        let recovered = abs(x.value) < 0.34 && abs(y.value) < 0.34 && abs(stretch.value) < 0.008
            && abs(shear.value) < 0.0035 && abs(pullX.value) < 0.40 && abs(pullY.value) < 0.40
        if let reaction = pendingReaction, recovered { return .some(reaction) }
        let settled = abs(x.value) < 0.02 && abs(y.value) < 0.02 && abs(x.velocity) < 0.04 && abs(y.velocity) < 0.04
            && abs(stretch.value) < 0.001 && abs(stretch.velocity) < 0.003 && abs(shear.value) < 0.0005
            && abs(shear.velocity) < 0.002 && abs(pullX.value) < 0.03 && abs(pullY.value) < 0.03
            && abs(pullX.velocity) < 0.06 && abs(pullY.velocity) < 0.06
        return settled ? .some(nil) : nil
    }

    /// Upstream: translate, rotate into the pull, stretch and shear, rotate back; about `anchor` (percent of the box).
    var transform: CATransform3D {
        let s = stretch.value
        let m = CGAffineTransform(rotationAngle: -angle)
            .concatenating(CGAffineTransform(a: 1, b: tan(shear.value), c: 0, d: 1, tx: 0, ty: 0))
            .concatenating(CGAffineTransform(scaleX: 1 + s, y: 1 - s * 0.30))
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: x.value, y: y.value))
        return CATransform3DMakeAffineTransform(m)
    }
}

/// Press and hold near the centre: the head squashes, eyes pinch together, then it wobbles back.
struct RobotSqueeze {
    static let holdBeforeCommit = 0.14
    private(set) var held = true
    private(set) var age: Double = 0
    private var releaseAge: Double = 0
    private(set) var q: CGFloat = 0
    private(set) var v: CGFloat = 0
    private var pressure: CGFloat = 0
    private var apex: Double = 0
    private var releaseDepth: CGFloat = 1

    mutating func release() {
        held = false
        releaseDepth = min(1, abs(q))
    }

    /// Returns true when the wobble has died out.
    mutating func step(seconds dt: Double, reduced: Bool) -> Bool {
        age += dt
        if !held { releaseAge += dt }
        if reduced {
            q = held ? 1 : 0
            v = 0
        } else {
            let omega: CGFloat = 6 / 0.57
            let k = held ? omega * omega : 190, d = held ? 2 * omega : 9
            let oldV = v
            var remaining = dt
            while remaining > 1e-9 {
                let h = CGFloat(min(1.0 / 240, remaining))
                remaining -= Double(h)
                v += ((held ? 1 : 0) - q) * k * h - v * d * h
                q += v * h
            }
            if !held, apex == 0, oldV < 0, v >= 0, q < 0 { apex = age }
        }
        if held { pressure = robotClamp((q - 0.94) / 0.06, 0, 1) }
        return !held && (reduced || (releaseAge > 0.35 && abs(q) < 0.0015 && abs(v) < 0.018))
    }

    func face(reduced: Bool) -> RobotFace {
        let p = held ? pressure : pressure * CGFloat(exp(-releaseAge * 20))
        let phase = CGFloat(age * 2 * .pi)
        let jitter = reduced ? 0 : 2 * p
        let ripple = apex > 0 ? 0.012 * CGFloat(exp(-(age - apex) * 12)) * sin(CGFloat(age - apex) * 72) * releaseDepth : 0
        let jelly = jitter * 0.005 * sin(phase * 11) + ripple
        let scale = 1 - 0.29 * q
        var face = RobotFace()
        face.headX = jitter * (0.7 * sin(phase * 13) + 0.3 * sin(phase * 19))
        face.headY = jitter * 0.45 * sin(phase * 17)
        face.headScaleX = scale + jelly
        face.headScaleY = scale - jelly
        for (key, home, delta) in [(\RobotFace.left, CGFloat(86), CGFloat(24)), (\RobotFace.right, CGFloat(154), CGFloat(-24))] {
            face[keyPath: key].x = home + delta * q
            face[keyPath: key].width = max(0, 54 - 31 * q)
            face[keyPath: key].height = max(0.1, 58 - 20 * q)
        }
        face.antennaX = RobotGeometry.antennaHome.x + jitter * 0.6 * sin(phase * 11 - 0.5)
        face.antennaY = RobotGeometry.antennaHome.y + (1 - scale + jelly) * 78 - v * 0.5
        return face
    }
}

/// Grab the antenna dot: it stretches out under the pointer, tugs the head, and twangs back on release.
struct RobotAntennaDrag {
    let home: CGPoint
    private let threshold: CGFloat
    private(set) var held = true
    private(set) var maxDistance: CGFloat = 0
    private var releaseAge: Double = 0
    private var target = CGPoint.zero
    private(set) var dot = CGPoint.zero
    private var dotVelocity = CGVector.zero
    private(set) var tug = CGPoint.zero
    private var tugVelocity = CGVector.zero

    init(home: CGPoint, viewSize: CGFloat) {
        self.home = home
        threshold = robotClamp(viewSize * 0.4, 24, 46)
    }

    mutating func track(dx: CGFloat, dy: CGFloat, viewSize: CGFloat) {
        let distance = hypot(dx, dy)
        maxDistance = max(maxDistance, distance)
        let gain: CGFloat = distance > threshold * 0.6 ? 0.24 : 0.19, scale = 240 / max(1, viewSize)
        target = CGPoint(x: robotClamp(dx * scale * gain, -25, 25), y: robotClamp(dy * scale * gain, -25, 25))
    }

    mutating func release() { held = false }

    var reacts: Bool { maxDistance > 2.5 }
    var pull: CGVector { CGVector(dx: robotClamp(tug.x, -25, 25), dy: robotClamp(tug.y, -25, 25)) }
    var stretch: CGFloat { robotClamp(dotVelocity.dy * 0.0004, -0.06, 0.06) }

    mutating func step(seconds dt: Double, reduced: Bool) -> Bool {
        if !held { releaseAge += dt }
        let settle = CGFloat(robotClamp((releaseAge - 0.45) / 0.35, 0, 1))
        if reduced {
            dot = held ? target : .zero
            tug = CGPoint(x: dot.x * 0.45, y: dot.y * 0.45)
        } else {
            var remaining = dt
            while remaining > 1e-9 {
                let h = CGFloat(min(1.0 / 240, remaining))
                remaining -= Double(h)
                if held {
                    let b = 1 - exp(-45 * h)
                    dot.x += (target.x - dot.x) * b
                    dot.y += (target.y - dot.y) * b
                    dotVelocity = .zero
                } else {
                    let d = 10 + 14 * settle
                    dotVelocity.dx += (-460 * dot.x - d * dotVelocity.dx) * h
                    dotVelocity.dy += (-460 * dot.y - d * dotVelocity.dy) * h
                    dot.x += dotVelocity.dx * h
                    dot.y += dotVelocity.dy * h
                }
                let k: CGFloat = held ? 118 : 330, d: CGFloat = held ? 7.1 : 10 + 12 * settle
                tugVelocity.dx += (k * ((held ? dot.x * 0.45 : 0) - tug.x) - d * tugVelocity.dx) * h
                tugVelocity.dy += (k * ((held ? dot.y * 0.45 : 0) - tug.y) - d * tugVelocity.dy) * h
                tug.x += tugVelocity.dx * h
                tug.y += tugVelocity.dy * h
            }
        }
        let still = max(abs(dot.x), abs(dot.y), abs(tug.x), abs(tug.y)) < 0.025
            && max(abs(dotVelocity.dx), abs(dotVelocity.dy), abs(tugVelocity.dx), abs(tugVelocity.dy)) < 0.06
        return !held && (reduced || still)
    }
}
