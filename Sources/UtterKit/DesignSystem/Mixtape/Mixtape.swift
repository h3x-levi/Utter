import AppKit
import SwiftUI

/// The Mixtape look: a cassette J-card on ruled stock, navy ballpoint ink, one red tape stripe.
enum Mixtape {
    enum Palette {
        typealias Swatch = Look.Swatch

        static let paper = Swatch(light: .hex(0xF8F9FB), dark: .hex(0x15171C))
        static let spine = Swatch(light: .hex(0xEEF1F6), dark: .hex(0x101216))
        static let fold = Swatch(light: .hex(0xFBFCFD), dark: .hex(0x181A20))
        static let rule = Swatch(light: .hex(0x2E50AA, 0.13), dark: .hex(0x96AFFF, 0.08),
                                 lightIncreased: .hex(0x2E50AA, 0.36), darkIncreased: .hex(0x96AFFF, 0.28))
        static let rule2 = Swatch(light: .hex(0x2E50AA, 0.26), dark: .hex(0x96AFFF, 0.18),
                                  lightIncreased: .hex(0x2E50AA, 0.55), darkIncreased: .hex(0x96AFFF, 0.45))
        static let ink = Swatch(light: .hex(0x1C2A5E), dark: .hex(0xE9EDF8))
        static let ink2 = Swatch(light: .hex(0x4A5680), dark: .hex(0xAEB6CD))
        static let ink3 = Swatch(light: .hex(0x646B82), dark: .hex(0x7D87A2),
                                 lightIncreased: .hex(0x565F7E), darkIncreased: .hex(0xA3ABC2))
        static let pen = Swatch(light: .hex(0x2A4FC4), dark: .hex(0x8FA8FF))
        static let penInk = Swatch(light: .hex(0x20348C), dark: .hex(0xC2D0FF))
        static let red = Swatch(light: .hex(0xD8352A), dark: .hex(0xE2463B))
        static let gold = Swatch(light: .hex(0xF1B632), dark: .hex(0xF1B632))
        static let navy = Swatch(light: .hex(0x1C2A5E), dark: .hex(0x2C3656))
        static let wash = Swatch(light: .hex(0x2A4FC4, 0.08), dark: .hex(0x8FA8FF, 0.09))
        static let mark = Swatch(light: .hex(0xD8352A, 0.2), dark: .hex(0xE2463B, 0.32))
        static let note = Swatch(light: .hex(0xF1B632, 0.17), dark: .hex(0xF1B632, 0.12))
        static let edge = Swatch(light: .hex(0x1E2846, 0.13), dark: .hex(0xFFFFFF, 0.08),
                                 lightIncreased: .hex(0x1E2846, 0.4), darkIncreased: .hex(0xFFFFFF, 0.3))
        static let key = Swatch(light: .hex(0xE6EAF1), dark: .hex(0x23262E))
        static let keyHi = Swatch(light: .hex(0xFFFFFF), dark: .hex(0xFFFFFF, 0.08))
        static let keyLo = Swatch(light: .hex(0x1C2A5E, 0.22), dark: .hex(0x000000, 0.6))

        static let pillRed = Swatch(light: .hex(0xD8352A), dark: .hex(0xD8352A),
                                    lightIncreased: .hex(0xCC2A20), darkIncreased: .hex(0xCC2A20))
        static let pillNavy = Swatch(light: .hex(0x1C2A5E), dark: .hex(0x1C2A5E),
                                     lightIncreased: .hex(0x3D5ED8), darkIncreased: .hex(0x3D5ED8))
        static let pillGoldInk = Swatch(light: .hex(0x1C2A5E), dark: .hex(0x1C2A5E),
                                        lightIncreased: .hex(0x121C45), darkIncreased: .hex(0x121C45))
        static let pillStripeNavy = Swatch(light: .hex(0x2C3A6E), dark: .hex(0x2C3A6E),
                                           lightIncreased: .hex(0x3D5ED8), darkIncreased: .hex(0x3D5ED8))
        static let pillStripeBlue = Swatch(light: .hex(0x5A6AA6), dark: .hex(0x5A6AA6))
        static let pillTape = Swatch(light: .hex(0x121419), dark: .hex(0x121419))
        static let pillTapeInk = Swatch(light: .hex(0xEEF2FB), dark: .hex(0xEEF2FB),
                                        lightIncreased: .hex(0xFFFFFF), darkIncreased: .hex(0xFFFFFF))
        static let pillTranscript = Swatch(light: .hex(0xDFE6FF), dark: .hex(0xDFE6FF),
                                           lightIncreased: .hex(0xF2F5FF), darkIncreased: .hex(0xF2F5FF))
        static let pillTapeRule = Swatch(light: .hex(0x96AFFF, 0.09), dark: .hex(0x96AFFF, 0.09),
                                         lightIncreased: .hex(0x96AFFF, 0.28), darkIncreased: .hex(0x96AFFF, 0.28))
    }

