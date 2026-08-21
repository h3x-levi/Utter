#!/usr/bin/env python3
"""The props Mochi interacts with, and the shared frame helpers.

The cat itself lives in `full_body.py`. This file holds what it sits at and what rises off
it: the keyboard, the steam, and the small grid utilities both modules use.

WHAT USED TO BE HERE, AND WHY IT IS GONE
----------------------------------------
Two whole cat silhouettes were built in this file and both were removed:

  * A head-over-pear sitting shape with two small feet. Rendered and looked at, it read as
    "a blob with ears" — no visible forelegs, no paws, no nose, no mouth. Replaced by
    `full_body.py`, which draws the whole animal.
  * A dedicated LEANING silhouette for the typing pose. It leaned correctly, but it was a
    second, differently-proportioned cat — smaller head, no nose or mouth, a different body
    line — and beside the other twelve states it read as a *different animal*. The typing
    pose is now the shared cat, lifted, with its head nudged forward.

Both are deleted rather than left commented out. An unused second silhouette in the same
file is the thing that makes the next reader ask which cat is the real one.
"""
from __future__ import annotations

CANVAS = 32
T = "."


def blank():
    return [[T] * CANVAS for _ in range(CANVAS)]


def fill_span(grid, row, first, last, char):
    if not 0 <= row < CANVAS:
        return
    for x in range(max(0, first), min(CANVAS - 1, last) + 1):
        grid[row][x] = char


def shift(grid, dx=0, dy=0):
    """The whole grid moved. Used to lift a pose clear of a prop, or settle one lower."""
    out = blank()
    for y, row in enumerate(grid):
        for x, char in enumerate(row):
            if char == T:
                continue
            ny, nx = y + dy, x + dx
            if 0 <= ny < CANVAS and 0 <= nx < CANVAS:
                out[ny][nx] = char
    return out


def to_strings(grid):
    return ["".join(row) for row in grid]


# ── Eyes ──────────────────────────────────────────────────────────────────────
#
# Re-exported from `full_body`, which owns the geometry, so `pupils()` and the body frames
# cannot drift apart.
from full_body import (      # noqa: E402  — after the helpers it depends on
    EYE_TRAVEL, EYE_WHITE_H, EYE_WHITE_W, EYE_WHITE_X, EYE_WHITE_Y,
    PUPIL_H, PUPIL_W, PUPIL_X, PUPIL_Y,
)


def pupils(dx=0, dy=0, char="k"):
    """Just the pupils, on an otherwise empty canvas: this is `eyes.png`."""
    grid = blank()
    for x0 in PUPIL_X:
        for row in range(PUPIL_H):
            fill_span(grid, PUPIL_Y + dy + row, x0 + dx, x0 + dx + PUPIL_W - 1, char)
    return grid


KEY_ROWS = (26, 30)
KEY_SPANS = [(9, 15), (16, 22)]

# The forelegs, one per key, 3 wide. Centred over their keycap.
PAW_COLUMNS = (9, 19)
PAW_W = 4


def add_keyboard(grid, pressed=None, top="g", side="s"):
    """Two keycaps in front of the cat, drawn with a visible side face.

    `pressed` is the index of the one pushed down.

    The caps were flat rectangles, which read as paper rather than as keys. A keycap in the
    reference is drawn in perspective: a lighter top face, offset, over a darker side. Two
    tones and a one-pixel offset are the whole of "3D" at this size — the top face is inset
    from the left and the side shows along the bottom and right, which is the direction the
    rest of the sprite is lit from.
    """
    top_row, bottom_row = KEY_ROWS
    for index, (first, last) in enumerate(KEY_SPANS):
        down = 1 if pressed == index else 0
        # Side face fills the whole cap...
        for row in range(top_row + down, bottom_row + 1):
            fill_span(grid, row, first, last, side)
        # ...and the top face sits on it, inset right and short of the bottom, so a lip of
        # side colour shows on the left and along the base.
        for row in range(top_row + down, bottom_row - 1):
            fill_span(grid, row, first + 1, last, top)
    return grid



# ── Steam, for the overheat reaction ──────────────────────────────────────────
#
# Drawn in the keyboard's grey rather than white: measured against the two extremes the
# companion sits on, #9A948C is 2.4:1 on a white desktop and 5.6:1 on a near-black one, so
# one colour is legible on both. White steam disappears on a light wallpaper, which is where
# most of these puffs would have been invisible.
STEAM_PUFFS = [
    # (row, first column, last column) — two rising columns, one each side of the ears.
    [(3, 4, 6), (2, 3, 5), (1, 4, 6), (3, 25, 27), (2, 26, 28), (1, 25, 27)],
    [(3, 3, 5), (2, 4, 6), (1, 3, 5), (3, 26, 28), (2, 25, 27), (1, 26, 28)],
]


def add_steam(grid, phase=0, char="s"):
    """Two puffs rising either side of the head. Alternates between two phases."""
    for row, first, last in STEAM_PUFFS[phase % len(STEAM_PUFFS)]:
        fill_span(grid, row, first, last, char)
    return grid


# ── Zzz, for the sleep animation ──────────────────────────────────────────────
#
# Three actual Z glyphs, not three bars. The first version drew horizontal runs and they read
# as dashes beside the cat's head — the shape is the whole signal, and a 3x3 Z is the smallest
# grid that carries it: a top bar, one centre pixel for the diagonal, a bottom bar.
#
#   ###
#   .#.
#   ###
#
# Drawn in the eye-white tone, because on a black cat only a light mark is visible at all —
# the same constraint that decides the nose and the closed eyes.
Z_GLYPH = ["###", ".#.", "###"]

# Where each Z sits, as (top row, left column), smallest and nearest the head first. They
# climb up and to the right, which is the direction the comic convention runs.
# One row lower than the obvious placement, because `phase` lifts the whole trail by a pixel:
# starting the top Z at row 0 pushed it to row -1 on two of the four frames, where its top bar
# was clipped off the canvas and the glyph rendered as a fragment.
ZZZ_POSITIONS = [(7, 22), (4, 25), (1, 28)]


def add_zzz(grid, phase=0, char="w"):
    """Three Z's drifting up beside the head.

    `phase` lifts the whole trail by a pixel and back, so the z's rise. Four phases with the
    last matching the first, so the loop closes rather than snapping.
    """
    lift = [0, 1, 1, 0][phase % 4]
    for top, left in ZZZ_POSITIONS:
        for row_offset, row in enumerate(Z_GLYPH):
            for column_offset, cell in enumerate(row):
                if cell != "#":
                    continue
                fill_span(grid, top - lift + row_offset,
                          left + column_offset, left + column_offset, char)
    return grid
