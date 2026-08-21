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

The whole mark is used, and that is new. This script used to flood-fill the source
to isolate a lightbulb from the eight rays around it, because the full mark spent a
third of an 18px tile on dashes that resolved to single grey pixels. The mark is now
five waveform bars drawn by `scripts/generate_mark.py` — no rays to discard, no
interior to preserve — so the luminance mask *is* the glyph and ~50 lines of flood
fill went with the bulb. If a future mark ever regains separable components, that
logic is in the repository's history rather than carried here unused.

One measured decision survives from the bulb era and still applies:

  * **No dilation.** An earlier version applied a 3x3 maximum filter to keep thin
    strokes alive. It did the opposite: it closed the gaps *between* the waveform
    bars, collapsing the glyph to a blob. Measured on the old bulb interior, alpha
    spread fell from 255 to 61 at 36px. The current mark is bars separated by a gap
    of 0.083 of its width — ~0.75px at an 18px tile — so it is if anything *more*
    vulnerable to a filter that grows ink. Do not add one.
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


def glyph_mask():
    """The mark, as a soft alpha mask cropped to its own bounds.

    The source is a white mark on black, so its luminance is already the coverage mask:
    bright pixels become opaque, dark ones transparent. Nothing needs isolating — see the
    module docstring for what used to happen here and why it stopped.

    Returned greyscale rather than hard binary so the bar edges stay antialiased once
    scaled down to 18px, which is where this mark lives or dies.
    """
    if not os.path.exists(SOURCE):
        sys.exit(f"Missing source artwork: {SOURCE}\n"
                 f"Run: python3 scripts/generate_mark.py")

    grey = Image.open(SOURCE).convert("L")

    # Crop to the ink at a low threshold, not at THRESHOLD: the bar caps are rounded, so
    # their outermost pixels are mid-grey antialiasing. Cropping at 96 would shave them
    # and leave the mark very slightly flat-topped.
    box = grey.point(lambda v: 255 if v >= 16 else 0).getbbox()
    if box is None:
        sys.exit("The source artwork is blank — nothing above the ink threshold.")
    return grey.crop(box)


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
