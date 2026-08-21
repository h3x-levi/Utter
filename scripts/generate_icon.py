#!/usr/bin/env python3
"""Build Utter's app icon from the source artwork in Assets/AppIconSource.png.

The artwork is a designed asset, so this script's job is to turn one square
image into a correct macOS icon: a coloured rounded plate with the mark on top,
rendered at every size macOS asks for.

  * **Every size is resampled from the master**, never chained. A 16px icon
    downscaled through several intermediate steps turns to mush.

  * **We ship our own plate.** macOS does *not* supply one.

An earlier version of this script shipped the bare white glyph on full
transparency, on the theory that macOS 26 composites a rounded plate behind
every app icon including legacy `.icns` ones. That theory was wrong, and the
resulting icon was close to invisible in Finder on a Mac in Light appearance:
measured on the shipped `icon_512x512.png`, 17.1% opaque, exactly **one**
distinct opaque colour — `(255,255,255)` — and therefore **1.00:1** against a
white Finder background.

What the earlier version actually observed was a system *app's own icon file*.
Every app on this machine ships its own background in the same `.icns` we ship.
Measured by extracting `Contents/Resources/*.icns` with `iconutil -c iconset`
and reading the 256px rep (`icon_128x128@2x.png`), over 7 Apple system apps
(Notes, Mail, Maps, Music, Reminders, Calculator, Terminal) and 4 third-party
apps (Slack, Firefox, Obsidian, VS Code):

    plate/canvas       0.8047 in 10 of 11  (Obsidian 0.8115)
    margin             uniform 25px of 256 on all four sides
    opaque at canvas edge   0.0% in 11 of 11
    opaque overall     61.7% - 62.6%

Nothing reaches the canvas edge in any of them, which also settles the second
half of the question: macOS does **not** mask a legacy `.icns` to a squircle. If
it did, those uniform margins would be pointless and the icons would be drawn
full-bleed. The 0.797 figure the old note quotes is the same shape measured with
a near-opaque alpha threshold; the 1px-per-side antialiased rim accounts for all
of the difference (`>200` gives 204x204, `>128` gives 206x206). `>0` gives
224x224 because Apple bakes a soft drop shadow into that margin — see
SHADOW_* below.

So the old "doubled dark square" defect was real, but its cause was not "we drew
a plate". It was drawing a plate at the *wrong* geometry inside the phantom one
the note had inferred. A plate at the measured geometry is simply what every
other app on the machine does.

Plate colour, and the bar that cannot be met
--------------------------------------------
The glyph is white, so the plate has to carry the contrast. It does: every pixel
of the gradient below clears **5.03:1** against white ink, measured on the
rendered 1024 rep by sampling the plate ring in polar coordinates.

What is *not* achievable, and should not be attempted, is contrast between the
plate and the desktop behind it. The two bars pull in opposite directions — a
plate light enough to separate from a dark Dock is too light for white ink — and
the band where both hold is almost empty. Apple does not even try. Measured on
the same 11 icons, plate fill versus the background it sits on:

    Notes / Slack / VS Code / Maps   white plate, **1.00:1** against white Finder
    Mail                             1.62:1 against white
    Music                            2.47:1 against white
    Terminal                         1.11:1 against a dark background
    Firefox                          1.04:1 against a dark background

Not one of them clears 3:1 on both. What actually separates a white Notes icon
from a white Finder background is the **baked drop shadow**, not the fill — which
is why this script bakes one too, and why the silhouette, not the fill contrast,
is the thing to protect.

Corner shape: circular, on measurement
--------------------------------------
Apple's corner is a continuous-curvature corner, not a circular arc, and
Pillow's `ImageDraw.rounded_rectangle` only draws circular ones. So the
approximation was measured rather than assumed. Sampling the real plate outline
radially from its centre (bisection on the bilinearly-interpolated alpha field
at the 0.5 crossing, 0.25 degree steps over one quadrant) and least-squares
fitting both models to it, at the 1024px rep where a plate is 824px:

    best-fit circular arc      r = 0.229-0.230 of the plate side
                               max deviation 2.00 - 2.38px  (0.24% - 0.29%)
    best-fit superellipse      |x/a|^n + |y/a|^n = 1, n = 5.18-5.20
                               max deviation 3.38 - 3.63px  (0.41% - 0.44%)

**The circular arc is not merely close enough, it fits better** — a Lamé
superellipse has no truly straight edge, so it bulges along the flats where
Apple's shape is dead straight, and that error is larger than the arc's error in
the corner. Hand-rolling a superellipse would have been more code and a worse
match. Hence `CORNER_RATIO` below, drawn with `rounded_rectangle` on a 4x
supersampled mask (Pillow's `ImageDraw` does not antialias).

The 16px and 32px reps get a simplified mark
--------------------------------------------
Apple hand-draws each small rep. We resample one master, so small sizes need one
concession, made after looking at the output rather than assuming it was fine.

Utter's mark is a white bulb with a waveform **knocked out** of it — interior
negative space, which is the first thing to die under downscaling. At 16px the
plate is ~12.9px and the mark ~8px, so the five waveform bars collapse into a
single blob dead centre and the glyph reads as a **donut, not a bulb**. Rendered
and inspected at 22x: unrecognisable.

So for sizes <= `SMALL_SIZE_MAX` the holes fully enclosed by ink are filled
(flood-fill from outside the ink bbox; open notches such as the gaps in the
bulb's base connect to the outside and correctly stay open), and the mark is
drawn slightly larger, `SMALL_GLYPH_PLATE_FRACTION`. That yields a clean solid
bulb silhouette at 16px. Four candidates were rendered and compared: 0.62 with
detail (donut, rejected), 0.62 filled (clean but small), 0.72 filled (chosen),
0.80 filled (bulb crowds the plate edge, rays clipped).

At 64px the waveform is legible again — five distinct bars — so the detailed
master is used from 64 up. Each rep is still resampled once, from whichever
master applies; nothing is chained.

One small-size compromise has **no** fix within a single-master pipeline and is
simply accepted: at 16px a plate of 0.8047 lands on 12.9px, so its edge is
antialiased across a pixel instead of landing crisply on 12px the way Apple's
separately-authored 16px rep does (they switch to a 0.750 ratio there — 12/16 —
purely to get pixel alignment). Matching that would shrink the large icon 6%
against every neighbour in the Dock, which is where the icon is actually looked
at, so the large sizes win.

Why this is a flat `.icns` and not a layered Liquid Glass icon
-------------------------------------------------------------
On macOS 26 the sanctioned app icon is a *layered* one authored in Apple's Icon
Composer: separate artwork layers the system lights itself, giving specular
highlights, refraction, and automatic Default/Dark/Mono renderings. We ship a
flat icon instead, and that is a toolchain limit, not a preference.

A layered icon reaches the app bundle exactly one way: as an `IconImageStack` /
`IconGroup` record inside a compiled `Assets.car`. Established empirically rather
than assumed — of every app on the build machine, eleven ship their Liquid Glass
icon that way (Safari, Chrome, Firefox, ChatGPT, the Office suite), and *zero*
ship a raw `.icon` document. So the `.icon` file is a build-time source, not a
resource that can be dropped into `Contents/Resources`.

`Assets.car` is a `BOMStore` archive, and its only compiler is `actool`, which
requires full Xcode. This machine has Command Line Tools only, so
`/usr/bin/actool` is the xcode-select shim and refuses:

    xcode-select: error: tool 'actool' requires Xcode, but active developer
    directory '/Library/Developer/CommandLineTools' is a command line tools
    instance

`iconutil` (which we do use) only converts between `.icns` and `.iconset`;
`assetutil` can read a compiled `Assets.car` but cannot write one. Hand-writing
the archive was rejected: it is an undocumented, OS-version-coupled binary
format, and a reverse-engineered encoder could not be verified without launching
the app.

**To upgrade this, a contributor with Xcode 26 should:** author the mark in Icon
Composer (a standalone download for macOS 26.4+, or bundled with Xcode 26) as
`Assets.xcassets/AppIcon.icon`, compile it with `actool` in place of the
`iconutil` call in `scripts/build-app.sh`, emit `Assets.car` into
`Contents/Resources`, and add `CFBundleIconName` to `Info.plist` alongside the
existing `CFBundleIconFile`. Keep emitting the `.icns` too — the system apps
above all still ship one as the pre-26 fallback. Do not add `CFBundleIconName`
without a matching `Assets.car`: it would name an asset that does not exist.

A self-contained coloured icon has no OS-version trade-off: it is drawn exactly
as supplied on macOS 13 and on 26 alike, and it carries its own contrast rather
than borrowing the desktop's. That is the whole reason to draw the plate here
rather than hope for one. (The earlier version of this file documented a
"macOS 13 trade-off this deliberately accepts" — a white glyph that would be
weak on pre-26 systems. There is no such trade-off any more, so that section is
gone rather than left standing as a stale caveat.)
"""
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SOURCE = os.path.join(ROOT, "Assets", "AppIconSource.png")
ICONSET = os.path.join(ROOT, "AppIcon.iconset")

