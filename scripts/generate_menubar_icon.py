#!/usr/bin/env python3
"""
Build the menu-bar icon from the same artwork as the app icon.

A menu-bar image is not a small app icon. It must be a **template image**: pure
shape in the alpha channel, with no colour of its own, so macOS can tint it —
black on a light menu bar, white on a dark one, and the accent colour while the
menu is open. That is what makes it adapt to light and dark automatically, and
it is why this cannot simply reuse AppIcon.icns (which carries a plate that would
render as a solid slab).

The conversion works because the source art is a light glyph on a dark ground, so
its luminance *is* the coverage mask: bright pixels become opaque, dark ones
transparent. The RGB is then forced to black, which macOS ignores for template
images but which keeps the file sensible if anything ever draws it untinted.

Two decisions here were made by measuring the 18px result, not by eye:

  * **Only the bulb is used, not the radiating rays.** The full mark is 68.8% of
    the source width, but the bulb alone is 44.1% — so dropping the rays renders
    the bulb 1.56x larger in the same tile. With the rays included, an 18px tile
    spends a third of its width on eight dashes that resolve to single grey
    pixels, and the waveform bars inside the bulb close up entirely.

  * **No dilation.** An earlier version applied a 3x3 maximum filter to keep thin
    strokes alive. It did the opposite: it filled the gaps *between* the waveform
    bars, collapsing the glyph to a blob. Measured on the bulb interior, alpha
    spread fell from 255 to 61 at 36px — i.e. the bars stopped being holes.
    (An even earlier version followed the dilation with a multiply-then-gamma
    "contrast boost" that drove the whole 18px tile to zero alpha, because the
    multiply squares values in 0-255 space.)

Output: MenuBarIcon/menubar-icon.png and @2x, loaded by setupMenuBar in
Sources/App/App.swift.
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SOURCE = os.path.join(ROOT, "Assets", "AppIconSource.png")
OUT_DIR = os.path.join(ROOT, "MenuBarIcon")

# The menu bar is 24pt tall; Apple's guidance is a glyph of roughly 16-18pt so it
# sits comfortably without crowding the bar.
BASE = 18

# Fraction of the tile left empty around the glyph.
PADDING = 0.06

# Luminance above which a source pixel counts as glyph rather than background.
# The art is near-binary (measured: 5th percentile 0, 95th percentile 254), so
# the exact threshold is not delicate.
THRESHOLD = 96

# Seed for the flood fill that finds the bulb, as a fraction of the source size.
# Lands on the bulb's upper-left shoulder — deliberately not the centre, which is
# a dark waveform bar and would seed the background instead.
SEED = (0.40, 0.30)


def glyph_mask():
    """The bulb, as a soft alpha mask cropped to its own bounds.

    Isolates the bulb by flood-filling from a point known to be inside it, then
    keeps any ink directly below it (the base and screw threads, which are
    separate components). The radiating rays are discarded — see module docstring.

    Returns greyscale rather than a hard binary mask so edges stay antialiased
    once scaled down.
    """
    if not os.path.exists(SOURCE):
        sys.exit(f"Missing source artwork: {SOURCE}")

    grey = Image.open(SOURCE).convert("L")
    w, h = grey.size
    px = grey.load()

    # Iterative flood fill; the recursive form overflows the stack at this size.
    seen = bytearray(w * h)
    stack = [(int(w * SEED[0]), int(h * SEED[1]))]
    bulb = []
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if px[x, y] < THRESHOLD:
            continue
        bulb.append((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

    if not bulb:
        sys.exit("Could not locate the bulb in the source artwork")

    xs = [p[0] for p in bulb]
    ys = [p[1] for p in bulb]
    x0, x1, y1 = min(xs), max(xs), max(ys)

    keep = bytearray(w * h)
    for x, y in bulb:
        keep[y * w + x] = 1
    # The base sits below the bulb as its own component; include it.
    for y in range(y1, h):
        for x in range(x0, x1 + 1):
            if px[x, y] >= THRESHOLD:
                keep[y * w + x] = 1

    out = Image.new("L", (w, h), 0)
    op = out.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if keep[row + x]:
                op[x, y] = px[x, y]

    box = out.point(lambda v: 255 if v >= 16 else 0).getbbox()
    return out.crop(box)


def render(mask, size):
    """One template image: black RGB, glyph coverage in alpha."""
    inner = max(1, round(size * (1 - PADDING * 2)))

    # Fit the glyph into the inner square without distorting it.
    scaled = mask.copy()
    scaled.thumbnail((inner, inner), Image.LANCZOS)

    alpha = Image.new("L", (size, size), 0)
    alpha.paste(
        scaled,
        ((size - scaled.width) // 2, (size - scaled.height) // 2),
    )

    # Template images: macOS reads only the alpha, but black RGB keeps the file
    # correct if it is ever drawn without tinting.
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.putalpha(alpha)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    mask = glyph_mask()

    for scale, name in ((1, "menubar-icon.png"), (2, "menubar-icon@2x.png")):
        out = os.path.join(OUT_DIR, name)
        render(mask, BASE * scale).save(out, "PNG", optimize=True)
        print(f"✓ Menu bar icon → {os.path.relpath(out, ROOT)} "
              f"({BASE * scale}x{BASE * scale}, template)")


if __name__ == "__main__":
    main()
