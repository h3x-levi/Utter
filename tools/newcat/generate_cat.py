#!/usr/bin/env python3
"""Generate the 64px pixel cat companion into Companions/, in two colourways.

    python3 tools/newcat/generate_cat.py            # writes both packs + /tmp preview sheets
    python3 tools/newcat/generate_cat.py --verify   # checks the art, writes nothing, exits !=0 on a fault
    python3 tools/newcat/generate_cat.py --coat gray # just one coat

The geometry lives in `cat_art.py`; this file assembles the states, maps codes to a palette
per coat, writes an APNG per state + `eyes.png` + `pack.json`, checks its own output, and
renders preview sheets to /tmp at the REAL on-screen sizes (36/52/84 logical pt and the
64/128 device-px the renderer actually shows for a 64px pixel pack on a 2x display) — because
the previous rounds looked wrong on screen after passing numbers judged at 150px.

STATE LOADING — READ BEFORE ADDING A STATE
------------------------------------------
`SpritePack.stateNames` is the loader's entire vocabulary. Today it is:
  resting alert thinking delighted startled sleepy knead overheat purr hunt drag walk
So `rolling`, `grooming` and `loaf` are generated here but WILL NOT LOAD until they are added
to `SpritePack.stateNames` (and given `CompanionMood` cases + `key(for:)` mappings + engine
triggers). That is Swift work, called out in this tool's report rather than done here — this
tool touches no Swift.
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

import cat_art as A

REPO = Path(__file__).resolve().parents[2]
COMPANIONS = REPO / "Companions"

EXACT_RATES = {4, 5, 8, 10, 20, 25}      # whole-millisecond frame rates (see write_apng)

# ── palettes ──────────────────────────────────────────────────────────────────────
# Codes: b fill · e edge ring · s far-limb · w eye-white · k pupil · p nose/inner-ear pink ·
#        t tongue · z light accent (zzz/steam/sparkle).
# The edge ring follows Mochi's trick: on the DARK coat it is LIGHTER than the fill (so the cat
# lifts off a dark desktop); on the LIGHT coat it is DARKER (so it lifts off a light desktop).
PALETTES = {
    "gray": {
        "b": "#5B6472", "e": "#8E98AB", "s": "#3D4552",
        "w": "#F2F5FA", "k": "#14181F", "p": "#E39AB0", "t": "#E27A86", "z": "#DCE3EC",
    },
    "orange": {
        "b": "#E8A24C", "e": "#A85E26", "s": "#C07C34",
        "w": "#FFFDF4", "k": "#3A2A18", "p": "#E0788A", "t": "#E06A76", "z": "#FFE7A8",
    },
}

COATS = {
    "gray":   ("pixel-cat-gray",   "Pixel Cat (Gray)"),
    "orange": ("pixel-cat-orange", "Pixel Cat (Ginger)"),
}


# ── composing a front-facing frame ─────────────────────────────────────────────────

def compose(body, expr="open", look=(0, 0), face_dy=0, accessory=None,
            squash=None, tongue_at=None):
    """Outline the body, bake the eye-whites/lids + nose + whiskers, add any accessory.

    Pupils are NOT baked — they ship as the `eyes.png` overlay the app draws on top (except
    while walking). `squash` compresses the whole thing toward the seat (the hunt crouch);
    `face_dy` places the baked face where a shifted head sits (knead, drag)."""
    face = A.blank()
    A.add_face(face, expr, look)
    if tongue_at is not None:
        tx, ty = tongue_at
        A.put(face, tx, ty, A.TONGUE)
        A.put(face, tx, ty + 1, A.TONGUE)
    if face_dy:
        face = A.shift(face, dy=face_dy)
    grid = A.overlay(body, face)
    if squash is not None:
        grid = A.vsquash(grid, squash)
    grid = A.outline_edge(grid)
    if accessory is not None:
        accessory(grid)          # accessories mutate in place
    return grid


def _resting_frames():
    base = A.sit_body()
    frames = [compose(base, "open") for _ in range(10)]
    frames[8] = compose(base, "shut")            # a single blink in the loop
    return frames


def _thinking_frames():
    base = A.sit_body()
    return [compose(base, "half", accessory=lambda g: A.add_think_dots(g, i))
            for i in range(4)]


def _sleepy_frames():
    frames = []
    for i in range(4):
        settle = 1 if i in (1, 2) else 0         # a one-pixel breath
        base = A.shift(A.sit_body(), dy=settle)
        frames.append(compose(base, "shut", accessory=lambda g, p=i: A.add_zzz(g, p)))
    return frames


def _delighted_frames():
    base = A.sit_body()
    return [compose(base, "happy", accessory=lambda g, p=i: A.add_sparkle(g, p))
            for i in range(2)]


def _overheat_frames():
    base = A.sit_body()
    return [compose(base, "half", accessory=lambda g, p=i: A.add_steam(g, p))
            for i in range(2)]


def _knead_frames():
    return [compose(A.knead(i), "open", face_dy=A.KNEAD_LIFT) for i in range(4)]


def _groom_frames():
    frames = []
    for i in range(4):
        grid, lick, paw = A.groom(i)
        tongue = (paw[0] + 1, paw[1] + 1) if lick else None
        frames.append(compose(grid, "half", look=(0, 1), tongue_at=tongue))
    return frames


def _loaf_frames():
    # the loaf head sits ~3px lower than the seated head, so the baked face rides with it
    return [compose(A.loaf(breath=b), "half", face_dy=3 + b) for b in (0, 1)]


def _roll_frames():
    frames = []
    for i in range(6):
        grid, tag = A.roll(i)
        if tag == "front":
            frames.append(compose(grid, "happy"))
        else:                                    # belly-up frames bake their own tiny face
            frames.append(A.outline_edge(grid))
    return frames


def _walk_frames():
    return A.walk_cycle()                         # already outlined + face baked


# state -> (frames, fps or None, eyeAnchor (dx,dy) or None)
def build_states():
    hunt_anchor = (0, A.eye_row_after_squash(0.82))
    return {
        "resting":   (_resting_frames(), 5, None),
        "alert":     ([compose(A.sit_body(), "wide")], None, None),
        "thinking":  (_thinking_frames(), 4, None),
        "delighted": (_delighted_frames(), 8, None),
        "startled":  ([compose(A.sit_body(), "wide",
                               accessory=lambda g: _bang(g))], None, None),
        "sleepy":    (_sleepy_frames(), 5, None),
        "knead":     (_knead_frames(), 10, (A.KNEAD_LEAN, A.KNEAD_LIFT)),
        "overheat":  (_overheat_frames(), 10, None),
        "purr":      ([compose(A.sit_body(), "happy")], None, None),
        "hunt":      ([compose(A.sit_body(), "wide", squash=0.82,
                               face_dy=0)], None, hunt_anchor),
        "drag":      ([compose(A.shift(A.sit_body(), dy=-3), "wide", face_dy=-3)],
                      None, (0, -3)),
        "walk":      (_walk_frames(), 10, None),
        # generated but NOT in SpritePack.stateNames yet (see module docstring / report):
        "loaf":      (_loaf_frames(), 5, (0, 3)),
        "grooming":  (_groom_frames(), 5, None),
        "rolling":   (_roll_frames(), 8, None),
    }


def _bang(grid):
    """A startled '!' above the head."""
    A.vspan(grid, 52, 8, 12, A.ACCENT)
    A.put(grid, 52, 14, A.ACCENT)
    return grid


# ── rendering ───────────────────────────────────────────────────────────────────

def render(grid, palette):
    img = Image.new("RGBA", (A.CANVAS, A.CANVAS), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == A.T:
                continue
            code = palette[ch].lstrip("#")
            px[x, y] = (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), 255)
    return img


def write_apng(path, images, delay_ms):
    if len(images) == 1:
        images[0].save(path)
        return
    images[0].save(path, save_all=True, append_images=images[1:], duration=delay_ms,
                   loop=0, disposal=Disposal.OP_BACKGROUND, blend=Blend.OP_SOURCE)


def emit_pack(coat, directory, display_name):
    palette = PALETTES[coat]
    states = build_states()
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)

    animation = {}
    anchors = {}
    written = []
    for state, (frames, fps, anchor) in states.items():
        if fps is not None and fps not in EXACT_RATES:
            raise SystemExit(f"{state}: {fps} fps is not a whole ms — pick one of {sorted(EXACT_RATES)}")
        images = [render(g, palette) for g in frames]
        delay = round(1000 / fps) if fps else 100
        write_apng(directory / f"{state}.png", images, delay)
        animation[state] = ({"frames": len(images), "fps": fps} if len(images) > 1
                            else {"frames": 1})
        if anchor is not None:
            anchors[state] = [anchor[0], anchor[1]]
        written.append((state, len(images)))

    render(A.pupils(), palette).save(directory / "eyes.png")

    (directory / "pack.json").write_text(json.dumps({
        "name": display_name,
        "author": "Utter — tools/newcat/generate_cat.py",
        "pixelArt": True,
        "eyeTravel": A.EYE_TRAVEL,
        "eyeAnchors": anchors,
        "animation": animation,
    }, indent=2) + "\n")
    return written


# ── verification ──────────────────────────────────────────────────────────────────

def contrast(hex_a, hex_b):
    def lum(code):
        vals = []
        for i in (0, 2, 4):
            v = int(code.lstrip("#")[i:i + 2], 16) / 255
            vals.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
        r, g, b = vals
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    a, b = lum(hex_a), lum(hex_b)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def verify_alpha(directory):
    problems = []
    for path in sorted(directory.glob("*.png")):
        alpha = Image.open(path).convert("RGBA").getchannel("A")
        low, high = alpha.getextrema()
        if low != 0:
            problems.append(f"{path.name}: nothing transparent")
        if high != 255:
            problems.append(f"{path.name}: nothing fully opaque")
        # histogram avoids materialising every pixel (and the deprecated getdata()).
        if any(alpha.histogram()[v] for v in range(1, 255)):
            problems.append(f"{path.name}: soft edges — pixel art must be hard")
    return problems


def verify_walk_motion(directory):
    """The walk must move its legs: >=6 frames, motion reaching above the ankle band, and
    enough changed pixels to read. Mirrors tools/mochi's check, tuned for the 64px canvas."""
    problems = []
    path = directory / "walk.png"
    if not path.exists():
        return [f"{directory.name}: no walk.png"]
    image = Image.open(path)
    count = getattr(image, "n_frames", 1)
    if count < 6:
        problems.append(f"walk.png: {count} frames — a gait needs at least 6")
    frames = []
    for i in range(count):
        image.seek(i)
        frames.append(image.convert("RGBA").copy())
    base = frames[0].load()
    worst_rows, worst_changed = None, 0
    for i, frame in enumerate(frames[1:], start=1):
        px = frame.load()
        changed = [(x, y) for y in range(A.CANVAS) for x in range(A.CANVAS)
                   if px[x, y] != base[x, y]]
        if not changed:
            problems.append(f"walk.png: frame {i} identical to frame 0")
            continue
        rows = [y for _, y in changed]
        if len(changed) > worst_changed:
            worst_changed, worst_rows = len(changed), (min(rows), max(rows))
    if worst_rows is None:
        return problems + ["walk.png: nothing moves at all"]
    top, bottom = worst_rows
    ANKLE = 46      # paws/lower legs live below this; motion must reach above it
    if top >= ANKLE:
        problems.append(f"walk.png: motion confined to rows {top}-{bottom} — a paw shuffle, not a leg cycle")
    if worst_changed < 150:
        problems.append(f"walk.png: only {worst_changed} pixels differ at the widest — too little to read at 64px")
    return problems


