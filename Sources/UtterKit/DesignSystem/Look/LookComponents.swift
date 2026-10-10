import AppKit
import SwiftUI

// MARK: - Plate surface

extension View {
    /// The caption plate behind any content: black 88%, hairline edge, opaque under Reduce Transparency.
    func lookPlate(radius: CGFloat = Look.Radius.plate) -> some View {
        background(PlateSurface(radius: radius, opaque: false))
    }
}

private struct PlateSurface: View {
    let radius: CGFloat
    let opaque: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(Look.Color.plate)
            .background { if opaque || reduceTransparency { shape.fill(Look.Color.ground) } }
            .overlay { Hairline(shape: shape) }
    }
}

private struct Hairline<S: InsettableShape>: View {
    let shape: S
    var color = Look.Color.hairline
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        shape.strokeBorder(color, lineWidth: 1 / displayScale)
    }
}

// MARK: - Caption plate

extension Look {
    enum PlateSize {
        case hero, pill
    }

    /// Two lines of caption on a plate. The newest word is yellow and cools to white when the next
    /// one arrives; the plate's size never depends on the words, so streaming never reflows it.
    struct CaptionPlate<Accessory: View>: View {
        let text: String
        let liveWord: String?
        let caret: Bool
        let size: PlateSize
        let accessory: Accessory

        init(text: String, liveWord: String? = nil, caret: Bool = false, size: PlateSize = .hero,
             @ViewBuilder accessory: () -> Accessory) {
            self.text = text
            self.liveWord = liveWord
            self.caret = caret
            self.size = size
            self.accessory = accessory()
        }

        var body: some View {
            let metrics = CaptionMetrics.of(size)
            let words = CaptionWords(text: text, liveWord: liveWord)
            HStack(alignment: .top, spacing: Space.x4) {
                accessory.frame(height: metrics.lineHeight)
                CaptionFlow(lineHeight: metrics.lineHeight, spacing: metrics.wordSpacing,
                            caretGap: metrics.caretGap, centred: size == .pill, hasCaret: caret) {
                    ForEach(words.items) { item in
                        WordCell(word: item.word, isLive: item.id == words.liveID, font: metrics.font)
                            .equatable()
                    }
                    if caret {
                        Rectangle().fill(Color.live).frame(width: 2, height: metrics.caretHeight)
                    }
                }
                .clipped()
                .lookAnimation(.plate, value: words.lastID)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(words.spoken)
                .accessibilityAddTraits(.updatesFrequently)
                // Mirrors the accessory so pill text centres on the plate, not on what is left of it.
                accessory.frame(height: metrics.lineHeight).hidden().accessibilityHidden(true)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: .infinity)
            .lookPlate()
            .accessibilityElement(children: .combine)
        }
    }
}

extension Look.CaptionPlate where Accessory == EmptyView {
    init(text: String, liveWord: String? = nil, caret: Bool = false, size: Look.PlateSize = .hero) {
        self.init(text: text, liveWord: liveWord, caret: caret, size: size) { EmptyView() }
    }
}

private struct WordCell: View, Equatable {
    let word: String
    let isLive: Bool
    let font: SwiftUI.Font

    var body: some View {
        Text(word)
            .font(font)
            .foregroundStyle(isLive ? Look.Color.live : Look.Color.plateInk)
            .contentTransition(.interpolate)
            .fixedSize()
            .lookAnimation(.cool, value: isLive)
    }
}

private struct CaptionMetrics {
    let font: SwiftUI.Font
    let lineHeight: CGFloat
    let wordSpacing: CGFloat
    let caretHeight: CGFloat
    let caretGap: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    static func of(_ size: Look.PlateSize) -> CaptionMetrics {
        size == .hero ? hero : pill
    }

    private static let hero = CaptionMetrics(
        font: Look.Font.plateHero, lineHeight: 37,
        wordSpacing: spaceWidth(NSFont.systemFont(ofSize: 28, weight: .semibold)),
        caretHeight: 29, caretGap: 4,
        horizontalPadding: Look.Space.x8, verticalPadding: Look.Space.x7)

