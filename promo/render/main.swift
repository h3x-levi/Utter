import AppKit

// Utter hype reel: 1080x1920 (or 1920x1080 with --wide), 30 fps, every cut on the 130 BPM grid in audio.swift.
// swiftc -O -o /tmp/utter-promo promo/render/main.swift promo/render/audio.swift
// /tmp/utter-promo <repo> stills 1,5.5,… [--wide]   frames at those beats into /tmp/utter-promo-stills
// /tmp/utter-promo <repo> video [--wide]            promo/Utter-Hype-9x16.mp4 or promo/Utter-Hype-16x9.mp4

let isWide = CommandLine.arguments.contains("--wide")
let W: CGFloat = isWide ? 1920 : 1080, H: CGFloat = isWide ? 1080 : 1920
/// The tall layout's value, or the wide one's.
func L<T>(_ tall: T, _ wide: T) -> T { isWide ? wide : tall }
let fps = 30.0
let totalBeats = 50.0

// MARK: - Palette and type

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}

enum Ink {
    static let navy = NSColor(hex: 0x1c2a5e), red = NSColor(hex: 0xd8352a), gold = NSColor(hex: 0xf1b632)
    static let paper = NSColor(hex: 0xf8f9fb), night = NSColor(hex: 0x0d1121), pen = NSColor(hex: 0x2a4fc4)
    static let rule = NSColor(hex: 0xc9d3e8), key = NSColor(hex: 0xe8ecf4), white = NSColor.white
}

enum Face { case poster, rounded, mono, body }

func font(_ size: CGFloat, _ face: Face) -> NSFont {
    switch face {
    case .poster: return NSFont.systemFont(ofSize: size, weight: .black, width: .compressed)
    case .mono: return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    case .body: return NSFont.systemFont(ofSize: size, weight: .semibold)
    case .rounded:
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }
}

func styled(_ s: String, _ f: NSFont, _ color: NSColor, kern: CGFloat = 0, stroke: CGFloat = 0) -> NSAttributedString {
    var a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color, .kern: kern]
    if stroke > 0 { a[.strokeWidth] = stroke; a[.strokeColor] = color }
    return NSAttributedString(string: s, attributes: a)
}

func fit(_ s: String, _ face: Face, width: CGFloat, kern: CGFloat = 0, max: CGFloat = 900) -> CGFloat {
    let probe = styled(s, font(200, face), .white, kern: kern * 200 / 100).size().width
    return min(max, 200 * width / probe)
}

// MARK: - Easing

func clamp(_ x: Double) -> Double { Swift.max(0, Swift.min(1, x)) }
func prog(_ lb: Double, _ start: Double, _ length: Double) -> Double { clamp((lb - start) / length) }
func outExpo(_ x: Double) -> Double { x >= 1 ? 1 : 1 - pow(2, -10 * x) }
func outBack(_ x: Double) -> Double { let c = 1.9; return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2) }
func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

// MARK: - Canvas

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: Int(W) * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
ctx.translateBy(x: 0, y: H)
ctx.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

func fill(_ color: NSColor, _ rect: CGRect = CGRect(x: -200, y: -200, width: W + 400, height: H + 400)) {
    ctx.setFillColor(color.cgColor); ctx.fill(rect)
}

func round(_ rect: CGRect, _ radius: CGFloat, _ color: NSColor, stroke: NSColor? = nil, line: CGFloat = 0) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path); ctx.setFillColor(color.cgColor); ctx.fillPath()
    if let stroke { ctx.addPath(path); ctx.setStrokeColor(stroke.cgColor); ctx.setLineWidth(line); ctx.strokePath() }
}

enum Align { case center, left }

/// Caps-centred text at (x, y), with its own scale, horizontal stretch, rotation and alpha.
func text(_ s: String, _ face: Face, _ size: CGFloat, _ color: NSColor, x: CGFloat = W / 2, y: CGFloat,
          align: Align = .center, scale: CGFloat = 1, stretch: CGFloat = 1, rotate: CGFloat = 0, alpha: CGFloat = 1,
          kern: CGFloat = 0, stroke: CGFloat = 0) {
    guard alpha > 0.001, scale > 0.001 else { return }
    let f = font(size, face)
    let a = styled(s, f, color, kern: kern, stroke: stroke)
    let w = a.size().width
    ctx.saveGState()
    ctx.translateBy(x: x, y: y); ctx.rotate(by: rotate); ctx.scaleBy(x: scale * stretch, y: scale); ctx.setAlpha(alpha)
    a.draw(at: CGPoint(x: align == .center ? -w / 2 : 0, y: f.capHeight / 2 - f.ascender))
    ctx.restoreGState()
}

/// A word slammed in: big and blurred-in by scale, landing on the beat.
func slam(_ s: String, _ color: NSColor, face: Face = .poster, y: CGFloat, width: CGFloat = 960, lb: Double, at start: Double,
          x: CGFloat = W / 2, maxSize: CGFloat = 900, rotate: CGFloat = 0) {
    guard lb >= start else { return }
    let p = outExpo(prog(lb, start, 0.3))
    text(s, face, fit(s, face, width: width, max: maxSize), color, x: x, y: y, scale: CGFloat(1 + 1.6 * (1 - p)),
         rotate: rotate, alpha: CGFloat(clamp(p * 3)))
}

