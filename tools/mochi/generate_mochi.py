#!/usr/bin/env python3
"""Generate Mochi, the pixel-cat companion, into Companions/.

Run:  python3 tools/mochi/generate_mochi.py
      python3 tools/mochi/generate_mochi.py --verify    # checks only, writes nothing

The silhouette and every pose live in `mochi_shapes.py`; this file turns them into the two
installable packs, checks its own output, and writes preview sheets to /tmp.

WHY 32x32
---------
The app snaps pixel packs to a whole-number scale and rounds down (`SpritePackView
.renderedSize`). Its size ladder is 36/52/68/84pt, which on a 2x display is 72/104/136/168
device pixels; their greatest common divisor is 8, so a 32px canvas renders at 32/48/64/80pt
— 2x, 3x, 4x, 5x. 2x is therefore the floor every decision has to survive, which is why the
previews render at 64px first.

FLAT, NOT SHADED
----------------
Two body tones, not four. Measured off the reference this is modelled on: 64,197 pixels of
one near-black and 53,451 of white, and no third fur tone at all. The first attempt here
shaded the fur across four tones with a directional rim light, which is why it read as a
different animal — at 32px, extra tones cost silhouette clarity and buy nothing.

The one deviation is `EDGE`: the outermost ring of body pixels is a fractionally lighter
black. Against a white wallpaper it is indistinguishable from the fill — measured 1.06:1,
which no eye resolves — but against a near-black wallpaper it lifts the shape to 1.9:1 and
the cat stops disappearing. A flat black cat on a black desktop is a real flaw in the thing
being copied, and this is the cheapest honest fix that does not change how it looks.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
    from PIL.PngImagePlugin import Blend, Disposal
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

from mochi_shapes import (
    CANVAS, EYE_TRAVEL, KEY_ROWS, T,
    add_keyboard, add_steam, add_zzz, pupils, shift, to_strings,
)
# The sitting silhouette lives in its own module: it is a whole cat — head, ears, face,
# torso, four legs, paws and tail — and it replaced a head-over-pear shape that read as a
# blob with ears. See `full_body.py` for what changed and why.
from full_body import FORELEGS, add_face, fill as fill_row, full_cat

# How the typing pose is posed off the shared silhouette: lifted to clear the keyboard, head
# nudged one column forward so it reads as attention rather than as a cat sitting near a
# keyboard. Both feed the eye anchor written into pack.json.
KNEAD_LIFT = -3
KNEAD_LEAN = -1

REPO = Path(__file__).resolve().parents[2]
COMPANIONS = REPO / "Companions"

# ── Palettes ──────────────────────────────────────────────────────────────────
#
# Five roles, and only two of them are the cat: `b` (fill) and `e` (the edge ring). `w` is
# the eye white, `k` the pupil and mouth, and `g`/`s` the keyboard prop.
PALETTES = {
    # The near-black from the reference, with its faint red cast — a true neutral black
    # reads as a hole punched in the desktop rather than as fur.
    # `e` is both the outer outline and the interior lines that separate the forelegs from
    # the torso. At #2E1A1A neither read against #170000 fur — measured 1.23:1 — so it is
    # lightened to #4A2E2E (1.9:1), which is also what lifts the silhouette off a dark
    # wallpaper. `p` is the nose: on a black cat only a light feature is visible at all.
    "midnight": {
        "b": "#170000", "e": "#4A2E2E", "w": "#FDFDFD", "k": "#0A0000",
        "p": "#E0708A", "g": "#D6D2CC", "s": "#9A948C",
    },
    # The light coat. Its edge ring goes the other way — darker than the fill — because on
    # a cream cat it is a white wallpaper that erases the silhouette, not a black one.
    "cream": {
        "b": "#EAC9A0", "e": "#A8794E", "w": "#FFFDF6", "k": "#4A3428",
        "p": "#E0708A", "g": "#D6D2CC", "s": "#9A948C",
    },
}

EXACT_RATES = {4, 5, 8, 10, 20, 25}


# ── Poses ─────────────────────────────────────────────────────────────────────

def pose_sit(eyes="open", lean=0, squash=0, whiskers=True, drop=0, leg_lift=(0, 0)):
    """The full-body sitting cat. `whiskers` is accepted and ignored — they are part of the
    silhouette now rather than an optional overlay, because a cat without them read as a bear.

    `leg_lift` raises each front paw, which is how the walk and the knead step: the mood
    transforms the engine adds (bob, lean) cannot move a limb, so the limb movement is the one
    thing the art has to supply."""
    grid = full_cat(squash=squash, lean=lean, leg_lift=leg_lift)
    add_face(grid, eyes=eyes, squash=squash + drop, lean=lean)
    return grid


def pose_knead(phase):
    """Two paws hammering two keycaps — the aggressive-typing pose, in four frames.

    Built from the SAME full-body cat as every other state, lifted three rows to clear the
    keyboard, with the head leaning one column forward. A dedicated leaning silhouette was
    built for this and then removed: it leaned correctly but was a second, differently-
    proportioned cat, and beside the other states read as a *different animal* — a worse
    defect than not leaning. The lean survives as the head shift, and that is what the
    per-state eye anchor is for: lifting the whole grid moves the eye whites with it, so the
    shared pupil layer has to be told or the pupils float below the face.

    The four frames make it *hammer* rather than gently alternate. One paw is planted on its
    key (pressed, so the cap travels down and the paw reaches onto it); the other is cocked
    high, about to strike. They swap sides each beat, with a passing frame between where both
    hover — the read is a cat pounding a keyboard, not patting it:

        0  left slams, right cocked        2  right slams, left cocked
        1  both hover (passing)            3  both hover (passing)
    """
    pressed = {0: 0, 1: None, 2: 1, 3: None}[phase]
    # (left, right) paw lift. The slamming paw is planted (0); its partner is cocked high (2);
    # the passing frames hold both mid-air (1).
    lifts = {0: (0, 2), 1: (1, 1), 2: (2, 0), 3: (1, 1)}[phase]

    grid = full_cat(lean=KNEAD_LEAN, leg_lift=lifts)
    add_face(grid, eyes="open", lean=KNEAD_LEAN)
    grid = shift(grid, dy=KNEAD_LIFT)
    # The planted paw reaches one row further, onto the key that has travelled down.
    if pressed is not None:
        first, last = FORELEGS[pressed]
        fill_row(grid, KEY_ROWS[0], first, last, "b")
    add_keyboard(grid, pressed=pressed)
    return grid


def pose_sleep(phase):
    """Curled and breathing, with z's rising.

    Four frames at 5 fps. This used to be a single still, because the engine stopped its
    ticker on falling asleep and a frozen clock holds one frame forever — a sleeping cat that
    does not move reads as a dead one. The engine now drops to 10 Hz instead of stopping, so
    the breath and the z's animate for about a third of the awake cost.

    The breath is one pixel: the whole body settles a row lower on the middle two frames. At
    32px one row is the smallest change that reads, and anything larger looks like panting.
    """
    # 1 and 2, not 2 and 3: at 3 the cat's hind paws reached row 31, the last row on the
    # canvas, where every other pose stops at 29. Nothing was clipped, but a pose with no
    # margin has none left for the breath the renderer adds on top.
    settle = 1 if phase in (1, 2) else 2
    grid = shift(pose_sit(eyes="shut"), dy=settle)
    add_zzz(grid, phase=phase)
    return grid


def pose_overheat(phase):
    """Flustered, with steam rising either side of the head.

    The cat is shifted down two rows to make room: on a 32px canvas the ears already reach
    row 1, so there was no headroom for a puff until the body moved. That is the reason steam
    could not just be drawn on top of the existing frames.
    """
    grid = shift(pose_sit(eyes="half"), dy=2)
    add_steam(grid, phase=phase)
    return grid


def pose_hunt():
    """Crouched: the head drops two rows toward the body, so the cat compresses to pounce."""
    return pose_sit(eyes="wide", squash=2)


def pose_drag():
    """Dangling. Shifted up so it hangs from the pointer rather than standing."""
    return shift(pose_sit(eyes="wide"), dy=-2)


def pose_walk(phase):
    """A four-phase step. The engine translates the window and adds the body bob and forward
    lean, so the one thing the art has to supply is the *legs*: lift alternate front paws so
    the character walks rather than slides across the desktop like a decal. A raised paw plus
    the engine's bob is enough to read as a step at 32px, where a full leg cycle would be a
    few indistinct pixels.

        0  lift left      1  both down (passing)
        2  lift right     3  both down (passing)
    """
    lifts = {0: (1, 0), 1: (0, 0), 2: (0, 1), 3: (0, 0)}[phase]
    return pose_sit(eyes="open", leg_lift=lifts)


POSES = {
    "resting":   {"frames": [pose_sit(), pose_sit(), pose_sit(), pose_sit(),
                             pose_sit(), pose_sit(), pose_sit(), pose_sit(),
                             pose_sit(eyes="shut"), pose_sit()], "fps": 5},
    "alert":     {"frames": [pose_sit(eyes="wide")], "fps": 8},
    "thinking":  {"frames": [pose_sit(eyes="half", lean=1), pose_sit(eyes="half", lean=1),
                             pose_sit(eyes="shut", lean=1), pose_sit(eyes="half", lean=1)],
                  "fps": 4},
    "delighted": {"frames": [pose_sit(eyes="happy", squash=-1)], "fps": 8},
    "startled":  {"frames": [pose_sit(eyes="wide", squash=-1)], "fps": 8},
    "sleepy":    {"frames": [pose_sleep(0), pose_sleep(1), pose_sleep(2), pose_sleep(3)],
                  "fps": 5},
    "knead":     {"frames": [pose_knead(0), pose_knead(1), pose_knead(2), pose_knead(3)],
                  "fps": 10},
    "overheat":  {"frames": [pose_overheat(0), pose_overheat(1)], "fps": 10},
    "purr":      {"frames": [pose_sit(eyes="happy")], "fps": 5},
    "hunt":      {"frames": [pose_hunt()], "fps": 8},
    "drag":      {"frames": [pose_drag()], "fps": 8},
    "walk":      {"frames": [pose_walk(0), pose_walk(1), pose_walk(2), pose_walk(3)],
                  "fps": 8},
    "stretch":   {"frames": [pose_sit(eyes="shut", squash=-2)], "fps": 5},
}


# ── Rendering ─────────────────────────────────────────────────────────────────

def outline_edge(grid):
    """Replace the outermost ring of body pixels with the edge tone.

    Body pixels only: the eye whites and the keyboard keep their own colours, or the cat
    ends up with a dark line through its eye.
    """
    out = [row[:] for row in grid]
    for y in range(CANVAS):
        for x in range(CANVAS):
            if grid[y][x] != "b":
                continue
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = y + dy, x + dx
                if not (0 <= ny < CANVAS and 0 <= nx < CANVAS) or grid[ny][nx] == T:
                    out[y][x] = "e"
                    break
    return out


def render(grid, palette):
    """One grid to RGBA at 1:1. Nothing is resampled here."""
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    pixels = image.load()
    for y, row in enumerate(grid):
        for x, char in enumerate(row):
            if char == T:
                continue
            code = palette[char].lstrip("#")
            pixels[x, y] = (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), 255)
    return image


def write_apng(path, images, delay_ms):
    if len(images) == 1:
        images[0].save(path)
        return
    images[0].save(path, save_all=True, append_images=images[1:], duration=delay_ms,
                   loop=0, disposal=Disposal.OP_BACKGROUND, blend=Blend.OP_SOURCE)


def emit_pack(coat, directory, display_name):
    palette = PALETTES[coat]
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)

    animation = {}
    written = []
    for state, spec in POSES.items():
        if spec["fps"] not in EXACT_RATES:
            raise SystemExit(f"{state}: {spec['fps']} fps is not a whole number of "
                             f"milliseconds — pick one of {sorted(EXACT_RATES)}")
        images = [render(outline_edge(grid), palette) for grid in spec["frames"]]
        write_apng(directory / f"{state}.png", images, round(1000 / spec["fps"]))
        # A rate is declared only where something animates; a still has no frame rate, and
        # the app's round-trip test checks the manifest against the art.
        animation[state] = ({"frames": len(images), "fps": spec["fps"]} if len(images) > 1
                            else {"frames": 1})
        written.append((state, len(images)))

    render(pupils(), palette).save(directory / "eyes.png")

    (directory / "pack.json").write_text(json.dumps({
        "name": display_name,
        "author": "Utter — tools/mochi/generate_mochi.py",
        "pixelArt": True,
        "eyeTravel": EYE_TRAVEL,
        # Where the eye layer sits for states whose head is not where the resting pose has
        # it. Only the leaning typing pose needs one.
        "eyeAnchors": {"knead": [KNEAD_LEAN, KNEAD_LIFT]},
        "animation": animation,
    }, indent=2) + "\n")
    return written


# ── Verification ──────────────────────────────────────────────────────────────

def contrast(hex_a, hex_b):
    def luminance(code):
        parts = []
        for i in (0, 2, 4):
            v = int(code.lstrip("#")[i:i + 2], 16) / 255
            parts.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
        r, g, b = parts
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    first, second = luminance(hex_a), luminance(hex_b)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)


def verify_pupil_budget():
    """Every offset in the budget must keep the pupil inside its white."""
    from mochi_shapes import (EYE_WHITE_X, EYE_WHITE_Y, EYE_WHITE_W, EYE_WHITE_H,
                              PUPIL_X, PUPIL_Y, PUPIL_W, PUPIL_H)
    problems = []
    for dx in (-EYE_TRAVEL, 0, EYE_TRAVEL):
        for dy in (-EYE_TRAVEL, 0, EYE_TRAVEL):
            for white_x, pupil_x in zip(EYE_WHITE_X, PUPIL_X):
                inside = (pupil_x + dx >= white_x
                          and pupil_x + dx + PUPIL_W - 1 <= white_x + EYE_WHITE_W - 1
                          and PUPIL_Y + dy >= EYE_WHITE_Y
                          and PUPIL_Y + dy + PUPIL_H - 1 <= EYE_WHITE_Y + EYE_WHITE_H - 1)
                if not inside:
                    problems.append(f"pupil at ({dx:+d},{dy:+d}) leaves the white at {white_x}")
    return problems


def verify_alpha(directory):
    problems = []
    for path in sorted(directory.glob("*.png")):
        alpha = Image.open(path).convert("RGBA").getchannel("A")
        low, high = alpha.getextrema()
        if low != 0:
            problems.append(f"{path.name}: nothing transparent")
        if high != 255:
            problems.append(f"{path.name}: nothing fully opaque")
        if any(0 < v < 255 for v in alpha.get_flattened_data()):
            problems.append(f"{path.name}: soft edges — pixel art must be hard")
    return problems


def preview(coat, path):
    """Every state at 2x, 3x and 4x, on a white and a near-black desktop."""
    palette = PALETTES[coat]
    eye = pupils()
    scales = (2, 3, 4)
    backgrounds = [(0xF5, 0xF5, 0xF7), (0x1A, 0x1A, 0x20)]
    cell_w = sum(CANVAS * s + 6 for s in scales) + 12
    cell_h = CANVAS * max(scales) + 6
    sheet = Image.new("RGB", (12 + len(POSES) * cell_w,
                              12 + len(backgrounds) * (cell_h + 10)), (58, 58, 66))
    y = 12
    for background in backgrounds:
        band = Image.new("RGB", (sheet.width, cell_h), background)
        x = 12
        for state, spec in POSES.items():
            grid = outline_edge(spec["frames"][0])
            merged = [row[:] for row in grid]
            for py in range(CANVAS):
                for px in range(CANVAS):
                    if eye[py][px] != T:
                        merged[py][px] = eye[py][px]
            image = render(merged, palette)
            for scale in scales:
                scaled = image.resize((CANVAS * scale, CANVAS * scale), Image.NEAREST)
                band.paste(scaled, (x, (cell_h - CANVAS * scale) // 2), scaled)
                x += CANVAS * scale + 6
            x += 12
        sheet.paste(band, (0, y))
        y += cell_h + 10
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    print("Checking the art…")
    problems = verify_pupil_budget()
    for problem in problems:
        print(f"  ✗ {problem}")
    if not problems:
        print(f"  ✓ pupil stays inside its white at every ±{EYE_TRAVEL} offset")

    for coat, palette in PALETTES.items():
        print(f"  · {coat:8} fill vs white desktop {contrast(palette['b'], '#F5F5F7'):5.2f}:1, "
              f"edge vs dark desktop {contrast(palette['e'], '#1A1A20'):4.2f}:1, "
              f"edge vs fill {contrast(palette['e'], palette['b']):4.2f}:1")

    if args.verify:
        raise SystemExit(1 if problems else 0)

    for coat, name in (("midnight", "Mochi (Midnight)"), ("cream", "Mochi (Cream)")):
        directory = COMPANIONS / f"mochi-{coat}"
        written = emit_pack(coat, directory, name)
        issues = verify_alpha(directory)
        for issue in issues:
            print(f"  ✗ {issue}")
        print(f"\n{directory.name}: {len(written)} states, "
              f"{sum(n for _, n in written)} frames, {CANVAS}x{CANVAS}px"
              + ("" if issues else "  ✓ alpha clean"))
        sheet = Path("/tmp") / f"mochi-{coat}-sheet.png"
        preview(coat, sheet)
        print(f"  preview: {sheet}")


if __name__ == "__main__":
    main()
