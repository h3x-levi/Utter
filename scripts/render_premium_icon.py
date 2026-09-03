#!/usr/bin/env python3
"""Build a premium Apple HIG macOS app icon for Utter.

Design Philosophy:
- Tangible Apple Materiality: Dark titanium squircle plate with subtle studio keylight and 1px chamfered edge bevel.
- 3D Sculptural Letter 'U': Ceramic white / liquid glass physical letter with natural top-left lighting, directional highlights, and soft ambient occlusion.
- Signature Apple Voice Ribbon: An illuminated 7-bar acoustic waveform glowing in Apple's signature Coral/Amber voice spectrum (Voice Memos & Logic Pro style).
- Optical Refraction & Depth: Micro-glow reflecting off the inner walls of the U.
"""

import os
import sys
import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

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
    """Create a smooth radial gradient surface."""
    img = Image.new("RGBA", (w, h))
    # Render at quarter size and upscale for performance
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
            # Smoothstep interpolation
            t = t * t * (3 - 2 * t)
            r = int(inner_color[0] * (1 - t) + outer_color[0] * t)
            g = int(inner_color[1] * (1 - t) + outer_color[1] * t)
            b = int(inner_color[2] * (1 - t) + outer_color[2] * t)
            a = int(inner_color[3] * (1 - t) + outer_color[3] * t)
            qdraw.point((x, y), fill=(r, g, b, a))
            
    return qimg.resize((w, h), Image.Resampling.BICUBIC)

