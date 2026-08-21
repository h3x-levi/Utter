# Companion pack generator

Turns a **contact sheet** of character poses into an installed Utter companion pack.

A generated-art contact sheet — a grid of poses on one transparent PNG — is what an
image model actually gives you when you ask for a character. It is not what the app
consumes: Utter wants one animated PNG per *state*. These three scripts bridge that,
so a new character is a few minutes of work rather than hand-cropping fifteen poses in
an image editor.

Standalone `swiftc` scripts rather than a target in `Package.swift`: they run on demand
against a file in `~/Downloads`, and nothing in the shipped app depends on them.

## Usage

```sh
cd tools/companion-pack
swiftc -O -o extract extract.swift && ./extract "/path/to/sheet.png"   # → /tmp/panda/poses.json
swiftc -O -o pack    pack.swift    && ./pack    "/path/to/sheet.png"   # → installs the pack
swiftc -O -o sheet   sheet.swift   && ./sheet                          # → contact.png, to eyeball it
```

Then open **Settings → Companion** and pick the character. `Rescan` picks up a
regenerated pack without restarting.

## What each step does

**`extract.swift`** — finds the poses. Thresholds the sheet's alpha to a solid-ink
mask, labels connected components, and merges small satellites (sparkles, hearts,
motion ticks, a detached paw) into the body they sit next to. Writes each pose's tight
bounding box to `poses.json`.

Poses are found, never assumed to be on a grid. Measured on the reference sheet, the
boxes ran 180–284 px wide and 240–326 px tall, and adjacent poses *touched* — so any
fixed-cell crop clips a neighbour's ear into frame.

**`pack.swift`** — cuts, cleans, centres, and assembles.

* **Vignette removal.** Generated sheets often carry a dark background glow baked into
  low-alpha pixels (~1200 haze pixels on the reference sheet, well away from any
  character). Thresholding alpha alone would also chop the character's own
  anti-aliased edge and drop shadow, so a soft pixel is kept only when it sits within
  3 px of solid ink, and discarded otherwise.
* **Bottom-aligned centring** on a square transparent canvas. Bottom, not centre:
  these are characters standing on a surface, and vertically centring a tall jumping
  pose against a squat sitting one makes the character bob between states.
* **One APNG per state**, with hand-chosen per-frame delays.

**`sheet.swift`** — renders every frame of every state at the real 56 px display size
over light *and* dark backdrops. Worth running: it is how the first pass was caught
assigning a contented smile to `startled` and an eating pose to `sleepy`.

## Editing the state assignments

The `states` array in `pack.swift` maps pose indices (1-based in `extract`'s output,
0-based in the array) to Utter's six states, with a delay per frame. This is the part
that needs a human eye — the poses on a sheet rarely map cleanly onto the states, and
two are worth calling out:

* **`startled`** must read as *alarm*. A reference sheet of a cute character usually
  has no distressed face at all, so it is better built from **motion** — a fast shake
  between two poses — than from a pose that merely looks like a wince. A calm closed-eye
  pose held here reads as the character being pleased that something failed.
* **`sleepy`** needs shut eyes and stillness. An eating or lying-with-a-heart pose is
  plainly awake, however relaxed it looks.

Per-frame timing is the reason the app uses APNG: `resting` holds a beat, blinks for
120 ms, then holds again, while `delighted` runs fast and even. A single frame rate
flattens both into a metronome. See `Sources/UtterKit/Companion/SpritePack.swift`.
