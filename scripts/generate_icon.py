#!/usr/bin/env python3
"""Build the official Apple HIG master icon for Utter.

Master Design Architecture:
- Apple Hardware Materiality: Dark Space-Black Titanium plate with 45° studio keylight,
  continuous squircle curvature (Apple HIG 0.8047 / 0.230 metrics), and a 1px chamfered rim glint.
- The Liquid Resonance 'U': A bold, sculptural letter 'U' where the vertical stems and
  harmonic valley are constructed from 7 fluid acoustic waveform capsules that merge seamlessly
  into a weighted, continuous acoustic resonance trough.
- Single-Color Elegance: Solid crisp Apple White (#FFFFFF) with natural directional 3D lighting,
  tactile specular highlights, and ambient occlusion contact shadow.
- Fully automated: Generates Assets/AppIconSource.png, 10 iconset variants, and compiles AppIcon.icns.
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

# Colors: Dark Space Black / Titanium Plate + Crisp Apple White Glyph
PLATE_TOP = (36, 40, 52)         # Refined space black with subtle deep indigo hue
PLATE_BOT = (14, 16, 22)         # Deep obsidian shadow
MARK_WHITE = (255, 255, 255)     # Solid crisp white

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

def make_studio_plate(w, h, cx, cy, radius):
    """Generate dark space-black titanium plate with studio keylight gradient."""
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
            r = int(PLATE_TOP[0] * (1 - t) + PLATE_BOT[0] * t)
            g = int(PLATE_TOP[1] * (1 - t) + PLATE_BOT[1] * t)
            b = int(PLATE_TOP[2] * (1 - t) + PLATE_BOT[2] * t)
            qdraw.point((x, y), fill=(r, g, b, 255))
            
    return qimg.resize((w, h), Image.Resampling.BICUBIC)

def build_icon():
    plate_side = int(W * PLATE_RATIO)
    radius = int(plate_side * CORNER_RATIO)
    margin = (W - plate_side) // 2

    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # -------------------------------------------------------------------------
    # 1. Dual Physical Drop Shadows (Ambient + Contact)
    # -------------------------------------------------------------------------
    amb_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    a_draw = ImageDraw.Draw(amb_shadow)
    a_off = int(W * 0.022)
    a_box = [margin, margin + a_off, margin + plate_side, margin + plate_side + a_off]
    a_draw.rounded_rectangle(a_box, radius=radius, fill=(0, 0, 0, 100))
    amb_shadow = amb_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.028)))
    canvas = Image.alpha_composite(canvas, amb_shadow)

    con_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(con_shadow)
    c_off = int(W * 0.008)
    c_box = [margin, margin + c_off, margin + plate_side, margin + plate_side + c_off]
    c_draw.rounded_rectangle(c_box, radius=radius, fill=(0, 0, 0, 150))
    con_shadow = con_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.010)))
    canvas = Image.alpha_composite(canvas, con_shadow)

    # -------------------------------------------------------------------------
    # 2. Titanium Plate with 45° Keylight & Chamfered Bevel
    # -------------------------------------------------------------------------
    plate_img = make_studio_plate(
        W, W,
        cx=margin + int(plate_side * 0.32),
        cy=margin + int(plate_side * 0.25),
        radius=int(plate_side * 1.15)
    )
    plate_mask = Image.new("L", (W, W), 0)
    p_draw = ImageDraw.Draw(plate_mask)
    plate_box = [margin, margin, margin + plate_side, margin + plate_side]
    p_draw.rounded_rectangle(plate_box, radius=radius, fill=255)

    plate_surface = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    plate_surface.paste(plate_img, (0, 0), plate_mask)

    # 1px Apple Chamfered Rim Glint
    b_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(b_layer)
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 45), width=int(2.5 * SUPERSAMPLE))
    plate_surface = Image.alpha_composite(plate_surface, b_layer)
    canvas = Image.alpha_composite(canvas, plate_surface)

    # -------------------------------------------------------------------------
    # 3. Sculptural Waveform-U Glyph
    # -------------------------------------------------------------------------
    cx = W // 2
    cy = W // 2 + int(12 * SUPERSAMPLE)

    num_bars = 7
    bar_w = int(42 * SUPERSAMPLE)       # Stately, solid Apple bar width
    bar_gap = int(24 * SUPERSAMPLE)     # Precision spacing
    total_w = num_bars * bar_w + (num_bars - 1) * bar_gap
    start_x = cx - total_w // 2 + bar_w // 2

    # Natural acoustic harmonic envelope forming the letter 'U':
    # Outer stems tall (430), mid bars (240), inner valley (130), center trough (75)
    raw_heights = [440, 260, 130, 80, 130, 260, 440]
    bar_heights = [int(h * SUPERSAMPLE) for h in raw_heights]

    # 3A. Ambient Occlusion Drop Shadow cast by the Glyph onto the Plate
    w_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ws_draw = ImageDraw.Draw(w_shadow)
    sh_y = int(14 * SUPERSAMPLE)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2 + sh_y
        by_bot = cy + h_bar // 2 + sh_y
        r_b = bar_w // 2
        ws_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=(0, 0, 0, 170), width=bar_w)
        ws_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=(0, 0, 0, 170))
        ws_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=(0, 0, 0, 170))

    # Base U-Trough Shadow
    basin_w = int(320 * SUPERSAMPLE)
    basin_h = int(140 * SUPERSAMPLE)
    basin_y = cy + int(145 * SUPERSAMPLE) + sh_y
    ws_draw.arc([cx - basin_w // 2, basin_y - basin_h, cx + basin_w // 2, basin_y + basin_h],
                start=15, end=165, fill=(0, 0, 0, 170), width=int(32 * SUPERSAMPLE))

    w_shadow = w_shadow.filter(ImageFilter.GaussianBlur(radius=int(10 * SUPERSAMPLE)))
    canvas = Image.alpha_composite(canvas, w_shadow)

    # 3B. Connecting Harmonic U-Basin (Continuous weighted base)
    basin_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(basin_layer)
    base_basin_y = cy + int(145 * SUPERSAMPLE)
    b_draw.arc([cx - basin_w // 2, base_basin_y - basin_h, cx + basin_w // 2, base_basin_y + basin_h],
               start=15, end=165, fill=MARK_WHITE + (255,), width=int(32 * SUPERSAMPLE))

    # 3C. Main Waveform Bars (Solid White with directional 3D specular highlight)
    bars_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    br_draw = ImageDraw.Draw(bars_layer)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2
        by_bot = cy + h_bar // 2
        r_b = bar_w // 2

        # Draw solid white capsule bar
        br_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=MARK_WHITE + (255,), width=bar_w)
        br_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=MARK_WHITE + (255,))
        br_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=MARK_WHITE + (255,))

    # 3D Specular Highlight on Left Ridge of Outer Stems
    spec_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sp_draw = ImageDraw.Draw(spec_layer)
    for idx in [0, 6]: # Outer left and outer right stems
        bx = start_x + idx * (bar_w + bar_gap)
        h_bar = bar_heights[idx]
        sp_draw.line([(bx - int(6 * SUPERSAMPLE), cy - h_bar // 2 + int(16 * SUPERSAMPLE)),
                      (bx - int(6 * SUPERSAMPLE), cy + h_bar // 2 - int(16 * SUPERSAMPLE))],
                     fill=(255, 255, 255, 130), width=int(8 * SUPERSAMPLE))

    spec_layer = spec_layer.filter(ImageFilter.GaussianBlur(radius=int(3 * SUPERSAMPLE)))

    # Composite Glyph Layers
    glyph = Image.alpha_composite(basin_layer, bars_layer)
    glyph = Image.alpha_composite(glyph, spec_layer)
    canvas = Image.alpha_composite(canvas, glyph)

    # -------------------------------------------------------------------------
    # 4. Master Downsample with Lanczos (Subpixel Sharpness)
    # -------------------------------------------------------------------------
    final_master = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    final_master.save(SOURCE)
    final_master.save(PREVIEW)
    print(f"✓ Official master icon saved to {SOURCE} and {PREVIEW}")

    # Export .iconset
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
    build_icon()
