#!/usr/bin/env python3
"""
Give a still-image companion pack motion, as numbered frames per state.

A pack of one PNG per state is correct but inert: the character holds a single
frame for as long as the mood lasts, which at 90 seconds of `resting` reads as a
sticker rather than a companion.

This generates real per-frame PNGs from those stills — the loader's second layout,
`resting/01.png 02.png …`, which takes precedence over a single `resting.png`. The
motion is geometric, applied to the whole figure, because that is what can be done
faithfully to source art without redrawing it. What it cannot do is change an
expression: a mouth that is closed in the still stays closed.

Each state gets motion chosen for what the state *means*, not a generic wobble:

  * `resting`   slow breathing, a shallow rise and fall. This one is on screen
                longest, so it is the most restrained.
  * `alert`     a small forward lean and lift, held — attentive, not agitated.
  * `thinking`  a gentle sway, as if weighing something.
  * `delighted` a bounce with squash-and-stretch. It lasts 1.2s, so it can be big.
  * `startled`  a sharp recoil that settles, with a slight rock.
  * `sleepy`    the slowest, deepest breathing of the set.

Squash-and-stretch conserves volume — a figure that compresses vertically widens
horizontally — because scaling one axis alone reads as the image stretching rather than
the character moving.

This step also owns the pack's *framing*: each pose is cropped to its own ink and
centred in one canvas shared by the whole pack, and `--fill` sets how much of the
rendered square the tallest pose occupies. That is the per-pack size control — see
`Companions/README.md` for the value each shipped pack uses and why.

Usage:
    python3 scripts/animate_pack.py <pack-dir> [--frames 8] [--fill 0.85]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

# Per-state motion. Amplitudes are fractions of the canvas, kept small: at the size the
# companion renders (`CompanionSize`, 36-84pt with 52 the default), a 2% shift is about
# a pixel and still reads, while anything large looks like a glitch.
#
#   squash  peak vertical compression (1.0 = none)
#   rise    peak upward travel, fraction of canvas
#   sway    peak horizontal travel, fraction of canvas
#   lean    peak rotation in degrees
#   fps     playback rate
#   ease    "sine" loops smoothly; "recoil" hits hard then settles
MOTION = {
    "resting":   {"squash": 0.020, "rise": 0.008, "sway": 0.000, "lean": 0.0, "fps": 8,  "ease": "sine"},
    "alert":     {"squash": 0.012, "rise": 0.016, "sway": 0.004, "lean": 1.2, "fps": 10, "ease": "sine"},
    "thinking":  {"squash": 0.014, "rise": 0.006, "sway": 0.014, "lean": 2.0, "fps": 8,  "ease": "sine"},
    "delighted": {"squash": 0.060, "rise": 0.055, "sway": 0.000, "lean": 0.0, "fps": 12, "ease": "sine"},
    "startled":  {"squash": 0.030, "rise": 0.030, "sway": 0.010, "lean": 3.0, "fps": 12, "ease": "recoil"},
    "sleepy":    {"squash": 0.028, "rise": 0.004, "sway": 0.000, "lean": 0.0, "fps": 5,  "ease": "sine"},
}

STATES = list(MOTION)


def phase(index: int, count: int, ease: str) -> float:
    """Normalised motion amount for one frame, in -1...1."""
    t = index / count
    if ease == "recoil":
        # A damped oscillation that starts at full deflection.
        #
        # The obvious `sin(2πt) * decay` is wrong here: sin(0) is 0, so the first
        # frame showed no motion at all and the tail flattened into two identical
        # frames — a visible stall in a 2.4-second state. Starting from a cosine
        # puts the jolt on frame 1 where a startle belongs, and a higher frequency
        # keeps the settle moving rather than idling near zero.
        return math.cos(math.pi * 2.5 * t) * math.exp(-1.8 * t)
    return math.sin(math.pi * 2 * t)


def transform(still: Image.Image, amount: float, spec: dict) -> Image.Image:
    """One frame: squash, rise, sway and lean applied to the whole figure."""
    width, height = still.size

    # Volume-conserving squash, anchored at the feet.
    vertical = 1 - spec["squash"] * max(amount, 0) + spec["squash"] * max(-amount, 0)
    horizontal = 1 / vertical

    new_size = (max(1, round(width * horizontal)), max(1, round(height * vertical)))
    scaled = still.resize(new_size, Image.LANCZOS)

    if spec["lean"]:
        # Expand before rotating so the corners are not cropped, then the paste
        # below re-centres. `expand=True` changes the size, which is why the offset
        # is computed from `scaled` afterwards.
        scaled = scaled.rotate(spec["lean"] * amount, resample=Image.BICUBIC,
                               expand=True)

    frame = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = (width - scaled.width) // 2 + round(width * spec["sway"] * amount)
    # Centred vertically, then lifted by `rise`.
    #
    # This used to bottom-align — feet on the floor, which is what squash-and-stretch
    # normally wants. It is wrong here for the same reason the framing above is centred:
    # scaling the *canvas* and then pinning its bottom edge slides the character down by
    # half the compression, so a peak squash sank it about 1.3pt below the pill on a 52pt
    # character. Weight still reads, because the app applies its own squash anchored at
    # `.bottom` when it draws the frame (`SpritePackView`); this layer only has to keep
    # the character where the user put it.
    y = (height - scaled.height) // 2 - round(height * spec["rise"] * max(amount, 0))
    frame.paste(scaled, (x, y), scaled)
    return frame


def animate(pack: str, frames: int, fill: float) -> None:
    if not os.path.isdir(pack):
        sys.exit(f"Not a pack directory: {pack}")

    manifest_path = os.path.join(pack, "pack.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as handle:
            manifest = json.load(handle)

    # Measure every state before writing any of them, so all frames in the pack can
    # share one canvas size, with each character *centred* in it.
    #
    # Three things the canvas has to get right, all of them only visible in the app:
    #
    #   1. **Room for the motion.** A stretch grows the figure upward and the stills are
    #      cropped tight (measured: 21px of headroom on a 463px figure), while
    #      `delighted` stretches by 6% and needs 28 — one frame had the top of the
    #      character's hair sliced off. Padding, not less motion: the amplitude is a
    #      design choice.
    #
    #   2. **One canvas for every state.** The renderer fits each frame into a fixed
    #      square with `aspectRatio(.fit)`, so a state padded taller than its neighbour
    #      is scaled down more and the character visibly shrank and grew as its mood
    #      changed.
    #
    #   3. **The character centred in that canvas.** This is what was wrong when the
    #      sleeping companion sat visibly below the pill. Padding went on the top only
    #      and each pose was bottom-aligned, so its visual mass fell below the middle of
    #      the frame — and since the app centres the frame on the pill, below the pill.
    #      Measured on a 52pt character: every pose sat low, standing ones by 2.8-4.5pt
    #      and the curled `sleepy` pose by 8.4pt.
    #
    #      So each pose is cropped to its own ink and centred, rather than sharing a
    #      baseline. A shared baseline is the right choice for a character standing on a
    #      floor; this one floats beside a capsule, where there is no floor to reference
    #      and what must stay put is the character's *centre*. Nothing jumps: a mood
    #      change swaps the whole drawing at once, so there is no fixed part to compare
    #      against — while under a shared baseline the drop was plainly visible.
    #      The shared *scale* still comes from `build_pack.py`, so poses keep their real
    #      relative sizes; only the framing changes here.
    stills: dict[str, Image.Image] = {}
    for state in STATES:
        still_path = os.path.join(pack, f"{state}.png")
        if not os.path.exists(still_path):
            continue
        source = Image.open(still_path).convert("RGBA")
        box = source.split()[3].getbbox()
        if not box:
            print(f"  ! {state}.png is empty — skipped")
            continue
        stills[state] = source.crop(box)

    if not stills:
        sys.exit("No state PNGs found — expected resting.png etc. in the pack.")

    # A canvas big enough for the *transformed* figure, not the still.
    #
    # The margin has to be computed from what `transform` actually does, which is more
    # than it looks. Budgeting `sway` for the sides and `squash + rise` for the top —
    # the obvious reading of the motion table — clipped five frames across the four
    # packs, all of them on the left and right edges. Two effects were missing:
    #
    #   * **Squash conserves volume**, so compressing vertically *widens* the figure by
    #     `1/(1 - squash)`. `delighted` squashes 6%, which is 6.4% wider — 16px on a
    #     255px panda, against a side margin of 2.
    #   * **Lean rotates**, and a rotated box is wider by `height · sin θ`. At 3° on a
    #     300px figure that is another 16px.
    #
    # Cropping each pose to its ink (above) is what exposed this: the old canvas kept
    # the still's own transparent padding, which absorbed the growth by accident.
    def bounds(image: Image.Image, spec: dict) -> tuple[float, float]:
        """Worst-case width and height of one state after the whole transform."""
        angle = math.radians(abs(spec["lean"]))
        cos, sin = math.cos(angle), math.sin(angle)
        # The extremes never co-occur — maximum widening happens at maximum vertical
        # compression — so taking each independently is a safe over-estimate.
        widest = image.width / (1 - spec["squash"])
        tallest = image.height * (1 + spec["squash"])
        return (
            widest * cos + tallest * sin + 2 * image.width * spec["sway"],
            tallest * cos + widest * sin + image.height * spec["rise"],
        )

    # Slack on top of the computed extent. The extent is exact in real numbers, but the
    # transform works in whole pixels: `round` on the scaled size and a floor-divided
    # paste offset together spend most of a tight margin, which left the ink sitting
    # 0.57px from the edge and reporting as clipped. Six pixels is cheap — at the size
    # these are drawn it is under a point — and it removes the class of problem.
    slack = 6
    extents = [bounds(im, MOTION[state]) for state, im in stills.items()]
    motion_width = math.ceil(max(w for w, _ in extents)) + slack * 2
    motion_height = math.ceil(max(h for _, h in extents)) + slack * 2

    # `fill` is the per-pack size control, and the canvas is how it is applied.
    #
    # The app fits every frame into one square of the chosen `CompanionSize`, so a
    # figure that occupies more of its canvas is drawn larger. Since the fit is driven by
    # the taller side, making the canvas `tallest_ink / fill` high renders the tallest
    # pose at exactly `fill` of the box — so `--fill 0.9` against `--fill 0.8` is a 12.5%
    # bigger character, guaranteed rather than tuned.
    #
    # This used to be `build_pack.py --pad`, which worked only because the frames kept
    # the still's own padding. Cropping each pose to its ink — which is what centres the
    # character properly — threw that padding away and collapsed every pack to within
    # 5% of the others, undoing the one that was deliberately larger. The control belongs
    # here now, in the step that decides the canvas.
    tallest_ink = max(im.height for im in stills.values())
    canvas_height = max(motion_height, math.ceil(tallest_ink / fill))
    canvas_width = motion_width
    if canvas_width > canvas_height:
        # A frame wider than it is tall makes the aspect-fit width-driven, and `fill`
        # then describes the wrong axis. None of the shipped packs does this — the
        # characters are all taller than wide — so it is reported rather than handled.
        print(f"  ! frames are wider ({canvas_width}) than tall ({canvas_height}); "
              f"--fill {fill} will not be reached")
        canvas_height = canvas_width
    canvas_size = (canvas_width, canvas_height)

    states: dict[str, dict] = {}
    for state, source in stills.items():
        spec = MOTION[state]

        still = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        still.paste(
            source,
            ((canvas_size[0] - source.width) // 2, (canvas_size[1] - source.height) // 2),
            source,
        )

        # Frames live in a folder named for the state, which the loader prefers over
        # the single file. The still is left in place as a fallback for anything that
        # reads the pack without folder support.
        out_dir = os.path.join(pack, state)
        shutil.rmtree(out_dir, ignore_errors=True)
        os.makedirs(out_dir)

        for index in range(frames):
            amount = phase(index, frames, spec["ease"])
            transform(still, amount, spec).save(
                os.path.join(out_dir, f"{index + 1:02d}.png"), "PNG", optimize=True
            )

        states[state] = {"frames": frames, "fps": spec["fps"]}
        print(f"  ✓ {state:11s} {frames} frames @ {spec['fps']}fps")

    # Record the intended rate per state. The loader reads this: `animation.<state>.fps`
    # is the per-state rate for the numbered-frame layout, and it takes precedence over
    # a pack-wide `fps`. (It did not always — every state used to fall back to 8 fps,
    # so `sleepy` played 60% fast and `delighted` 33% slow. See
    # `SpritePackStore.declaredFPS`.)
    manifest["animation"] = states
    with open(manifest_path, "w") as handle:
        json.dump(manifest, handle, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack")
    parser.add_argument("--frames", type=int, default=8)
    parser.add_argument("--fill", type=float, default=0.85,
                        help="how much of the rendered square the tallest pose "
                             "fills; the per-pack size control")
    args = parser.parse_args()
    animate(args.pack, args.frames, args.fill)


if __name__ == "__main__":
    main()