    static let paper = Color(nsColor: Palette.paper.nsColor)
    static let spine = Color(nsColor: Palette.spine.nsColor)
    static let fold = Color(nsColor: Palette.fold.nsColor)
    static let rule = Color(nsColor: Palette.rule.nsColor)
    static let rule2 = Color(nsColor: Palette.rule2.nsColor)
    static let ink = Color(nsColor: Palette.ink.nsColor)
    static let ink2 = Color(nsColor: Palette.ink2.nsColor)
    static let ink3 = Color(nsColor: Palette.ink3.nsColor)
    static let pen = Color(nsColor: Palette.pen.nsColor)
    static let penInk = Color(nsColor: Palette.penInk.nsColor)
    static let red = Color(nsColor: Palette.red.nsColor)
    static let gold = Color(nsColor: Palette.gold.nsColor)
    static let navy = Color(nsColor: Palette.navy.nsColor)
    static let wash = Color(nsColor: Palette.wash.nsColor)
    static let mark = Color(nsColor: Palette.mark.nsColor)
    static let note = Color(nsColor: Palette.note.nsColor)
    static let edge = Color(nsColor: Palette.edge.nsColor)
    static let key = Color(nsColor: Palette.key.nsColor)
    static let keyHi = Color(nsColor: Palette.keyHi.nsColor)
    static let keyLo = Color(nsColor: Palette.keyLo.nsColor)

    static let ruleSpacing: CGFloat = 34

    static func body(_ size: CGFloat = 13, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat = 11, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }

    static let press = Animation.spring(response: 0.22, dampingFraction: 0.55)
}

extension View {
    /// SF Pro Rounded heavy caps; `tracking` is in em, as the mock's letter-spacing.
    func mixtapeCaps(_ size: CGFloat, tracking: CGFloat = 0.2) -> some View {
        font(.system(size: size, weight: .heavy, design: .rounded))
            .tracking(size * tracking)
            .textCase(.uppercase)
    }
}

/// Ruled inlay stock: a 1 pt rule at the foot of every 34 pt line.
struct RuledBackground: View {
    var body: some View {
        Rules().fill(Mixtape.rule).accessibilityHidden(true)
    }

    private struct Rules: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            var y = rect.minY + Mixtape.ruleSpacing - 1
            while y < rect.maxY {
                path.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 1))
                y += Mixtape.ruleSpacing
            }
            return path
        }
    }
}

/// The ballpoint ellipse drawn round a selected track number; open at the top like a pen stroke.
struct HandCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 17, y: 3.2))
        path.addCurve(to: CGPoint(x: 2.6, y: 11.6), control1: CGPoint(x: 9.6, y: 2.4), control2: CGPoint(x: 2.8, y: 5.9))
        path.addCurve(to: CGPoint(x: 16.2, y: 20.6), control1: CGPoint(x: 2.4, y: 17.2), control2: CGPoint(x: 9, y: 20.8))
        path.addCurve(to: CGPoint(x: 29.6, y: 11.4), control1: CGPoint(x: 23.6, y: 20.4), control2: CGPoint(x: 29.9, y: 16.7))
        path.addCurve(to: CGPoint(x: 16, y: 3.6), control1: CGPoint(x: 29.3, y: 6.6), control2: CGPoint(x: 23.8, y: 3.5))
        return path.applying(Self.fit(CGSize(width: 32, height: 24), in: rect))
    }

    static func fit(_ box: CGSize, in rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / box.width, y: rect.height / box.height)
    }
}

/// The drawn tick for a pasted track.
struct InkTick: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines([CGPoint(x: 1.5, y: 5.6), CGPoint(x: 4.6, y: 8.4), CGPoint(x: 10.6, y: 1.6)])
        return path.applying(HandCircle.fit(CGSize(width: 12, height: 10), in: rect))
    }
}

/// A pen stroke that draws itself once when it appears; under Reduce Motion it is simply there.
struct DrawnStroke<S: Shape>: View {
    let shape: S
    let lineWidth: CGFloat
    let animation: Animation

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ shape: S, lineWidth: CGFloat = 1.7, animation: Animation = .timingCurve(0.3, 0.7, 0.3, 1, duration: 0.5)) {
        self.shape = shape
        self.lineWidth = lineWidth
        self.animation = animation
    }

    var body: some View {
        shape.trim(from: 0, to: reduceMotion ? 1 : progress)
            .stroke(Mixtape.pen, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .onAppear { withAnimation(animation) { progress = 1 } }
            .accessibilityHidden(true)
    }
}

/// A section title in caps over a 2 pt ink rule, with a mono detail on the right.
struct SideHeader: View {
    let title: String
    var detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .mixtapeCaps(12.5, tracking: 0.24)
                .foregroundStyle(Mixtape.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let detail {
                Text(detail).font(Mixtape.mono(11.5, .semibold)).foregroundStyle(Mixtape.ink3)
            }
        }
        .lineLimit(1)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Mixtape.ink).frame(height: 2) }
    }
}

/// The gold-tinted callout, for a suggestion such as a newly heard name.
struct InkNote<Actions: View>: View {
    let message: Text
    let actions: Actions

    init(_ message: Text, @ViewBuilder actions: () -> Actions) {
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            message
                .font(Mixtape.body(12.5))
                .foregroundStyle(Mixtape.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) { actions }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Mixtape.note, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

extension InkNote where Actions == EmptyView {
    init(_ message: Text) {
        self.init(message) { EmptyView() }
    }
}
