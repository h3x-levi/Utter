# Companion packs

The companion packs Utter ships. `scripts/build-app.sh` copies this whole directory
into `Utter.app/Contents/Resources/Companions`, which is where
`SpritePackStore.bundledDirectory` looks — so a fresh install has all of them with no
setup. A folder of the same name under
`~/Library/Application Support/Utter/Companions` overrides the bundled one.

**Utter ships no third-party art.** Two packs that depicted recognisable characters from
published anime were removed: generating art does not create a licence, because copyright
attaches to a character's visual expression rather than to the tool that drew it. Art of
someone else's character is a pack the *user* installs, which is what the override path
above is for. The policy is stated on `SpritePack` in
`Sources/UtterKit/Companion/SpritePack.swift`.

The two `mochi-*` packs were removed too, and for an unrelated reason: they were replaced
by the 64px `pixel-cat-*` pair, which has articulated legs the 32px canvas had no room
for. A `userdata.json` naming a removed pack is not a broken install —
`UserData.resolveCompanionCharacter` maps any unknown id onto the default pack and writes
the correction back, which `CompanionSelectionTests` pins for every retired id.

A pack is a still per state (`resting.png`, `alert.png`, …), one folder of numbered frames
per state, and a `pack.json` naming the display name and the per-state frame rate.

Two shapes ship. The **photo packs** (`dog`, `panda`) draw the six original moods —
`resting`, `alert`, `thinking`, `delighted`, `startled`, `sleepy`. The **pixel packs**
(`pixel-cat-gray`, `pixel-cat-orange`) add the pet states and the walk gait — `knead`,
`overheat`, `purr`, `hunt`, `drag`, `walk` — plus an `eyes.png` sprite the renderer moves
independently so the cat can track the cursor. A pack that omits a state still works:
`SpritePack.animation(for:)` falls back to `resting`, which is what lets the photo packs
ship six.

> **`walk` is drawn in profile, and it is the only state that is.** Every mood is a
> front-on sitting cat, because that is the pose you look at. A sitting animal cannot walk,
> though: the old walk cycle was the sitting pose with a one-pixel paw raise, and across all
> four frames only 21-42 pixels changed, all of them inside rows 26-29 — a shuffle at the hem
> while the engine slid the whole window sideways at 42pt/s. `tools/newcat/cat_art.py` draws
> a side view with two articulated legs instead; the art faces right only, and
> `pose.facing` mirrors it for left.
>
> One consequence worth knowing before you author a pack: the profile head **bakes its own
> eye**, and `SpritePackView` suppresses `eyes.png` while a pack with a `walk` cycle is
> walking. A shared overlay anchored to a front-on head puts *two* eyes on a profile face, and
> no `eyeAnchors` offset fixes that — the problem is the count, not the position. Cursor
> tracking stops for the length of a walk, which is the right trade: an animal in motion looks
> where it is going.

> **The trap.** `SpritePack.stateNames` is the loader's entire vocabulary — a state is read
> from disk only if it is named there, and that holds even for a pack with a `pack.json`,
> because `discoverByConvention` populates the animations either way. The pet states were
> once drawn, shipped, and never loaded for exactly this reason, and the `resting` fallback
> made it silent: the cat played its idle loop instead of kneading. **Adding a state means
> adding it to `stateNames`, not just generating the PNG.** `ShippedPackTests` now names the
> pixel packs' states individually so the fallback cannot hide it again.

## Regenerating a pack

**The two shapes have two separate pipelines.** Reaching for the wrong one is the mistake
worth avoiding: `build_pack.py` takes a photograph as input and there is no photograph
behind the pixel cats.

### The pixel packs (`pixel-cat-gray`, `pixel-cat-orange`)

Drawn from primitives in code, so both packs come out of one script and the art's
provenance is the script itself:

```sh
python3 tools/newcat/generate_cat.py            # writes both coats
python3 tools/newcat/generate_cat.py --verify    # checks the art, writes nothing, exits non-zero on a fault
```

`--verify` is worth running on any change: it proves the pupil stays inside its white at
every eye offset, prints the coat contrast against a light and a dark desktop, and checks that
the **walk cycle actually moves its legs** — at least six frames, motion reaching above the
ankle rows, and enough changed pixels to read at 64px. That last check exists because the
previous walk failed all three and nothing noticed: the frames were present, correctly sized
and alpha-clean, and still not a walk.

The canvas is 64px, not the 32px the first pixel packs used, and the size ladder is the
cost of that: the renderer snaps to a whole-number multiple of the canvas, so a 64px master
draws at 32/32/64/64pt across the four size settings where a 32px one drew 32/48/64/80. The
trade was taken deliberately — at 32px a leg is three pixels and cannot articulate.

