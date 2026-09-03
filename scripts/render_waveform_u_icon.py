#!/usr/bin/env python3
"""Build an Apple-grade icon where the letter 'U' IS the audio waveform.

Concept:
An array of 9 precision acoustic waveform bars whose amplitude envelope and
connecting continuous harmonic base form the sculptural letter 'U'.
Rendered on an authentic Apple dark titanium squircle with studio keylight,
tactile chamfered rim, and signature Voice Memos coral-to-amber lighting.
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

def render_waveform_u():
    plate_side = int(W * PLATE_RATIO)
    radius = int(plate_side * CORNER_RATIO)
    margin = (W - plate_side) // 2

    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # 1. Ambient & Contact Drop Shadows
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

    # 2. Dark Titanium Plate
    plate_grad = make_radial_gradient(
        W, W,
        cx=margin + int(plate_side * 0.3),
        cy=margin + int(plate_side * 0.25),
        radius=int(plate_side * 1.1),
        inner_color=(36, 40, 52, 255),
        outer_color=(14, 16, 22, 255)
    )
    plate_mask = Image.new("L", (W, W), 0)
    p_draw = ImageDraw.Draw(plate_mask)
    plate_box = [margin, margin, margin + plate_side, margin + plate_side]
    p_draw.rounded_rectangle(plate_box, radius=radius, fill=255)

    plate_surface = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    plate_surface.paste(plate_grad, (0, 0), plate_mask)

    # Chamfered rim highlight
    bevel_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bevel_layer)
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 45), width=int(2.5 * SUPERSAMPLE))
    plate_surface = Image.alpha_composite(plate_surface, bevel_layer)
    canvas = Image.alpha_composite(canvas, plate_surface)

    # 3. Waveform Letter "U"
    # An 11-bar harmonic waveform envelope shaped like the letter U
    cx = W // 2
    cy = W // 2 + int(10 * SUPERSAMPLE)

    num_bars = 9
    bar_w = int(28 * SUPERSAMPLE)
    bar_gap = int(24 * SUPERSAMPLE)
    total_w = num_bars * bar_w + (num_bars - 1) * bar_gap
    start_x = cx - total_w // 2 + bar_w // 2

    # Heights of 9 bars forming the letter 'U' (valley in center, high on outer stems)
    # [380, 290, 180, 95, 60, 95, 180, 290, 380]
    raw_heights = [390, 310, 195, 110, 70, 110, 195, 310, 390]
    bar_heights = [int(h * SUPERSAMPLE) for h in raw_heights]

    # Gradient colors: Electric Coral to Radiant Amber to Sunlight Gold
    # Left stem -> Valley (warm core) -> Right stem
    palette = [
        (255, 60, 50),   # 0: Outer left Coral
        (255, 95, 45),   # 1: Mid left
        (255, 140, 40),  # 2: Inner left Amber
        (255, 180, 50),  # 3: Low left Gold
        (255, 215, 80),  # 4: Valley Center (Warm peak light)
        (255, 180, 50),  # 5: Low right Gold
        (255, 140, 40),  # 6: Inner right Amber
        (255, 95, 45),   # 7: Mid right
        (255, 60, 50)    # 8: Outer right Coral
    ]

    # 3A. Waveform Drop Shadow on Plate
    wave_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ws_draw = ImageDraw.Draw(wave_shadow)
    sh_y = int(12 * SUPERSAMPLE)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2 + sh_y
        by_bot = cy + h_bar // 2 + sh_y
        r_b = bar_w // 2
        ws_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=(0, 0, 0, 150), width=bar_w)
        ws_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=(0, 0, 0, 150))
        ws_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=(0, 0, 0, 150))

    # Also shadow for connecting bottom U-basin
    basin_y = cy + int(145 * SUPERSAMPLE) + sh_y
    basin_w = int(280 * SUPERSAMPLE)
    basin_h = int(110 * SUPERSAMPLE)
    ws_draw.arc([cx - basin_w//2, basin_y - basin_h, cx + basin_w//2, basin_y + basin_h],
                start=20, end=160, fill=(0, 0, 0, 150), width=int(26 * SUPERSAMPLE))

    wave_shadow = wave_shadow.filter(ImageFilter.GaussianBlur(radius=int(10 * SUPERSAMPLE)))
    canvas = Image.alpha_composite(canvas, wave_shadow)

    # 3B. Connecting Harmonic Base Ribbon (ties the waveform into an unmistakable 'U')
    basin_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(basin_layer)
    base_basin_y = cy + int(145 * SUPERSAMPLE)
    b_draw.arc([cx - basin_w//2, base_basin_y - basin_h, cx + basin_w//2, base_basin_y + basin_h],
               start=20, end=160, fill=(255, 140, 40, 255), width=int(24 * SUPERSAMPLE))

    # 3C. Main Waveform Bars Layer
    wave_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)

    for i, (h_bar, col) in enumerate(zip(bar_heights, palette)):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2
        by_bot = cy + h_bar // 2
        r_b = bar_w // 2

        # Outer capsule
        w_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=col + (255,), width=bar_w)
        w_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=col + (255,))
        w_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=col + (255,))

        # Inner 3D specular light filament
        core_w = int(8 * SUPERSAMPLE)
        core_h = int(h_bar * 0.70)
        c_top = cy - core_h // 2
        c_bot = cy + core_h // 2
        w_draw.line([(bx, c_top), (bx, c_bot)], fill=(255, 250, 230, 210), width=core_w)
        w_draw.ellipse([bx - core_w//2, c_top - core_w//2, bx + core_w//2, c_top + core_w//2], fill=(255, 255, 255, 220))
        w_draw.ellipse([bx - core_w//2, c_bot - core_w//2, bx + core_w//2, c_bot + core_w//2], fill=(255, 255, 255, 220))

    # 3D Soft Volumetric Glow & Bloom
    combined_wave = Image.alpha_composite(basin_layer, wave_layer)
    wave_glow_wide = combined_wave.filter(ImageFilter.GaussianBlur(radius=int(26 * SUPERSAMPLE)))
    wave_glow_tight = combined_wave.filter(ImageFilter.GaussianBlur(radius=int(8 * SUPERSAMPLE)))

    canvas = Image.alpha_composite(canvas, wave_glow_wide)
    canvas = Image.alpha_composite(canvas, wave_glow_tight)
    canvas = Image.alpha_composite(canvas, combined_wave)

    # 4. Master Downsample with Lanczos
    final_master = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    final_master.save(SOURCE)
    final_master.save(PREVIEW)
    print(f"✓ Master Waveform-U icon rendered to {SOURCE} and {PREVIEW}")

    # Generate all .iconset sizes
    os.makedirs(ICONSET, exist_ok=True)
    for px, name in VARIANTS:
        variant = final_master.resize((px, px), Image.Resampling.LANCZOS)
        variant.save(os.path.join(ICONSET, name))
    print(f"✓ Generated 10 iconset sizes in {ICONSET}")

    # Compile .icns
    icns_path = os.path.join(ROOT, "AppIcon.icns")
    os.system(f"iconutil -c icns {ICONSET} -o {icns_path}")
    print(f"✓ Compiled AppIcon.icns ({os.path.getsize(icns_path)} bytes)")

if __name__ == "__main__":
    render_waveform_u()
