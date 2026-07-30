#!/usr/bin/env python3
"""Glyph data and the letter-joining maths, shared by the two editors.

`tool/glyph_editor.py` edits the letterforms in `src/glyphs.json`.
`tool/join_editor.py` edits how pairs of letters connect, in `src/pairs.json`.
Neither owns this module; both import it.

The joining code here mirrors `src/composer.js` so the editors preview exactly
what the app will draw. `tool/test_glyphdata.py` checks the two against each
other and fails if they drift apart.

No tkinter here on purpose, so the data and the maths stay testable headless.
"""
import base64
import io
import json
import math
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
    _HAS_PIL = True
except ImportError:
    Image = None  # type: ignore
    ImageDraw = None  # type: ignore
    ImageFont = None  # type: ignore
    _HAS_PIL = False

REPO = Path(__file__).resolve().parent.parent
GLYPHS_FILE = REPO / "src" / "glyphs.json"
JOIN_FILE = REPO / "src" / "join.json"
PAIRS_FILE = REPO / "src" / "pairs.json"
SACRAMENTO_FONT = REPO / "vendor" / "sacramento" / "Sacramento-Regular.ttf"

# Sacramento metrics: x-height 627 units in a 2048-unit em. The overlay is
# normalized onto the editor baseline (y=70) and x-height guide (y=30).
SACRAMENTO_UNITS_PER_EM = 2048
SACRAMENTO_X_HEIGHT = 627
SACRAMENTO_RENDER_SIZE = 1024

# Rendering / interaction
DEFAULT_SCALE = 8.0
DEFAULT_MARGIN_X = 80
DEFAULT_MARGIN_Y = 40
HIT_R = 14
ANCHOR_EPS = 0.5         # glyph-unit proximity for "linked" anchors
SNAP_RADIUS = 6.0        # glyph-unit snap radius for connect-on-release
ZOOM_FACTOR = 1.1
SAMPLES_PER_CURVE = 30

# Modes



REFERENCE_LINES = [
    (0, "ascender"),
    (30, "x-height"),
    (70, "baseline"),
    (100, "descender"),
]

# --- Loading / saving ---


def load_glyphs(path=GLYPHS_FILE):
    """Read `glyphs.json` into `{key: [advance_width, strokes]}`, where
    `strokes` is a list of beziers and each bezier is a list of four mutable
    `[x, y]` control points."""
    raw = json.loads(path.read_text())
    return {
        key: [glyph["advanceWidth"], glyph["strokes"]]
        for key, glyph in raw.items()
    }


def dump_glyphs(glyphs):
    """Render the glyph map back to JSON, one bezier per line so that hand
    edits show up as readable diffs."""
    def num(v):
        return str(int(v)) if v == int(v) else f"{v:g}"

    def bezier(bez):
        return "[" + ", ".join(f"[{num(x)}, {num(y)}]" for x, y in bez) + "]"

    entries = []
    for key in sorted(glyphs):
        adv, strokes = glyphs[key]
        strokes_text = ",\n".join(
            "      [\n"
            + ",\n".join(f"        {bezier(bez)}" for bez in stroke)
            + "\n      ]"
            for stroke in strokes
        )
        entries.append(
            f"  {json.dumps(key)}: {{\n"
            f'    "advanceWidth": {num(adv)},\n'
            f'    "strokes": [\n{strokes_text}\n    ]\n'
            f"  }}"
        )
    return "{\n" + ",\n".join(entries) + "\n}\n"


# --- Bezier helpers ---


def cubic_at(t, p0, p1, p2, p3):
    u = 1 - t
    return (
        u * u * u * p0[0] + 3 * u * u * t * p1[0]
        + 3 * u * t * t * p2[0] + t * t * t * p3[0],
        u * u * u * p0[1] + 3 * u * u * t * p1[1]
        + 3 * u * t * t * p2[1] + t * t * t * p3[1],
    )


def sample_cubic(p0, p1, p2, p3, n=SAMPLES_PER_CURVE):
    return [cubic_at(i / (n - 1), p0, p1, p2, p3) for i in range(n)]


def split_cubic(bez, t):
    """De Casteljau split. Returns (left, right) — two new beziers whose
    union exactly reproduces the original curve. Each returned bezier is a
    list of four fresh `[x, y]` mutable lists."""
    P0, P1, P2, P3 = bez

    def lerp(a, b, u):
        return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]

    Q0 = lerp(P0, P1, t)
    Q1 = lerp(P1, P2, t)
    Q2 = lerp(P2, P3, t)
    R0 = lerp(Q0, Q1, t)
    R1 = lerp(Q1, Q2, t)
    S = lerp(R0, R1, t)
    return (
        [[P0[0], P0[1]], Q0, R0, S],
        [[S[0], S[1]], R1, Q2, [P3[0], P3[1]]],
    )