# Master render size: the largest icon macOS asks for.
SIZE = 1024

# --- plate geometry, from the 11-app measurement in the docstring ------------

# Plate side as a fraction of the canvas. 0.8047 is 206/256 and 824/1024, the
# value 10 of the 11 measured apps use exactly. The remaining 0.1953 is the
# uniform transparent margin the drop shadow lives in.
PLATE_RATIO = 0.8047

# Corner radius as a fraction of the plate side. Best-fit circular arc against
# the real outline at 1024 (see docstring): 0.229 - 0.230 across four apps.
CORNER_RATIO = 0.230

# Supersample factor for the plate mask. `ImageDraw` does not antialias, so the
# mask is drawn 4x and area-averaged down with BOX (exact, no ringing — LANCZOS
# would overshoot on a hard binary edge).
SUPERSAMPLE = 4

# --- plate colour -----------------------------------------------------------

# Derived from the app's own palette rather than invented, then darkened to a
# measured contrast bar. The hue is the default light theme's accent ("Paper",
# Sources/UtterKit/Model/ThemeManager.swift:48) — a warm amber, which is also
# what a lamp app should be. The depth comes from the "Ember" dark theme's
# canvas (ThemeManager.swift:93), rgb(33,14,11).
#
# The raw Paper accent is rgb(214,128,27) and gives white ink only **3.02:1** —
# under the 4.5:1 bar, and the washed-out look this icon is being fixed for. So
# the gradient top is that accent at 0.752x, which lands on exactly 5.00:1, and
# the bottom is that darkened amber mixed 45% toward the Ember canvas.
#
# Against white ink these two give 5.00:1 and 8.86:1. Sampled off the *rendered*
# 1024 plate the endpoints land a unit away, rgb(160,96,20) and rgb(110,63,17),
# for a measured 5.03:1 - 8.82:1 across every plate pixel. So the whole plate
# clears 4.5:1, including where the mark's waveform is knocked out of the bulb
# and the plate shows through it. _self_check() enforces the floor.
PLATE_TOP = (161, 96, 20)
PLATE_BOTTOM = (109, 63, 17)

