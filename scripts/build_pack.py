#!/usr/bin/env python3
"""
Turn one image per mood into a companion sprite pack's state stills.

The input is what an image generator gives you: one picture per state, each framed
however it happened to come out, with the transparency flattened into pixels
(`dechecker` undoes that part).

The job here is the part a per-image tool cannot do — **normalise across states**.
Cropping each state to its own bounds and scaling each to fill its own square is
what the earlier single-image path did, and it makes a lying-down `sleepy` pose as
tall as a standing `alert` one. The character then visibly changes size and its feet
jump the moment its mood changes, which is the most noticeable defect a sprite pack
can have.

So: cut every state, measure them all, then apply **one shared scale** and **one
shared baseline** to the whole set. A pose that is genuinely wider and shorter stays
wider and shorter, and the feet stay on the floor between moods. The scale is driven
by the largest state, so nothing is clipped.

What reaches this point is already the figure alone: `dechecker` drops decoration that
floats free of it (scattered sparkles, a "Zzz"), and keeps a prop that touches it — a
question mark resting against an ear survives. That is what makes one shared scale
meaningful, since a stray sparkle in the corner of one state would otherwise set the
scale for all six.

Frames are written at `--size`, which only needs to beat what the app draws:
`SpritePackStore.maxFrameSide` thumbnails every frame to ~113px on load, so 320
leaves ample headroom for a retina 44pt render and keeps the pack small.

Usage:
    python3 scripts/build_pack.py --out Companions/panda --name Panda \\
        resting=/path/sitting.jpeg alert=/path/forward.jpeg ...

Then give it motion:
    python3 scripts/animate_pack.py Companions/panda
"""
from __future__ import annotations

import argparse
import json
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

from dechecker import cut_alpha

# The six moods the app asks for, in the order the loader documents them.
STATES = ["resting", "alert", "thinking", "delighted", "startled", "sleepy"]


def matte(path: str) -> Image.Image:
    """RGBA for one source image, cutting the background only if it needs cutting.

    Art that already carries alpha must be used as it is. Running the cut over it
    would be strictly worse on both counts: `cut_alpha` reads RGB, so it would throw
    away the alpha it was handed, and it produces a *binary* matte — while a real
    cutout has anti-aliased edges (measured: 5-11% of pixels at partial alpha). Those
    soft pixels are what stop the character wearing a hard fringe against a wallpaper.

    "Already has alpha" means the channel actually varies. A PNG saved as RGBA with
    every pixel opaque carries no matte at all, and has to go through the cut like a
    JPEG would.
    """
    image = Image.open(path)
    if image.mode in ("RGBA", "LA", "PA"):
        rgba = image.convert("RGBA")
        low, _high = rgba.split()[3].getextrema()
        if low < 250:
            print("  source has its own alpha — kept as-is")
            return rgba
    return cut_alpha(image)


def build(pairs: dict[str, str], out_dir: str, name: str, author: str, size: int,
          pad: float, dry_run: bool) -> None:
    unknown = set(pairs) - set(STATES)
    if unknown:
        sys.exit(f"Unknown state(s): {', '.join(sorted(unknown))}\n"
                 f"Expected any of: {', '.join(STATES)}")

    cut: dict[str, Image.Image] = {}
    for state in STATES:
        source = pairs.get(state)
        if not source:
            continue
        if not os.path.exists(source):
            sys.exit(f"Missing source for {state}: {source}")
        print(f"{state}:")
        image = matte(source)
        box = image.split()[3].getbbox()
        if not box:
            sys.exit(f"  {state}: nothing left after the cut — check the background")
        cropped = image.crop(box)
        cut[state] = cropped
        print(f"  ink {cropped.width}x{cropped.height}")

    if not cut:
        sys.exit("No states given.")

    # One scale for the whole pack, set by whichever state needs the most room.
    widest = max(im.width for im in cut.values())
    tallest = max(im.height for im in cut.values())
    budget = size * (1 - pad * 2)
    scale = budget / max(widest, tallest)
    print(f"\nshared scale {scale:.4f} (largest state {widest}x{tallest} -> "
          f"{round(widest * scale)}x{round(tallest * scale)} in a {size}px canvas)")

    if dry_run:
        for state, im in cut.items():
            print(f"  {state:10s} -> {round(im.width * scale):3d}x{round(im.height * scale):3d}")
        return

    os.makedirs(out_dir, exist_ok=True)
    baseline = size - round(size * pad)      # y of the floor every state stands on

    for state, im in cut.items():
        target = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        scaled = im.resize(target, Image.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(scaled, ((size - scaled.width) // 2, baseline - scaled.height), scaled)
        path = os.path.join(out_dir, f"{state}.png")
        canvas.save(path, "PNG", optimize=True)
        print(f"  wrote {path}  ({target[0]}x{target[1]} on {size}x{size})")

    # Merge rather than overwrite: `animate_pack.py` writes an `animation` section
    # into the same file, and re-running this must not throw that away.
    manifest_path = os.path.join(out_dir, "pack.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as handle:
            manifest = json.load(handle)
    # No `id`: the loader takes a pack's id from its folder name, so writing one here
    # would be a second source of truth that nothing reads.
    manifest["name"] = name
    manifest["author"] = author
    with open(manifest_path, "w") as handle:
        json.dump(manifest, handle, indent=2)
    print(f"  wrote {manifest_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, help="pack directory to write")
    parser.add_argument("--name", required=True, help="display name in the picker")
    parser.add_argument("--author", default="from individually generated poses",
                        help="credit line stored in pack.json")
    parser.add_argument("--size", type=int, default=320)
    parser.add_argument("--pad", type=float, default=0.05,
                        help="margin as a fraction of the canvas")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("pairs", nargs="+", metavar="state=path")
    args = parser.parse_args()

    pairs: dict[str, str] = {}
    for pair in args.pairs:
        if "=" not in pair:
            sys.exit(f"Expected state=path, got: {pair}")
        state, path = pair.split("=", 1)
        pairs[state] = path

    build(pairs, args.out, args.name, args.author, args.size, args.pad, args.dry_run)


if __name__ == "__main__":
    main()
