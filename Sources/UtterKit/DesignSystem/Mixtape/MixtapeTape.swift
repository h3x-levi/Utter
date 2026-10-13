import SwiftUI

struct TapeSegment<ID: Hashable>: Identifiable {
    let id: ID
    let words: Int
    /// What VoiceOver reads for the segment, e.g. the track's title.
    var label: String

    /// Words with no track to show (Keep history is off), as one quiet segment.
    static func unkept(_ words: Int, id: ID) -> [TapeSegment] {
        words > 0 ? [TapeSegment(id: id, words: words, label: "Dictated today, not kept")] : []
    }
}

extension Mixtape {
    /// Segment widths: each track's share of `max(goal, total)`, so the tape fills toward the goal.
    static func tapeWidths(_ words: [Int], goal: Int, track: CGFloat, gap: CGFloat = 2) -> [CGFloat] {
        let scale = CGFloat(max(goal, words.reduce(0, +), 1))
        let usable = max(0, track - gap * CGFloat(max(words.count - 1, 0)))
        return words.map { usable * CGFloat(max($0, 0)) / scale }
    }
}

/// The red brand stripe: today's tape, one segment per track, filling toward the word goal.
struct TapeStripe<ID: Hashable>: View {
    enum Status { case ready, setup, recording }

    let label: String?
    let status: Status
    let segments: [TapeSegment<ID>]
    /// Nil when there's no goal: the tape just counts.
    let goal: Int?
    let selected: ID?
    let insets: EdgeInsets
    let onSelect: (ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ label: String? = nil, status: Status = .ready, segments: [TapeSegment<ID>], goal: Int?,
         selected: ID? = nil, insets: EdgeInsets = EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14),
         onSelect: @escaping (ID) -> Void = { _ in }) {
        self.label = label
        self.status = status
        self.segments = segments
        self.goal = goal
        self.selected = selected
        self.insets = insets
        self.onSelect = onSelect
    }

    private static var setupInk: Color { Color(nsColor: .hex(0x1C2A5E)) }
    private var ink: Color { status == .setup ? Self.setupInk : .white }
    private var total: Int { segments.reduce(0) { $0 + $1.words } }

    var body: some View {
        HStack(spacing: 12) {
            if status == .recording { RecordingDot().transition(.opacity) }
            if let label { Text(label).mixtapeCaps(10.5, tracking: 0.2).fixedSize() }
            track
            Text(goal.map { "\(total) / \($0) words" } ?? "\(total) words")
                .font(Mixtape.mono(11, .semibold))
                .tracking(0.22)
                .textCase(.uppercase)
                .fixedSize()
                .accessibilityLabel(goal.map { "\(total) of \($0) words" } ?? "\(total) words")
        }
        .lineLimit(1)
        .foregroundStyle(ink)
        .padding(insets)
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)
        .background(status == .setup ? Mixtape.gold : Mixtape.red)
        .animation(.easeInOut(duration: 0.3), value: status)
        .accessibilityElement(children: .contain)
    }

    private var track: some View {
        GeometryReader { geo in
            let widths = Mixtape.tapeWidths(segments.map(\.words), goal: goal ?? 0, track: geo.size.width)
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    Segment(width: widths[index], fill: ink, current: segment.id == selected) { onSelect(segment.id) }
                        .accessibilityLabel(segment.label)
                        .transition(reduceMotion ? .opacity : .modifier(active: Grow(progress: 0), identity: Grow(progress: 1)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .leading)
        }
        .frame(minWidth: 40)
        .frame(height: 8)
        .background(ink.opacity(status == .setup ? 0.18 : 0.26))
        .clipShape(Capsule())
        .animation(.timingCurve(0.2, 1, 0.3, 1, duration: reduceMotion ? 0 : 0.7), value: segments.map(\.id))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's tape")
    }

    private struct Segment: View {
        let width: CGFloat
        let fill: Color
        let current: Bool
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                RoundedRectangle(cornerRadius: 1).fill(fill).frame(width: width)
            }
            .buttonStyle(.plain)
            .opacity(hovering || current ? 0.62 : 1)
            .animation(.easeOut(duration: 0.2), value: hovering || current)
            .onHover { hovering = $0 }
            .accessibilityAddTraits(current ? .isSelected : [])
        }
    }

    private struct Grow: ViewModifier {
        let progress: CGFloat

        func body(content: Content) -> some View {
            content.scaleEffect(x: max(progress, 0.001), anchor: .leading).opacity(progress)
        }
    }

    private struct RecordingDot: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let dot = Circle().frame(width: 8, height: 8).accessibilityLabel("Recording")
            if reduceMotion {
                dot
            } else {
                dot.phaseAnimator([1.0, 0.25]) { $0.opacity($1) } animation: { _ in .easeInOut(duration: 0.6) }
            }
        }
    }
}

