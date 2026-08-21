#!/usr/bin/env python3
"""
Recover alpha from character art whose transparency was flattened into pixels.

Generated art arrives as JPEG with no alpha channel, and the background baked in
as real pixels. Two styles turn up, and they need opposite treatment:

  * **Checkerboard** — the familiar transparency indicator, two alternating greys
    in ~30px squares (measured: 251/206, 255/211, 254/219 across images).
  * **Solid** — one flat colour, in practice near-black (measured: 0-3).

`background_style` tells them apart by how much the border ring varies: a
checkerboard spreads 40-57 levels, a solid one 0-3. Nothing in between has been
seen, so the threshold sits in the gap rather than being tuned.

Three properties make the cut reliable rather than a guess:

  * **The background is neutral.** Its greys are R=G=B, while character art is
    saturated — orange gi, green satchel, pink cheeks. A low saturation *and* a
    near-background luminance together identify background, and a saturated pixel
    is never removed regardless of brightness.

  * **Background is connected to the border.** A flood fill inward from the edges
    only removes background that is actually outside the character. Without it, a
    white eye highlight, a panda's white face, or the white kanji roundel — all
    neutral, all bright — would be punched out from inside the figure. This is
    what makes a black-and-white character possible at all: a panda's own black is
    as dark as a black background and as light as a white one, and only its
    enclosing outline distinguishes the two.

  * **The figure is connected; decoration floats.** Generated art scatters
    sparkles, "Zzz" and question marks around the character. They survive the flood
    fill (they are saturated or enclosed), then dominate the bounding box — so the
    character is drawn small and off-centre, its framing differs per state, and
    whatever sits furthest out is clipped by the canvas. At 44pt none of it is
    legible anyway: the largest "Z" in this set renders about 4pt tall.

    Size cannot separate them — measured, a sleepy pose's smallest "z" is 0.35% of
    the body and a celebrating pose's largest sparkle is 0.32%. **Distance can.**
    A paw split off by its own dark outline sits 2-9px from the body; every piece of
    floating decoration sits 57px or more away. So the rule is proximity, not area:
    keep whatever is within `ATTACHED_GAP_FRACTION` of the figure, drop the rest.
    That keeps paws and paw-pad details (which an area rule would punch holes in)
    and discards the props, which is a real loss stated plainly rather than a
    threshold tuned until it looked right.

JPEG compression means values are not exact, so every test uses a tolerance.

Usage:
    python3 scripts/dechecker.py <in.jpeg> <out.png> [--pad 0.06] [--size 512]
"""
from __future__ import annotations

import argparse
import sys
from collections import deque

try:
    from PIL import Image, ImageFilter
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install --user Pillow")

# How far a pixel's channels may differ before it counts as coloured rather than
# grey. JPEG on a flat grey still wanders a few levels.
NEUTRAL_TOLERANCE = 26

# How far from a known checker grey a pixel may sit and still be background.
LUMINANCE_TOLERANCE = 34

# The same, for a solid background — necessarily much tighter. On a black
# background the character's own black ink measures 11 at its softest antialiased
# edge and 20-56 inside, against a background of 0-3. The checker tolerance of 34
# would eat the ears; 8 sits inside the gap and leaves the antialiased rim opaque,
# where it reads as the drawn outline.
SOLID_TOLERANCE = 8

# Border-ring spread that separates the two styles. Measured: 0-3 for solid,
# 40-57 for checkerboard.
STYLE_SPREAD_THRESHOLD = 12

# How close a detached piece must be to the figure to count as part of it,
# as a fraction of the image's longer side. 1% of 2048px = 20px, which sits in the
# measured gap between "paw split off by its outline" (2-9px) and "floating
# decoration" (57px+).
ATTACHED_GAP_FRACTION = 0.01

# How big a detached piece must be, as a fraction of the figure, before other pieces
# may reach the figure *through* it. Keeps the paw-pad chain while stopping a cloud of
# compression specks from bridging the background. A paw is 3.9% of the body; the
# specks are 0.006% and below.
CHAIN_MIN_FRACTION = 0.001


def border_samples(image: Image.Image) -> list[int]:
    """Luminance around the border ring, which is always background."""
    width, height = image.size
    px = image.load()
    samples: list[int] = []
    for x in range(0, width, 5):
        samples += [px[x, 2][0], px[x, height - 3][0]]
    for y in range(0, height, 5):
        samples += [px[2, y][0], px[width - 3, y][0]]
    return samples