    private static let pill = CaptionMetrics(
        font: Look.Font.platePill, lineHeight: 24,
        wordSpacing: spaceWidth(Look.Font.displayFace(size: 17, weight: .semibold)),
        caretHeight: 18, caretGap: 3,
        horizontalPadding: Look.Space.x5, verticalPadding: Look.Space.x4)

    private static func spaceWidth(_ font: NSFont) -> CGFloat {
        (" " as NSString).size(withAttributes: [.font: font]).width
    }
}

extension Look {
    /// The tail of a caption as identity-stable cells: a word keeps its id for as long as it is shown,
    /// so a new word inserts one cell and only the previous live cell changes.
    struct CaptionWords: Equatable {
        struct Item: Identifiable, Equatable {
            let id: Int
            let word: String
        }

        // ponytail: 64 words is several times two lines at either plate size; raise it if plates widen.
        static let tail = 64

        let items: [Item]
        let liveID: Int?
        let spoken: String

        var lastID: Int { items.last?.id ?? -1 }

        init(text: String, liveWord: String?, tail: Int = CaptionWords.tail) {
            let committed = text.split(whereSeparator: \.isWhitespace)
            let live = liveWord?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var shown = committed.suffix(live.isEmpty ? tail : tail - 1).map(String.init)
            if !live.isEmpty { shown.append(live) }
            let total = committed.count + (live.isEmpty ? 0 : 1)
            let first = total - shown.count
            items = shown.enumerated().map { Item(id: first + $0.offset, word: $0.element) }
            liveID = live.isEmpty ? nil : total - 1
            spoken = [text, live].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    /// Words left to right in a fixed two-line window. Earlier lines are placed above the window and
    /// clipped, which is how a caption rolls up.
    struct CaptionFlow: SwiftUI.Layout {
        static let maxLines = 2

        let lineHeight: CGFloat
        let spacing: CGFloat
        let caretGap: CGFloat
        let centred: Bool
        let hasCaret: Bool

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width + spacing }
            return CGSize(width: width, height: lineHeight * CGFloat(Self.maxLines))
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let wordCount = hasCaret ? sizes.count - 1 : sizes.count
            var widths = sizes.prefix(wordCount).map(\.width)
            if hasCaret, !widths.isEmpty { widths[widths.count - 1] += caretGap + sizes[wordCount].width }

            let lines = Self.lines(widths: widths, maxWidth: bounds.width, spacing: spacing)
            let hidden = max(0, lines.count - Self.maxLines)
            var caretPoint = CGPoint(x: bounds.minX, y: bounds.minY + lineHeight / 2)
            for (row, line) in lines.enumerated() {
                let lineWidth = line.reduce(0) { $0 + widths[$1] } + spacing * CGFloat(line.count - 1)
                var x = bounds.minX + (centred ? (bounds.width - lineWidth) / 2 : 0)
                let y = bounds.minY + (CGFloat(row - hidden) + 0.5) * lineHeight
                for index in line {
                    subviews[index].place(at: CGPoint(x: x, y: y), anchor: .leading, proposal: .unspecified)
                    caretPoint = CGPoint(x: x + sizes[index].width + caretGap, y: y)
                    x += widths[index] + spacing
                }
            }
            if hasCaret {
                if lines.isEmpty, centred { caretPoint.x = bounds.midX }
                subviews[wordCount].place(at: caretPoint, anchor: .leading, proposal: .unspecified)
            }
        }

        /// Greedy line breaks. A word wider than the line gets a line to itself.
        static func lines(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [Range<Int>] {
            var lines: [Range<Int>] = []
            var start = 0
            var x: CGFloat = 0
            for (index, width) in widths.enumerated() {
                if index == start {
                    x = width
                } else if x + spacing + width > maxWidth {
                    lines.append(start..<index)
                    start = index
                    x = width
                } else {
                    x += spacing + width
                }
            }
            if start < widths.count { lines.append(start..<widths.count) }
            return lines
        }
    }
}

// MARK: - Sound tag

extension Look {
    /// A bracketed sound tag, `[ LISTENING ]`. Only the word takes the state colour; `.live` puts it
    /// on a small plate because caption yellow is only legible there. `widest` reserves room for the
    /// longest label the slot will show, so a state change never reflows its neighbours.
    struct SoundTag: View {
        enum State {
            case neutral, ok, warn, live
        }