def reverse_bezier_list(beziers):
    """Reverse a sequence of beziers so the curve runs backwards. Returns a
    new list with each bezier's points reversed and list order reversed."""
    return [
        [list(b[3]), list(b[2]), list(b[1]), list(b[0])]
        for b in reversed(beziers)
    ]


def load_sacramento_reference(character):
    # Return a grayscale mask and bounds in editor coordinates. Keeping this
    # transform separate from Tk makes alignment testable on headless hosts.
    if not _HAS_PIL:
        raise RuntimeError("Pillow is required for the Sacramento overlay")
    if not SACRAMENTO_FONT.exists():
        raise FileNotFoundError(SACRAMENTO_FONT)

    font = ImageFont.truetype(str(SACRAMENTO_FONT), SACRAMENTO_RENDER_SIZE)
    left, top, right, bottom = font.getbbox(character, anchor="ls")
    width = max(1, right - left)
    height = max(1, bottom - top)
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    draw.text((-left, -top), character, font=font, fill=255, anchor="ls")

    font_units_per_pixel = SACRAMENTO_UNITS_PER_EM / SACRAMENTO_RENDER_SIZE
    glyph_units_per_pixel = 40.0 / (
        SACRAMENTO_X_HEIGHT / font_units_per_pixel
    )
    bounds = (
        left * glyph_units_per_pixel,
        70.0 + top * glyph_units_per_pixel,
        right * glyph_units_per_pixel,
        70.0 + bottom * glyph_units_per_pixel,
    )
    return mask, bounds


# --- Letter joining ---
#
# A mirror of the join in `src/composer.js`, so the editor's neighbour preview
# shows what the app will actually draw. `tool/test_glyphdata.py` checks the
# two against each other. Everything here is in glyph units; the join is linear
# in scale, so it holds at any size.

JOIN_SAMPLES = 400      # working resolution before respacing, as in composer.js
BASELINE_Y = 70
X_HEIGHT_Y = 30

# How the app finally draws a composed path. Mirrored from src/composer.js and
# src/canvas.js so the join editor can show what will actually appear on screen;
# tool/test_glyphdata.py fails if these drift from the source they copy.
APP_GLYPH_SCALE = 2.2
APP_LINE_WIDTH = 16


def load_join(path=JOIN_FILE):
    return json.loads(path.read_text())


def dump_join(join):
    return json.dumps(join, indent=2) + "\n"


def load_pairs(path=PAIRS_FILE):
    return json.loads(path.read_text())


def dump_pairs(pairs):
    """One pair per line, sorted, so a session's work reads as a clean diff."""
    def num(v):
        return str(int(v)) if float(v) == int(v) else f"{float(v):g}"

    rows = []
    for key in sorted(pairs):
        if len(key) != 2:                     # the "_" documentation note
            rows.append(f"  {json.dumps(key)}: {json.dumps(pairs[key])}")
            continue
        v = pairs[key]
        rows.append(
            f'  {json.dumps(key)}: {{ "from": {num(v["from"])}, "to": {num(v["to"])}, '
            f'"dx": {num(v["dx"])}, '
            f'"h1": [{num(v["h1"][0])}, {num(v["h1"][1])}], '
            f'"h2": [{num(v["h2"][0])}, {num(v["h2"][1])}] }}'
        )
    return "{\n" + ",\n".join(rows) + "\n}\n"


# Point spacing along a stroke, in glyph units. The app respaces to
# POINT_SPACING world units at APP_GLYPH_SCALE; matching it here is what makes
# a cut fraction mean the same thing in the editor as it does on screen.
APP_POINT_SPACING = 2
_SPACING = APP_POINT_SPACING / APP_GLYPH_SCALE


def _respace(fine, spacing=_SPACING):
    """Redistribute a polyline evenly along its length. Mirrors respace() in
    src/composer.js — sampling at even steps of t instead would bunch points up
    wherever the control points make a curve accelerate, and a cut fraction
    would then point somewhere different here than in the app."""
    out = [fine[0]]
    travelled, nxt = 0.0, spacing
    for i in range(1, len(fine)):
        (fx, fy), (tx, ty) = fine[i - 1], fine[i]
        length = math.hypot(tx - fx, ty - fy)
        if length <= 0:
            continue
        while travelled + length >= nxt:
            u = (nxt - travelled) / length
            out.append((fx + (tx - fx) * u, fy + (ty - fy) * u))
            nxt += spacing
        travelled += length
    out.append(fine[-1])
    return out


def _sample_stroke(beziers):
    points = []
    for bez in beziers:
        samples = _respace(sample_cubic(*bez, n=JOIN_SAMPLES))
        points.extend(samples if not points else samples[1:])
    return points


