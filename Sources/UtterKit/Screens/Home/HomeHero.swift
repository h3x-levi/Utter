import SwiftUI

/// Home's hero: today's dictations and notes as liquid beads in one trough, each as long as its words.
/// The trough runs on under the floating sidebar.
struct HomeHero: View {
    /// Newest first.
    let today: [LibraryItem]
    let open: (LibraryItem) -> Void

    @State private var hovered: String?
    @State private var rowWidth: CGFloat = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// From the content's leading edge: beads start 6 pt in from the text column.
    static let beadLead: CGFloat = 54
    static let textLead: CGFloat = 48
    private static let troughEnd: CGFloat = 22

    /// `hovered` is for snapshots.
    init(today: [LibraryItem], open: @escaping (LibraryItem) -> Void, hovered: String? = nil) {
        self.today = today
        self.open = open
        _hovered = State(initialValue: hovered)
    }

    private var ordered: [LibraryItem] { today.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            band
            readout
                .frame(height: 22)
                .padding(.leading, Self.textLead)
                .padding(.trailing, 30)
        }
        .lookAnimation(.quick, value: hovered)
    }

    private var band: some View {
        let ordered = ordered
        return beads(ordered)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            .padding(.leading, Self.beadLead)
            .padding(.trailing, Self.troughEnd * 2)
            .frame(height: 72)
            .background {
                MoonlightGlass(shape: Capsule())
                    .frame(height: 44)
                    .padding(.horizontal, Self.troughEnd)
                    .ignoresSafeArea(.container, edges: .leading)
            }
            .lookAnimation(.settle, value: ordered.map(\.id))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Today's dictations and notes")
    }

    private func beads(_ ordered: [LibraryItem]) -> some View {
        let most = Double(max(ordered.map(\.words).max() ?? 1, 1))
        return RibbonLayout(words: ordered.map(\.words)) {
            ForEach(ordered) { item in
                Button { open(item) } label: {
                    RibbonSegment(liquid: RibbonTint.liquid(for: item),
                                  seed: Double(item.uuid.uuid.1) / 255,
                                  energy: 0.35 + 0.65 * Double(item.words) / most,
                                  lifted: item.id == hovered,
                                  dimmed: hovered != nil && item.id != hovered)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { hovered = item.id } else if hovered == item.id { hovered = nil }
                }
                .transition(pour)
                .accessibilityLabel(item.title)
                .accessibilityValue("\(item.kindName), \(item.date.formatted(date: .omitted, time: .shortened)), \(item.words) words")
                .accessibilityHint("Opens it in Library")
            }
        }
    }

    private var pour: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .modifier(active: Pour(progress: 0), identity: Pour(progress: 1)),
                                               removal: .opacity)
    }

    @ViewBuilder
    private var readout: some View {
        if let item = today.first(where: { $0.id == hovered }) {
            line(item).transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)))
        } else if today.isEmpty {
            Text("Each thing you say today adds a bead to this line.")
                .foregroundStyle(Look.Color.ink2)
        } else {
            times.transition(.opacity)
        }
    }

    private func line(_ item: LibraryItem) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(RibbonTint.color(RibbonTint.liquid(for: item), dark: scheme == .dark)).frame(width: 7, height: 7)
                Text(item.kindName).fontWeight(.semibold)
                Text(item.date, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Look.Color.ink3)
            }
            .font(.callout)
            Text(item.title).lineLimit(1)
            Spacer(minLength: 12)
            Text("Click to open").font(.subheadline).foregroundStyle(Look.Color.ink3)
        }
        .accessibilityHidden(true)
    }

    /// A time under the start of each bead, skipping any that would crowd the one before.
    private var times: some View {
        let ordered = ordered
        let starts = RibbonLayout.starts(RibbonLayout.widths(ordered.map(\.words), in: rowWidth))
        var last = -CGFloat.infinity
        let shown = zip(ordered, starts).filter { _, x in
            guard x - last >= 80 else { return false }
            last = x
            return true
        }
        return ZStack(alignment: .leading) {
            ForEach(shown, id: \.0.id) { item, x in
                Text(item.date, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Look.Color.ink3)
                    .offset(x: Self.beadLead - Self.textLead + x + 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// v2's per-app Moonlight liquid. Utter doesn't record which app a dictation went into yet, so notes and
/// meetings take their own hue and each dictation a stable pick from the rest.
enum RibbonTint {
    typealias Pair = (dark: SIMD3<Float>, light: SIMD3<Float>)

    static let mail: Pair = (.oklch(0.92, 0.02, 250), .oklch(0.42, 0.06, 255))
    static let slack: Pair = (.oklch(0.86, 0.035, 205), .oklch(0.48, 0.05, 210))
    static let notes: Pair = (.oklch(0.93, 0.02, 85), .oklch(0.56, 0.03, 80))
    static let messages: Pair = (.oklch(0.86, 0.035, 165), .oklch(0.48, 0.05, 165))
    static let safari: Pair = (.oklch(0.82, 0.05, 245), .oklch(0.46, 0.08, 245))
    static let xcode: Pair = (.oklch(0.76, 0.035, 260), .oklch(0.38, 0.03, 260))

    static func liquid(for item: LibraryItem) -> Pair {
        switch item.kind {
        case .note: notes
        case .meeting: messages
        case .dictation: [mail, slack, safari, xcode][Int(item.uuid.uuid.0) % 4]
        }
    }

    static func color(_ pair: Pair, dark: Bool) -> Color { Color(nsColor: (dark ? pair.dark : pair.light).color) }
}

/// One dictation's liquid bead: a glassy capsule that swells and brightens while hovered.
private struct RibbonSegment: View {
    let liquid: RibbonTint.Pair
    let seed: Double
    let energy: Double
    let lifted: Bool
    let dimmed: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let dark = scheme == .dark
        let style = PillPalette.moonlight.style(dark: dark)
        let color = dark ? liquid.dark : liquid.light
        ZStack {
            LiquidFill(color: color, deep: style.body, seed: seed, dark: dark)
            LiquidFill(color: color + (style.listening - color) * 0.6, deep: style.listening, seed: seed, dark: dark, lit: true)
                .opacity(lifted ? 1 : 0)
        }
        .clipShape(Pebble())
        .overlay { Pebble(gloss: true).fill(LiquidFill.gloss) }
        .overlay { Pebble().stroke(LiquidFill.rim(deep: style.body, dark: dark), lineWidth: 0.75) }
        // Without the group, the hosted renderer draws the gradient gloss at the pebble's full size under a shadow.
        .compositingGroup()
        .shadow(color: .black.opacity(lifted ? (dark ? 0.5 : 0.22) : 0), radius: 5, y: 3)
        .frame(height: 32 * energy)
        .scaleEffect(y: lifted && !reduceMotion ? 1.15 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(dimmed ? 0.58 : 1)
        .contentShape(Rectangle().inset(by: -2))
    }
}

/// Moonlight liquid seen through glass: a depth gradient with soft caustics. Callers give it a shape.
struct LiquidFill: View {
    let color: SIMD3<Float>
    let deep: SIMD3<Float>
    let seed: Double
    let dark: Bool
    var lit = false

    static let gloss = LinearGradient(colors: [.white.opacity(0.92), .white.opacity(0.12)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)

    static func rim(deep: SIMD3<Float>, dark: Bool) -> LinearGradient {
        LinearGradient(colors: dark ? [.white.opacity(0.55), .white.opacity(0.06)]
                                    : [.white.opacity(0.9), Color(nsColor: deep.color).opacity(0.45)],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let surface = Color(nsColor: color.color), depth = Color(nsColor: deep.color)
        let stops: [Gradient.Stop] = dark
            ? [.init(color: surface.opacity(lit ? 0.96 : 0.82), location: 0),
               .init(color: depth.opacity(lit ? 0.5 : 0.32), location: 0.55),
               .init(color: depth.opacity(lit ? 0.72 : 0.5), location: 1)]
            : [.init(color: surface.opacity(lit ? 0.8 : 0.6), location: 0),
               .init(color: depth.opacity(0.92), location: 1)]
        ZStack {
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            EllipticalGradient(colors: [.white.opacity(dark ? 0.5 : 0.32), .white.opacity(0)],
                               center: UnitPoint(x: 0.22 + 0.56 * seed, y: 0.68), endRadiusFraction: 0.5)
            EllipticalGradient(colors: [surface.opacity(dark ? 0.35 : 0.22), surface.opacity(0)],
                               center: UnitPoint(x: 0.85 - 0.6 * seed, y: 0.3), endRadiusFraction: 0.32)
        }
    }
}

/// A capsule of liquid centred in its frame, never taller than it is wide; `gloss` is its highlight.
struct Pebble: Shape {
    var gloss = false

    func path(in rect: CGRect) -> Path {
        let height = min(rect.height, rect.width)
        var body = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        if gloss {
            let inset = max(min(height * 0.42, rect.width * 0.3), 2)
            body = CGRect(x: body.minX + inset, y: body.minY + height * 0.13,
                          width: max(body.width - 2 * inset, 0), height: max(height * 0.2, 1.5))
        }
        return Path(roundedRect: body, cornerRadius: body.height / 2, style: .continuous)
    }
}

/// The glass the ribbon and the onboarding droplet are made of: the icon's navy glass with a soft inner
/// depth, lit from above. `depth` scales its cast shadow.
struct MoonlightGlass<S: InsettableShape>: View {
    let shape: S
    var depth: CGFloat = 1

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let dark = scheme == .dark
        let glass = Color(nsColor: PillPalette.moonlight.style(dark: dark).tint.color)
            .opacity(reduceTransparency ? 1 : dark ? 0.8 : 0.75)
        shape
            .fill(glass.shadow(.inner(color: .black.opacity(dark ? 0.6 : 0.14), radius: 4, y: 2)))
            .overlay {
                shape.fill(LinearGradient(colors: [.clear, .white.opacity(dark ? 0.05 : 0.45)],
                                          startPoint: .center, endPoint: .bottom))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: dark ? [.white.opacity(0.24), .white.opacity(0.05)]
                                                               : [.white, .black.opacity(0.1)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: contrast == .increased ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(dark ? 0.34 : 0.1), radius: 8 * depth, y: 5 * depth)
    }
}

/// A new dictation flows in from the ribbon's right end.
private struct Pour: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 0.05 + 0.95 * progress, y: 0.5 + 0.5 * progress, anchor: .trailing)
            .offset(x: 28 * (1 - progress))
    }
}

/// Lays beads out left to right from the leading edge, each as wide as its words.
struct RibbonLayout: SwiftUI.Layout {
    let words: [Int]

    static let spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 320, height: proposal.height ?? 32)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = Self.widths(words, in: bounds.width)
        for (subview, (width, x)) in zip(subviews, zip(widths, Self.starts(widths))) {
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
        }
    }

    /// About 4 pt a word between `minimum` and `maximum`, so a light day keeps small beads; a crowded day
    /// shrinks them in proportion until they fit `total`.
    static func widths(_ words: [Int], in total: CGFloat, perWord: CGFloat = 4,
                       minimum: CGFloat = 12, maximum: CGFloat = 120) -> [CGFloat] {
        guard !words.isEmpty else { return [] }
        let natural = words.map { min(max(CGFloat($0) * perWord, minimum), maximum) }
        let room = max(0, total - spacing * CGFloat(words.count - 1))
        guard natural.reduce(0, +) > room else { return natural }
        let floor = min(minimum, room / CGFloat(words.count))
        let spare = room - floor * CGFloat(words.count)
        let excess = natural.map { $0 - floor }
        let excessSum = excess.reduce(0, +)
        return excess.map { floor + (excessSum > 0 ? spare * $0 / excessSum : 0) }
    }

    static func starts(_ widths: [CGFloat]) -> [CGFloat] {
        var x: CGFloat = 0
        return widths.map { width in
            defer { x += width + spacing }
            return x
        }
    }
}
