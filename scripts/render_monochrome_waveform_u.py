#!/usr/bin/env python3
"""Build a single-color, non-neon, premium Apple HIG app icon for Utter.

Design Specifications:
- Theme: Minimalist Apple Hardware & Design.
- Symbol: The Letter 'U' IS the audio waveform — a 9-bar acoustic equalizer array with a continuous curved U-base.
- Color: Single solid crisp white (#FFFFFF) with tactile physical lighting (no neon, no glows, no multi-color).
- Plate: Dark Space Gray titanium squircle with chamfered rim and natural ambient drop shadow.
"""

import os
import sys
import math
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ICONSET = os.path.join(ROOT, "AppIcon.iconset")
SOURCE = os.path.join(ROOT, "Assets", "AppIconSource.png")
PREVIEW = os.path.join(ROOT, "docs", "assets", "app_icon_preview.png")

SIZE = 1024
SUPERSAMPLE = 4
W = SIZE * SUPERSAMPLE

PLATE_RATIO = 0.8047
CORNER_RATIO = 0.230

# Colors (Single Color White on Dark Titanium)
PLATE_TOP = (34, 38, 50)        # Dark space-gray titanium
PLATE_BOT = (16, 18, 24)        # Midnight obsidian
MARK_COLOR = (255, 255, 255)    # Single solid white

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

def make_radial_gradient(w, h, cx, cy, radius, inner_color, outer_color):
    qw, qh = w // 4, h // 4
    qimg = Image.new("RGBA", (qw, qh))
    qdraw = ImageDraw.Draw(qimg)
    qcx, qcy, qrad = cx // 4, cy // 4, radius // 4
    for y in range(qh):
        for x in range(qw):
            dx = x - qcx
            dy = y - qcy
            dist = math.sqrt(dx * dx + dy * dy)
            t = min(1.0, max(0.0, dist / qrad))
            t = t * t * (3 - 2 * t)
            r = int(inner_color[0] * (1 - t) + outer_color[0] * t)
            g = int(inner_color[1] * (1 - t) + outer_color[1] * t)
            b = int(inner_color[2] * (1 - t) + outer_color[2] * t)
            a = int(inner_color[3] * (1 - t) + outer_color[3] * t)
            qdraw.point((x, y), fill=(r, g, b, a))
    return qimg.resize((w, h), Image.Resampling.BICUBIC)

