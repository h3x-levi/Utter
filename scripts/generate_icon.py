#!/usr/bin/env python3
"""Draw Utter's app icon: seven bars on chrome tape, cut from the island's red, gold and blue stripe.

  python3 scripts/generate_icon.py   Assets/AppIconSource.png, AppIcon.iconset and AppIcon.icns

Every size is drawn, not downsampled: at 64 px and below edges snap to whole pixels,
the sheen drops out below 128 and the 16 px icon keeps five bars so it stays crisp.
"""

import math
import os
import subprocess

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANVAS = 4096
BODY = 824.0

RED = (226, 70, 59)
GOLD = (241, 182, 50)
BLUE = (142, 160, 224)
TAPE_TOP = (34, 37, 46)
TAPE_BOT = (15, 17, 21)
WHITE = (255, 255, 255)
BARS = [6, 11, 14, 9, 14, 11, 6]

ICONSET = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"), (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"), (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"), (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]


class Grid:
    """Body units (0..824 across the icon body) to canvas pixels, snapped at small sizes."""

    def __init__(self, px):
        self.px = px
        self.k = CANVAS / px
        side = {16: 14, 32: 26, 64: 52, 128: 104}.get(px, BODY * px / 1024)
        self.m = (px - side) / 2
        self.p = side / BODY
        self.snap = px <= 64

    def t(self, v):
        return self.m + v * self.p

    def __call__(self, v):
        t = self.t(v)
        return (round(t) if self.snap else t) * self.k

    def len(self, v):
        return v * self.p * self.k

    def box(self):
        return [self(0), self(0), self(BODY), self(BODY)]


def squircle(box, n=5.0, steps=2048):
    x0, y0, x1, y1 = box
    cx, cy, a, b = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    pts = []
    for i in range(steps):
        c, s = math.cos(2 * math.pi * i / steps), math.sin(2 * math.pi * i / steps)
        pts.append((cx + a * math.copysign(abs(c) ** (2 / n), c), cy + b * math.copysign(abs(s) ** (2 / n), s)))
    return pts


def polygon_mask(pts, alpha=1.0, dy=0.0, blur=0.0):
    """Coverage mask of a polygon; blurred masks are built at quarter size, which a soft edge cannot show."""
    s = 4 if blur else 1
    m = Image.new("L", (CANVAS // s, CANVAS // s), 0)
    ImageDraw.Draw(m).polygon([(x / s, (y + dy) / s) for x, y in pts], fill=int(255 * alpha))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(max(blur / s, 0.3))).resize((CANVAS, CANVAS), Image.BICUBIC)
    return m


def tape(g):
    """Vertical chrome gradient with a faint grain at sizes large enough to show it."""
    size = (CANVAS, CANVAS)
    img = Image.composite(Image.new("RGB", size, TAPE_BOT), Image.new("RGB", size, TAPE_TOP),
                          Image.linear_gradient("L").resize(size, Image.BICUBIC))
    if g.px < 256:
        return img
    grain = Image.effect_noise((CANVAS // 4, CANVAS // 4), 1.2).resize(size, Image.BICUBIC).convert("RGB")
    return ImageChops.add(img, grain, offset=-128)


def bar_columns(g, n, width, gap, cx):
    """Left edges and width (canvas px) for n bars centred on body x cx."""
    if g.snap:
        w = max(1, round(width * g.p))
        s = w + max(1, round(gap * g.p))
        left = round(g.t(cx) - ((n - 1) * s + w) / 2)
        return [(left + i * s) * g.k for i in range(n)], w * g.k
    w, s = g.len(width), g.len(width + gap)
    left = g(cx) - ((n - 1) * s + w) / 2
    return [left + i * s for i in range(n)], w


def bar(d, x, w, cy, h, fill, g):
    """Vertical capsule of height h (canvas px) centred on canvas y cy."""
    if g.snap:
        hp = max(round(h / g.k), round(w / g.k))
        top, h = round(cy / g.k - hp / 2) * g.k, hp * g.k
    else:
        top = cy - h / 2
    h = max(h, w)
    d.rounded_rectangle([x, top, x + w, top + h], radius=w / 2, fill=fill + (255,))


def finish(content, g, rim=(255, 255, 255, 30)):
    """Clip content to the squircle body and lay it on the soft macOS drop shadow."""
    body = squircle(g.box())
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for dy, blur, alpha in ((0.010, 0.018, 0.30), (0.003, 0.004, 0.20)):
        out.paste((0, 0, 0, 255), (0, 0), polygon_mask(body, alpha, dy * CANVAS, blur * CANVAS))
    if g.px >= 64:
        ImageDraw.Draw(content, "RGBA").line(body + body[:1], fill=rim, width=int(max(3.2 * g.p * g.k, 1.2 * g.k)))
    layer = content.convert("RGBA")
    layer.putalpha(polygon_mask(body))
    out = Image.alpha_composite(out, layer)
    return out.resize((g.px, g.px), Image.BOX if g.px <= 128 else Image.LANCZOS)


def icon(px):
    g = Grid(px)
    img = tape(g)
    if g.px >= 128:
        sheen = squircle([g(-260), g(-420), g(700), g(240)], n=2)
        img.paste(WHITE, (0, 0), polygon_mask(sheen, 0.07, 0, g.len(120)))
    d = ImageDraw.Draw(img, "RGBA")
    heights, colors = BARS, [RED] * 5 + [GOLD, BLUE]
    if g.px == 16:
        heights, colors = [11, 14, 9, 14, 11], [RED] * 3 + [GOLD, BLUE]
    xs, w = bar_columns(g, len(heights), 56, 36, 412)
    for x, h, color in zip(xs, heights, colors):
        bar(d, x, w, g(412), g.len(470) * h / 14, color, g)
    return finish(img, g)


if __name__ == "__main__":
    renders = {px: icon(px) for px in sorted({px for px, _ in ICONSET})}
    renders[1024].save(os.path.join(ROOT, "Assets", "AppIconSource.png"))
    iconset = os.path.join(ROOT, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for px, name in ICONSET:
        renders[px].save(os.path.join(iconset, name))
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(ROOT, "AppIcon.icns")], check=True)
    print("Icon: Assets/AppIconSource.png, AppIcon.iconset, AppIcon.icns")
