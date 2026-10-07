# UtterKit - source layout

The whole app lives in this library target. `Sources/Utter/main.swift` is a two-line
executable that calls `UtterApp.main()`, and that split is the reason for it: **SwiftPM
cannot attach a test target to an executable target**, so while the app was one
executable, none of it was reachable from a test - `import XCTest` fails to resolve and
`@testable import` has no module to enter. Verified on this machine before the move.

The practical rule that follows: `UtterApp` is the only `public` symbol here. Everything
else stays `internal`, and `Tests/UtterKitTests` reaches it with
`@testable import UtterKit`. If you find yourself adding `public` to something, check
whether a test is what you actually needed.

Nine folders, grouped by role. SwiftPM compiles nested directories automatically, so
these are organisational only - `Package.swift` names just `Sources/UtterKit` as the
target path and needs no update when files move between them.

| Folder | What belongs here |
|---|---|
| `App/` | Process lifecycle: the `NSApplicationDelegate`, every window, the menu-bar item, config, crash reporting. |
| `Model/` | Persisted state and preferences. No UI, no AppKit windows. |
| `Speech/` | Recognition and text processing: the Whisper provider, model catalogue and downloads, dictionary correction, sentence repunctuation, AI commands. |
| `Audio/` | Capture and playback: microphone input, UI sounds, pausing other apps' audio. |
| `Input/` | Reading from and writing to the rest of the system: the hotkey monitor, text injection, foreground-app context. |
| `DesignSystem/` | Reusable appearance. Tokens, the glass surfaces and control kit, bento primitives. Nothing app-specific. |
| `Screens/` | One file per screen, plus the window shells they live in. |
| `Pill/` | The floating dictation pill. Its own folder because it is a separate `NSPanel` with its own state machine, not a screen in the main window. |
| `Companion/` | The desktop companion: an independent `NSPanel` with its own saved position, first placed beside the pill. Geometry (every number derives from the character's size), behaviour engine, pose model, and the sprite-pack loader that supplies every character. |

## Tests

`swift test` - over 340 tests. The suite started at 37 around the companion's behaviour
engine and the sprite-pack loader, and has grown to cover window sizing, the pill's
morph timing and shell shape, note persistence, meeting audio and WAV framing, key
chords, crash-log summarising, and the design system's translucency ramp.

Three patterns worth copying when adding more:

**Pin the relationship, not the number.** A design token is a constant, so asserting
its value only restates the source. What is worth a test is the *ordering* between
tokens where the ordering is load-bearing and has already been got wrong once  - 
`VeilRampTests` pins that a nested surface is more opaque than the surface it sits
on, because when it wasn't, the tiles read as being behind the card they were on.

**Step the clock, never sleep.** `CompanionBehaviour.step(_:)` advances simulated time
through the same code path the 30 Hz timer drives. The behaviour it verifies plays out
over tens of seconds (a 90-second sleep timer, multi-second ambient acts) and a test
that waited for that in real time is a test nobody runs. It also removes the flakiness
of asserting against a wall-clock timer on a loaded machine.

**Write real files for the loader.** A companion pack is user-authored data arriving
from the filesystem, so the tests build actual APNGs and manifests in a temporary
directory and read them back through the real loader. The cases that matter are the
malformed and hostile ones - path traversal, absolute paths, broken JSON, a frame
larger than its sheet - and a mocked loader proves nothing about any of them.

These earned their keep on the first run: they caught a path-resolution bug that would
have rejected *every* legitimate `pack.json` pack, and a hop that stacked on itself and
travelled nearly double its intended height.

## Conventions worth knowing before editing

**Design tokens over literals.** Colours, spacing, radii and type come from
`DesignSystem/DesignTokens.swift`. A raw `.font(.system(size: 13))` or
`Color(white:)` in a screen is a bug, not a shortcut - the tokens are what make
the seven themes work.

**The neutral ramp is warm.** `Ink` and `Line` are deliberately warm-tinted, not
`labelColor`/`separatorColor`. Mixing in a cool system grey next to them reads as
two design systems fighting.

**Glass belongs to chrome, never behind text.** `glassEffect` is for surfaces that
float above the content they act on and carry controls rather than prose. Text
composited onto Liquid Glass loses subpixel font smoothing and measures roughly 3×
softer, which reads as blurry, so anything holding a label or a paragraph uses a
standard material instead - that is also what Apple's HIG requires. Two things
that sound like glass and are not: the window and content-card surfaces are
`NSVisualEffectView` (a *standard* material, per the HIG's own vocabulary), and
`Veil` in `DesignTokens.swift` is the themed wash over them, in three named
opacities so translucency is one decision rather than seven. Ask
`grep -rn 'glassEffect\|glassSurface(' Sources` which surfaces are actually glass;
a component named `Glass*` is a member of the control kit, not a promise about its
material (`GlassChip`, `Keycap` and `GlassSelectableRow` are all measured opt-outs).

**Themes set `NSApp.appearance`.** `preferredColorScheme` styles SwiftUI views but
does *not* change the `NSAppearance` that dynamic `NSColor`s resolve against, so
tokens would return their light-mode values inside a dark window.
`ThemeManager.applyAppearance()` exists for that reason.

**Avoid self-measuring layout in the main window's view tree.** `ViewThatFits` and
`GeometryReader`-driven sizing publish an intrinsic size up through
`NSHostingView`, and the window honours it - that collapsed the window to ~133 pt
wide. `showMainWindow` re-asserts the size on the runloop as a backstop.

**Nothing leaves the machine.** There is no networking outside the optional,
user-initiated speech-model download in `Speech/ModelStore.swift`. Keep it that
way: `scripts/build-app.sh` fails the build if a `.env` appears.

**Every character is a sprite pack, and nothing is drawn in code.** `Companion/SpritePack.swift`
is the only source of a companion's art. Characters drawn in code shipped alongside the packs
twice - four originally, then two Persian cats - and both sets were removed, so a pack is now
the *only* way a character can exist. A `userdata.json` that still names a removed character or
a removed pack is migrated by `UserData.resolveCompanionCharacter`, and with no pack installed
the companion **cannot** be shown - `CompanionWindow.show()` declines rather than putting an
empty panel on screen, and the Companion settings pane says so.

**Only art Utter is allowed to ship may be bundled.** The folders in `Companions/` are
copied into the app bundle by `scripts/build-app.sh` as defaults, and a user folder of
the same name overrides one. Licensed characters are copyrighted, so anything of that
kind belongs in the user's own Companions folder and not in the repository. Nothing is
ever fetched, and a pack's `pack.json` is treated as untrusted input: a `file` path
that resolves outside its own folder is rejected.

**Companion art is APNG, not GIF.** GIF transparency is a single bit, so an
anti-aliased edge becomes a staircase and a soft shadow becomes hard blocks  - 
measured on a 56px character, 32 distinct alpha levels collapsed to 2 and all 212
partially-transparent pixels went fully opaque or fully clear. APNG is a PNG, so it
keeps 8-bit alpha *and* a per-frame delay, which is why `CompanionAnimation` stores
`delays` per frame rather than one pack-wide `fps`: an animator holds a pose then
snaps through the next few frames, and a fixed frame rate flattens that into a
metronome. Animated GIFs still load - refusing a file the OS can read would be
unhelpful - but they will look wrong, and that is the format.

**The companion has one clock.** `CompanionBehaviour` ticks at 30 Hz and composes
every frame; the views are pure functions of the pose it publishes. Per-part
`repeatForever` animations are what make desktop pets read as looping GIFs - with
one driver a blink can interrupt a roll, and a recording can interrupt both. It also
means the character costs nothing when idle: the ticker stops when the panel hides
and when the character falls asleep.