        let label: String
        let state: State
        let widest: String?

        init(_ label: String, state: State = .neutral, widest: String? = nil) {
            self.label = label
            self.state = state
            self.widest = widest
        }

        var body: some View {
            ZStack(alignment: .leading) {
                if let widest { tag(widest).hidden() }
                tag(label)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        }

        private func tag(_ text: String) -> some View {
            HStack(spacing: Space.x1) {
                Text(verbatim: "[")
                word(text)
                Text(verbatim: "]")
            }
            .font(Font.tag.weight(.regular))
            .foregroundStyle(Color.ink)
        }

        private func word(_ text: String) -> some View {
            Text(text)
                .font(Font.tag)
                .tracking(Font.tagTracking)
                .textCase(.uppercase)
                .foregroundStyle(ink)
                .padding(.horizontal, state == .live ? 5 : 0)
                .padding(.vertical, state == .live ? 2 : 0)
                .background {
                    if state == .live { RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color.plate) }
                }
        }

        private var ink: SwiftUI.Color {
            switch state {
            case .neutral: Color.inkTertiary
            case .ok: Color.ok
            case .warn: Color.warn
            case .live: Color.live
            }
        }
    }
}

// MARK: - Cue row

extension Look {
    /// One past dictation: a mono cue line (number, time, app, words), then up to two lines of text.
    struct CueRow: View {
        let number: Int
        let time: Date
        let app: String
        let words: Int
        let text: String

        var body: some View {
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(verbatim: Self.cueLine(number: number, time: time, app: app, words: words))
                    .font(Font.mono)
                    .foregroundStyle(Color.inkTertiary)
                    .lineLimit(1)
                Text(text)
                    .font(Font.body)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(3)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityValue("\(app), \(time.formatted(date: .omitted, time: .shortened)), \(Self.wordCount(words)), cue \(number)")
        }

        /// Fixed-width mono cells, so every row's columns line up without measuring anything.
        static func cueLine(number: Int, time: Date, app: String, words: Int) -> String {
            let appCell = app.count > 8 ? app.prefix(7).trimmingCharacters(in: .whitespaces) + "…" : app
            return pad(String(number), to: 6) + timecode.string(from: time) + "  "
                + pad(appCell, to: 9) + pad(String(words), to: 3, leading: true) + " "
                + (words == 1 ? "word" : "words")
        }

        static func wordCount(_ words: Int) -> String { words == 1 ? "1 word" : "\(words) words" }

        private static func pad(_ value: String, to width: Int, leading: Bool = false) -> String {
            let fill = String(repeating: " ", count: max(width - value.count, leading ? 0 : 1))
            return leading ? fill + value : value + fill
        }

        private static let timecode: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
    }
}

// MARK: - Keycap

extension Look {
    struct Keycap: View {
        let key: String

        init(_ key: String) { self.key = key }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            Text(key)
                .font(Font.tag.weight(.regular))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
                .frame(minWidth: 34, minHeight: 30, alignment: .bottomLeading)
                .background {
                    shape.fill(Color.wellRaised)
                        .shadow(color: Color.ink.opacity(0.2), radius: 0.5, y: 1)
                        .overlay { Hairline(shape: shape, color: Color.ink.opacity(0.26)) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(key) key")
        }
    }
}

// MARK: - Buttons

extension Look {
    /// A control on a plate, such as Copy on the island.
    struct PlateButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            PlateButtonBody(configuration: configuration)
        }
    }

    /// A text-only action in ink, such as "Show all in Library".
    struct QuietButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            QuietButtonBody(configuration: configuration)
        }
    }
}