/// Letters rising in one after another.
func stagger(_ s: String, _ face: Face, _ size: CGFloat, _ color: NSColor, x center: CGFloat = W / 2, y: CGFloat, lb: Double, at start: Double,
             every: Double = 0.07, kern: CGFloat = 0) {
    let f = font(size, face)
    let total = styled(s, f, color, kern: kern).size().width
    var x = center - total / 2
    for (i, ch) in s.enumerated() {
        let piece = String(ch)
        let w = styled(piece, f, color, kern: kern).size().width
        let p = outBack(prog(lb, start + Double(i) * every, 0.35))
        if lb >= start + Double(i) * every {
            text(piece, face, size, color, x: x + w / 2, y: y + CGFloat((1 - p) * 140), scale: CGFloat(0.4 + 0.6 * p),
                 alpha: CGFloat(clamp(p * 2)), kern: kern)
        }
        x += w
    }
}

func ruled(_ color: NSColor = Ink.paper) {
    fill(color)
    ctx.setStrokeColor(Ink.rule.withAlphaComponent(0.7).cgColor); ctx.setLineWidth(3)
    var y: CGFloat = 68
    while y < H + 100 { ctx.move(to: CGPoint(x: -100, y: y)); ctx.addLine(to: CGPoint(x: W + 100, y: y)); y += 68 }
    ctx.strokePath()
}

func sunburst(_ color: NSColor, _ b: Double, center: CGPoint = CGPoint(x: W / 2, y: H / 2)) {
    ctx.saveGState(); ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: CGFloat(b * 0.12))
    ctx.setFillColor(color.cgColor)
    for i in 0..<16 {
        let a0 = CGFloat(i) * .pi / 8, a1 = a0 + .pi / 16
        ctx.move(to: .zero)
        ctx.addLine(to: CGPoint(x: cos(a0) * 2400, y: sin(a0) * 2400))
        ctx.addLine(to: CGPoint(x: cos(a1) * 2400, y: sin(a1) * 2400))
        ctx.closePath()
    }
    ctx.fillPath(); ctx.restoreGState()
}

/// Rows of outlined UTTER drifting in opposite directions, the poster's wallpaper.
func marquee(_ color: NSColor, _ b: Double, word: String = "UTTER") {
    let row = String(repeating: word + "  ", count: 8)
    for r in 0..<7 {
        let dir: CGFloat = r % 2 == 0 ? 1 : -1
        let shift = CGFloat(b * 60).truncatingRemainder(dividingBy: 700) * dir
        text(row, .poster, 300, color, x: -900 + shift, y: CGFloat(150 + r * 290), align: .left, stroke: 2.5)
    }
}

func tape(_ rect: CGRect) {
    let w = rect.width
    fill(Ink.red, CGRect(x: rect.minX, y: rect.minY, width: w * 0.6, height: rect.height))
    fill(Ink.gold, CGRect(x: rect.minX + w * 0.6, y: rect.minY, width: w * 0.2, height: rect.height))
    fill(Ink.navy, CGRect(x: rect.minX + w * 0.8, y: rect.minY, width: w * 0.2, height: rect.height))
}

func tag(_ s: String, _ color: NSColor, _ ink: NSColor, x: CGFloat, y: CGFloat, size: CGFloat = 30, alpha: CGFloat = 1, scale: CGFloat = 1) {
    let w = styled(s, font(size, .mono), ink, kern: 2).size().width + size * 1.4
    ctx.saveGState(); ctx.translateBy(x: x, y: y); ctx.scaleBy(x: scale, y: scale); ctx.setAlpha(alpha)
    round(CGRect(x: -w / 2, y: -size * 0.95, width: w, height: size * 1.9), size * 0.95, color)
    text(s, .mono, size, ink, x: 0, y: 0, kern: 2)
    ctx.restoreGState()
}

func tick(_ p: Double, at origin: CGPoint, size: CGFloat, color: NSColor, width: CGFloat) {
    let pts = [CGPoint(x: 0, y: 0.55), CGPoint(x: 0.38, y: 0.9), CGPoint(x: 1, y: 0.1)].map { CGPoint(x: origin.x + $0.x * size, y: origin.y + $0.y * size) }
    ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: pts[0])
    let first = clamp(p * 2), second = clamp(p * 2 - 1)
    ctx.addLine(to: CGPoint(x: pts[0].x + (pts[1].x - pts[0].x) * first, y: pts[0].y + (pts[1].y - pts[0].y) * first))
    if second > 0 { ctx.addLine(to: CGPoint(x: pts[1].x + (pts[2].x - pts[1].x) * second, y: pts[1].y + (pts[2].y - pts[1].y) * second)) }
    ctx.strokePath()
}

enum PillLook { case rest, listening, handsFree, typed }

