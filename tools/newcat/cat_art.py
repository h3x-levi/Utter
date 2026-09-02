"""Pixel primitives and pose geometry for the 64px code-drawn cat.

Everything here works on a `grid`: a list of `CANVAS` rows, each a list of `CANVAS`
single-character colour codes. `T` ("." ) is transparent. `generate_cat.py` maps the codes
to a palette per colourway and rasterises to RGBA.

WHY 64, NOT 32
--------------
Mochi is 32px and its walk is a two-leg shuffle because "at 32px a leg is three pixels and
the body is eighteen, so a second pair either hides behind the first or becomes a separate
pair of limbs" (tools/mochi/walk_cycle.py). Its own note ends: "If this ever moves to a 64px
canvas, the far pair is worth trying again — there would be room." This is that canvas. Four
articulated legs, real limb bend, and a face with room for two eyes, a nose and whiskers.

The renderer snaps a pixel pack DOWN to a whole-number scale (`SpritePackView.renderedSize`).
On a 2x display a 64px master lands at 1:1 (64 device px, the 36/52pt settings) or 2x (128
device px, the 68/84pt settings) — it is never downscaled, so the grid stays crisp. The cost
is coarser size steps than Mochi's 32px ladder; that is the price of room for legs, and it is
stated in the report rather than hidden.

FLAT, FEW TONES
---------------
Mochi's hard lesson, kept: two body tones (fill + a one-pixel edge ring), not a shaded coat —
"at 32px, extra tones cost silhouette clarity and buy nothing". At 64px there is a little more
room, so the walk adds ONE more tone (`s`, the far-side limbs) for depth, and the face carries
eye-white, pupil and nose-pink. No gradient, no rim light. The silhouette does the work.
"""
from __future__ import annotations

import math

CANVAS = 64
T = "."

# Colour codes used in a grid. The palette in generate_cat.py maps each to a hex per coat.
#   b  body fill            e  edge / outline ring        s  far-side limb (walk depth only)
#   w  eye white            k  pupil / dark line          p  nose & inner-ear pink
#   t  tongue (grooming)    z  zzz / steam / sparkle (light accent)
BODY, EDGE, FAR, WHITE, PUPIL, PINK, TONGUE, ACCENT = "b", "e", "s", "w", "k", "p", "t", "z"


# ── grid primitives ─────────────────────────────────────────────────────────────

def blank():
    return [[T] * CANVAS for _ in range(CANVAS)]


def in_bounds(x, y):
    return 0 <= x < CANVAS and 0 <= y < CANVAS


def put(grid, x, y, c):
    if in_bounds(x, y):
        grid[y][x] = c


def hspan(grid, y, x0, x1, c):
    """Fill an inclusive horizontal run. x0/x1 may be floats; they are rounded."""
    a, b = sorted((int(round(x0)), int(round(x1))))
    for x in range(a, b + 1):
        put(grid, x, y, c)


def vspan(grid, x, y0, y1, c):
    a, b = sorted((int(round(y0)), int(round(y1))))
    for y in range(a, b + 1):
        put(grid, x, y, c)


def disk(grid, cx, cy, r, c):
    """A filled circle of radius r."""
    for y in range(int(cy - r), int(cy + r) + 1):
        dy = y - cy
        if abs(dy) > r:
            continue
        dx = math.sqrt(max(0.0, r * r - dy * dy))
        hspan(grid, y, cx - dx, cx + dx, c)


def thick_line(grid, x0, y0, x1, y1, c, radius=1.0):
    """A line with a round brush of the given radius, so a limb has width and its ends round.

    Sampled densely along the segment; each sample stamps a small disk. Cheap at this size and
    it gives joints that do not fray into single pixels the way a Bresenham line does.
    """
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        cx = x0 + (x1 - x0) * t
        cy = y0 + (y1 - y0) * t
        disk(grid, cx, cy, radius, c)