/// A 34 pt track on the rules: number, one line of text, running time.
struct TrackRow<Actions: View>: View {
    let number: Int
    let title: String
    let time: String
    let selected: Bool
    let ticked: Bool
    let emphasized: Bool
    let highlight: String
    let actions: Actions?

    @State private var hovering = false

    init(number: Int, title: String, time: String, selected: Bool = false, ticked: Bool = false,
         emphasized: Bool = false, highlight: String = "", @ViewBuilder actions: () -> Actions) {
        self.number = number
        self.title = title
        self.time = time
        self.selected = selected
        self.ticked = ticked
        self.emphasized = emphasized
        self.highlight = highlight
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(String(format: "%02d", number))
                    .font(Mixtape.mono(11, .semibold))
                    .foregroundStyle(selected ? Mixtape.red : Mixtape.ink3)
                    .frame(width: 26, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if selected { DrawnStroke(HandCircle()).frame(width: 32, height: 24).offset(x: -8) }
                    }
                HStack(spacing: 6) {
                    Text(markedTitle)
                        .font(Mixtape.body(13, selected || emphasized ? .semibold : .regular))
                        .truncationMode(.tail)
                        .background {
                            if hovering {
                                LinearGradient(stops: [.init(color: .clear, location: 0.58), .init(color: Mixtape.wash, location: 0.58)],
                                               startPoint: .top, endPoint: .bottom)
                            }
                        }
                    if ticked {
                        DrawnStroke(InkTick(), lineWidth: 1.8, animation: .easeOut(duration: 0.4).delay(0.1))
                            .frame(width: 12, height: 10)
                            .accessibilityLabel("Pasted")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !(selected && actions != nil) {
                    Text(time).font(Mixtape.mono(11.5)).foregroundStyle(Mixtape.ink3)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Track \(number), \(title), \(time)\(ticked ? ", pasted" : "")")
            .accessibilityAddTraits(selected ? .isSelected : [])
            if selected, let actions {
                HStack(spacing: 2) { actions }
            }
        }
        .lineLimit(1)
        .foregroundStyle(Mixtape.ink)
        .frame(height: Mixtape.ruleSpacing)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var markedTitle: AttributedString {
        var text = AttributedString(title)
        guard !highlight.isEmpty else { return text }
        var rest = text.startIndex..<text.endIndex
        while let match = text[rest].range(of: highlight, options: .caseInsensitive) {
            text[match].swiftUI.backgroundColor = Mixtape.mark
            rest = match.upperBound..<text.endIndex
        }
        return text
    }
}

extension TrackRow where Actions == EmptyView {
    init(number: Int, title: String, time: String, selected: Bool = false, ticked: Bool = false,
         emphasized: Bool = false, highlight: String = "") {
        self.number = number
        self.title = title
        self.time = time
        self.selected = selected
        self.ticked = ticked
        self.emphasized = emphasized
        self.highlight = highlight
        self.actions = nil
    }
}

/// A new track writes itself onto the line from the left.
struct WriteOn: ViewModifier {
    @State private var written = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { geo in Rectangle().frame(width: written || reduceMotion ? geo.size.width + 8 : 0) }
                    .padding(.leading, -8)
            }
            .onAppear { withAnimation(.timingCurve(0.4, 0.1, 0.3, 1, duration: 0.9).delay(0.15)) { written = true } }
    }
}