/// Utter's REC stripe pill, drawn at any size: bars dance with the music.
func pill(_ look: PillLook, center: CGPoint, scale s: CGFloat, b: Double) {
    let size: CGSize = look == .rest ? CGSize(width: 64, height: 12) : CGSize(width: look == .handsFree ? 92 : 72, height: 22)
    let rect = CGRect(x: center.x - size.width * s / 2, y: center.y - size.height * s / 2, width: size.width * s, height: size.height * s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 6 * s / 4), blur: 18, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    if look == .rest {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)); ctx.clip()
        tape(rect)
        ctx.restoreGState(); return
    }
    round(rect, rect.height / 2, look == .typed ? Ink.navy : Ink.red)
    ctx.restoreGState()
    if look == .typed { tick(1, at: CGPoint(x: center.x - 8 * s, y: center.y - 7 * s), size: 15 * s, color: .white, width: 3 * s); return }
    let heights: [CGFloat] = [6, 11, 14, 9, 14, 11, 6]
    let barW = 2.2 * s, gap = 2.6 * s
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    let left = center.x - total / 2 - (look == .handsFree ? 9 * s : 0)
    for (i, h) in heights.enumerated() {
        let dance = 0.55 + 0.45 * abs(sin(b * .pi * 2 + Double(i) * 1.1))
        let bh = h * s * 1.05 * CGFloat(dance)
        round(CGRect(x: left + CGFloat(i) * (barW + gap), y: center.y - bh / 2, width: barW, height: bh), barW / 2, .white)
    }
    if look == .handsFree {
        let lx = center.x + 30 * s, ly = center.y
        round(CGRect(x: lx - 4 * s, y: ly - 1 * s, width: 8 * s, height: 6.5 * s), 1.5 * s, .white)
        ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(1.6 * s)
        ctx.addArc(center: CGPoint(x: lx, y: ly - 1 * s), radius: 2.6 * s, startAngle: .pi, endAngle: 0, clockwise: false); ctx.strokePath()
    }
}

var images: [String: NSImage] = [:]
func image(_ name: String, _ root: URL) -> NSImage {
    if let hit = images[name] { return hit }
    let img = NSImage(contentsOf: root.appendingPathComponent(name)) ?? NSImage(size: CGSize(width: 10, height: 10))
    images[name] = img
    return img
}

func draw(_ img: NSImage, center: CGPoint, width: CGFloat, rotate: CGFloat = 0, alpha: CGFloat = 1, scale: CGFloat = 1) {
    let h = width * img.size.height / img.size.width
    ctx.saveGState(); ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: rotate); ctx.scaleBy(x: scale, y: scale)
    img.draw(in: CGRect(x: -width / 2, y: -h / 2, width: width, height: h), from: .zero, operation: .sourceOver, fraction: alpha,
             respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    ctx.restoreGState()
}

// MARK: - Scenes (lb = beats since the scene began)

var root = URL(fileURLWithPath: ".")

func open(_ lb: Double, _ b: Double) {
    let flipped = lb >= 2
    fill(flipped ? Ink.red : Ink.night)
    marquee((flipped ? Ink.navy : Ink.white).withAlphaComponent(0.1), b)
    if lb < 3 {
        slam("STOP", flipped ? Ink.navy : .white, y: L(720, 360), width: L(960, 1100), lb: lb, at: 0, maxSize: L(900, 480))
        slam("TYPING.", flipped ? .white : Ink.red, y: L(1150, 750), width: L(960, 1500), lb: lb, at: 1, maxSize: L(900, 480))
    } else {
        text("STOP TYPING.", .poster, Swift.min(L(900, 150), fit("STOP TYPING.", .poster, width: L(760, 700))), Ink.navy, y: L(520, 150), alpha: 0.9)
        slam("JUST", .white, y: L(900, 430), width: L(700, 800), lb: lb, at: 3, maxSize: L(900, 360))
        slam("TALK.", Ink.gold, y: L(1300, 800), width: L(960, 1300), lb: lb, at: 3.25, maxSize: L(900, 420))
    }
}

func holdFn(_ lb: Double, _ b: Double) {
    ruled()
    slam("HOLD", Ink.navy, y: L(360, 330), width: L(720, 760), lb: lb, at: 0, x: L(540, 560), maxSize: L(900, 400))
    let pressed = lb > 0.5
    let key = CGRect(x: L(350, 1230), y: L(560, 260) + (pressed ? 14 : 0), width: L(380, 340), height: L(380, 340))
    round(key.offsetBy(dx: 0, dy: pressed ? 4 : 18), 70, NSColor(hex: 0xb9c3d8))
    round(key, 70, pressed ? NSColor(hex: 0xd9dfeb) : Ink.key, stroke: NSColor(hex: 0xc4cddf), line: 4)
    text("fn", .mono, 150, Ink.navy, x: key.minX + 70, y: key.maxY - 110, align: .left)
    if pressed { tag("HOLD THE KEY", Ink.navy, .white, x: L(540, 1400), y: L(1030, 690), size: 30, alpha: CGFloat(prog(lb, 0.5, 0.3))) }
    slam("SAY IT.", Ink.red, y: L(1330, 760), width: L(960, 860), lb: lb, at: 2, x: L(540, 560), maxSize: L(900, 420))
    if lb >= 2 { pill(.listening, center: CGPoint(x: L(540, 1400), y: L(1690, 900)), scale: CGFloat(L(5, 4) * outBack(prog(lb, 2, 0.4))), b: b) }
}

