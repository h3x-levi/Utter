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
    /// Header-glyph colour. `nil` means `Ink.secondary`, deliberately — see the
    /// note on the `foregroundStyle` below. Pass a tint only when the glyph is
    /// *reporting* something (granted/denied, running/stopped), never for decoration.
    var tint: Color?
    var accessory: AnyView?
    @ViewBuilder let content: () -> Content

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

    /// `GroupBox`, not a hand-drawn surface.
    ///
    /// This tile used to paint itself: `.padding(Space.cardPadding)` then
    /// `.glassSurface(.content, in: Radius.rect(Radius.panel), …)`, which is a fill
    /// plus a rim gradient plus a light-mode shadow. That is what the light themes
    /// were reporting as washed out, and the numbers were already recorded one file
    /// over in `ContentGlass`: on Paper the tile fill is (1.0, 0.988, 0.965) against
    /// a near-white canvas — **1.117:1**, below the 3:1 floor for a non-text
    /// boundary — and the rim it leans on measures **1.015:1** (Paper) / **1.022:1**
    /// (Linen) in light mode against ~1.55:1 in dark. A tile edge you cannot see is
    /// a tile edge that isn't there.
    ///
    /// `GroupBox` is macOS's own container for exactly this ("a set of related
    /// controls with an optional title"), and `DefaultGroupBoxStyle` draws the
    /// system's grouped background — which is appearance-aware by construction, so
    /// the light-mode contrast stops being something this file has to hit by hand.
    /// It also supplies the content inset, so `Space.cardPadding` goes away rather
    /// than double-padding inside the system's own.
    ///
    /// Available macOS 10.15, well under the 13.3 floor — no availability branch.
    /// Deliberately *not* given `.backgroundStyle(Surface.raised)`: that is the
    /// 1.117:1 fill above, so handing it to the system container would reinstate the
    /// exact defect this replaces. The theme still reaches the tile through the
    /// themed window plane the material samples.
    var body: some View {
        tile
            // Kept from the hand-drawn version. `BentoRow` puts three of these in an
            // HStack and equal widths are the entire premise of the grid (see its
            // note on the 1646-vs-1679pt misalignment), so the tile has to take the
            // width it is offered instead of sizing to its longest line. GroupBox
            // does not stretch on its own.
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Header or no header. Two `GroupBox` initialisers rather than one with an
    /// `EmptyView` label, because an empty label still occupies a row in the
    /// group's stack and `BentoTile(title: nil)` is a real call (`BentoStat` here,
    /// `ReadyPanel` in Home, `NotesView`) — those tiles would gain a blank strip.
    @ViewBuilder
    private var tile: some View {
        if title != nil || accessory != nil {
            GroupBox {
                tileContent
            } label: {
                header
            }
        } else {
            GroupBox { tileContent }
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: Space.x2) {
            if let systemImage {
                // `Ink.secondary` by default, not the accent.
                //
                // This one line was the app's largest single source of accent
                // colour: every tile with an icon and no explicit tint got one,
                // which came to 6 glyphs in Style, 5 in Privacy, 4 in Home and 78
                // in What's New. The HIG is direct about that — "reserve it for
                // elements that truly benefit from emphasis", and "refrain from
                // adding color to the background of multiple controls" — and once
                // the accent is on every section header it has stopped meaning
                // anything, so the tiles that use it to *report* something (a
                // granted permission, an active state) no longer read as different.
                //
                // It also failed contrast. A 13pt glyph is non-text content, so its
                // floor is 3:1; the accent on a tile measured **2.95:1** on Paper.
                // This is the same defect that was already fixed one call site at a
                // time — see the export button in `HomeView`, which measured
                // **1.39:1** inheriting this default and had to opt out by hand.
                // Fixing the default retires the opt-outs.
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint ?? Ink.secondary)
                    .frame(width: 18)
            }
            if let title {
                Text(title).typo(.sectionHeader, ink: Ink.primary)
            }
            Spacer(minLength: 0)
            if let accessory { accessory }
        }
        // The label sits in `GroupBox`'s own stack, which offers it the group's
        // width; without this the header would shrink to its text and the accessory
        // (search field, export menu, "New command") would stop being right-aligned.
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single large number with a caption — the smallest bento unit.
struct BentoStat: View {
    let value: String
    let label: String
    var systemImage: String
    /// Same default and the same reasoning as `BentoTile.tint` — a 13pt glyph on a
    /// tile at the accent measures 2.95:1 against a 3:1 floor, and a stat's
    /// emphasis is already carried by a 26pt number. The two status tints in Home
    /// (`Tint.success`, `Tint.handsFree`) are passed explicitly and stay.
    var tint: Color = Ink.secondary

    var body: some View {
        BentoTile {
            // Icon above the text, not beside it.
            //
            // The icon used to lead an HStack with the label, which pushed the
            // label ~20pt right of the number underneath it — two competing left
            // rails inside one tile, reading as a ragged margin. Stacking the icon
            // means the label and the number share a single left edge.
            VStack(alignment: .leading, spacing: Space.x2) {
                // Fixed square icon slot.
                //
                // SF Symbols have different intrinsic heights (measured 11.8 /
                // 13.9 / 15.0pt across these three glyphs), and without a fixed
                // slot each tile sized to its own icon — leaving tile 1 two points
                // shorter than its neighbours with its whole text stack 2px high.
                // A fixed frame makes the three tiles identical.
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .typo(.statNumber, ink: Ink.primary)
                        .monospacedDigit()
                        // A fixed line height keeps the em-dash placeholder on the
                        // numerals' baseline; without it the dash floated
                        // mid-slot while the digits sat low.
                        .frame(height: 32, alignment: .bottom)
                    Text(label).typo(.microLabel)
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