### The photo packs (`dog`, `panda`)

Two steps, in order. `build_pack.py` cuts the background if it needs cutting, applies
**one scale across all six states** so the poses keep their real relative sizes, and
writes the stills; `animate_pack.py` then gives each state motion and writes the frames.

`animate_pack.py` owns the *framing*: it crops each pose to its own ink and centres it
in one canvas shared by the whole pack. Centred, not standing on a shared baseline —
the app centres the frame on the companion's position, so what has to stay put is the
character's middle. Under the old baseline framing every pose sat low, and the curled
`sleepy` pose sat 8.4pt below the pill on a 52pt character, which is what the user saw.

```sh
python3 scripts/build_pack.py --out Companions/<id> --name "<display name>" \
    resting=<path> alert=<path> thinking=<path> \
    delighted=<path> startled=<path> sleepy=<path>
python3 scripts/animate_pack.py Companions/<id> --fill <fraction>
```

The exact commands used for the shipped packs are below. They matter: re-running one
with different arguments changes how big that character appears on screen.

## Why `--fill` is set per pack

`--fill` (on `animate_pack.py`) is the per-pack size control: the fraction of the
rendered square that the pack's *tallest* pose occupies. The app fits every frame into
one square of the size chosen in settings (`CompanionSize`, 36-84pt), and the fit is
driven by the taller side,
so a canvas built as `tallest_ink / fill` renders that pose at exactly `fill` of the box.
Measured at the default 52pt, in the `resting` state — `fill` is a fraction, so the
ratios hold at every size:

| pack   | `--fill` | rendered height |
|--------|----------|-----------------|
| dog    | 0.80     | 40.6pt          |
| panda  | 0.80     | 38.7pt          |

Both shipped art packs sit at 0.80, and they still render at different heights, because
`fill` sizes the tallest pose and `resting` is not it. Panda comes out smallest because
its tallest state is `thinking`, whose question mark adds height the resting pose does
not use.

The knob exists because a proportion is not a size. A tall slim figure reads as smaller
than a round one at the same height, so it wants a larger `fill` — around 0.90 against
0.80 for about 12% more presence — rather than every other pack being shrunk to match it.
A pack whose character is much taller than it is wide should expect to set this.

**This used to be `build_pack.py --pad`** and moved when the framing changed. `--pad`
worked only because the frames kept the still's own padding; cropping each pose to its
ink — which is what centres the character on the pill — discarded that and collapsed every
pack to within 5% of the others. Setting the canvas from `fill` is the same idea
applied where the canvas is now decided, and it is exact rather than tuned. `--pad` still
exists on `build_pack.py` as a plain margin and no longer affects rendered size.

## Shipped packs

Sources live outside the repository, in a local folder of generated poses.

```sh
# Golden Dog — 1792x2400 PNG cutouts with their own alpha, used as-is
python3 scripts/build_pack.py --out Companions/dog --name "Golden Dog" \
    resting=Golden_retriever_puppy_nodding_2K_*.png \
    alert=Golden_retriever_puppy_standing_*.png \
    thinking=Puppy_thinking_with_question_mark_*.png \
    delighted=Golden_retriever_puppy_celebrating_2K_*.png \
    startled=Surprised_puppy_with_red_collar_*.png \
    sleepy=Golden_retriever_puppy_rolling_2K_*.png
python3 scripts/animate_pack.py Companions/dog --fill 0.80

# Panda — JPEGs, mixed backgrounds: three on a checkerboard, three on solid black.
# `dechecker.py` detects which from the border and switches rules.
python3 scripts/build_pack.py --out Companions/panda --name Panda \
    resting=Panda_sitting_with_green_bag_*.jpeg \
    alert=Stylized_panda_looking_forward_*.jpeg \
    thinking=Cartoon_panda_thinking_with_ques*.jpeg \
    delighted=Cartoon_panda_celebrating_joyfully_2K_*.jpeg \
    startled=Cartoon_panda_looking_startled_2K_*.jpeg \
    sleepy=Sleepy_cartoon_panda_sitting_2K_*.jpeg
python3 scripts/animate_pack.py Companions/panda --fill 0.80
```

## What the tests check

`Tests/UtterKitTests/ShippedPackTests.swift` loads these packs from the repository —
not a fixture — and asserts that all six moods are animated, that every frame in a pack
is the same size (a frame padded taller than its neighbour is scaled down more, so the
character changed size with its mood), that the per-state frame rates survive the round
trip through `pack.json`, and that no decoded frame exceeds what the renderer can use.

Adding a pack means adding its id to the `shipped` list there. That list is literal on
purpose: deleting a pack should fail a test rather than quietly shrinking the set.
