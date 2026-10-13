import SwiftUI

/// An ink pill with a rounded heavy caps label: outlined, filled (one per group) or ghost.
struct PenButtonStyle: ButtonStyle {
    enum Kind { case outline, fill, ghost }
    enum Size { case regular, small }

    var kind: Kind = .outline
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        Pen(configuration: configuration, kind: kind, small: size == .small)
    }

    private struct Pen: View {
        let configuration: Configuration
        let kind: Kind
        let small: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .mixtapeCaps(small ? 10.5 : 11, tracking: 0.08)
                .lineLimit(1)
                .foregroundStyle(kind == .fill ? Mixtape.paper : Mixtape.ink)
                .padding(.horizontal, small ? 11 : 14)
                .frame(height: small ? 26 : 30)
                .background(Capsule().fill(kind == .fill ? Mixtape.ink : hovering ? Mixtape.wash : .clear))
                .overlay(Capsule().strokeBorder(kind == .ghost ? Mixtape.rule2 : Mixtape.ink, lineWidth: 1.5))
                .brightness(kind == .fill && hovering ? 0.06 : 0)
                .contentShape(Capsule())
                .opacity(enabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
                .animation(Mixtape.press, value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == PenButtonStyle {
    static func pen(_ kind: PenButtonStyle.Kind = .outline, _ size: PenButtonStyle.Size = .regular) -> PenButtonStyle {
        PenButtonStyle(kind: kind, size: size)
    }
}

/// A 28 pt round icon button in secondary ink, for row actions and More.
struct InkIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Icon(configuration: configuration)
    }

    private struct Icon: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? Mixtape.ink : Mixtape.ink2)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovering ? Mixtape.wash : .clear))
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
                .animation(Mixtape.press, value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == InkIconButtonStyle {
    static var inkIcon: InkIconButtonStyle { InkIconButtonStyle() }
}

/// A search field written on a line: ink underline, red while focused.
struct LineField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Mixtape.ink3)
                .accessibilityHidden(true)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(Mixtape.ink)
                .tint(Mixtape.red)
                .focused($focused)
                .accessibilityLabel(placeholder)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder).foregroundStyle(Mixtape.ink3).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
        }
        .font(Mixtape.body(13))
        .lineLimit(1)
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Rectangle().fill(focused ? Mixtape.red : Mixtape.ink).frame(height: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

struct DeckKey {
    let title: String
    let systemImage: String
    let isOn: Bool
    /// Second palette layer, e.g. the red dot inside `record.circle`.
    let accent: Color?
    let action: () -> Void

    init(_ title: String, systemImage: String, isOn: Bool = false, accent: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isOn = isOn
        self.accent = accent
        self.action = action
    }
}

/// Joined transport keys, like a cassette deck: a key that is on sinks and shows a red dot.
struct DeckKeys: View {
    let keys: [DeckKey]

    init(_ keys: [DeckKey]) {
        self.keys = keys
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 0) {
            ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                Button(action: key.action) {
                    VStack(spacing: 5) {
                        icon(key)
                        Text(key.title)
                    }
                }
                .buttonStyle(KeyStyle(isOn: key.isOn))
                .overlay(alignment: .leading) {
                    if index > 0 { Rectangle().fill(Mixtape.edge).frame(width: 1) }
                }
                .accessibilityAddTraits(key.isOn ? .isSelected : [])
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Mixtape.edge, lineWidth: 1))
        .background(shape.fill(Mixtape.keyLo).offset(y: 2))
    }

    @ViewBuilder
    private func icon(_ key: DeckKey) -> some View {
        let image = Image(systemName: key.systemImage).font(.system(size: 14, weight: .medium))
        if let accent = key.accent {
            image.symbolRenderingMode(.palette).foregroundStyle(Mixtape.ink, accent)
        } else {
            image.foregroundStyle(Mixtape.ink)
        }
    }

    private struct KeyStyle: ButtonStyle {
        let isOn: Bool

        func makeBody(configuration: Configuration) -> some View {
            Key(configuration: configuration, isOn: isOn)
        }
    }

    private struct Key: View {
        let configuration: ButtonStyleConfiguration
        let isOn: Bool
        @State private var hovering = false

        var body: some View {
            let down = configuration.isPressed || isOn
            configuration.label
                .mixtapeCaps(9.5, tracking: 0.14)
                .lineLimit(1)
                .foregroundStyle(hovering ? Mixtape.ink : Mixtape.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    ZStack(alignment: .top) {
                        Mixtape.key
                        if down {
                            LinearGradient(colors: [Mixtape.keyLo, Mixtape.keyLo.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 6)
                        } else {
                            LinearGradient(stops: [.init(color: Mixtape.keyHi, location: 0), .init(color: Mixtape.keyHi.opacity(0), location: 0.4)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isOn { Circle().fill(Mixtape.red).frame(width: 6, height: 6).padding(.top, 8).padding(.trailing, 10) }
                }
                .offset(y: down ? 1.5 : 0)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: down)
                .onHover { hovering = $0 }
        }
    }
}

/// A key printed on the card, for the shortcut hints.
struct Keycap: View {
    let label: String

    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(Mixtape.mono(10.5))
            .foregroundStyle(Mixtape.ink2)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Mixtape.rule2))
    }
}