def background_style(image: Image.Image) -> tuple[str, list[int]]:
    """`("solid" | "checker", values)` — the background kind and its grey(s)."""
    samples = border_samples(image)
    if not samples:
        return "checker", [242, 186]

    if max(samples) - min(samples) < STYLE_SPREAD_THRESHOLD:
        return "solid", [round(sum(samples) / len(samples))]

    # Cluster into light and dark rather than taking the two most common values:
    # JPEG spreads each grey over several levels, so the raw histogram has no clean
    # peak.
    #
    # The split point is the midpoint of the observed range, not a fixed constant.
    # These images do not agree on their checker colours — measured 242/186 on one
    # and 166/86 on another, presumably different export settings. A hard threshold
    # put both of the darker pair on the same side, so only one grey was learned and
    # half the checkerboard survived as opaque pixels.
    split = (min(samples) + max(samples)) / 2
    light = [v for v in samples if v >= split]
    dark = [v for v in samples if v < split]
    greys = []
    if light:
        greys.append(round(sum(light) / len(light)))
    if dark:
        greys.append(round(sum(dark) / len(dark)))
    return "checker", greys or [242, 186]


def is_background(pixel: tuple[int, int, int], style: str, greys: list[int]) -> bool:
    r, g, b = pixel[:3]
    if max(r, g, b) - min(r, g, b) > NEUTRAL_TOLERANCE:
        return False                     # saturated: character art
    value = (r + g + b) // 3

    if style == "solid":
        return abs(value - greys[0]) <= SOLID_TOLERANCE

    if any(abs(value - grey) <= LUMINANCE_TOLERANCE for grey in greys):
        return True
    # Also treat anything *between* the two checker greys as background. JPEG
    # ringing along the boundary between light and dark squares lands in that
    # middle band, and those pixels survived as a faint grid of lines over the
    # transparency. They are only reachable by the flood fill from outside the
    # character, so widening the test here cannot eat into the art.
    if len(greys) == 2:
        low, high = min(greys), max(greys)
        return low - LUMINANCE_TOLERANCE <= value <= high + LUMINANCE_TOLERANCE
    return False


def cut_alpha(image: Image.Image, verbose: bool = True) -> Image.Image:
    """RGBA at the source's own size: background transparent, specks removed."""
    rgb = image.convert("RGB")
    width, height = rgb.size
    px = rgb.load()
    style, greys = background_style(rgb)

    # Flood fill inward from every border pixel. Anything reached is outside the
    # character; anything enclosed by the outline is kept even when it is neutral,
    # which is what protects the eyes, the white face and the kanji roundel.
    transparent = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        index = y * width + x
        if not transparent[index] and is_background(px[x, y], style, greys):
            transparent[index] = 1
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                index = ny * width + nx
                if not transparent[index] and is_background(px[nx, ny], style, greys):
                    transparent[index] = 1
                    queue.append((nx, ny))

    dropped = drop_detached(transparent, width, height)

    out = Image.new("RGBA", (width, height))
    op = out.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            if transparent[row + x]:
                op[x, y] = (0, 0, 0, 0)
            else:
                r, g, b = px[x, y]
                op[x, y] = (r, g, b, 255)

    if verbose:
        note = f", dropped {dropped} detached piece(s)" if dropped else ""
        print(f"  background: {style} {greys}{note}")
    return out


def opaque_components(transparent: bytearray, width: int, height: int) -> list[list[int]]:
    """Every connected run of opaque pixels, largest first."""
    label = bytearray(width * height)      # 0 = unvisited, 1 = seen
    components: list[list[int]] = []

    for start in range(width * height):
        if transparent[start] or label[start]:
            continue
        pixels = [start]
        label[start] = 1
        queue = deque([start])
        while queue:
            index = queue.popleft()
            x, y = index % width, index // width
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height:
                    n = ny * width + nx
                    if not transparent[n] and not label[n]:
                        label[n] = 1
                        pixels.append(n)
                        queue.append(n)
        components.append(pixels)

    components.sort(key=len, reverse=True)
    return components