func types(_ lb: Double, _ b: Double) {
    if lb < 2 {
        fill(Ink.gold)
        stagger("LET GO.", .poster, Swift.min(L(900, 560), fit("LET GO.", .poster, width: L(900, 1500))), Ink.navy, y: L(960, 540), lb: lb, at: 0, every: 0.06)
        return
    }
    fill(Ink.navy)
    if lb < 4 {
        slam("IT TYPES", .white, y: L(820, 380), width: L(960, 1300), lb: lb, at: 2, maxSize: L(900, 400))
        slam("FOR YOU.", Ink.gold, y: L(1180, 740), width: L(960, 1200), lb: lb, at: 2.5, maxSize: L(900, 400))
        return
    }
    text("TYPES TYPES TYPES", .poster, L(260, 200), NSColor.white.withAlphaComponent(0.12), x: 110, y: L(960, 540), rotate: -.pi / 2, stroke: 2.5)
    let rise = outExpo(prog(lb, 4, 0.5))
    let card = CGRect(x: L(90, 360), y: L(600, 170) + CGFloat((1 - rise) * 900), width: L(900, 1200), height: L(660, 560))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 24), blur: 60, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    round(card, 40, Ink.paper)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.clip()
    tape(CGRect(x: card.minX, y: card.minY, width: card.width, height: 26))
    ctx.setStrokeColor(Ink.rule.cgColor); ctx.setLineWidth(3)
    for i in 1...5 { let y = card.minY + 160 + CGFloat(i) * 92; ctx.move(to: CGPoint(x: card.minX, y: y)); ctx.addLine(to: CGPoint(x: card.maxX, y: y)) }
    ctx.strokePath()
    ctx.restoreGState()
    text("TRACK 03  ·  INTO MESSAGES  ·  0:03", .mono, 28, NSColor(hex: 0x6b7593), x: card.minX + 56, y: card.minY + 110, align: .left, kern: 1)
    let lines = ["Running ten minutes", "late, save me a seat."]
    let typed = Int(prog(lb, 4.5, 2.2) * Double(lines.joined().count))
    var left = typed
    for (i, line) in lines.enumerated() {
        let shown = String(line.prefix(Swift.max(0, left)))
        left -= line.count
        let y = card.minY + 230 + CGFloat(i) * 92 + 16
        text(shown, .rounded, 74, Ink.pen, x: card.minX + 56, y: y, align: .left)
        if left < 0 || (i == 1 && left == 0) {
            let w = styled(shown, font(74, .rounded), .black).size().width
            if Int(lb * 4) % 2 == 0 || left < 0 { fill(Ink.red, CGRect(x: card.minX + 60 + w, y: y - 40, width: 7, height: 80)) }
            break
        }
    }
    if lb >= 6.8 {
        tick(prog(lb, 6.8, 0.3), at: CGPoint(x: card.maxX - 170, y: card.maxY - 170), size: 110, color: Ink.red, width: 14)
    }
    if lb >= 7 { slam("ANYWHERE YOUR CURSOR IS.", .white, y: L(1460, 900), width: L(900, 1400), lb: lb, at: 7, maxSize: L(900, 170)) }
}

func apps(_ lb: Double, _ b: Double) {
    let words = ["MAIL", "SLACK", "NOTES", "XCODE", "SAFARI", "DOCS", "TERMINAL", "ANY APP."]
    // One background per beat, words twice a beat: full-screen colour changes stay under 3 a second.
    let bgs = [Ink.red, Ink.red, Ink.navy, Ink.navy, Ink.gold, Ink.gold, Ink.night, Ink.night]
    let inks = [NSColor.white, Ink.navy, NSColor.white, Ink.gold, Ink.navy, Ink.red, Ink.gold, NSColor.white]
    let i = Swift.min(7, Int(lb * 2))
    let shade = Swift.min(7, Int(lb) * 2)
    fill(bgs[shade])
    text("INTO", .mono, 44, inks[i].withAlphaComponent(0.8), y: L(640, 260), kern: 12)
    let local = lb * 2 - Double(i)
    let w = words[i]
    text(w, .poster, Swift.min(L(900, 540), fit(w, .poster, width: L(960, 1700))), inks[i], y: L(960, 560), scale: CGFloat(1 + 0.35 * (1 - outExpo(clamp(local * 2.5)))),
         stretch: i == 7 ? 1 : CGFloat(1 + 0.08 * sin(local * .pi)))
    let bar = CGRect(x: L(120, 360), y: L(1640, 900), width: L(840, 1200), height: 26)
    round(bar, 13, inks[i].withAlphaComponent(0.18))
    ctx.saveGState(); ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 13, cornerHeight: 13, transform: nil)); ctx.clip()
    tape(CGRect(x: bar.minX, y: bar.minY, width: bar.width * CGFloat(prog(lb, 0, 4)), height: bar.height))
    ctx.restoreGState()
}