private struct PlateButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Look.Radius.control, style: .continuous)
        configuration.label
            .font(Look.Font.heading)
            .foregroundStyle(isEnabled ? Look.Color.plateInk : Look.Color.plateInkSecondary)
            .padding(.horizontal, Look.Space.x3)
            .frame(minHeight: 28)
            .background(shape.fill(Look.Color.plateInk.opacity(configuration.isPressed ? 0.26 : 0.14)))
            .contentShape(.focusEffect, shape)
            .contentShape(shape)
    }
}

private struct QuietButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Look.Font.secondary.weight(.medium))
            .foregroundStyle(!isEnabled ? Look.Color.inkTertiary
                             : configuration.isPressed ? Look.Color.inkSecondary : Look.Color.ink)
            .contentShape(Rectangle())
    }
}

// MARK: - Well

extension Look {
    /// The white content well on the grey ground.
    struct Well<Content: View>: View {
        let spacing: CGFloat
        let content: Content

        init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
            self.spacing = spacing
            self.content = content()
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.well, style: .continuous)
            VStack(alignment: .leading, spacing: spacing) { content }
                .padding(Space.x6)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background { shape.fill(Color.well).overlay { Hairline(shape: shape) } }
        }
    }
}

// MARK: - Readiness, empty state, live dot

extension Look {
    /// One requirement as a sound tag, with its fix beside it when it is missing.
    struct ReadinessTag: View {
        enum State {
            case ready, working, missing
        }

        let label: String
        let state: State
        let actionTitle: String
        let grant: (() -> Void)?

        init(label: String, state: State, actionTitle: String = "Grant", grant: (() -> Void)? = nil) {
            self.label = label
            self.state = state
            self.actionTitle = actionTitle
            self.grant = grant
        }

        var body: some View {
            HStack(spacing: Space.x2) {
                Image(systemName: symbol)
                    .font(Font.tag)
                    .foregroundStyle(state == .missing ? Color.warn : Color.ink)
                    .frame(width: 12)
                    .accessibilityHidden(true)
                SoundTag(label, state: state == .missing ? .warn : .neutral)
                if state == .missing, let grant {
                    Button(actionTitle, action: grant)
                        .controlSize(.small)
                        .accessibilityHint(label)
                }
            }
            // Tall enough for the small button, so granting never changes the row's height.
            .frame(minHeight: 24)
            .accessibilityElement(children: .contain)
        }

        private var symbol: String {
            switch state {
            case .ready: "checkmark"
            case .working: "ellipsis"
            case .missing: "exclamationmark"
            }
        }
    }

    /// An empty list as a caption would mark it, `[ SILENCE ]`, with the one thing to do next.
    struct EmptyCue: View {
        let tag: String
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?

        init(_ tag: String = "silence", message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
            self.tag = tag
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }

        var body: some View {
            VStack(spacing: Space.x3) {
                SoundTag(tag)
                Text(message)
                    .font(Font.body)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.x8)
            .accessibilityElement(children: .contain)
        }
    }

    /// The live mic. Static on purpose; it keeps its frame when off so lighting it never reflows.
    struct LiveDot: View {
        var isLive = true

        var body: some View {
            Circle()
                .fill(Color.mic)
                .frame(width: 8, height: 8)
                .opacity(isLive ? 1 : 0)
                .accessibilityLabel("Microphone live")
                .accessibilityHidden(!isLive)
        }
    }
}

// MARK: - Sidebar selection

extension View {
    /// Inside a `List(selection:)` sidebar row: the selected row becomes a caption plate. The plate is
    /// opaque and 2pt wider than the system highlight on each side, which it draws over.
    func lookSidebarRow(isSelected: Bool) -> some View {
        modifier(Look.SidebarSelection(isSelected: isSelected))
    }
}

extension Look {
    struct SidebarSelection: ViewModifier {
        let isSelected: Bool

        func body(content: Content) -> some View {
            content
                .font(isSelected ? Font.heading : Font.secondary)
                .foregroundStyle(isSelected ? Color.plateInk : Color.ink)
                .listItemTint(isSelected ? Color.plateInk : Color.inkSecondary)
                .listRowBackground(isSelected ? PlateSurface(radius: Radius.plate, opaque: true)
                    .padding(.horizontal, Space.x2) : nil)
        }
    }
}