# Minimum acceptable white-ink contrast against any point of the plate.
CONTRAST_FLOOR = 4.5

# --- baked drop shadow ------------------------------------------------------

# Apple bakes one, which is what the margin is for, and it is what makes a
# same-tone plate visible against the desktop at all (see above). Measured on
# Apple's 256px rep: the soft (alpha > 0) bounds sit at L16 T18 R16 B14 against a
# plate margin of 25 — so the shadow reaches ~9px sideways, 7px up, 11px down —
# and its peak alpha outside the plate is 33/255. SHADOW_ALPHA was tuned against
# that rather than guessed: at 32 it renders 35/255 at 256px, and the soft bbox
# lands on exactly Apple's L16 T18 R16 B14.
SHADOW_ALPHA = 32
SHADOW_OFFSET = 0.008          # of canvas, downward
SHADOW_BLUR = 0.018            # of canvas, Gaussian radius

# --- glyph ------------------------------------------------------------------

# Longest side of the mark's ink bbox as a fraction of the **plate** side (not
# the canvas — that was the old constant's meaning, and it does not survive the
# plate). Apple's own glyphs measured on their longest axis: Terminal 0.485,
# Mail 0.495 tall / 0.723 wide, Music 0.631. 0.62 sits inside that range, at the
# upper end deliberately: Utter's mark is a bulb with thin radiating dashes, and
# the dashes inflate the bbox without adding visual mass, so it reads smaller
# than it measures.
GLYPH_PLATE_FRACTION = 0.62

