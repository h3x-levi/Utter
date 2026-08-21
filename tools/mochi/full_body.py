"""A full-body sitting cat: head, ears, face, torso, four legs, paws and tail.

WHY THIS REPLACES THE PEAR
--------------------------
The first silhouette was a head over a pear-shaped body with two small feet. Rendered and
looked at, it read as "a blob with ears": no visible front legs, no paws, no nose, no mouth.
Every one of those is a feature the eye uses to say "cat", and at 32px there is room for all
of them — a 32x32 canvas is generous by 8-bit standards.

WHAT MAKES THE LEGS VISIBLE
---------------------------
The forelegs sit in FRONT of the torso, in the same fur colour, so they are invisible unless
something separates them. The outer outline pass cannot help: it only marks pixels adjacent to
transparency, and these are interior. So the separators are drawn explicitly — a 1px edge-tone
line down each leg's sides (its paw's own outer columns, run up the leg), and the paws are drawn
one pixel WIDER than the leg so the ankle reads. That is the whole trick.

WHAT READS ON A BLACK CAT
-------------------------
Only light features. A dark nose or mouth on #170000 fur is invisible — the same defect that
hid three states' closed eyes. So the nose is pink and the mouth is a light line.
"""

CANVAS = 32
T = "."

# ── Ears ──────────────────────────────────────────────────────────────────────
# Triangles with a notch between them. The notch is what makes them ears rather than a
# lumpy head, and it has to survive at 2x — 6 columns wide.
EARS = {
    1: [(9, 11), (20, 22)],
    2: [(8, 12), (19, 23)],
    3: [(8, 13), (18, 23)],
}

# ── Head ──────────────────────────────────────────────────────────────────────
# Rows 4-15, widest at the eye line. Wider than the torso, which is the chibi proportion
# that reads as a cat rather than as a dog.
HEAD = {
    4: (8, 23), 5: (7, 24), 6: (6, 25), 7: (6, 25),
    8: (6, 25), 9: (6, 25), 10: (6, 25), 11: (6, 25),
    12: (6, 25), 13: (7, 24), 14: (8, 23), 15: (10, 21),
}

# ── Torso ─────────────────────────────────────────────────────────────────────
# Narrower than the head at the shoulders (row 16-17) so there is a visible neck, then
# flaring to the haunches.
TORSO = {
    16: (12, 19), 17: (11, 20), 18: (10, 21), 19: (9, 22),
    20: (8, 23), 21: (8, 23), 22: (7, 24), 23: (7, 24),
    24: (7, 24), 25: (8, 23), 26: (9, 22),
}

# ── Legs ──────────────────────────────────────────────────────────────────────
# Forelegs hang in front of the torso and continue past it, so they are seen against the
# background below the body as well as separated from it above.
FORELEG_ROWS = (20, 27)
FORELEGS = [(11, 14), (17, 20)]
# Paws are a pixel wider each side than the leg, which is what makes an ankle.
PAW_ROWS = (28, 29)
PAWS = [(10, 15), (16, 21)]

# Hind paws, splayed either side — the pose a real cat sits in, and the cheapest way to say
# "this animal has four legs" without drawing two more limbs.
HIND_PAWS = {27: [(6, 9), (22, 25)], 28: [(6, 10), (21, 25)]}

# ── Face ──────────────────────────────────────────────────────────────────────
# Eye geometry is UNCHANGED from the previous silhouette on purpose: `eyes.png` is a shared
# asset anchored to these coordinates, so moving them would need every anchor recomputed.
# GOOGLY: big round whites with a small bead, and equal slack on both axes.
#
# The eye was a 5x4 white with a 2x2 pupil and 1px of travel. That tracks, but it cannot be
# googly: a googly eye is a bead loose in a round dome, so it needs (a) a white that is
# roughly circular rather than a letterbox, and (b) enough slack for the bead to visibly
# roll and overshoot.
#
# 6x6 white with a 2x2 pupil leaves exactly 2px of slack on every side, so `EYE_TRAVEL` is 2
# on both axes — which matters, because the renderer applies one scalar to both and the
# engine clamps the pupil to a *circle*. Unequal slack would let the bead ride out of a
# letterboxed white on the diagonals.
#
# Two 6-wide whites plus a 4px gap span 16 of the head's 20 columns, which is the proportion
# that makes it read as googly rather than merely awake.
EYE_WHITE_X = (8, 18)
EYE_WHITE_Y = 7
EYE_WHITE_W = 6
EYE_WHITE_H = 6
PUPIL_X = (10, 20)
PUPIL_Y = 9
PUPIL_W = 2
PUPIL_H = 2
EYE_TRAVEL = 2

NOSE = (14, 15, 16)          # row, first, last — pink, so it reads on a black coat
MOUTH = [(15, 15, 16), (16, 14, 14), (16, 17, 17)]   # a stroke under the nose, then two corners

WHISKER_ROWS = [11, 13]
WHISKER_LEFT = (2, 5)
WHISKER_RIGHT = (26, 29)