func drop(_ lb: Double, _ b: Double) {
    fill(Ink.red)
    sunburst(Ink.gold.withAlphaComponent(0.16), b)
    slam("100%", .white, y: L(760, 560), width: L(980, 1050), lb: lb, at: 0, x: L(540, 620), maxSize: L(900, 640))
    slam("ON YOUR", Ink.navy, y: L(1100, 430), width: L(900, 720), lb: lb, at: 1, x: L(540, 1480), maxSize: L(900, 300))
    slam("MAC.", Ink.gold, y: L(1430, 760), width: L(760, 640), lb: lb, at: 2, x: L(540, 1480), maxSize: L(900, 380))
    let tags = L([("ON-DEVICE", 250.0, 300.0, -0.12), ("OFFLINE", 820.0, 420.0, 0.1), ("WHISPER.CPP", 280.0, 1700.0, 0.08), ("NO UPLOADS", 790.0, 1780.0, -0.1)],
                 [("ON-DEVICE", 300.0, 150.0, -0.12), ("OFFLINE", 1660.0, 160.0, 0.1), ("WHISPER.CPP", 330.0, 960.0, 0.08), ("NO UPLOADS", 1640.0, 980.0, -0.1)])
    for (n, t) in tags.enumerated() where lb >= 2 + Double(n) * 0.4 {
        let p = outBack(prog(lb, 2 + Double(n) * 0.4, 0.3))
        ctx.saveGState(); ctx.translateBy(x: CGFloat(t.1), y: CGFloat(t.2)); ctx.rotate(by: CGFloat(t.3))
        tag(t.0, .white, Ink.red, x: 0, y: 0, size: 36, scale: CGFloat(p))
        ctx.restoreGState()
    }
}

func noStrings(_ lb: Double, _ b: Double) {
    fill(Ink.navy)
    marquee(NSColor.white.withAlphaComponent(0.06), b, word: "LOCAL")
    for (i, line) in ["NO CLOUD", "NO ACCOUNT", "NO SUBSCRIPTION"].enumerated() where lb >= Double(i) {
        let y = L(CGFloat(560 + i * 270), CGFloat(200 + i * 220))
        slam(line, .white, y: y, width: L(900, 1300), lb: lb, at: Double(i), maxSize: L(900, 200))
        let p = inOut(prog(lb, Double(i) + 0.3, 0.25))
        let size = Swift.min(L(900, 200), fit(line, .poster, width: L(900, 1300)))
        let half = styled(line, font(size, .poster), .white).size().width / 2
        if p > 0 {
            ctx.setStrokeColor(Ink.red.cgColor); ctx.setLineWidth(26); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: W / 2 - half - 20, y: y + 30)); ctx.addLine(to: CGPoint(x: W / 2 - half - 20 + (2 * half + 40) * CGFloat(p), y: y - 30)); ctx.strokePath()
        }
    }
    slam("JUST YOU.", Ink.gold, y: L(1460, 900), width: L(860, 900), lb: lb, at: 3, maxSize: L(900, 210))
}

func library(_ lb: Double, _ b: Double) {
    ruled()
    fill(Ink.red, CGRect(x: -200, y: -200, width: W + 400, height: 300))
    let segs = 12
    for s in 0..<Swift.min(segs, Int(lb * 3.5) + 1) { round(CGRect(x: 60 + CGFloat(s) * 54, y: 44, width: 46, height: 14), 7, .white) }
    let count = Int(168 * outExpo(prog(lb, 0, 3)))
    text("\(count) / 500 WORDS", .mono, 30, .white, x: W - 360, y: 51, align: .left, kern: 2)
    slam("EVERY WORD", Ink.navy, y: L(300, 380), width: L(900, 720), lb: lb, at: 0, x: L(540, 470), maxSize: L(900, 260))
    slam("ON ONE TAPE.", Ink.red, y: L(530, 640), width: L(900, 720), lb: lb, at: 0.5, x: L(540, 470), maxSize: L(900, 240))
    if lb >= 1 {
        let p = outExpo(prog(lb, 1, 1.1))
        draw(image("Assets/screenshots/library.webp", root), center: CGPoint(x: L(540, 1430), y: L(1280, 600) + CGFloat((1 - p) * 1300)), width: L(1060, 900),
             rotate: CGFloat(-0.14 * (1 - p)), scale: CGFloat(1 + 0.03 * sin(lb * .pi)))
    }
    if lb >= 3 { tag("SIDE A · SIDE B · EVERY DAY", Ink.navy, .white, x: L(540, 470), y: L(1720, 860), size: 30, scale: CGFloat(outBack(prog(lb, 3, 0.3)))) }
}