# Reps at or below this size get the simplified mark — enclosed holes filled and
# drawn a little larger. See "The 16px and 32px reps" in the docstring.
SMALL_SIZE_MAX = 32
SMALL_GLYPH_PLATE_FRACTION = 0.72

# White, so it reads against the plate above.
GLYPH_COLOR = (255, 255, 255)

# Luminance above which a source pixel counts as glyph rather than background.
# The artwork is near-binary, so this is not delicate. Luminance doubles as the
# alpha mask, which is what knocks the waveform out of the bulb and lets the
# plate show through it.
INK_THRESHOLD = 96

# The sizes an .iconset must contain, as (pixel size, filename).
VARIANTS = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def _relative_luminance(rgb):
    """WCAG relative luminance of an sRGB triple."""
    chan = []
    for v in rgb:
        v /= 255.0
        chan.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    r, g, b = chan
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(a, b):
    la, lb = _relative_luminance(a), _relative_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def _self_check():
    """Fail the build rather than ship an illegible icon.

    Not an assert: `python3 -O` would strip it, and the whole point of this
    script's history is that a silently wrong icon shipped once already.
    """
    for name, colour in (("PLATE_TOP", PLATE_TOP), ("PLATE_BOTTOM", PLATE_BOTTOM)):
        ratio = contrast_ratio(GLYPH_COLOR, colour)
        if ratio < CONTRAST_FLOOR:
            sys.exit(f"{name} {colour} gives glyph contrast {ratio:.2f}:1, "
                     f"below the {CONTRAST_FLOOR}:1 floor")
    # The plate must not reach the canvas edge, or macOS has nothing to sit the
    # icon in and neighbours in the Dock will not line up.
    if not 0.75 <= PLATE_RATIO <= 0.85:
        sys.exit(f"PLATE_RATIO {PLATE_RATIO} is outside the measured 0.80 convention")
    if not 0.15 <= CORNER_RATIO <= 0.30:
        sys.exit(f"CORNER_RATIO {CORNER_RATIO} is outside the measured 0.23 convention")


def plate_mask(side, radius):
    """A rounded-square mask of `side` px, antialiased by supersampling."""
    ss = SUPERSAMPLE
    big = Image.new("L", (side * ss, side * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, side * ss - 1, side * ss - 1), radius=round(radius * ss), fill=255
    )
    return big.resize((side, side), Image.BOX)


def plate_gradient(side):
    """Vertical PLATE_TOP -> PLATE_BOTTOM ramp, the direction Apple lights from."""
    ramp = Image.linear_gradient("L").resize((side, side), Image.BILINEAR)
    top = Image.new("RGB", (side, side), PLATE_TOP)
    bottom = Image.new("RGB", (side, side), PLATE_BOTTOM)
    return Image.composite(bottom, top, ramp)