def render_monochrome_waveform_icon():
    plate_side = int(W * PLATE_RATIO)
    radius = int(plate_side * CORNER_RATIO)
    margin = (W - plate_side) // 2

    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # 1. Dual-Stage Drop Shadow (Contact + Ambient)
    amb_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    a_draw = ImageDraw.Draw(amb_shadow)
    a_off = int(W * 0.022)
    a_box = [margin, margin + a_off, margin + plate_side, margin + plate_side + a_off]
    a_draw.rounded_rectangle(a_box, radius=radius, fill=(0, 0, 0, 95))
    amb_shadow = amb_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.028)))
    canvas = Image.alpha_composite(canvas, amb_shadow)

    con_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(con_shadow)
    c_off = int(W * 0.008)
    c_box = [margin, margin + c_off, margin + plate_side, margin + plate_side + c_off]
    c_draw.rounded_rectangle(c_box, radius=radius, fill=(0, 0, 0, 140))
    con_shadow = con_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.010)))
    canvas = Image.alpha_composite(canvas, con_shadow)

    # 2. Dark Titanium Squircle Plate
    plate_grad = make_radial_gradient(
        W, W,
        cx=margin + int(plate_side * 0.35),
        cy=margin + int(plate_side * 0.28),
        radius=int(plate_side * 1.15),
        inner_color=PLATE_TOP + (255,),
        outer_color=PLATE_BOT + (255,)
    )
    plate_mask = Image.new("L", (W, W), 0)
    p_draw = ImageDraw.Draw(plate_mask)
    plate_box = [margin, margin, margin + plate_side, margin + plate_side]
    p_draw.rounded_rectangle(plate_box, radius=radius, fill=255)

    plate_surface = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    plate_surface.paste(plate_grad, (0, 0), plate_mask)

    # 1px Apple Chamfered Rim Highlight
    b_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(b_layer)
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 40), width=int(2.5 * SUPERSAMPLE))
    plate_surface = Image.alpha_composite(plate_surface, b_layer)
    canvas = Image.alpha_composite(canvas, plate_surface)

    # 3. Waveform Letter 'U' (Single Color White)
    cx = W // 2
    cy = W // 2 + int(10 * SUPERSAMPLE)

    num_bars = 9
    bar_w = int(32 * SUPERSAMPLE)       # Sturdy, premium bar width
    bar_gap = int(22 * SUPERSAMPLE)     # Refined spacing
    total_w = num_bars * bar_w + (num_bars - 1) * bar_gap
    start_x = cx - total_w // 2 + bar_w // 2

    # Amplitude Envelope for 'U'
    raw_heights = [410, 320, 200, 110, 65, 110, 200, 320, 410]
    bar_heights = [int(h * SUPERSAMPLE) for h in raw_heights]

    # 3A. Soft Drop Shadow from the Waveform onto Plate
    w_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ws_draw = ImageDraw.Draw(w_shadow)
    sh_y = int(14 * SUPERSAMPLE)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2 + sh_y
        by_bot = cy + h_bar // 2 + sh_y
        r_b = bar_w // 2
        ws_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=(0, 0, 0, 160), width=bar_w)
        ws_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=(0, 0, 0, 160))
        ws_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=(0, 0, 0, 160))

    # Bottom U-basin shadow
    basin_w = int(290 * SUPERSAMPLE)
    basin_h = int(120 * SUPERSAMPLE)
    basin_y = cy + int(145 * SUPERSAMPLE) + sh_y
    ws_draw.arc([cx - basin_w // 2, basin_y - basin_h, cx + basin_w // 2, basin_y + basin_h],
                start=20, end=160, fill=(0, 0, 0, 160), width=int(26 * SUPERSAMPLE))

    w_shadow = w_shadow.filter(ImageFilter.GaussianBlur(radius=int(9 * SUPERSAMPLE)))
    canvas = Image.alpha_composite(canvas, w_shadow)

    # 3B. Connecting Harmonic U-Basin (Solid White)
    basin_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(basin_layer)
    base_basin_y = cy + int(145 * SUPERSAMPLE)
    b_draw.arc([cx - basin_w // 2, base_basin_y - basin_h, cx + basin_w // 2, base_basin_y + basin_h],
               start=20, end=160, fill=MARK_COLOR + (255,), width=int(26 * SUPERSAMPLE))

    # 3C. Waveform Bars (Solid White with subtle directional top-down light)
    bars_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    br_draw = ImageDraw.Draw(bars_layer)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2
        by_bot = cy + h_bar // 2
        r_b = bar_w // 2

        # Draw solid white capsule bar
        br_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=MARK_COLOR + (255,), width=bar_w)
        br_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=MARK_COLOR + (255,))
        br_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=MARK_COLOR + (255,))

    # Composite basin and bars
    glyph = Image.alpha_composite(basin_layer, bars_layer)
    canvas = Image.alpha_composite(canvas, glyph)

    # 4. Master Downsample with Lanczos (Ultra-clean subpixel anti-aliasing)
    final_master = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    final_master.save(SOURCE)
    final_master.save(PREVIEW)
    print(f"✓ Single-color Waveform-U icon rendered to {SOURCE} and {PREVIEW}")

    # Generate all .iconset sizes
    os.makedirs(ICONSET, exist_ok=True)
    for px, name in VARIANTS:
        variant = final_master.resize((px, px), Image.Resampling.LANCZOS)
        variant.save(os.path.join(ICONSET, name))
    print(f"✓ Generated 10 iconset sizes in {ICONSET}")

    # Compile .icns with iconutil
    icns_path = os.path.join(ROOT, "AppIcon.icns")
    os.system(f"iconutil -c icns {ICONSET} -o {icns_path}")
    print(f"✓ Compiled AppIcon.icns ({os.path.getsize(icns_path)} bytes)")

if __name__ == "__main__":
    render_monochrome_waveform_icon()