func hub(_ lb: Double, _ b: Double) {
    fill(Ink.night)
    sunburst(NSColor.white.withAlphaComponent(0.03), b, center: CGPoint(x: W - 180, y: 0))
    fill(NSColor(hex: 0x1c2234), CGRect(x: -200, y: -200, width: W + 400, height: 270))
    text("CLICK THE MENU BAR", .mono, 30, NSColor.white.withAlphaComponent(0.7), x: 70, y: 36, align: .left, kern: 3)
    for (i, h) in [11.0, 14, 9, 14, 11].enumerated() { round(CGRect(x: W - 180 + CGFloat(i) * 9, y: 36 - CGFloat(h), width: 5, height: CGFloat(h * 2)), 2.5, .white) }
    let p = outBack(prog(lb, 0, 0.7))
    draw(image("Assets/screenshots/hub.webp", root), center: CGPoint(x: L(600, 1450), y: L(-700, -600) + CGFloat(p) * L(1340, 1160)), width: L(700, 520))
    if lb >= 1.5 {
        let q = outBack(prog(lb, 1.5, 0.3))
        let key = CGRect(x: L(80, 150), y: L(1360, 300), width: 190, height: 190)
        ctx.saveGState(); ctx.translateBy(x: key.midX, y: key.midY); ctx.scaleBy(x: CGFloat(q), y: CGFloat(q)); ctx.translateBy(x: -key.midX, y: -key.midY)
        round(key.offsetBy(dx: 0, dy: 10), 40, NSColor(hex: 0x8d97b3)); round(key, 40, Ink.key)
        text("\u{21A9}", .rounded, 120, Ink.navy, x: key.midX, y: key.midY)
        ctx.restoreGState()
        slam("PASTE IT", .white, y: L(1390, 330), width: L(640, 560), lb: lb, at: 1.5, x: L(650, 680), maxSize: L(900, 230))
        slam("AGAIN.", Ink.gold, y: L(1560, 560), width: L(560, 520), lb: lb, at: 1.75, x: L(650, 680), maxSize: L(900, 230))
    }
    if lb >= 2.5 {
        let looks: [(PillLook, String)] = [(.rest, "AT REST"), (.listening, "LISTENING"), (.handsFree, "HANDS-FREE"), (.typed, "TYPED")]
        let i = Swift.min(3, Int((lb - 2.5) / 0.375))
        pill(looks[i].0, center: CGPoint(x: L(540, 520), y: L(1760, 860)), scale: 3.2, b: b)
        text(looks[i].1, .mono, 30, NSColor.white.withAlphaComponent(0.8), x: L(540, 520), y: L(1860, 960), kern: 6)
    }
}

func meetings(_ lb: Double, _ b: Double) {
    fill(Ink.gold)
    slam("MEETINGS", Ink.navy, y: L(380, 360), width: L(940, 800), lb: lb, at: 0, x: L(540, 500), maxSize: L(900, 280))
    slam("INTO NOTES.", Ink.red, y: L(620, 640), width: L(860, 800), lb: lb, at: 0.5, x: L(540, 500), maxSize: L(900, 240))
    let rise = outExpo(prog(lb, 1, 0.4))
    let card = CGRect(x: L(70, 1000), y: L(820, 220) + CGFloat((1 - rise) * 1100), width: L(940, 840), height: L(640, 560))
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: 20), blur: 50, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    round(card, 40, Ink.paper); ctx.restoreGState()
    text("DESIGN SYNC  ·  32:00", .mono, 30, NSColor(hex: 0x6b7593), x: card.minX + 60, y: card.minY + 80, align: .left, kern: 2)
    let turns: [(String, NSColor, [String])] = [("YOU", Ink.red, ["Let's start with", "the pill."]), ("OTHERS", Ink.navy, ["Agreed. One colour", "per state."])]
    for (i, turn) in turns.enumerated() where lb >= 1.5 + Double(i) {
        let p = outBack(prog(lb, 1.5 + Double(i), 0.3))
        let top = card.minY + 170 + CGFloat(i) * 230
        tag(turn.0, turn.1, .white, x: card.minX + 140, y: top + 40, size: 30, scale: CGFloat(p))
        for (j, line) in turn.2.enumerated() {
            text(line, .rounded, L(58, 52), Ink.navy, x: card.minX + 270, y: top + 40 + CGFloat(j) * 76, align: .left, alpha: CGFloat(clamp(p)))
        }
    }
    if lb >= 3.2 { tag("RECORDED AND TRANSCRIBED ON YOUR MAC", Ink.navy, .white, x: L(540, 500), y: L(1600, 880), size: 28, scale: CGFloat(outBack(prog(lb, 3.2, 0.3)))) }
}