def glyph_mask():
    """The artwork's ink as a soft alpha mask, cropped to its own bounds.

    Returns the greyscale image rather than a hard binary one so diagonals stay
    antialiased when it is scaled down.
    """
    if not os.path.exists(SOURCE):
        sys.exit(f"Missing source artwork: {SOURCE}")

    grey = Image.open(SOURCE).convert("L")
    box = grey.point(lambda v: 255 if v >= INK_THRESHOLD else 0).getbbox()
    if box is None:
        sys.exit("Source artwork appears to be blank")
    return grey.crop(box)


def fill_enclosed_holes(mark):
    """Make holes that ink fully surrounds solid, leaving open notches alone.

    Flood-fills the background inward from a 1px transparent border, so anything
    the flood cannot reach is enclosed. The waveform inside the bulb is enclosed
    and gets filled; the gaps between the bars of the bulb's base open onto the
    outside and are left as they are.
    """
    w, h = mark.size
    padded = Image.new("L", (w + 2, h + 2), 0)
    padded.paste(mark.point(lambda v: 255 if v >= INK_THRESHOLD else 0), (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128, thresh=0)
    holes = padded.point(lambda v: 255 if v == 0 else 0).crop((1, 1, w + 1, h + 1))
    out = mark.copy()
    out.paste(255, (0, 0), holes)
    return out


def build_master(glyph_fraction, simplify_glyph):
    """Compose a 1024px icon: shadow, then plate, then the mark on top."""
    side = round(SIZE * PLATE_RATIO)
    origin = (SIZE - side) // 2
    mask = plate_mask(side, side * CORNER_RATIO)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Shadow first, offset down and blurred, so the plate covers its own centre.
    shadow_mask = Image.new("L", (SIZE, SIZE), 0)
    shadow_mask.paste(mask, (origin, origin + round(SIZE * SHADOW_OFFSET)))
    shadow_mask = shadow_mask.filter(
        ImageFilter.GaussianBlur(SIZE * SHADOW_BLUR)
    ).point(lambda v: v * SHADOW_ALPHA // 255)
    canvas.paste(Image.new("RGB", (SIZE, SIZE), (0, 0, 0)), (0, 0), shadow_mask)

    plate = plate_gradient(side).convert("RGBA")
    plate.putalpha(mask)
    canvas.alpha_composite(plate, (origin, origin))

    mark = glyph_mask()
    if simplify_glyph:
        mark = fill_enclosed_holes(mark)
    target = round(side * glyph_fraction)
    mark.thumbnail((target, target), Image.LANCZOS)
    ink = Image.new("RGBA", mark.size, GLYPH_COLOR + (0,))
    ink.putalpha(mark)
    canvas.alpha_composite(
        ink, ((SIZE - mark.width) // 2, (SIZE - mark.height) // 2)
    )
    return canvas


def main():
    _self_check()
    os.makedirs(ICONSET, exist_ok=True)
    detailed = build_master(GLYPH_PLATE_FRACTION, simplify_glyph=False)
    simplified = build_master(SMALL_GLYPH_PLATE_FRACTION, simplify_glyph=True)

    for size, name in VARIANTS:
        master = simplified if size <= SMALL_SIZE_MAX else detailed
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(ICONSET, name), "PNG", optimize=True
        )

    print(f"✓ Icon set written to {os.path.relpath(ICONSET, ROOT)}/ "
          f"({len(VARIANTS)} sizes from {os.path.relpath(SOURCE, ROOT)})")
    print(f"  sizes <= {SMALL_SIZE_MAX}px use the simplified mark "
          f"({SMALL_GLYPH_PLATE_FRACTION} of plate, holes filled)")
    print(f"  plate {round(SIZE * PLATE_RATIO)}/{SIZE} = {PLATE_RATIO}, "
          f"corner r={CORNER_RATIO}, glyph {GLYPH_PLATE_FRACTION} of plate")
    print(f"  glyph contrast: {contrast_ratio(GLYPH_COLOR, PLATE_TOP):.2f}:1 top, "
          f"{contrast_ratio(GLYPH_COLOR, PLATE_BOTTOM):.2f}:1 bottom")


if __name__ == "__main__":
    main()
