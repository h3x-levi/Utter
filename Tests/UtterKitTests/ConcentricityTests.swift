import SwiftUI
import Testing
@testable import UtterKit

/// Why every nested surface in this app keeps a fixed corner radius.
///
/// macOS 26 adds `ConcentricRectangle` and the `containerShape(_:)` overload that
/// publishes a container's curve, and the obvious reading of this codebase — a row at
/// `Radius.control` sitting inside a tile at `Radius.panel` — is that those fixed
/// constants are a concentricity bug waiting to be converted. They are not, and the
/// reason is arithmetic rather than taste: **a `.concentric` child resolves to
/// `container radius − inset`, and every inset in this app is already at or beyond its
/// container's radius.** Converting would render sharp corners throughout.
///
/// That was measured, not reasoned about — `ConcentricRectangle` was rendered offscreen
/// at 1pt scale and its corner compared against `RoundedRectangle` references; the full
/// results are recorded above `Radius` in DesignTokens.swift. Two of them matter here:
/// with no container published the shape resolves to a **sharp rectangle**, and the
/// *larger* of the two axis insets governs, so a child needs to be inside its
/// container's corner on **both** axes before concentricity has anything to act on.
///
/// So this suite pins the *precondition* rather than a shape. Nothing in a build catches
/// a spacing retune that quietly makes concentricity applicable — or, worse, one that
/// makes a future `.concentric` conversion look reasonable while still resolving to
/// zero. If a pair here ever moves inside its container's corner, this fails and names
/// it, which is the moment the API is worth reaching for.
///
/// Pure numbers, so it runs without a window, an appearance, or a Mac on 26.
@Suite("Corner concentricity")
struct ConcentricityTests {

    /// Every place this app nests a rounded surface inside another one.
    ///
    /// `inset` is the distance from the container's edge to the child's edge on the
    /// tighter axis — the one that governs — so a pair passes only if the child stays
    /// outside the container's corner on both.
    private static let pairs: [(container: CGFloat, inset: CGFloat, label: String)] = [
        (Radius.panel, Space.cardPadding,
         "BentoTile / SettingsCard / card() → its content"),
        (Radius.card, Space.x3,
         "GlassSelectableRow, ModelRow → their content"),
        (Radius.control, Space.x3,
         "WordRow / SnippetRow / CustomCommandRow → their content"),
        (Radius.panel, Space.x4,
         "MeetingOfferPanel card → its button row"),
    ]

    @Test("Every nested surface sits at or beyond its container's corner")
    func nestingIsBeyondTheCorner() {
        for pair in Self.pairs {
            #expect(pair.inset >= pair.container,
                    """
                    \(pair.label): inset \(pair.inset)pt is now inside the container's \
                    \(pair.container)pt corner, so a concentric child would resolve to \
                    \(pair.container - pair.inset)pt instead of 0. Concentricity now \
                    applies here — see the note above `Radius` in DesignTokens.swift \
                    before keeping the fixed value.
                    """)
        }
    }

    @Test("A concentric child would collapse to a sharp corner at today's spacing")
    func concentricWouldResolveToZero() {
        // The same fact stated as the consequence, because that is the half a reader
        // will not have done in their head. `max(0, …)` is the measured behaviour: the
        // resolution floors at zero rather than going negative, and it does not
        // extrapolate outward for a child larger than its container either.
        for pair in Self.pairs {
            let resolved = max(0, pair.container - pair.inset)
            #expect(resolved == 0,
                    "\(pair.label): would render a \(resolved)pt corner, not the sharp one this suite assumes")
        }
    }

    /// The radius scale has to stay monotonic.
    ///
    /// This is the invariant that survives whatever happens to concentricity: a larger
    /// surface never gets a tighter corner than a smaller one, so nesting reads as
    /// nesting. It is the same class of ordering `VeilRampTests` pins for translucency,
    /// and it has the same failure mode — five constants that each look deliberate in
    /// isolation while two of them have crossed over.
    @Test("The radius ladder increases with the size of the surface")
    func radiusLadderIsMonotonic() {
        let ladder: [(name: String, radius: CGFloat)] = [
            ("chip", Radius.chip),
            ("control", Radius.control),
            ("field", Radius.field),
            ("card", Radius.card),
            ("panel", Radius.panel),
        ]
        for (smaller, larger) in zip(ladder, ladder.dropFirst()) {
            #expect(smaller.radius < larger.radius,
                    "\(larger.name) must have a wider corner than \(smaller.name) — equal or tighter and the nesting reads backwards")
        }
    }

    /// The shape the app actually draws, on the path that actually ships.
    ///
    /// Pinned because this is the branch a future reader is most likely to assume is
    /// dead. The package floor is macOS 13.3 (set by the prebuilt whisper xcframework),
    /// so `Radius.rect` is not a fallback for a `ConcentricRectangle` that ships
    /// elsewhere — it is the only shape any of these surfaces ever gets, on every OS the
    /// app supports including 26. `.continuous` is part of that: macOS squircles are
    /// continuous, and `.circular` reads as web CSS.
    @Test("Radius.rect is a continuous rounded rectangle at the radius asked for")
    func rectIsContinuousAtTheRequestedRadius() {
        for radius in [Radius.chip, Radius.control, Radius.field, Radius.card, Radius.panel] {
            let shape = Radius.rect(radius)
            #expect(shape.cornerSize == CGSize(width: radius, height: radius))
            #expect(shape.style == .continuous,
                    "a \(radius)pt corner drawn `.circular` reads as web CSS, not as a macOS squircle")
        }
    }
}