def verify_frame_sizes(directory):
    """Every frame the same size (else the character changes size with its mood), and 64x64."""
    problems = []
    for path in sorted(directory.glob("*.png")):
        if path.name == "eyes.png":
            continue
        img = Image.open(path)
        for i in range(getattr(img, "n_frames", 1)):
            img.seek(i)
            if img.size != (A.CANVAS, A.CANVAS):
                problems.append(f"{path.name} frame {i} is {img.size}, not {A.CANVAS}x{A.CANVAS}")
    eyes = directory / "eyes.png"
    if eyes.exists() and Image.open(eyes).size != (A.CANVAS, A.CANVAS):
        problems.append("eyes.png does not match the frame size — the loader will discard it")
    return problems


# ── preview ─────────────────────────────────────────────────────────────────────

def preview(coat, path):
    """Every state's first frame, with pupils composited (as the app draws them), at the real
    sizes: 36/52/84 logical pt and 64/128 device px, on a light and a dark desktop."""
    palette = PALETTES[coat]
    states = build_states()
    sizes = [36, 52, 64, 84, 128]
    bgs = [(0xF3, 0xF3, 0xF6), (0x1A, 0x1A, 0x20)]
    pad = 6
    cell_w = sum(sizes) + pad * len(sizes)
    cell_h = 128 + 22
    cols = len(states)
    W = pad + cols * (cell_w + pad)
    H = pad + len(bgs) * (cell_h + pad)
    sheet = Image.new("RGB", (W, H), (0x30, 0x30, 0x38))
    for bi, bg in enumerate(bgs):
        band = Image.new("RGB", (W, cell_h), bg)
        x = pad
        for state, (frames, _fps, anchor) in states.items():
            grid = frames[0]
            if state != "walk":                    # walk suppresses the eye overlay
                pup = A.pupils()
                if anchor:
                    pup = A.shift(pup, dx=anchor[0], dy=anchor[1])
                grid = A.overlay(grid, pup)
            img = render(grid, palette)
            xx = x
            for sz in sizes:
                sc = img.resize((sz, sz), Image.NEAREST)
                band.paste(sc, (xx, (cell_h - sz) // 2 + 14), sc)
                xx += sz + pad
            x += cell_w + pad
        sheet.paste(band, (0, pad + bi * (cell_h + pad)))
    sheet.save(path)


def preview_walk(coat, path):
    palette = PALETTES[coat]
    frames = A.walk_cycle()
    bgs = [(0xF3, 0xF3, 0xF6), (0x1A, 0x1A, 0x20)]
    for scale, tag in ((3, "3x"), (1, "1x")):
        pad = 6
        cw = A.CANVAS * scale
        W = pad + len(frames) * (cw + pad)
        H = pad + len(bgs) * (cw + pad)
        out = Image.new("RGB", (W, H), (0x30, 0x30, 0x38))
        for bi, bg in enumerate(bgs):
            band = Image.new("RGB", (W, cw + pad), bg)
            for i, f in enumerate(frames):
                img = render(f, palette).resize((cw, cw), Image.NEAREST)
                band.paste(img, (pad + i * (cw + pad), pad // 2), img)
            out.paste(band, (0, pad + bi * (cw + pad)))
        out.save(str(path).replace(".png", f"_{tag}.png"))


# ── main ────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--coat", choices=list(COATS), help="only this coat")
    args = ap.parse_args()

    coats = [args.coat] if args.coat else list(COATS)

    print("Contrast:")
    for coat in coats:
        pal = PALETTES[coat]
        print(f"  {coat:7} fill/white {contrast(pal['b'], '#F3F3F6'):4.2f}:1  "
              f"edge/dark {contrast(pal['e'], '#1A1A20'):4.2f}:1  "
              f"edge/fill {contrast(pal['e'], pal['b']):4.2f}:1")

    if args.verify:
        bad = 0
        for coat in coats:
            pack_id, name = COATS[coat]
            directory = COMPANIONS / pack_id
            issues = (verify_alpha(directory) + verify_walk_motion(directory)
                      + verify_frame_sizes(directory))
            for issue in issues:
                print(f"  ✗ {coat}: {issue}")
            bad += len(issues)
        raise SystemExit(1 if bad else 0)

    for coat in coats:
        pack_id, name = COATS[coat]
        directory = COMPANIONS / pack_id
        written = emit_pack(coat, directory, name)
        issues = verify_alpha(directory) + verify_walk_motion(directory) + verify_frame_sizes(directory)
        for issue in issues:
            print(f"  ✗ {issue}")
        total = sum(n for _, n in written)
        print(f"\n{pack_id}: {len(written)} states, {total} frames, {A.CANVAS}x{A.CANVAS}px"
              + ("" if issues else "  ✓ clean"))
        sheet = Path("/tmp") / f"{pack_id}-sheet.png"
        walk = Path("/tmp") / f"{pack_id}-walk.png"
        preview(coat, sheet)
        preview_walk(coat, walk)
        print(f"  preview: {sheet}")
        print(f"  walk:    {str(walk).replace('.png', '_3x.png')}")


if __name__ == "__main__":
    main()