def render_apple_icon():
    plate_side = int(W * PLATE_RATIO)
    radius = int(plate_side * CORNER_RATIO)
    margin = (W - plate_side) // 2

    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # =========================================================================
    # LAYER 1: Ambient & Contact Drop Shadows
    # =========================================================================
    # Diffuse ambient shadow
    amb_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    a_draw = ImageDraw.Draw(amb_shadow)
    a_off = int(W * 0.022)
    a_box = [margin, margin + a_off, margin + plate_side, margin + plate_side + a_off]
    a_draw.rounded_rectangle(a_box, radius=radius, fill=(0, 0, 0, 95))
    amb_shadow = amb_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.028)))
    canvas = Image.alpha_composite(canvas, amb_shadow)

    # Tight contact shadow
    con_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(con_shadow)
    c_off = int(W * 0.008)
    c_box = [margin, margin + c_off, margin + plate_side, margin + plate_side + c_off]
    c_draw.rounded_rectangle(c_box, radius=radius, fill=(0, 0, 0, 140))
    con_shadow = con_shadow.filter(ImageFilter.GaussianBlur(radius=int(W * 0.010)))
    canvas = Image.alpha_composite(canvas, con_shadow)

    # =========================================================================
    # LAYER 2: Titanium Squircle Plate with Studio Keylight
    # =========================================================================
    # Background gradient plate (Top-left keylight #2C3040 to bottom-right #12141A)
    plate_grad = make_radial_gradient(
        W, W,
        cx=margin + int(plate_side * 0.3),
        cy=margin + int(plate_side * 0.25),
        radius=int(plate_side * 1.1),
        inner_color=(42, 47, 62, 255),
        outer_color=(15, 17, 23, 255)
    )

    # Mask to squircle
    plate_mask = Image.new("L", (W, W), 0)
    p_draw = ImageDraw.Draw(plate_mask)
    plate_box = [margin, margin, margin + plate_side, margin + plate_side]
    p_draw.rounded_rectangle(plate_box, radius=radius, fill=255)

    plate_surface = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    plate_surface.paste(plate_grad, (0, 0), plate_mask)

    # Tactile Chamfered Bevel: 1px top highlight, dark bottom rim
    bevel_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bevel_layer)
    # Inner light rim
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 45), width=int(2.5 * SUPERSAMPLE))
    # Top-only specular glint
    glint_box = [margin + int(2 * SUPERSAMPLE), margin + int(2 * SUPERSAMPLE),
                 margin + plate_side - int(2 * SUPERSAMPLE), margin + int(plate_side * 0.45)]
    b_draw.rounded_rectangle(plate_box, radius=radius, outline=(255, 255, 255, 75), width=int(1.2 * SUPERSAMPLE))

    plate_surface = Image.alpha_composite(plate_surface, bevel_layer)
    canvas = Image.alpha_composite(canvas, plate_surface)

    # =========================================================================
    # LAYER 3: 3D Sculptural Letter "U" (Ceramic White + Liquid Glass)
    # =========================================================================
    cx = W // 2
    cy = W // 2 + int(10 * SUPERSAMPLE)

    u_w = int(470 * SUPERSAMPLE)      # Width of U
    u_h = int(490 * SUPERSAMPLE)      # Height of U
    stem_w = int(100 * SUPERSAMPLE)   # Stem thickness
    r_cap = stem_w // 2

    u_top = cy - int(215 * SUPERSAMPLE)
    u_bot = u_top + u_h
    u_left = cx - u_w // 2 + r_cap
    u_right = cx + u_w // 2 - r_cap

    # 3A. Deep Ambient Occlusion Drop Shadow cast by U onto the plate
    u_shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    us_draw = ImageDraw.Draw(u_shadow)
    sh_y = int(14 * SUPERSAMPLE)

    us_draw.line([(u_left, u_top + sh_y), (u_left, u_bot - (u_w // 2 - r_cap) + sh_y)], fill=(0, 0, 0, 160), width=stem_w)
    us_draw.line([(u_right, u_top + sh_y), (u_right, u_bot - (u_w // 2 - r_cap) + sh_y)], fill=(0, 0, 0, 160), width=stem_w)
    us_draw.ellipse([u_left - r_cap, u_top + sh_y - r_cap, u_left + r_cap, u_top + sh_y + r_cap], fill=(0, 0, 0, 160))
    us_draw.ellipse([u_right - r_cap, u_top + sh_y - r_cap, u_right + r_cap, u_top + sh_y + r_cap], fill=(0, 0, 0, 160))
    arc_box_sh = [u_left - r_cap, u_bot - (u_right - u_left + stem_w) + sh_y, u_right + r_cap, u_bot + sh_y]
    us_draw.chord(arc_box_sh, start=0, end=180, fill=(0, 0, 0, 160))
    u_shadow = u_shadow.filter(ImageFilter.GaussianBlur(radius=int(9 * SUPERSAMPLE)))
    canvas = Image.alpha_composite(canvas, u_shadow)

    # 3B. Solid White 3D Ceramic U Base Layer
    u_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    u_draw = ImageDraw.Draw(u_layer)

    # Left & Right Stems
    u_draw.line([(u_left, u_top), (u_left, u_bot - (u_w // 2 - r_cap))], fill=(255, 255, 255, 255), width=stem_w)
    u_draw.line([(u_right, u_top), (u_right, u_bot - (u_w // 2 - r_cap))], fill=(255, 255, 255, 255), width=stem_w)

    # Top Rounded Caps
    u_draw.ellipse([u_left - r_cap, u_top - r_cap, u_left + r_cap, u_top + r_cap], fill=(255, 255, 255, 255))
    u_draw.ellipse([u_right - r_cap, u_top - r_cap, u_right + r_cap, u_top + r_cap], fill=(255, 255, 255, 255))

    # Bottom Outer Arc Chord
    arc_box = [u_left - r_cap, u_bot - (u_right - u_left + stem_w), u_right + r_cap, u_bot]
    u_draw.chord(arc_box, start=0, end=180, fill=(255, 255, 255, 255))

    # Inner cutout of U
    inner_w = u_w - 2 * stem_w
    inner_r = inner_w // 2
    inner_top = u_top
    inner_bot = u_bot - stem_w
    u_draw.rectangle([cx - inner_r, inner_top, cx + inner_r, inner_bot - inner_r], fill=(0, 0, 0, 0))
    u_draw.ellipse([cx - inner_r, inner_bot - 2 * inner_r, cx + inner_r, inner_bot], fill=(0, 0, 0, 0))

    # 3C. 3D Bevel & Cylindrical Top Highlight on the U Glyph
    u_bevel = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ub_draw = ImageDraw.Draw(u_bevel)
    # Bright specular line along left stem & outer curve
    spec_w = int(22 * SUPERSAMPLE)
    spec_offset = int(18 * SUPERSAMPLE)
    ub_draw.line([(u_left - spec_offset, u_top), (u_left - spec_offset, u_bot - (u_w // 2))],
                 fill=(255, 255, 255, 120), width=spec_w)
    ub_draw.line([(u_right - spec_offset, u_top), (u_right - spec_offset, u_bot - (u_w // 2))],
                 fill=(255, 255, 255, 90), width=spec_w)
    u_bevel = u_bevel.filter(ImageFilter.GaussianBlur(radius=int(6 * SUPERSAMPLE)))

    # Composite U Base & Highlight
    u_layer = Image.alpha_composite(u_layer, u_bevel)
    canvas = Image.alpha_composite(canvas, u_layer)

    # =========================================================================
    # LAYER 4: The Illuminated Voice Spectrum Ribbon (Voice Memos / Logic Pro)
    # =========================================================================
    wave_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)

    wave_cy = cy - int(8 * SUPERSAMPLE)
    bar_w = int(22 * SUPERSAMPLE)
    bar_gap = int(22 * SUPERSAMPLE)

    # 7 Symmetrical Acoustic Waveform Heights (Harmonic curve)
    bar_heights = [
        int(55 * SUPERSAMPLE),   # 1. Outer left
        int(95 * SUPERSAMPLE),   # 2. Mid left
        int(150 * SUPERSAMPLE),  # 3. Inner left
        int(220 * SUPERSAMPLE),  # 4. Center Peak (Maximum vocal resonance)
        int(150 * SUPERSAMPLE),  # 5. Inner right
        int(95 * SUPERSAMPLE),   # 6. Mid right
        int(55 * SUPERSAMPLE)    # 7. Outer right
    ]

    # Apple Voice Memos Gradient Palette: Electric Coral (#FF3B30) -> Vibrant Amber (#FF9500)
    bar_colors = [
        (255, 155, 60),
        (255, 130, 45),
        (255, 95, 40),
        (255, 60, 45),   # Deep coral peak
        (255, 95, 40),
        (255, 130, 45),
        (255, 155, 60)
    ]

    total_w = len(bar_heights) * bar_w + (len(bar_heights) - 1) * bar_gap
    start_x = cx - total_w // 2 + bar_w // 2

    for i, (h_bar, col) in enumerate(zip(bar_heights, bar_colors)):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = wave_cy - h_bar // 2
        by_bot = wave_cy + h_bar // 2
        r_b = bar_w // 2

        # Draw capsule bar with solid vibrant color
        w_draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=col + (255,), width=bar_w)
        w_draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=col + (255,))
        w_draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=col + (255,))

        # Inner bright core highlight (gives 3D physical illumination)
        core_w = int(7 * SUPERSAMPLE)
        core_h = int(h_bar * 0.65)
        core_top = wave_cy - core_h // 2
        core_bot = wave_cy + core_h // 2
        w_draw.line([(bx, core_top), (bx, core_bot)], fill=(255, 235, 200, 200), width=core_w)

    # Volumetric Optical Glow
    wave_glow_wide = wave_layer.filter(ImageFilter.GaussianBlur(radius=int(22 * SUPERSAMPLE)))
    wave_glow_tight = wave_layer.filter(ImageFilter.GaussianBlur(radius=int(8 * SUPERSAMPLE)))

    canvas = Image.alpha_composite(canvas, wave_glow_wide)
    canvas = Image.alpha_composite(canvas, wave_glow_tight)
    canvas = Image.alpha_composite(canvas, wave_layer)

    # =========================================================================
    # LAYER 5: Downsample & Export Master
    # =========================================================================
    final_master = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
    final_master.save(SOURCE)
    final_master.save(PREVIEW)
    print(f"✓ Master Apple-design icon saved to {SOURCE} and {PREVIEW}")

    # Export .iconset
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
    render_apple_icon()
