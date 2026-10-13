import SwiftUI

enum CompanionNoticeKind: Equatable {
    case failure, timer, reminder, pinned

    var symbol: String {
        switch self {
        case .failure: "exclamationmark.triangle.fill"
        case .timer: "timer"
        case .reminder: "bell.fill"
        case .pinned: "pin.fill"
        }
    }

    var spokenKind: String {
        switch self {
        case .failure: "Dictation failed"
        case .timer: "Focus timer"
        case .reminder: "Reminder"
        case .pinned: "Pinned note"
        }
    }
}

/// One message beside the robot. The kind comes from state, never from reading the words.
struct CompanionNotice: Equatable {
    let kind: CompanionNoticeKind
    let line: String
    var detail: String? = nil

    var accessibilityLabel: String {
        detail.map { "\(kind.spokenKind): \(line). \($0)" } ?? "\(kind.spokenKind): \(line)"
    }
}

/// Display only: the panel never takes focus and the bubble passes clicks through.
struct CompanionBubbleView: View {
    let notice: CompanionNotice

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(notice.line)
                    .font(notice.kind == .timer ? .callout.monospacedDigit() : .callout)
                    .lineLimit(3)
                if let detail = notice.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            Image(systemName: notice.kind.symbol)
                .foregroundStyle(notice.kind == .failure ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .modifier(BubbleSurface(shape: shape, reduceTransparency: reduceTransparency))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityLabel)
    }
}

private struct BubbleSurface: ViewModifier {
    let shape: RoundedRectangle
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}
