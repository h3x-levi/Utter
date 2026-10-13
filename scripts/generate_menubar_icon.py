#!/usr/bin/env python3
"""Build a crisp, high-visibility native macOS menu-bar template icon for Utter.

Key Requirements for macOS Menu Bar Templates:
1. 100% Transparent Background: Zero background fill, plate, or shadow.
2. 100% Opaque Pure Glyph: Black/White RGB with full alpha (255) on strokes so macOS
   can dynamically tint it (crisp white on dark menu bars, crisp black on light menu bars,
   and accent color when clicked).
3. Pixel-Aligned Razor Sharpness: 18x18px (@1x) and 36x36px (@2x) rendered with 4x supersampling.
"""

import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "MenuBarIcon")

BASE_SIZE = 18
SUPERSAMPLE = 4

def render_menubar_template(target_size):
    """Render the app icon's bars as a template image for the menu bar."""
    W = target_size * SUPERSAMPLE
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = W // 2
    cy = W // 2

    # Scale geometry based on target size
    scale = target_size / BASE_SIZE
    
    # The app icon's five small-size bars
    bar_w = int(2.0 * scale * SUPERSAMPLE)
    bar_gap = int(1.4 * scale * SUPERSAMPLE)
    num_bars = 5
    
    raw_heights = [11, 14, 9, 14, 11]
    bar_heights = [int(h * scale * SUPERSAMPLE) for h in raw_heights]
    
    total_w = num_bars * bar_w + (num_bars - 1) * bar_gap
    start_x = cx - total_w // 2 + bar_w // 2

    # Draw vertical capsule bars (Pure Black RGB, 255 Alpha for macOS Template Tinting)
    INK = (0, 0, 0, 255)

    for i, h_bar in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        by_top = cy - h_bar // 2
        by_bot = cy + h_bar // 2
        r_b = bar_w // 2
        
        draw.line([(bx, by_top + r_b), (bx, by_bot - r_b)], fill=INK, width=bar_w)
        draw.ellipse([bx - r_b, by_top, bx + r_b, by_top + bar_w], fill=INK)
        draw.ellipse([bx - r_b, by_bot - bar_w, bx + r_b, by_bot], fill=INK)

    # Downsample with Lanczos for subpixel antialiasing
    final_img = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_img

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    for scale, name in ((1, "menubar-icon.png"), (2, "menubar-icon@2x.png")):
        size = BASE_SIZE * scale
        icon = render_menubar_template(size)
        out_path = os.path.join(OUT_DIR, name)
        icon.save(out_path, "PNG", optimize=True)
        print(f"✓ Menu bar icon → {os.path.relpath(out_path, ROOT)} ({size}x{size}, 100% opaque template)")

if __name__ == "__main__":
    main()