def _direction(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    return (1.0, 0.0) if length < 1e-3 else (dx / length, dy / length)


def lead_in_length(points, exit_y):
    """How many opening points are lead-in: the rise from the baseline up to
    the height the previous letter left off at, clamped to the band between
    the x-height and the baseline where cursive connections belong."""
    target = min(BASELINE_Y, max(X_HEIGHT_Y, exit_y))
    for i, (_x, y) in enumerate(points):
        if y <= target:
            return i
    return 0


def _bridge(start, start_dir, end, end_dir):
    chord = math.hypot(end[0] - start[0], end[1] - start[1])
    if chord < 1e-3:
        return []
    h = chord / 3
    return sample_cubic(
        [start[0], start[1]],
        [start[0] + start_dir[0] * h, start[1] + start_dir[1] * h],
        [end[0] - end_dir[0] * h, end[1] - end_dir[1] * h],
        [end[0], end[1]],
        n=JOIN_SAMPLES,
    )


def cut_index(points, at):
    """Mirror of cutIndex() in composer.js."""
    return min(len(points) - 1, max(0, round(at * (len(points) - 1))))


def compose_run(glyphs, keys, gap, pairs=None):
    """Lay out `keys` as one joined run, the way `composePhrase` does.

    Yields a dict per key: `offset` (the x translation applied to the glyph),
    `points` (its placed main stroke, cut at both ends by its joins), `trimmed`
    (the opening the join discarded), `bridge` (the connecting curve in from
    the previous letter) and `join` (the parameters that produced it, whether
    hand-tuned or derived).
    """
    pairs = pairs or {}
    joins = [pairs.get(keys[i] + keys[i + 1]) for i in range(len(keys) - 1)]
    run = []
    exit_point = exit_dir = None
    for i, key in enumerate(keys):
        strokes = glyphs[key][1]
        full = _sample_stroke(strokes[0]) if strokes else []
        if len(full) < 2:
            continue
        into = joins[i - 1] if i > 0 else None
        out_of = joins[i] if i < len(joins) else None

        if into:
            head = cut_index(full, into["to"])
        elif exit_point:
            head = lead_in_length(full, exit_point[1])
        else:
            head = 0
        tail = cut_index(full, out_of["from"]) if out_of else len(full) - 1
        points, trimmed = full[head:max(tail, head + 1) + 1], full[:head + 1]

        offset = (exit_point[0] + (into["dx"] if into else gap) - points[0][0]
                  if exit_point else 0.0)
        shift = lambda pts: [(x + offset, y) for x, y in pts]
        points, trimmed = shift(points), shift(trimmed)

        bridge, used = [], None
        if exit_point:
            entry_dir = _direction(points[0], points[1])
            used = into or _auto_join(exit_point, exit_dir, points[0], entry_dir, gap, full, head)
            bridge = _bridge_from(exit_point, points[0], used)
        run.append({
            "key": key, "offset": offset, "points": points,
            "trimmed": trimmed, "bridge": bridge, "join": used,
            "head": head, "tail": tail, "sample_count": len(full),
        })
        exit_point, exit_dir = points[-1], _direction(points[-2], points[-1])
    return run


def _auto_join(start, start_dir, end, end_dir, gap, full, head):
    """The join the algorithm would make, expressed in the same shape a tuned
    pair uses — so tuning always begins from what the app already does."""
    chord = math.hypot(end[0] - start[0], end[1] - start[1])
    h = chord / 3
    return {
        "from": 1.0,
        "to": round(head / max(1, len(full) - 1), 4),
        "dx": round(gap, 2),
        "h1": [round(start_dir[0] * h, 2), round(start_dir[1] * h, 2)],
        "h2": [round(-end_dir[0] * h, 2), round(-end_dir[1] * h, 2)],
    }


def _bridge_from(start, end, join):
    if math.hypot(end[0] - start[0], end[1] - start[1]) < 1e-3:
        return []
    return sample_cubic(
        [start[0], start[1]],
        [start[0] + join["h1"][0], start[1] + join["h1"][1]],
        [end[0] + join["h2"][0], end[1] + join["h2"][1]],
        [end[0], end[1]],
        n=JOIN_SAMPLES,
    )


def compose_around(glyphs, keys, index, gap, pairs=None):
    """`compose_run`, re-anchored so that `keys[index]` sits at its own
    coordinates — the editor edits that glyph, so it must not move."""
    run = compose_run(glyphs, keys, gap, pairs)
    shift = -run[index]["offset"]
    for item in run:
        item["offset"] += shift
        for field in ("points", "trimmed", "bridge"):
            item[field] = [(x + shift, y) for x, y in item[field]]
    return run