func words(_ lb: Double, _ b: Double) {
    fill(Ink.navy)
    marquee(NSColor.white.withAlphaComponent(0.06), b, word: "WORDS")
    slam("IT LEARNS", .white, y: L(360, 380), width: L(880, 800), lb: lb, at: 0, x: L(540, 520), maxSize: L(900, 260))
    slam("YOUR WORDS.", Ink.gold, y: L(600, 640), width: L(900, 820), lb: lb, at: 0.5, x: L(540, 520), maxSize: L(900, 240))
    let chips = ["Kubernetes", "Okafor", "Edinburgh", "Utter"]
    for (i, w) in chips.enumerated() where lb >= 1 + Double(i) * 0.5 {
        let p = outExpo(prog(lb, 1 + Double(i) * 0.5, 0.45))
        let from: CGFloat = i % 2 == 0 ? -900 : 900
        let y = L(CGFloat(880 + i * 190), CGFloat(200 + i * 200))
        let size: CGFloat = 76
        let tw = styled(w, font(size, .rounded), Ink.pen).size().width
        let x = L(540, 1450) + from * CGFloat(1 - p) + (i % 2 == 0 ? -40 : 40)
        let chip = CGRect(x: x - tw / 2 - 60, y: y - 70, width: tw + 190, height: 140)
        round(chip, 70, .white)
        text(w, .rounded, size, Ink.pen, x: chip.minX + 60 + tw / 2, y: y)
        tick(prog(lb, 1.3 + Double(i) * 0.5, 0.3), at: CGPoint(x: chip.maxX - 100, y: y - 26), size: 52, color: Ink.red, width: 9)
    }
    if lb >= 3.2 { tag("SPELLED YOUR WAY", Ink.gold, Ink.navy, x: L(540, 520), y: L(1700, 880), size: 30, scale: CGFloat(outBack(prog(lb, 3.2, 0.3)))) }
}

func logo(_ lb: Double, _ b: Double) {
    fill(Ink.night)
    sunburst(Ink.navy.withAlphaComponent(0.55), b, center: CGPoint(x: L(540, 560), y: L(960, 540)))
    let p = outBack(prog(lb, 0, 0.5))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 120, color: Ink.red.withAlphaComponent(0.55).cgColor)
    draw(image("Assets/AppIconSource.png", root), center: CGPoint(x: L(540, 560), y: L(640, 540)), width: L(560, 480), rotate: CGFloat(0.25 * (1 - p)), scale: CGFloat(p))
    ctx.restoreGState()
    stagger("UTTER", .rounded, fit("UTTER", .rounded, width: 820), .white, x: L(540, 1300), y: L(1110, 400), lb: lb, at: 0.75, every: 0.08)
    if lb >= 2 { text("TALK INSTEAD OF TYPING.", .rounded, 58, Ink.gold, x: L(540, 1300), y: L(1300, 580), alpha: CGFloat(outExpo(prog(lb, 2, 0.3))), kern: 1) }
    if lb >= 2.5 { text("FREE  ·  OPEN SOURCE  ·  ON YOUR MAC", .mono, 32, NSColor.white.withAlphaComponent(0.85), x: L(540, 1300), y: L(1395, 670), alpha: CGFloat(outExpo(prog(lb, 2.5, 0.3))), kern: 2) }
    if lb >= 2.5 { tape(CGRect(x: L(340, 1100), y: L(1460, 730), width: 400 * CGFloat(outExpo(prog(lb, 2.5, 0.6))), height: 16)) }
    if lb >= 4 { text("github.com/h3x-levi/Utter", .mono, 40, NSColor.white, x: L(540, 1300), y: L(1620, 840), alpha: CGFloat(outExpo(prog(lb, 4, 0.3)))) }
}

struct Scene { let start: Double; let length: Double; let draw: (Double, Double) -> Void }
let scenes = [
    Scene(start: 0, length: 4, draw: open), Scene(start: 4, length: 4, draw: holdFn), Scene(start: 8, length: 8, draw: types),
    Scene(start: 16, length: 4, draw: apps), Scene(start: 20, length: 4, draw: drop), Scene(start: 24, length: 4, draw: noStrings),
    Scene(start: 28, length: 4, draw: library), Scene(start: 32, length: 4, draw: hub), Scene(start: 36, length: 4, draw: meetings),
    Scene(start: 40, length: 4, draw: words), Scene(start: 44, length: 6, draw: logo),
]
let cuts = scenes.map(\.start).dropFirst()

// MARK: - Transitions and the frame

func wipe(_ b: Double, around cut: Double) {
    let p = (b - (cut - 0.5)) / 1.0
    guard p > 0, p < 1 else { return }
    let travel = CGFloat(inOut(p)) * (W * 3.4) - W * 1.7
    for (i, color) in [Ink.red, Ink.gold, Ink.navy].enumerated() {
        let x = travel - CGFloat(i) * 260
        ctx.setFillColor(color.cgColor)
        ctx.move(to: CGPoint(x: x - 700, y: -200)); ctx.addLine(to: CGPoint(x: x + 300, y: -200))
        ctx.addLine(to: CGPoint(x: x + 700, y: H + 200)); ctx.addLine(to: CGPoint(x: x - 300, y: H + 200)); ctx.closePath(); ctx.fillPath()
    }
}

func kickEnvelope(_ b: Double) -> Double {
    let step = b * 4
    let inBar = step.truncatingRemainder(dividingBy: 16)
    let last = [0.0, 3, 7, 10].last { $0 <= inBar } ?? -6
    return exp(-(inBar - last) * 1.6)
}

var seed: UInt32 = 0x9e37_79b9
func random() -> CGFloat { seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5; return CGFloat(seed % 10_000) / 10_000 }

