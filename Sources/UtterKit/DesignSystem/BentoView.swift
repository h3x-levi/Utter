import SwiftUI

/// Bento-box building blocks: rounded tiles of varying weight arranged on a grid.
///
/// The layout language is a small set of tile sizes rather than free-form
/// containers, so screens stay on a rhythm without every view inventing its own
/// spacing. Tiles carry their own title, so a screen reads as a set of cards
/// rather than one long column.
struct BentoTile<Content: View>: View {
    let title: String?
    var systemImage: String?
    var tint: Color?
    var accessory: AnyView?
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    init(
        title: String? = nil,
        systemImage: String? = nil,
        tint: Color? = nil,
        accessory: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            if title != nil || accessory != nil || systemImage != nil {
                header
            }
            content()
        }
        .padding(Space.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDark ? Color.black.opacity(0.35) : Color.white.opacity(0.65))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isDark
                            ? [Color.white.opacity(0.22), Color.white.opacity(0.04)]
                            : [Color.white.opacity(0.85), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.06),
            radius: 8, x: 0, y: 3
        )
    }

    private var header: some View {
        HStack(spacing: Space.x2) {
            if let systemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill((tint ?? Ink.secondary).opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint ?? Ink.secondary)
                }
            }
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.primary)
            }
            Spacer(minLength: 0)
            if let accessory { accessory }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single large number with a caption — the smallest bento unit.
struct BentoStat: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Tint.accent

    var body: some View {
        BentoTile {
            VStack(alignment: .leading, spacing: Space.x2) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.16))
                            .frame(width: 28, height: 28)
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                        .frame(height: 28, alignment: .bottom)
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// A row of equal-width bento tiles that fills the full content width.
///
/// `GridItem(.adaptive(minimum:))` looks like the natural fit but is wrong here:
/// adaptive columns choose a column *count* and leave the remainder as spacing
/// around the items, so a three-tile row measured 1646pt inside a 1679pt column
/// — 33pt narrower than the full-width tiles above and below it, with its left
/// and right edges out of line with theirs. A bento grid's whole premise is that
/// tiles share edges, so the columns are explicitly flexible and equal instead,
/// and the row spans its container exactly.
///
/// `columns` is the count at full width. Below `collapseBelow` the row falls to
/// a single column, so tiles never get squeezed narrower than they can hold.
struct BentoRow<Content: View>: View {
    /// Kept for call-site readability — `BentoRow(columns: 3)` documents intent —
    /// but the row no longer branches on it. Tiles are equal-width and always on
    /// one line; see the note in `body` for why the responsive path was removed.
    var columns: Int = 2
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Just an HStack: no ViewThatFits, no GeometryReader, no state.
        //
        // Two earlier versions of this view resized the whole window, and both are
        // worth recording because the failure looked nothing like a layout bug.
        //
        //   1. A `GeometryReader` measured the row's width into `@State` and chose
        //      a column count from it — measure, set state, relayout, measure
        //      again. That loop oscillated, and the window flickered between
        //      133x142 and 168x117 as SwiftUI republished an intrinsic size
        //      mid-cycle.
        //   2. `ViewThatFits` replaced it, which resolves in one pass but publishes
        //      its *smallest* candidate as the intrinsic width. The single-column
        //      fallback's width propagated up through `NSHostingView` and the
        //      window honoured it: measured falling 1180 → 268 → 133 in four
        //      seconds.
        //
        // Responsive column collapsing is not worth a window that resizes itself,
        // and it was never needed here: the window's 1000pt minimum leaves ~810pt
        // of content, which fits three 190pt tiles with room to spare.
        HStack(alignment: .top, spacing: Space.groupGap) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
