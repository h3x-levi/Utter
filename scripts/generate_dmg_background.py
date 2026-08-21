#!/usr/bin/env python3
"""
Generate the DMG installer background for Utter.

Deliberately simple: a warm gradient field, an italic headline in Apple's own
system font, and two quiet drop zones marked by a dashed ring and an arrow. No
cards, no glass panels, no tiles.

The previous version tried to reproduce Liquid Glass here with layered panels.
That was the wrong call twice over: the panels were only ~14 luminance units off
the field, so they read as one stretched shape rather than as distinct cards, and
a static PNG has nothing behind it to refract — the whole point of the material.
An installer window is also not app chrome; it's a one-screen instruction, and it
should just look good and say what to do.

Fonts come from /System/Library/Fonts: SFNSItalic for the headline (the real
system italic, not a synthesised slant) and SFNS for everything else.

The canvas stays LIGHT. Finder draws DMG icon labels ("Utter.app",
"Applications") in dark text regardless of system appearance, so a dark
background makes them illegible.

Icon coordinates MUST stay in sync with scripts/build-app.sh — see ICON_SLOTS,
which this script prints on every run.
"""
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

WIDTH = 720
HEIGHT = 480

# A warm cream field, cooling very slightly toward the bottom so it isn't flat.
FIELD_TOP = (253, 246, 236)
FIELD_BOTTOM = (243, 236, 230)
# Utter's amber, used for the glow, the arrow, and the drop ring.
ACCENT = (226, 149, 45)

INK = (38, 32, 28)
INK_SECONDARY = (122, 110, 100)
INK_TERTIARY = (168, 156, 146)

# Finder centres each icon here.
ICON_Y = 250
ICON_SLOTS = {
    "app": (188, ICON_Y),
    "applications": (532, ICON_Y),
}

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "build_assets")

# Real system faces. SFNSItalic is the genuine italic cut.
FONT_ITALIC = ["/System/Library/Fonts/SFNSItalic.ttf",
               "/System/Library/Fonts/NewYorkItalic.ttf"]
FONT_TEXT = ["/System/Library/Fonts/SFNS.ttf",
             "/System/Library/Fonts/HelveticaNeue.ttc"]


def find_font(candidates, size):
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def variable_font(candidates, size, weight):
    """Load a font and set a weight axis if the face is variable.

    SF ships as a variable font, so the bold cut comes from the `wght` axis
    rather than a separate file. Falls back silently on a static face.
    """
    font = find_font(candidates, size)
    try:
        font.set_variation_by_axes([weight])
    except Exception:
        pass
    return font


def field(w, h, s):
    """Warm vertical gradient plus one soft amber glow behind the headline."""
    base = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(base)
    for y in range(h):
        t = y / max(h - 1, 1)
        # Eased rather than linear, so the transition doesn't band.
        e = t * t * (3 - 2 * t)
        draw.line([(0, y), (w, y)], fill=tuple(
            round(FIELD_TOP[i] + (FIELD_BOTTOM[i] - FIELD_TOP[i]) * e)
            for i in range(3)
        ))
    base = base.convert("RGBA")

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [-0.15 * w, -0.55 * h, 1.15 * w, 0.42 * h], fill=ACCENT + (34,)
    )
    return Image.alpha_composite(
        base, glow.filter(ImageFilter.GaussianBlur(radius=100 * s))
    )


def drop_ring(base, centre, s, dashed):
    """A ring marking a drop target.

    Solid under the app icon (it's already there), dashed under Applications
    (something goes here) — the oldest visual convention in the installer, and
    clearer than a card.
    """
    cx, cy = [v * s for v in centre]
    r = 74 * s
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if dashed:
        # 44 dashes with a 55% duty cycle reads as a dashed circle at both scales.
        segments = 44
        for i in range(segments):
            if i % 2:
                continue
            a0 = 360 * i / segments
            a1 = a0 + (360 / segments) * 1.1
            draw.arc([cx - r, cy - r, cx + r, cy + r], a0, a1,
                     fill=ACCENT + (150,), width=max(1, round(2 * s)))
    else:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                     fill=(255, 255, 255, 120),
                     outline=(255, 255, 255, 210), width=max(1, round(1.5 * s)))
    return Image.alpha_composite(base, layer)