# ── Tail ──────────────────────────────────────────────────────────────────────
# Curls up the right side with a one-pixel gap from the haunch, which is what keeps it a
# tail rather than a bulge.
TAIL = [
    # Two pixels wide throughout. At 1px it read as a stray thread rather than a tail —
    # measured at 2x that is a single device pixel against a busy edge.
    (26, 25), (26, 26), (27, 26), (26, 27), (25, 27), (25, 28),
    (24, 28), (24, 29), (23, 28), (23, 29), (22, 28), (22, 29),
    (21, 27), (21, 28), (20, 27), (20, 28), (19, 27),
]


def blank():
    return [[T] * CANVAS for _ in range(CANVAS)]


def fill(grid, row, first, last, char):
    if not 0 <= row < CANVAS:
        return
    for x in range(max(0, first), min(CANVAS - 1, last) + 1):
        grid[row][x] = char


def full_cat(fur="b", edge="e", light="w", pink="p", squash=0, lean=0, leg_lift=(0, 0)):
    """The whole animal. `squash` moves the head rows only; `lean` shifts the head sideways.

    `leg_lift` raises each foreleg's paw by that many pixels — the whole of the walk cycle
    and the knead slam. A raised paw is drawn higher with the foreleg shortened to meet it, so
    a cat lifting alternate front paws reads as a step; at 32px that one-pixel lift is the
    smallest change that reads without the leg detaching from the body."""
    grid = blank()

    for row, (first, last) in HEAD.items():
        fill(grid, row + squash, first + lean, last + lean, fur)
    for row, spans in EARS.items():
        for first, last in spans:
            fill(grid, row + squash, first + lean, last + lean, fur)
    for row, (first, last) in TORSO.items():
        fill(grid, row, first, last, fur)

    # Hind paws before the forelegs, so a foreleg drawn over one still reads as in front.
    for row, spans in HIND_PAWS.items():
        for first, last in spans:
            fill(grid, row, first, last, fur)

    # Forelegs and paws, one leg at a time so each can lift independently. The foreleg is
    # shortened from the bottom by the lift and the paw is drawn that many rows higher, so
    # the foot rises rather than the leg stretching.
    for i, ((fl_first, fl_last), (pw_first, pw_last)) in enumerate(zip(FORELEGS, PAWS)):
        lift = leg_lift[i] if i < len(leg_lift) else 0
        for row in range(FORELEG_ROWS[0], FORELEG_ROWS[1] + 1 - lift):
            fill(grid, row, fl_first, fl_last, fur)
        for row in range(PAW_ROWS[0] - lift, PAW_ROWS[1] + 1 - lift):
            fill(grid, row, pw_first, pw_last, fur)

    for row, column in TAIL:
        if 0 <= row < CANVAS and 0 <= column < CANVAS:
            grid[row][column] = fur

    # The separators and ankle, per leg, following the same lift so the outline tracks the
    # foot up. The separators are the paw's own outer columns run down the leg.
    for i, ((fl_first, fl_last), (pw_first, pw_last)) in enumerate(zip(FORELEGS, PAWS)):
        lift = leg_lift[i] if i < len(leg_lift) else 0
        for column in (pw_first, pw_last):
            for row in range(FORELEG_ROWS[0], PAW_ROWS[1] + 1 - lift):
                if grid[row][column] == fur:
                    grid[row][column] = edge
        # The ankle line, where the leg meets its paw. Without it the paw reads as the leg
        # simply getting wider, which is not a foot.
        fill(grid, PAW_ROWS[0] - 1 - lift, fl_first, fl_last, edge)

    for row in WHISKER_ROWS:
        fill(grid, row + squash, WHISKER_LEFT[0] + lean, WHISKER_LEFT[1] + lean, fur)
        fill(grid, row + squash, WHISKER_RIGHT[0] + lean, WHISKER_RIGHT[1] + lean, fur)

    return grid


def add_face(grid, eyes="open", squash=0, lean=0, light="w", pink="p", dark="k"):
    """Eye whites, nose and mouth. The pupils live in `eyes.png`, not here."""
    top = EYE_WHITE_Y + squash
    for x0 in EYE_WHITE_X:
        left = x0 + lean
        if eyes == "open":
            # Corners inset by one on the top and bottom rows, which is all a 6px circle is
            # at this scale. A full square reads as a screen, not an eye.
            for row in range(EYE_WHITE_H):
                inset = 1 if row in (0, EYE_WHITE_H - 1) else 0
                fill(grid, top + row, left + inset, left + EYE_WHITE_W - 1 - inset, light)
        elif eyes == "wide":
            for row in range(-1, EYE_WHITE_H):
                fill(grid, top + row, left, left + EYE_WHITE_W - 1, light)
        elif eyes == "half":
            for row in range(2, EYE_WHITE_H):
                fill(grid, top + row, left, left + EYE_WHITE_W - 1, light)
        elif eyes == "shut":
            fill(grid, top + 2, left, left + EYE_WHITE_W - 1, light)
        elif eyes == "happy":
            fill(grid, top + 2, left, left + 1, light)
            fill(grid, top + 1, left + 2, left + 2, light)
            fill(grid, top + 2, left + 3, left + EYE_WHITE_W - 1, light)

    row, first, last = NOSE
    fill(grid, row + squash, first + lean, last + lean, pink)
    for row, first, last in MOUTH:
        fill(grid, row + squash, first + lean, last + lean, light)
    return grid
