import AppKit
import SwiftUI

struct VoiceEngineView: View {
    @State private var model: WordsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    init(model: WordsViewModel? = nil) {
        _model = State(initialValue: model ?? WordsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Names and terms Utter should always hear right, short phrases that expand as you speak, and commands that rewrite your words.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 560, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                LensPicker(selection: $model.section, options: WordsViewModel.Section.allCases, title: \.rawValue, count: count)
                    .accessibilityLabel("Words section")
                ZStack(alignment: .topLeading) {
                    section
                        .id(model.section)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
                }
                .animation(Look.Motion.pane.animation(reduceMotion: reduceMotion), value: model.section)
            }
            .contentEdge()
        }
        .contentScrollEdge()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(Look.Color.tint)
        .onAppear { model.reload() }
    }

    @ViewBuilder
    private var section: some View {
        switch model.section {
        case .dictionary: DictionarySection(model: model)
        case .snippets: SnippetsSection(model: model)
        case .commands: CommandsSection(model: model)
        }
    }

    private func count(_ section: WordsViewModel.Section) -> Int? {
        switch section {
        case .dictionary: model.words.count
        case .snippets: model.snippets.count
        case .commands: model.commands.count
        }
    }
}

// MARK: - Content layer, shared with Companion

extension View {
    /// The page's left edge: 48 clear of the sidebar glass, 30 from the trailing edge.
    func contentEdge() -> some View {
        padding(.leading, 48)
            .padding(.trailing, 30)
            .padding(.top, 18)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func contentScrollEdge() -> some View {
        if #available(macOS 26, *) { scrollEdgeEffectStyle(.hard, for: .top) } else { self }
    }

    func cardBackground() -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: Look.Card.radius, style: .continuous)
            shape.fill(Look.Color.fill)
                .overlay {
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.15), Look.Color.edge],
                                                      startPoint: .top, endPoint: .init(x: 0.5, y: 0.12)))
                }
        }
    }

    /// Rows inside take `Look.Card.rowRadius`, so they stay concentric with the card.
    func contentCard() -> some View {
        padding(Look.Card.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
    }

    func fieldBox(icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            textFieldStyle(.plain)
        }
        .font(.body)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Look.Color.hover, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A title and an optional inline subtitle, with actions at the card's trailing edge.
struct CardHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

/// A row of a card: minimum height 46 with its explanation inline under the label.
struct OptionRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    init(_ title: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.tertiary).monospacedDigit()
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 46)
    }
}

/// The hairline between two rows; never above the first or below the last.
struct RowRule: View {
    var body: some View {
        Look.Color.hover.frame(height: 1).padding(.horizontal, 12)
    }
}

/// The two lines a card shows when its list is empty.
struct EmptyNote: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(message).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// v2's `.seg`: a track with a lens that slides to the chosen option.
struct LensPicker<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var count: (Option) -> Int? = { _ in nil }

    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    withAnimation(reduceMotion ? nil : Look.Motion.lens.animation(reduceMotion: false)) { selection = option }
                } label: {
                    HStack(spacing: 6) {
                        Text(title(option))
                        if let count = count(option) {
                            Text(count, format: .number)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .contentTransition(.numericText(value: Double(count)))
                        }
                    }
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background {
                        if on {
                            Capsule().fill(Look.Color.lens)
                                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "lens", in: lens)
                        }
                    }
                }
                .buttonStyle(Look.RowStyle(radius: 14, scale: Look.Press.nav, quiet: true, selected: on))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Look.Color.hover, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .contain)
    }
}

/// Wraps its children onto as many lines as the width needs, like v2's chip sets.
struct FlowStack: SwiftUI.Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        Self.arrange(subviews.map { $0.sizeThatFits(.unspecified) }, width: proposal.width ?? .infinity, spacing: spacing).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let frames = Self.arrange(sizes, width: bounds.width, spacing: spacing).frames
        for (view, frame) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }

    static func arrange(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for size in sizes {
            let item = CGSize(width: min(size.width, width), height: size.height)
            if x > 0, x + item.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: item))
            widest = max(widest, x + item.width)
            line = max(line, item.height)
            x += item.width + spacing
        }
        return (frames, CGSize(width: widest, height: y + line))
    }
}
