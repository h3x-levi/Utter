#!/usr/bin/env python3
"""Build a world-class macOS app icon for Utter.

Design Architecture:
- Authentic Apple HIG macOS squircle plate with subtle top-to-bottom gradient and tactile edge bevel.
- Bold, sculptural Letter 'U' for 'Utter' with crisp geometric precision and subtle 3D lighting.
- Witty Voice Element: An elegant 5-bar acoustic audio waveform nested inside the U curve in vibrant warm amber/coral, symbolizing voice speech and dictation.
- Clean, premium, iconic — looks stunning in the Dock at both 1024px and 16px.
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

# Colors
PLATE_TOP = (32, 36, 48)       # Deep slate blue-gray
PLATE_BOT = (18, 20, 28)       # Midnight obsidian
BEVEL_COLOR = (255, 255, 255, 30) # Subtle top glass rim highlight

GLYPH_WHITE = (255, 255, 255)
GLYPH_SHADOW = (10, 12, 18, 140)

# Warm voice accent (Amber / Coral)
ACCENT_AMBER = (255, 122, 40)
ACCENT_CORAL = (255, 90, 60)
ACCENT_LIGHT = (255, 175, 80)

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

def make_gradient_plate(w, h, top_rgb, bot_rgb):
    """Create a vertical gradient image."""
    grad = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(grad)
    for y in range(h):
        t = y / float(h)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))
    return grad

def render_master():
    plate_side = int(W * PLATE_RATIO)
    radius = int(plate_side * CORNER_RATIO)
    margin = (W - plate_side) // 2

    # Canvas
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # 1. Drop shadow behind plate
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_offset = int(W * 0.018)
    s_box = [margin, margin + s_offset, margin + plate_side, margin + plate_side + s_offset]
    s_draw.rounded_rectangle(s_box, radius=radius, fill=(0, 0, 0, 85))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.024)))
    img = Image.alpha_composite(img, shadow)

    # 2. Rounded Plate with gradient
    plate_raw = make_gradient_plate(W, W, PLATE_TOP, PLATE_BOT)
    plate_mask = Image.new("L", (W, W), 0)
    p_draw = ImageDraw.Draw(plate_mask)
    plate_box = [margin, margin, margin + plate_side, margin + plate_side]
    p_draw.rounded_rectangle(plate_box, radius=radius, fill=255)
    plate = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    plate.paste(plate_raw, (0, 0), plate_mask)

    # Subtle inner bevel stroke around plate edge
    bevel_img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bevel_img)
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 35), width=int(2.5 * SUPERSAMPLE))
    plate = Image.alpha_composite(plate, bevel_img)
    img = Image.alpha_composite(img, plate)

    # 3. Sculptural Letter "U"
    cx = W // 2
    cy = W // 2 + int(12 * SUPERSAMPLE)

    u_w = int(460 * SUPERSAMPLE)      # Outer width of U
    u_h = int(480 * SUPERSAMPLE)      # Height of U
    stem_w = int(96 * SUPERSAMPLE)    # Thickness of U stems
    r_cap = stem_w // 2

    u_top = cy - int(210 * SUPERSAMPLE)
    u_bot = u_top + u_h
    u_left = cx - u_w // 2 + r_cap
    u_right = cx + u_w // 2 - r_cap

    # Draw Glyph Soft Drop Shadow on Plate
    glyph_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gs_draw = ImageDraw.Draw(glyph_shadow)
    sh_off = int(8 * SUPERSAMPLE)

    # Shadow stems & base
    gs_draw.line([(u_left, u_top + sh_off), (u_left, u_bot - (u_w // 2 - r_cap) + sh_off)], fill=GLYPH_SHADOW, width=stem_w)
    gs_draw.line([(u_right, u_top + sh_off), (u_right, u_bot - (u_w // 2 - r_cap) + sh_off)], fill=GLYPH_SHADOW, width=stem_w)
    gs_draw.ellipse([u_left - r_cap, u_top + sh_off - r_cap, u_left + r_cap, u_top + sh_off + r_cap], fill=GLYPH_SHADOW)
    gs_draw.ellipse([u_right - r_cap, u_top + sh_off - r_cap, u_right + r_cap, u_top + sh_off + r_cap], fill=GLYPH_SHADOW)
    arc_box_sh = [u_left - r_cap, u_bot - (u_right - u_left + stem_w) + sh_off, u_right + r_cap, u_bot + sh_off]
    gs_draw.chord(arc_box_sh, start=0, end=180, fill=GLYPH_SHADOW)
    glyph_shadow = glyph_shadow.filter(ImageFilter.GaussianBlur(radius=int(6 * SUPERSAMPLE)))
    img = Image.alpha_composite(img, glyph_shadow)

    # Draw Solid White U Glyph
    glyph_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glyph_layer)

    # U Stems
    g_draw.line([(u_left, u_top), (u_left, u_bot - (u_w // 2 - r_cap))], fill=GLYPH_WHITE + (255,), width=stem_w)
    g_draw.line([(u_right, u_top), (u_right, u_bot - (u_w // 2 - r_cap))], fill=GLYPH_WHITE + (255,), width=stem_w)

    # Rounded top caps
    g_draw.ellipse([u_left - r_cap, u_top - r_cap, u_left + r_cap, u_top + r_cap], fill=GLYPH_WHITE + (255,))
    g_draw.ellipse([u_right - r_cap, u_top - r_cap, u_right + r_cap, u_top + r_cap], fill=GLYPH_WHITE + (255,))

    # Outer bottom semicircle chord
    arc_box = [u_left - r_cap, u_bot - (u_right - u_left + stem_w), u_right + r_cap, u_bot]
    g_draw.chord(arc_box, start=0, end=180, fill=GLYPH_WHITE + (255,))

    # Cut out inner hole of U to restore plate
    inner_w = u_w - 2 * stem_w
    inner_r = inner_w // 2
    inner_top = u_top
    inner_bot = u_bot - stem_w
    # Cutout with inner plate color
    g_draw.rectangle([cx - inner_r, inner_top, cx + inner_r, inner_bot - inner_r], fill=(0, 0, 0, 0))
    g_draw.ellipse([cx - inner_r, inner_bot - 2 * inner_r, cx + inner_r, inner_bot], fill=(0, 0, 0, 0))

    img = Image.alpha_composite(img, glyph_layer)

    # 4. Witty Voice Dictation Element: 5-Bar Acoustic Voice Waveform inside U
    # Nested symmetrically inside the U: [18%, 45%, 90%, 45%, 18%]
    wave_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)

    wave_center_y = cy - int(10 * SUPERSAMPLE)
    bar_w = int(24 * SUPERSAMPLE)
    bar_gap = int(28 * SUPERSAMPLE)
    bar_heights = [
        int(60 * SUPERSAMPLE),   # Far left
        int(120 * SUPERSAMPLE),  # Mid left
        int(200 * SUPERSAMPLE),  # Center peak (Voice energy)
        int(120 * SUPERSAMPLE),  # Mid right
        int(60 * SUPERSAMPLE)    # Far right
    ]
    bar_colors = [
        (255, 150, 60),
        (255, 120, 40),
        (255, 80, 40),
        (255, 120, 40),
        (255, 150, 60)
    ]

    total_wave_w = len(bar_heights) * bar_w + (len(bar_heights) - 1) * bar_gap
    start_x = cx - total_wave_w // 2 + bar_w // 2

    for i, (h_bar, col) in enumerate(zip(bar_heights, bar_colors)):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = wave_center_y - h_bar // 2
        by_bot = wave_center_y + h_bar // 2
        r_bar = bar_w // 2

        # Draw rounded vertical capsule bar
        w_draw.line([(bx, by_top + r_bar), (bx, by_bot - r_bar)], fill=col + (255,), width=bar_w)
        w_draw.ellipse([bx - r_bar, by_top, bx + r_bar, by_top + bar_w], fill=col + (255,))
        w_draw.ellipse([bx - r_bar, by_bot - bar_w, bx + r_bar, by_bot], fill=col + (255,))

    # Soft ambient glow around the voice waveform
    wave_glow = wave_layer.filter(ImageFilter.GaussianBlur(radius=int(12 * SUPERSAMPLE)))
    # Composite glow then sharp waveform
    img = Image.alpha_composite(img, wave_glow)
    img = Image.alpha_composite(img, wave_layer)

    # 5. Downsample to 1024x1024 with Lanczos for subpixel sharpness
    final_img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    final_img.save(SOURCE)
    final_img.save(PREVIEW)
    print(f"✓ Master icon rendered to {SOURCE} and {PREVIEW}")

    # Generate all .iconset sizes
    os.makedirs(ICONSET, exist_ok=True)
    for px, name in VARIANTS:
        variant = final_img.resize((px, px), Image.Resampling.LANCZOS)
        variant.save(os.path.join(ICONSET, name))
    print(f"✓ Generated 10 iconset variants in {ICONSET}")

    # Compile .icns with iconutil
    icns_path = os.path.join(ROOT, "AppIcon.icns")
    os.system(f"iconutil -c icns {ICONSET} -o {icns_path}")
    print(f"✓ Compiled AppIcon.icns ({os.path.getsize(icns_path)} bytes)")

if __name__ == "__main__":
    render_master()