def stroke_path(grid, points, c, radius=1.0):
    """A round-brushed polyline through (x, y) points — used for the tail curve."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        thick_line(grid, x0, y0, x1, y1, c, radius)


def triangle(grid, p0, p1, p2, c):
    """Fill a triangle by scanline. Points are (x, y)."""
    pts = sorted([p0, p1, p2], key=lambda p: p[1])
    (x0, y0), (x1, y1), (x2, y2) = pts

    def edge(ya, yb, xa, xb, y):
        if yb == ya:
            return xa
        return xa + (xb - xa) * (y - ya) / (yb - ya)

    for y in range(int(round(y0)), int(round(y2)) + 1):
        if y < y1:
            xa = edge(y0, y1, x0, x1, y)
        else:
            xa = edge(y1, y2, x1, x2, y)
        xb = edge(y0, y2, x0, x2, y)
        hspan(grid, y, xa, xb, c)


def overlay(dst, src):
    """Paste every non-transparent pixel of src onto dst (in place, new grid returned)."""
    out = [row[:] for row in dst]
    for y in range(CANVAS):
        for x in range(CANVAS):
            if src[y][x] != T:
                out[y][x] = src[y][x]
    return out


def shift(grid, dx=0, dy=0):
    out = blank()
    for y in range(CANVAS):
        for x in range(CANVAS):
            if grid[y][x] != T and in_bounds(x + dx, y + dy):
                out[y + dy][x + dx] = grid[y][x]
    return out


def mirror(grid):
    return [row[::-1] for row in grid]


def outline_edge(grid):
    """Recolour the outermost ring of BODY pixels to the edge tone.

    Body pixels only, and only where they touch transparency — so the face features (whites,
    pupil, nose) never get a dark ring, and the far-limb tone is left flat. This is Mochi's
    trick: the ring is a fraction lighter/darker than the fill so the silhouette lifts off both
    a light and a dark desktop.
    """
    out = [row[:] for row in grid]
    for y in range(CANVAS):
        for x in range(CANVAS):
            if grid[y][x] != BODY:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not in_bounds(nx, ny) or grid[ny][nx] == T:
                    out[y][x] = EDGE
                    break
    return out


# ── smooth silhouette from a half-width profile ─────────────────────────────────

def _smooth_profile(controls, y0, y1):
    """Interpolate half-widths between (y, halfwidth) control points with a smoothstep, so the
    outline curves rather than stepping. Returns {y: halfwidth} for y in [y0, y1]."""
    controls = sorted(controls)
    out = {}
    for y in range(y0, y1 + 1):
        # locate the segment
        lo = controls[0]
        hi = controls[-1]
        for a, b in zip(controls, controls[1:]):
            if a[0] <= y <= b[0]:
                lo, hi = a, b
                break
        (ya, wa), (yb, wb) = lo, hi
        if yb == ya:
            out[y] = wa
        else:
            t = (y - ya) / (yb - ya)
            t = t * t * (3 - 2 * t)  # smoothstep
            out[y] = wa + (wb - wa) * t
    return out


# The sitting cat, front-on. Half-width of the body mass at each row, centred on CX.
# Round head, a gentle neck pinch so the head reads as a head, widening to the seated haunches.
CX = 32
HEAD_TOP = 12
NECK_ROW = 34
BODY_BASE = 58

BODY_PROFILE_CONTROLS = [
    (HEAD_TOP, 4),     # crown starts narrow
    (15, 13),          # head widening
    (20, 16),          # head widest (cheeks)
    (26, 15),
    (NECK_ROW, 11),    # neck pinch
    (38, 15),          # shoulders
    (46, 19),
    (52, 21),          # haunches widest
    (56, 20),
    (BODY_BASE, 12),   # rounding to the seat
]

# Ears: base row and the two triangle tips. Tilted very slightly outward.
EAR_BASE = 15
LEFT_EAR = ((18, EAR_BASE), (29, EAR_BASE), (20, 3))   # (base-left, base-right, tip)
RIGHT_EAR = ((35, EAR_BASE), (46, EAR_BASE), (44, 3))
INNER_EAR_L = ((21, EAR_BASE - 2), (26, EAR_BASE - 2), (22, 6))
INNER_EAR_R = ((38, EAR_BASE - 2), (43, EAR_BASE - 2), (42, 6))

# Front paws sit at the base of the seated body, separated by a notch so two legs read.
PAW_ROW = 56
LEFT_PAW_CX = 26
RIGHT_PAW_CX = 38
PAW_R = 4


def sit_body(draw_front_legs=True):
    """The seated silhouette: body mass, ears, tail, and (optionally) two separated front paws.

    `draw_front_legs=False` leaves the belly whole, for poses that redraw the forelimbs
    themselves — kneading paws, a raised grooming paw.
    """
    grid = blank()
    profile = _smooth_profile(BODY_PROFILE_CONTROLS, HEAD_TOP, BODY_BASE)
    for y, hw in profile.items():
        hspan(grid, y, CX - hw, CX + hw, BODY)

    # Ears on top of the crown.
    triangle(grid, *LEFT_EAR, BODY)
    triangle(grid, *RIGHT_EAR, BODY)

    # Tail: sweeps out from the lower-right haunch, curls up along the right side with a hooked
    # tip — the friendly "tail up" carriage, and a strong cat cue in a front-on pose.
    tail = [(50, 54), (55, 52), (57, 46), (55, 40), (51, 37), (48, 39)]
    stroke_path(grid, tail, BODY, radius=2.2)

    if draw_front_legs:
        _front_legs(grid)
    return grid


def _front_legs(grid):
    """Carve the two front legs out of the seated belly so they read as separate limbs.

    The belly is one filled mass; without this it is a beanbag. A transparent notch down the
    centre splits it into two legs, `outline_edge` then rings each leg, and a couple of toe
    lines break each paw. This is the recurring failure the task calls out — legs vanishing
    into the body — fixed with contrast rather than a colour the palette does not have.
    """
    # Round the two paws at the base.
    disk(grid, LEFT_PAW_CX, PAW_ROW - 1, PAW_R, BODY)
    disk(grid, RIGHT_PAW_CX, PAW_ROW - 1, PAW_R, BODY)

    # The centre notch: transparent gap between the legs, from the paws up under the belly.
    for y in range(44, PAW_ROW + 2):
        # gap narrows toward the top so the legs join the body rather than being sticks
        half = 1 if y < 49 else 2
        for x in range(CX - half, CX + half + 1):
            put(grid, x, y, T)

    # Toe lines on each paw.
    for cx in (LEFT_PAW_CX, RIGHT_PAW_CX):
        put(grid, cx, PAW_ROW + 1, EDGE)
        put(grid, cx - 2, PAW_ROW + 1, EDGE)
        put(grid, cx + 2, PAW_ROW + 1, EDGE)


# ── face ─────────────────────────────────────────────────────────────────────────
# Eyes are baked as WHITES only; the pupil is a separate tracking overlay (eyes.png), exactly
# like Mochi. A closed expression bakes an eyelid line instead, in the pupil tone, so the
# overlay pupil lands on it and merges rather than floating on a shut eye.

EYE_CY = 22
LEFT_EYE_CX = 24
RIGHT_EYE_CX = 40
EYE_RX = 4
EYE_RY = 4

NOSE_CX = 32
NOSE_ROW = 27

EYE_TRAVEL = 3  # source pixels the tracking pupil may move — clamped by the loader too


def _eye_white(grid, cx, wide=False, half=False):
    rx = EYE_RX + (1 if wide else 0)
    ry = EYE_RY + (1 if wide else 0)
    if half:
        ry = 2
    for y in range(EYE_CY - ry, EYE_CY + ry + 1):
        dy = (y - EYE_CY) / ry
        if abs(dy) > 1:
            continue
        dx = rx * math.sqrt(max(0.0, 1 - dy * dy))
        hspan(grid, y, cx - dx, cx + dx, WHITE)


def _eye_closed(grid, cx, happy=False):
    """A shut eye: a bold 2px curve spanning the full eye, centred on EYE_CY so the tracking
    pupil (drawn on top) lands on the curve's middle and merges into it rather than floating.

    `happy` gives a caret ∩ (peak in the middle → ^^), otherwise a content bowl ⌣."""
    span = EYE_RX + 1
    for dx in range(-span, span + 1):
        curve = (dx * dx) / (span * span)          # 0 at centre, 1 at the ends
        if happy:
            y = EYE_CY - 1 + int(round(curve * 2))  # ∩ : centre up, ends down
        else:
            y = EYE_CY + 1 - int(round(curve * 2))  # ⌣ : centre down, ends up
        put(grid, cx + dx, y, PUPIL)
        put(grid, cx + dx, y + 1, PUPIL)


def add_face(grid, expr="open", look=(0, 0)):
    """Draw eye whites (or lids), nose, mouth and whiskers for an expression.

    `expr`: open | wide | half | shut | happy. `look` biases the baked whites a touch (the
    live tracking is the overlay's job); mostly (0,0)."""
    lx = LEFT_EYE_CX + look[0]
    rx = RIGHT_EYE_CX + look[0]

    if expr in ("open", "wide", "half"):
        _eye_white(grid, lx, wide=(expr == "wide"), half=(expr == "half"))
        _eye_white(grid, rx, wide=(expr == "wide"), half=(expr == "half"))
    elif expr == "happy":
        _eye_closed(grid, lx, happy=True)
        _eye_closed(grid, rx, happy=True)
    else:  # shut
        _eye_closed(grid, lx, happy=False)
        _eye_closed(grid, rx, happy=False)

    # Nose: a small pink inverted triangle.
    triangle(grid, (NOSE_CX - 2, NOSE_ROW), (NOSE_CX + 2, NOSE_ROW),
             (NOSE_CX, NOSE_ROW + 2), PINK)
    # Mouth: the little ω under the nose.
    put(grid, NOSE_CX, NOSE_ROW + 3, PUPIL)
    put(grid, NOSE_CX - 2, NOSE_ROW + 4, PUPIL)
    put(grid, NOSE_CX - 1, NOSE_ROW + 5, PUPIL)
    put(grid, NOSE_CX + 2, NOSE_ROW + 4, PUPIL)
    put(grid, NOSE_CX + 1, NOSE_ROW + 5, PUPIL)

    # Inner ears (pink), drawn after the crown so they sit inside the ear.
    triangle(grid, *INNER_EAR_L, PINK)
    triangle(grid, *INNER_EAR_R, PINK)

    _whiskers(grid)


def _whiskers(grid):
    """Three whiskers each side, springing from the muzzle. Edge tone, one pixel."""
    for side in (-1, 1):
        root = NOSE_CX + side * 4
        for i, (dyr, dyt, length) in enumerate([(-1, -2, 12), (1, 0, 13), (3, 3, 11)]):
            y0 = NOSE_ROW + dyr
            y1 = NOSE_ROW + dyt
            x0 = root
            x1 = root + side * length
            # a gentle 2-pixel poly so it is not a dead-straight ruler line
            put(grid, x0, y0, EDGE)
            midx = x0 + side * (length // 2)
            midy = (y0 + y1) // 2
            thick_line(grid, x0, y0, midx, midy, EDGE, radius=0.4)
            thick_line(grid, midx, midy, x1, y1, EDGE, radius=0.4)


def pupils(look=(0, 0)):
    """The tracking pupil overlay (eyes.png): two dark beads with a light catch-light.

    Drawn on the same 64px canvas as the body, everything else transparent, so it lands exactly
    over the baked whites. The loader offsets this layer toward the cursor at run time.
    """
    grid = blank()
    for cx in (LEFT_EYE_CX, RIGHT_EYE_CX):
        px = cx + look[0]
        py = EYE_CY + look[1]
        disk(grid, px, py, 1.7, PUPIL)
        put(grid, px + 1, py - 1, WHITE)  # catch-light
    return grid


# ── the walk, in profile, facing right ───────────────────────────────────────────
#
# A sitting animal cannot walk, so this is a separate silhouette — a side-on cat with four
# legs solved by two-bone IK, drawn facing right; `SpritePackView` mirrors it for left. The
# gait is a real lateral-sequence walk (reference docs/cat-motion-reference.md §2.1): footfall
# order left-hind, left-fore, right-hind, right-fore, a quarter-cycle apart, so three feet are
# down at almost every instant. Legs bend at a knee that JUTS the right way — fore elbow back,
# hind stifle forward — which is what reads as a cat rather than a table sliding along.
#
# Anti-skate is impossible to satisfy exactly here and that is stated, not hidden: the engine
# pans the window ~34pt per 0.8s cycle, which at this canvas is ~34 art-px of world travel per
# stance — two thirds of the body. A paw cannot slide that far without crossing the whole cat.
# So the stride is sized to read as a clear step (~12px fore/aft) and the residual skate is
# accepted, exactly as Mochi accepted its 4px stride at 32px. The leg CYCLE, the body bob and
# the tail sway are what sell the walk; the pan supplies the ground speed.

GROUND_ROW = 54
WALK_FRAMES = 8

# Torso, profile. Top (back) and bottom (belly) lines over x; belly tucks up toward the rear.
# Sits low and deep so the cat reads as a sturdy animal, not a leggy one.
TORSO_X0, TORSO_X1 = 7, 47


def _torso_top(x):
    # a level back with a slight rise over the shoulders (front/right)
    t = (x - TORSO_X0) / (TORSO_X1 - TORSO_X0)
    return 29 - 2.0 * t


def _torso_bottom(x):
    # belly: deep at the chest (right), tucked up at the waist (left)
    t = (x - TORSO_X0) / (TORSO_X1 - TORSO_X0)
    tuck = math.sin(t * math.pi)          # deepest mid-body
    return 41 - 3.0 * t - 1.5 * tuck + 3.5 * t   # net: rises toward rear


# Head, profile, at the front (right). A touch bigger and lower for a rounder, less kittenish read.
HEAD_CX, HEAD_CY, HEAD_R = 54, 24, 8.5
# One ear, up and slightly back from the crown.
WALK_EAR = ((49, 18), (56, 18), (50, 7))
WALK_INNER_EAR = ((51, 16), (55, 16), (51, 10))
WALK_NOSE = (62, 25)
WALK_EYE = (56, 23)

# Leg anchors on the torso (shoulder at the chest, hip at the haunch), tucked a little inside
# the belly so the limb roots INTO the body — the "back leg disconnected" failure is a hip
# drawn in mid-air, so both anchors sit on solid fur.
SHOULDER = (43, 38)
HIP = (13, 38)

# Bone lengths (upper, lower). Lower a touch longer than upper, as in a real cat (tibia>femur,
# reference §1.2), which also puts the knee high where it reads. Short enough that the cat is
# not on stilts: shoulder (~y30) to ground (54) is ~24px, and the leg folds within that.
FORE_BONES = (8.5, 9.5)
HIND_BONES = (9.5, 10.5)

# contact phase, anchor, bones, knee-direction (+1 forward / -1 back), tone, is_far
#   near side = right (reference §2.1 tuple [far-hind .00, far-fore .25, near-hind .50, near-fore .75])
WALK_LEGS = [
    ("far-hind",  0.00, HIP,      HIND_BONES, +1, FAR,  True),
    ("far-fore",  0.25, SHOULDER, FORE_BONES, -1, FAR,  True),
    ("near-hind", 0.50, HIP,      HIND_BONES, +1, BODY, False),
    ("near-fore", 0.75, SHOULDER, FORE_BONES, -1, BODY, False),
]

DUTY_FORE = 0.64
DUTY_HIND = 0.60
STRIDE = 10.0        # total fore/aft paw travel, px
FRONT_REACH = 4.0    # how far ahead of the anchor a paw contacts
LIFT = 4.0           # swing arc height


def _paw(anchor, contact_phase, t, duty):
    """World paw position (x, y) for a leg at cycle time t."""
    ax, _ay = anchor
    contact_x = ax + FRONT_REACH
    p = (t - contact_phase) % 1.0
    if p < duty:                                   # stance: planted, sliding backward
        s = p / duty
        return contact_x - STRIDE * s, GROUND_ROW
    u = (p - duty) / (1 - duty)                    # swing: forward + up on a sine arc
    x = (contact_x - STRIDE) + STRIDE * u
    y = GROUND_ROW - LIFT * math.sin(math.pi * u)
    return x, y


def _knee(anchor, paw, bones, side):
    """Two-bone IK knee, on the chosen side of the hip→paw line."""
    (ax, ay), (px, py) = anchor, paw
    l1, l2 = bones
    dx, dy = px - ax, py - ay
    d = math.hypot(dx, dy)
    d = max(abs(l1 - l2) + 0.01, min(d, l1 + l2 - 0.01))   # keep reachable
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    ux, uy = dx / d, dy / d
    bx, by = ax + a * ux, ay + a * uy
    # perpendicular; `side` picks fore(back)/hind(forward) so the joint juts the cat way
    return bx + side * h * uy, by - side * h * ux


def _draw_leg(grid, anchor, paw, bones, side, tone):
    knee = _knee(anchor, paw, bones, side)
    thick_line(grid, anchor[0], anchor[1], knee[0], knee[1], tone, radius=2.1)   # thigh/upper
    thick_line(grid, knee[0], knee[1], paw[0], paw[1], tone, radius=1.7)         # shank/lower
    disk(grid, paw[0], paw[1], 2.0, tone)          # paw


def _body_bob(t):
    """Vertical body oscillation: two dips per stride (once per forefoot fall), ~2px."""
    return int(round(1.0 - 1.0 * math.cos(2 * 2 * math.pi * (t - 0.75))))


def walk_frame(i):
    """One frame of the walk cycle, i in [0, WALK_FRAMES)."""
    t = i / WALK_FRAMES
    bob = _body_bob(t)
    grid = blank()

    # 1) far legs first, behind everything.
    for _n, phase, anchor, bones, side, tone, is_far in WALK_LEGS:
        if not is_far:
            continue
        duty = DUTY_HIND if "hind" in _n else DUTY_FORE
        paw = _paw(anchor, phase, t, duty)
        _draw_leg(grid, (anchor[0], anchor[1] + bob), paw, bones, side, tone)

    # 2) tail (rear/left), before the body so the body covers its root — a raised, hooked tail
    #    that sways gently fore/aft (a walking cat's tail is near-parallel/up, reference §4.9).
    sway = math.sin(2 * math.pi * t) * 2.0
    tail = [(TORSO_X0, 31 + bob), (5, 27 + bob), (3, 22), (3, 16),
            (5 + sway, 13), (8 + sway, 14)]
    stroke_path(grid, tail, BODY, radius=1.9)

    # 3) torso, neck, head.
    for x in range(TORSO_X0, TORSO_X1 + 1):
        vspan(grid, x, _torso_top(x) + bob, _torso_bottom(x) + bob, BODY)
    disk(grid, HEAD_CX, HEAD_CY + bob, HEAD_R, BODY)
    # neck: bridge chest to head so the head is not a floating ball
    thick_line(grid, TORSO_X1 - 2, 29 + bob, HEAD_CX - 4, HEAD_CY + 5 + bob, BODY, radius=3.2)
    triangle(grid, (WALK_EAR[0][0], WALK_EAR[0][1] + bob),
             (WALK_EAR[1][0], WALK_EAR[1][1] + bob),
             (WALK_EAR[2][0], WALK_EAR[2][1] + bob), BODY)

    # 4) near legs, over the body so a forward-swinging leg passes in front of the chest.
    for _n, phase, anchor, bones, side, tone, is_far in WALK_LEGS:
        if is_far:
            continue
        duty = DUTY_HIND if "hind" in _n else DUTY_FORE
        paw = _paw(anchor, phase, t, duty)
        _draw_leg(grid, (anchor[0], anchor[1] + bob), paw, bones, side, tone)

    grid = outline_edge(grid)

    # 5) face, baked (the eye overlay is suppressed while walking): inner ear, eye, nose, mouth.
    triangle(grid, (WALK_INNER_EAR[0][0], WALK_INNER_EAR[0][1] + bob),
             (WALK_INNER_EAR[1][0], WALK_INNER_EAR[1][1] + bob),
             (WALK_INNER_EAR[2][0], WALK_INNER_EAR[2][1] + bob), PINK)
    ex, ey = WALK_EYE
    disk(grid, ex, ey + bob, 2.0, WHITE)
    disk(grid, ex + 1, ey + bob, 1.2, PUPIL)
    nx, ny = WALK_NOSE
    put(grid, nx, ny + bob, PINK)
    put(grid, nx, ny + 1 + bob, PINK)
    # a little muzzle/mouth line so the profile is not a featureless wedge
    put(grid, nx - 1, ny + 3 + bob, EDGE)
    put(grid, nx - 3, ny + 3 + bob, EDGE)
    return grid


def walk_cycle():
    return [walk_frame(i) for i in range(WALK_FRAMES)]


# ── accessories (rising z's, steam, sparkle, thought dots) ────────────────────────

def add_zzz(grid, phase):
    """Three z's drifting up and to the right of the head, cycling by phase."""
    base = [(46, 18), (50, 13), (54, 9)]
    for i, (x, y) in enumerate(base):
        lit = (phase % 3) >= i          # they appear in sequence
        if not lit:
            continue
        sz = 2 + i
        # a tiny block 'z'
        hspan(grid, y, x, x + sz, ACCENT)
        put(grid, x + sz, y + 1, ACCENT)
        put(grid, x + sz - 1, y + 1, ACCENT) if sz > 2 else None
        put(grid, x, y + 2, ACCENT)
        hspan(grid, y + 2, x, x + sz, ACCENT)


def add_steam(grid, phase):
    """Two flustered puffs either side of the head."""
    off = phase % 2
    for side in (-1, 1):
        x = CX + side * 20
        y = 8 - off
        disk(grid, x, y, 2, ACCENT)
        disk(grid, x + side, y - 3, 1.5, ACCENT)


def add_sparkle(grid, phase):
    """Little four-point sparkles for a delighted cat."""
    spots = [(12, 12), (52, 10), (50, 30)]
    for i, (x, y) in enumerate(spots):
        if (phase + i) % 2 == 0:
            put(grid, x, y, ACCENT)
            put(grid, x - 1, y, ACCENT); put(grid, x + 1, y, ACCENT)
            put(grid, x, y - 1, ACCENT); put(grid, x, y + 1, ACCENT)


def add_think_dots(grid, phase):
    """A rising trail of dots by the head — a quiet 'hmm'."""
    dots = [(50, 16), (54, 12), (57, 9)]
    for i, (x, y) in enumerate(dots):
        if (phase % (len(dots) + 1)) > i:
            disk(grid, x, y, 1.4, ACCENT)


# ── knead: front-on, two paws making biscuits ────────────────────────────────────
# Maps to CompanionMood.kneading (shown while typing). The cat is lifted a little and leans
# in, and the two forepaws press down alternately on a soft cushion — the "making biscuits"
# motion. Four frames: L press / both mid / R press / both mid.
KNEAD_LIFT = -3          # rows the whole cat rises so the paws have somewhere to press
KNEAD_LEAN = -1          # engine leans it too; this shifts the eye anchor, see pack.json
CUSHION_ROW = 55


def knead(phase):
    lifts = {0: (0, 3), 1: (2, 2), 2: (3, 0), 3: (2, 2)}[phase]   # (left, right) paw raise
    grid = shift(sit_body(draw_front_legs=False), dy=KNEAD_LIFT)

    # A soft cushion the paws press: a flat rounded bar.
    for x in range(20, 45):
        put(grid, x, CUSHION_ROW, EDGE)
        put(grid, x, CUSHION_ROW + 1, EDGE)

    # The two forelegs, each a short limb from the chest to a paw whose height is the knead lift.
    for cx, lift in ((LEFT_PAW_CX, lifts[0]), (RIGHT_PAW_CX, lifts[1])):
        top = 42 + KNEAD_LIFT
        paw_y = 52 + KNEAD_LIFT - lift
        thick_line(grid, cx, top, cx, paw_y, BODY, radius=2.0)
        disk(grid, cx, paw_y, 2.4, BODY)
    return grid


# ── loaf: the compact "cat loaf" ──────────────────────────────────────────────────
# Reference §4.2: paws FORWARD, sternum/belly to the ground, head up, relaxed — NOT paws tucked
# under (that is a fear posture). A low rounded bread-loaf body with the head on top and two
# paws poking forward at the front.
LOAF_PROFILE = [
    (33, 6),    # body starts under the head
    (37, 16),
    (42, 21),   # widest
    (48, 22),
    (52, 20),
    (55, 14),   # rounding to the flat base
]


def loaf(breath=0):
    """The compact bread-loaf: a low rounded body, head on top, forepaws forward (reference
    §4.2 — paws forward, not tucked under, which would read as fear)."""
    grid = blank()
    prof = _smooth_profile(LOAF_PROFILE, 33, 55)
    for y, hw in prof.items():
        hspan(grid, y, CX - hw, CX + hw, BODY)

    # head on top, front-on, tucked down onto the loaf
    disk(grid, CX, 25 + breath, 12, BODY)
    triangle(grid, (CX - 13, 17 + breath), (CX - 3, 17 + breath), (CX - 11, 6 + breath), BODY)
    triangle(grid, (CX + 3, 17 + breath), (CX + 13, 17 + breath), (CX + 11, 6 + breath), BODY)

    # two forepaws poking forward at the front base, a notch between them
    for cx in (CX - 7, CX + 7):
        disk(grid, cx, 53, 3, BODY)
    for x in range(CX - 1, CX + 2):
        put(grid, x, 53, T); put(grid, x, 54, T)
    for cx in (CX - 7, CX + 7):
        put(grid, cx - 2, 55, EDGE); put(grid, cx + 2, 55, EDGE)

    # tail wrapped along the right side, tucked against the body
    stroke_path(grid, [(CX + 19, 53), (CX + 23, 50), (CX + 23, 44), (CX + 19, 41)],
                BODY, radius=2.0)
    return grid


# ── grooming: licks a raised forepaw ──────────────────────────────────────────────
# Reference §4.4: "licks its front paws and strokes them across its head". Head dips toward a
# paw lifted to the mouth, tongue out. Four frames of the lick.
def groom(phase):
    grid = sit_body(draw_front_legs=False)
    # left front leg stays planted
    disk(grid, LEFT_PAW_CX, PAW_ROW - 1, PAW_R, BODY)
    put(grid, LEFT_PAW_CX - 2, PAW_ROW + 1, EDGE); put(grid, LEFT_PAW_CX + 2, PAW_ROW + 1, EDGE)

    # right paw lifts toward the muzzle; the lick reaches out on the middle frames
    reach = {0: 0, 1: 2, 2: 3, 3: 1}[phase]
    paw_x = 34
    paw_y = 33 - reach
    thick_line(grid, RIGHT_PAW_CX, 44, paw_x, paw_y, BODY, radius=2.2)
    disk(grid, paw_x, paw_y, 3, BODY)
    return grid, ("lick" if phase in (1, 2) else None), (paw_x, paw_y)


# ── rolling: flops onto the back, paws up, rights itself ──────────────────────────
# Reference §4.7 "Play Roll on Back": belly exposed, all paws in the air, agonistic signals
# ABSENT (so a happy face, not ears-back). Six frames: sit → tip → on-back → wiggle → tip → sit.
def _on_back(wiggle=0):
    """Belly-up: a horizontal rounded body with four paws sticking UP and the head to the side."""
    grid = blank()
    # rounded belly-up body, lying across
    disk(grid, CX, 42, 15, BODY)
    for x in range(CX - 15, CX + 16):
        vspan(grid, x, 40, 50, BODY)
    # head to the left, resting on the ground (reference: head also rests on the ground)
    disk(grid, 16, 44, 9, BODY)
    triangle(grid, (10, 38), (16, 36), (9, 30), BODY)   # ear up
    triangle(grid, (16, 36), (22, 38), (23, 30), BODY)
    # four paws pointing up from the belly, wiggling
    paw_xs = [CX - 9, CX - 2, CX + 6, CX + 13]
    for i, px in enumerate(paw_xs):
        w = wiggle if i % 2 == 0 else -wiggle
        top = 30 + (i % 2)
        thick_line(grid, px, 40, px + w, top, BODY, radius=1.8)
        disk(grid, px + w, top, 2.0, BODY)
    # tail flopped to the right
    stroke_path(grid, [(CX + 14, 46), (CX + 20, 44), (CX + 24, 47)], BODY, radius=1.9)
    return grid


def roll(phase):
    """One of six frames. Returns a grid; the belly-up frames carry a happy face baked in."""
    if phase == 0:
        return sit_body(), "front"
    if phase == 1:
        return shift(sit_body(), dx=-3, dy=2), "front"     # tipping over
    if phase in (2, 3):
        g = _on_back(wiggle=(2 if phase == 2 else -2))
        # a small happy face on the side-resting head (belly-up, playful)
        hx, hy = 16, 44
        put(g, hx + 4, hy - 2, WHITE); put(g, hx + 5, hy - 2, PUPIL)   # one eye, content
        put(g, hx + 3, hy - 3, PUPIL); put(g, hx + 6, hy - 3, PUPIL)
        put(g, hx + 7, hy + 1, PINK)                                   # nose
        return g, None
    if phase == 4:
        return shift(sit_body(), dx=-2, dy=1), "front"     # righting
    return sit_body(), "front"


def vsquash(grid, factor, base=57):
    """Compress a grid vertically toward `base` by `factor` (<1 shrinks). Used for the hunt
    crouch: the head drops toward the body while the seat stays planted."""
    out = blank()
    for y in range(CANVAS):
        for x in range(CANVAS):
            if grid[y][x] != T:
                ny = int(round(base - (base - y) * factor))
                put(out, x, ny, grid[y][x])
    return out


def eye_row_after_squash(factor, base=57):
    """Where the baked eyes land after `vsquash`, so the pack can anchor the pupil overlay."""
    return int(round(base - (base - EYE_CY) * factor)) - EYE_CY