def dilated(mask: bytearray, width: int, height: int, radius: int) -> Image.Image:
    """The mask grown by `radius` pixels, as an 'L' image.

    Grown on a quarter-scale copy: a rank filter wide enough to do this in one pass
    at full size is O(radius^2) per pixel over four megapixels, and the tolerance
    being measured is 20px against a 48px separation — precision this does not need.
    """
    factor = 4
    small = (max(1, width // factor), max(1, height // factor))
    image = Image.frombytes("L", (width, height), bytes(255 if v else 0 for v in mask))
    # BOX averaging keeps any trace of the mask, which thresholding back to 255 turns
    # into a dilation of up to one small-pixel — accounted for by the passes below.
    grown = image.resize(small, Image.BOX).point(lambda v: 255 if v else 0)
    for _ in range(max(1, round(radius / factor))):
        grown = grown.filter(ImageFilter.MaxFilter(3))
    return grown.resize((width, height), Image.NEAREST)


def drop_detached(transparent: bytearray, width: int, height: int) -> int:
    """Remove every opaque component that does not touch the figure.

    Mutates `transparent` in place and returns how many components it removed. Two
    rounds, so a piece attached to a piece attached to the figure survives — a paw
    pad reaches the body through the paw, not directly.

    The second round only reaches out from pieces of real size. JPEG ringing along the
    outline leaves hundreds of specks (measured: 631 of 782 components on one image sit
    within the radius of the figure), and chaining through those bridged the whole
    background one 20px hop at a time — 151 genuinely distant pieces came back down to
    1. Requiring a piece to be `CHAIN_MIN_FRACTION` of the figure before anything can
    reach *through* it keeps the paw chain working without letting a cloud of noise
    ferry the search across the canvas.
    """
    components = opaque_components(transparent, width, height)
    if len(components) < 2:
        return 0

    radius = max(2, round(max(width, height) * ATTACHED_GAP_FRACTION))
    chainable = len(components[0]) * CHAIN_MIN_FRACTION
    kept = {0}

    for round_index in range(2):
        figure = bytearray(width * height)
        for index in kept:
            if round_index > 0 and index != 0 and len(components[index]) < chainable:
                continue
            for pixel in components[index]:
                figure[pixel] = 1
        reach = dilated(figure, width, height, radius).load()

        for index, pixels in enumerate(components):
            if index in kept:
                continue
            # Sample rather than test every pixel: a component that touches the
            # figure does so along an edge, and these are hundreds of pixels or more.
            for pixel in pixels[:: max(1, len(pixels) // 400)]:
                if reach[pixel % width, pixel // width]:
                    kept.add(index)
                    break

    dropped = 0
    for index, pixels in enumerate(components):
        if index in kept:
            continue
        for pixel in pixels:
            transparent[pixel] = 1
        dropped += 1
    return dropped


def cut(image: Image.Image, pad: float) -> Image.Image:
    """Cut, then re-pad to a square canvas so a single image stands alone.

    Pack-level work uses `cut_alpha` instead and normalises across states, which a
    per-image square cannot do: cropping each state to its own bounds and scaling
    each to the same square makes a lying-down pose as tall as a standing one, so
    the character visibly changes size when its mood changes.
    """
    out = cut_alpha(image)
    box = out.split()[3].getbbox()
    if box:
        out = out.crop(box)
    side = round(max(out.size) * (1 + pad * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # Feet sit on the floor: the app anchors squash and lean at the bottom.
    canvas.paste(
        out,
        ((side - out.width) // 2, side - out.height - round(side * pad)),
        out,
    )
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("destination")
    parser.add_argument("--pad", type=float, default=0.06)
    parser.add_argument("--size", type=int, default=512)
    args = parser.parse_args()

    image = Image.open(args.source)
    result = cut(image, args.pad)
    result = result.resize((args.size, args.size), Image.LANCZOS)
    result.save(args.destination, "PNG", optimize=True)

    alpha = result.split()[3]
    box = alpha.getbbox()
    clear = sum(1 for v in alpha.resize((80, 80)).get_flattened_data() if v < 8)
    print(f"  {args.destination}: {result.size[0]}x{result.size[1]}, "
          f"{clear / 6400 * 100:.0f}% transparent, ink {box[2] - box[0]}x{box[3] - box[1]}")


if __name__ == "__main__":
    main()