func glitch(strength: CGFloat) {
    guard let raw = ctx.data else { return }
    let px = raw.bindMemory(to: UInt8.self, capacity: Int(W * H * 4))
    let row = Int(W) * 4
    let copy = Array(UnsafeBufferPointer(start: px, count: Int(W * H * 4)))
    let split = Int(14 * strength)
    for y in 0..<Int(H) {
        let base = y * row
        for x in 0..<Int(W) {
            let r = Swift.min(Int(W) - 1, x + split), bl = Swift.max(0, x - split)
            px[base + x * 4 + 2] = copy[base + r * 4 + 2]
            px[base + x * 4] = copy[base + bl * 4]
        }
    }
    for _ in 0..<Int(10 * strength) {
        let y0 = Int(random() * (H - 120)), h = 20 + Int(random() * 90), dx = Int((random() - 0.5) * 160 * strength)
        for y in y0..<(y0 + h) {
            let base = y * row
            for x in 0..<Int(W) {
                let sx = Swift.min(Int(W) - 1, Swift.max(0, x - dx))
                for c in 0..<4 { px[base + x * 4 + c] = copy[base + sx * 4 + c] }
            }
        }
    }
}

func frame(_ b: Double) {
    ctx.saveGState()
    fill(.black)
    let scene = scenes.last { b >= $0.start } ?? scenes[0]
    let lb = b - scene.start
    var zoom = 1 + 0.12 * exp(-lb * 9)
    if (20..<44).contains(b) { zoom += 0.022 * kickEnvelope(b) }
    let shake = (b >= 19 && b < 20) ? CGFloat((b - 19) * 14) : ((20..<20.5).contains(b) || (44..<44.4).contains(b) ? 16 : 0)
    ctx.translateBy(x: W / 2 + (random() - 0.5) * shake, y: H / 2 + (random() - 0.5) * shake)
    ctx.scaleBy(x: CGFloat(zoom), y: CGFloat(zoom))
    ctx.translateBy(x: -W / 2, y: -H / 2)
    if let cut = [8.0, 32].first(where: { abs(b - $0) < 0.2 }), let before = scenes.last(where: { $0.start < cut }),
       let after = scenes.first(where: { $0.start == cut }) {
        let p = CGFloat(inOut((b - (cut - 0.2)) / 0.4))
        ctx.saveGState(); ctx.translateBy(x: 0, y: -H * p); before.draw(b - before.start, b); ctx.restoreGState()
        ctx.saveGState(); ctx.translateBy(x: 0, y: H * (1 - p)); after.draw(Swift.max(0, b - cut), b); ctx.restoreGState()
    } else {
        scene.draw(lb, b)
    }
    ctx.restoreGState()
    for cut in [4.0, 16, 28, 40] { wipe(b, around: cut) }
    if let cut = cuts.last(where: { $0 <= b }), b - cut < 0.2 { fill(NSColor.white.withAlphaComponent(CGFloat(0.55 * (1 - (b - cut) / 0.2)))) }
    if b > 49.4 { fill(NSColor.black.withAlphaComponent(CGFloat(clamp((b - 49.4) / 0.6)))) }
    if (20..<20.35).contains(b) || (44..<44.3).contains(b) || (16..<16.15).contains(b) { glitch(strength: 1) }
}

// MARK: - Output

func png(_ url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let args = CommandLine.arguments.filter { $0 != "--wide" }
guard args.count >= 3 else { print("usage: utter-promo <repo> stills <beats> | video [--wide]"); exit(64) }
root = URL(fileURLWithPath: args[1])

if args[2] == "stills" {
    let out = URL(fileURLWithPath: isWide ? "/tmp/utter-promo-stills-wide" : "/tmp/utter-promo-stills", isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for value in (args.count > 3 ? args[3] : "1").split(separator: ",") {
        let b = Double(value)!
        frame(b)
        try png(out.appendingPathComponent(String(format: "beat-%05.2f.png", b)))
    }
    print(out.path)
} else {
    let wav = URL(fileURLWithPath: "/tmp/utter-promo.wav")
    try writeWAV(soundtrack(beats: totalBeats), to: wav)
    let output = root.appendingPathComponent(isWide ? "promo/Utter-Hype-16x9.mp4" : "promo/Utter-Hype-9x16.mp4")
    let ffmpeg = Process()
    ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    ffmpeg.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(Int(W))x\(Int(H))", "-r", "\(Int(fps))",
                        "-i", "-", "-i", wav.path, "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                        "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                        "-af", "loudnorm=I=-14:TP=-1:LRA=7", "-ar", "48000", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", output.path]
    let pipe = Pipe()
    ffmpeg.standardInput = pipe
    try ffmpeg.run()
    let frames = Int((totalBeats * beatSeconds * fps).rounded(.up))
    for i in 0..<frames {
        frame(Double(i) / fps / beatSeconds)
        pipe.fileHandleForWriting.write(Data(bytesNoCopy: ctx.data!, count: Int(W * H * 4), deallocator: .none))
        if i % 60 == 0 { print("frame \(i)/\(frames)") }
    }
    try pipe.fileHandleForWriting.close()
    ffmpeg.waitUntilExit()
    print(ffmpeg.terminationStatus == 0 ? output.path : "ffmpeg failed")
}
