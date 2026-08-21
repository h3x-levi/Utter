import Testing
@testable import UtterKit

/// The translucency ramp in `Veil`.
///
/// These are constants, so the thing worth pinning is not a value but the
/// *ordering* between them, which is load-bearing and has been got wrong once
/// already: the bento tiles were a neutral `.regularMaterial` that landed one unit
/// from the sidebar, and the nesting hierarchy read backwards — a tile looked like
/// it was behind the card it sat on. The fix was to raise the tile's veil, and
/// nothing but a comment stops the next retune from inverting it again.
///
/// Pure numbers, so this runs without a window, an appearance, or a Mac on 26.
@Suite("Veil translucency ramp")
struct VeilRampTests {

    /// The three roles, outermost first — the order a user's eye goes through them.
    private static func ramp(isDark: Bool) -> [(name: String, opacity: Double)] {
        [("windowShell", Veil.windowShell(isDark: isDark)),
         ("contentSurface", Veil.contentSurface(isDark: isDark)),
         ("nestedSurface", Veil.nestedSurface(isDark: isDark))]
    }

    @Test("In light mode a surface is more opaque than the surface it sits on")
    func lightRampIncreases() {
        let ramp = Self.ramp(isDark: false)
        for (outer, inner) in zip(ramp, ramp.dropFirst()) {
            #expect(outer.opacity < inner.opacity,
                    "\(inner.name) must be more opaque than \(outer.name) — equal or thinner and the nesting reads backwards")
        }
    }

    @Test("The innermost surface is the most opaque in both appearances")
    func nestedIsAlwaysHeaviest() {
        // Dark mode is not the light ramp inverted — there is far less luminance
        // behind the window, so the shell can be thinner than the content card and
        // still separate (0.55 shell vs 0.45 content). The one relationship that
        // has to survive in both is the innermost surface being the most opaque,
        // because that is the tile-on-card case that measured wrong.
        for isDark in [true, false] {
            let nested = Veil.nestedSurface(isDark: isDark)
            #expect(nested > Veil.contentSurface(isDark: isDark))
            #expect(nested > Veil.windowShell(isDark: isDark))
        }
    }

    @Test("Every veil stays a veil")
    func opacitiesAreInRange() {
        // 1.0 is an opaque fill, which removes the backdrop the material and the
        // glass above it exist to sample; 0 is no veil at all, so the theme stops
        // showing through and every theme looks the same on the same wallpaper.
        for isDark in [true, false] {
            for role in Self.ramp(isDark: isDark) {
                #expect(role.opacity > 0, "\(role.name) at 0 drops the theme entirely")
                #expect(role.opacity < 1, "\(role.name) at 1 is an opaque fill, not a veil")
            }
            #expect(Veil.contentSurfaceLegacy(isDark: isDark) > 0)
            #expect(Veil.contentSurfaceLegacy(isDark: isDark) < 1)
            #expect(Veil.sheetLegacy(isDark: isDark) > 0)
            #expect(Veil.sheetLegacy(isDark: isDark) < 1)
        }
    }

    @Test("The three roles are genuinely different recipes")
    func rolesDoNotCollide() {
        // The defect this enum replaced was seven hand-written recipes where two
        // pairs differed by 0.02-0.04 — a difference nobody could name, and one of
        // them made Settings read cooler than the window that opened it. If two
        // roles ever tune to the same number they are one role, and the answer is
        // to delete a case rather than keep a synonym.
        for isDark in [true, false] {
            let values = Self.ramp(isDark: isDark).map(\.opacity)
            #expect(Set(values).count == values.count)
        }
    }

    @Test("The pre-26 content card is thinner than the macOS 26 one")
    func legacyContentIsThinner() {
        // With no Liquid Glass layered above it the same veil reads heavier, so the
        // fallback was tuned down. Recorded as a test because the direction is the
        // surprising part: the *older* OS gets the *more* transparent surface, and
        // a future tidy-up that "aligns" them would darken every pre-26 window.
        for isDark in [true, false] {
            #expect(Veil.contentSurfaceLegacy(isDark: isDark)
                    < Veil.contentSurface(isDark: isDark))
        }
    }
}