def arrow(base, start, end, s):
    """A tapered arrow from the app to Applications."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x0, y0 = [v * s for v in start]
    x1, y1 = [v * s for v in end]

    # Shaft: a dotted line, so it guides without drawing attention.
    steps = 22
    for i in range(steps):
        t0 = i / steps
        if i % 2:
            continue
        px = x0 + (x1 - x0) * t0
        py = y0 + (y1 - y0) * t0
        rad = 2.0 * s
        draw.ellipse([px - rad, py - rad, px + rad, py + rad],
                     fill=ACCENT + (120,))

    # Head.
    head = 11 * s
    angle = math.atan2(y1 - y0, x1 - x0)
    draw.polygon([
        (x1, y1),
        (x1 - head * math.cos(angle - 0.42), y1 - head * math.sin(angle - 0.42)),
        (x1 - head * math.cos(angle + 0.42), y1 - head * math.sin(angle + 0.42)),
    ], fill=ACCENT + (190,))
    return Image.alpha_composite(base, layer)


def centred(draw, text, font, cx, y, fill):
    w = draw.textlength(text, font=font)
    draw.text((cx - w / 2, y), text, font=font, fill=fill)


def render(scale: int):
    s = scale
    w, h = WIDTH * s, HEIGHT * s
    base = field(w, h, s)

    base = drop_ring(base, ICON_SLOTS["app"], s, dashed=False)
    base = drop_ring(base, ICON_SLOTS["applications"], s, dashed=True)
    base = arrow(base, (282, ICON_Y), (438, ICON_Y), s)

    draw = ImageDraw.Draw(base)
    cx = w // 2

    # Headline in the true system italic — the "subject" of the screen.
    head = find_font(FONT_ITALIC, round(38 * s))
    try:
        head.set_variation_by_axes([700])
    except Exception:
        pass
    centred(draw, "Utter", head, cx, round(58 * s), INK + (255,))

    sub = variable_font(FONT_TEXT, round(15 * s), 400)
    centred(draw, "Drag the app into your Applications folder",
            sub, cx, round(112 * s), INK_SECONDARY + (255,))

    # Captions above each ring, clear of the filename label Finder draws below.
    cap = variable_font(FONT_TEXT, round(11 * s), 600)
    centred(draw, "UTTER", cap, ICON_SLOTS["app"][0] * s,
            round((ICON_Y - 104) * s), INK_TERTIARY + (255,))
    centred(draw, "APPLICATIONS", cap, ICON_SLOTS["applications"][0] * s,
            round((ICON_Y - 104) * s), INK_TERTIARY + (255,))

    # One quiet line of reassurance, centred at the foot.
    foot = variable_font(FONT_TEXT, round(12 * s), 400)
    centred(draw, "Works offline  ·  No account needed  ·  Nothing is uploaded",
            foot, cx, round(408 * s), INK_TERTIARY + (255,))

    version = "dev"
    version_path = os.path.join(os.path.dirname(__file__), "..", ".version")
    if os.path.exists(version_path):
        with open(version_path) as f:
            version = f.read().strip()
    ver = find_font(["/System/Library/Fonts/Menlo.ttc"], round(10 * s))
    vt = f"v{version}"
    vw = draw.textlength(vt, font=ver)
    draw.text((w - vw - round(14 * s), round(10 * s)), vt,
              font=ver, fill=INK_TERTIARY + (170,))

    return base


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for scale, name in ((1, "dmg-background.png"), (2, "dmg-background@2x.png")):
        img = render(scale)
        out = os.path.join(OUT_DIR, name)
        img.convert("RGB").save(out, "PNG", optimize=True)
        print(f"✓ DMG background → {out} ({img.size[0]}×{img.size[1]})")
    print(f"  icon slots: app={ICON_SLOTS['app']} "
          f"applications={ICON_SLOTS['applications']}")


if __name__ == "__main__":
    sys.exit(main())
