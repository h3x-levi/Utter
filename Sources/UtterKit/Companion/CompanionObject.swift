import SwiftUI

enum CompanionObject: String, CaseIterable, Identifiable {
    case none, ball, box, yarn, cushion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .ball: "Ball"
        case .box: "Box"
        case .yarn: "Yarn"
        case .cushion: "Cushion"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "nosign"
        case .ball: "circle.fill"
        case .box: "shippingbox.fill"
        case .yarn: "scribble"
        case .cushion: "bed.double.fill"
        }
    }

    var playDuration: TimeInterval {
        switch self {
        case .none: 0
        case .ball: 3.4
        case .box: 3.8
        case .yarn: 3.6
        case .cushion: 4.2
        }
    }
}

/// One synchronized character-and-prop interaction sampled from the behaviour clock.
///
/// Values are normalized: character offsets are fractions of the character side, prop
/// offsets are fractions of the prop side. The window and prop views scale them once, so
/// the same physical sequence works at every companion size without another animation
/// clock drifting away from the character.
struct CompanionObjectPlay: Equatable {
    let object: CompanionObject
    let progress: CGFloat

    init(object: CompanionObject, progress: CGFloat) {
        self.object = object
        self.progress = min(1, max(0, progress))
    }

    var characterOffset: CGSize {
        switch object {
        case .none:
            return .zero
        case .ball:
            let engaged = window(0.02, 0.18, 0.82, 1)
            let pounce = pulse(0.08, 0.24, 0.42)
            let roll = pulse(0.42, 0.62, 0.82)
            return CGSize(width: 0.20 * engaged, height: -0.12 * pounce + 0.08 * roll)
        case .box:
            let inside = window(0.04, 0.30, 0.86, 1)
            return CGSize(width: 0.28 * inside, height: 0.14 * inside)
        case .yarn:
            let engaged = window(0.03, 0.18, 0.84, 1)
            let pounce = abs(sin(progress * .pi * 4)) * engaged
            return CGSize(width: 0.20 * engaged, height: -0.10 * pounce)
        case .cushion:
            let settled = window(0.03, 0.34, 0.90, 1)
            return CGSize(width: 0.24 * settled, height: 0.20 * settled)
        }
    }

    var characterRotation: Double {
        switch object {
        case .ball:
            return 360 * Double(ramp(0.38, 0.78))
        case .yarn:
            let engaged = window(0.08, 0.20, 0.80, 0.94)
            return Double(sin(progress * .pi * 6) * 7 * engaged)
        case .none, .box, .cushion:
            return 0
        }
    }

    var characterScale: CGFloat {
        switch object {
        case .box:
            return 1 - 0.16 * window(0.10, 0.34, 0.84, 0.98)
        case .cushion:
            return 1 - 0.08 * window(0.12, 0.40, 0.88, 1)
        case .none, .ball, .yarn:
            return 1
        }
    }

    var propOffset: CGSize {
        switch object {
        case .ball:
            let firstBat = ramp(0.14, 0.38)
            let returnBat = ramp(0.48, 0.76)
            let bounce = abs(sin(progress * .pi * 4)) * window(0.10, 0.20, 0.76, 0.88)
            let settle = 1 - ramp(0.80, 1)
            return CGSize(width: (-0.72 * firstBat + 0.58 * returnBat) * settle,
                          height: -0.42 * bounce)
        case .yarn:
            let active = window(0.08, 0.18, 0.82, 0.96)
            return CGSize(width: 0.32 * sin(progress * .pi * 5) * active,
                          height: -0.24 * abs(sin(progress * .pi * 5)) * active)
        case .none, .box, .cushion:
            return .zero
        }
    }

    var propRotation: Double {
        switch object {
        case .ball: 720 * Double(ramp(0.12, 0.80))
        case .yarn: 360 * Double(ramp(0.08, 0.86))
        case .box: -26 * Double(window(0.02, 0.18, 0.80, 0.98))
        case .none, .cushion: 0
        }
    }

    var propScaleY: CGFloat {
        switch object {
        case .cushion:
            return 1 - 0.24 * window(0.16, 0.42, 0.86, 1)
        case .ball:
            return 1 - 0.12 * pulse(0.16, 0.24, 0.34)
        case .none, .box, .yarn:
            return 1
        }
    }

    var characterIsRolling: Bool {
        object == .ball && progress >= 0.38 && progress < 0.82
    }

    var objectSitsBehindCharacter: Bool {
        object == .cushion
    }

    private func ramp(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return progress >= end ? 1 : 0 }
        let value = min(1, max(0, (progress - start) / (end - start)))
        return value * value * (3 - 2 * value)
    }

    private func pulse(_ start: CGFloat, _ peak: CGFloat, _ end: CGFloat) -> CGFloat {
        progress <= peak ? ramp(start, peak) : 1 - ramp(peak, end)
    }

    private func window(
        _ start: CGFloat,
        _ entered: CGFloat,
        _ leaving: CGFloat,
        _ end: CGFloat
    ) -> CGFloat {
        ramp(start, entered) * (1 - ramp(leaving, end))
    }
}

struct CompanionObjectView: View {
    let object: CompanionObject
    let size: CGFloat
    let play: CompanionObjectPlay?
    let onInteract: () -> Void

    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        objectBody
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture(perform: onInteract)
            .accessibilityLabel(object.label)
            .accessibilityHint("Click to play")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var objectBody: some View {
        let activePlay = !motion.reduceMotion && play?.object == object ? play : nil
        switch object {
        case .none:
            EmptyView()
        case .ball:
            Circle()
                .fill(.red.gradient)
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                .scaleEffect(x: 1, y: activePlay?.propScaleY ?? 1, anchor: .bottom)
                .rotationEffect(.degrees(activePlay?.propRotation ?? 0))
                .offset(
                    x: (activePlay?.propOffset.width ?? 0) * size,
                    y: (activePlay?.propOffset.height ?? 0) * size
                )
        case .yarn:
            ZStack {
                Circle().fill(Color.purple.gradient)
                Path { path in
                    path.move(to: CGPoint(x: size * 0.22, y: size * 0.52))
                    path.addCurve(
                        to: CGPoint(x: size * 0.86, y: size * 0.84),
                        control1: CGPoint(x: size * 0.48, y: size * 0.15),
                        control2: CGPoint(x: size * 0.58, y: size)
                    )
                }
                .stroke(.white.opacity(0.65), lineWidth: 1.5)
            }
            .rotationEffect(.degrees(activePlay?.propRotation ?? 0))
            .offset(
                x: (activePlay?.propOffset.width ?? 0) * size,
                y: (activePlay?.propOffset.height ?? 0) * size
            )
        case .box:
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: size * 0.08)
                    .fill(Color.brown.gradient)
                    .frame(height: size * 0.7)
                    .offset(y: size * 0.25)
                Rectangle()
                    .fill(Color.orange.opacity(0.85))
                    .frame(height: size * 0.22)
                    .rotationEffect(
                        .degrees(activePlay?.propRotation ?? 0),
                        anchor: .bottomLeading
                    )
            }
        case .cushion:
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(Color.blue.opacity(0.72).gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.25)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
                .scaleEffect(
                    x: 1,
                    y: activePlay?.propScaleY ?? 1,
                    anchor: .bottom
                )
        }
    }
}
