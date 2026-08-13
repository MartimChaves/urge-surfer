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

# Sacramento metrics, in a 2048-unit em. The overlay is normalized onto the
# editor baseline (y=70) and, depending on case, the x-height guide (y=30) or
# the ascender guide (y=0).
SACRAMENTO_UNITS_PER_EM = 2048
SACRAMENTO_X_HEIGHT = 627
SACRAMENTO_CAP_HEIGHT = 1550
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
    """Read `glyphs.json` into
    `{key: [advance_width, strokes, lead_out, lift_after]}`, where `strokes` is
    a list of beziers and each bezier is a list of four mutable `[x, y]` control
    points. `lead_out` is where the letter's tail is cut when something follows
    it; 1.0 keeps the whole stroke. `lift_after` means the letter does not hand
    over at all, and `join_from_second` that it hands over from its second
    stroke rather than its first — see `compose_run`."""
    raw = json.loads(path.read_text())
    return {
        key: [
            glyph["advanceWidth"],
            glyph["strokes"],
            glyph.get("leadOut", 1.0),
            glyph.get("liftAfter", False),
            glyph.get("joinFromSecondStroke", False),
        ]
        for key, glyph in raw.items()
    }


def join_stroke(glyph):
    """Which of a glyph's strokes hands over to the next letter. Everything
    before it is drawn first, as the letterform requires; everything after it is
    a second pass, drawn once the word is finished."""
    return 1 if glyph[4] else 0


def dump_glyphs(glyphs):
    """Render the glyph map back to JSON, one bezier per line so that hand
    edits show up as readable diffs."""
    def num(v):
        return str(int(v)) if v == int(v) else f"{v:g}"

    def bezier(bez):
        return "[" + ", ".join(f"[{num(x)}, {num(y)}]" for x, y in bez) + "]"

    entries = []
    for key in sorted(glyphs):
        adv, strokes, lead_out, lift_after, join_from_second = glyphs[key]
        strokes_text = ",\n".join(
            "      [\n"
            + ",\n".join(f"        {bezier(bez)}" for bez in stroke)
            + "\n      ]"
            for stroke in strokes
        )
        entries.append(
            f"  {json.dumps(key)}: {{\n"
            f'    "advanceWidth": {num(adv)},\n'
            f'    "leadOut": {num(lead_out)},\n'
            + ('    "liftAfter": true,\n' if lift_after else "")
            + ('    "joinFromSecondStroke": true,\n' if join_from_second else "")
            + f'    "strokes": [\n{strokes_text}\n    ]\n'
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

    # Capitals are matched on cap height, lowercase on x-height. Sacramento is a
    # script face with flamboyant capitals — cap height 1550 against an x-height
    # of 627, a ratio of 2.47 where a text face sits near 1.4 — so normalising
    # everything on the x-height puts a capital 99 units above the baseline, 39
    # past the ascender guide, and the reference has to be shrunk by eye before
    # it is any use. On cap height it lands on the ascender guide, which is
    # where this dataset's own capitals sit.
    reference, target = ((SACRAMENTO_CAP_HEIGHT, 70.0) if character.isupper()
                         else (SACRAMENTO_X_HEIGHT, 40.0))
    glyph_units_per_pixel = target / (reference / font_units_per_pixel)
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

# Every letter hands over to the next at one fixed height. Mirrored from
# src/composer.js. Measured two ways: across 56 hand-tuned pairs the second
# letter's cut landed at y = 50.0..52.2 for 24 of the 26 letters, a spread of
# one to two point spacings; and Sacramento, which joins by a fixed convention
# rather than by any OpenType feature, hands over at 46% of its x-height, which
# is y = 51.6 here.
HANDOVER_Y = 51.0

# How many trailing samples of a stroke may be a bezier overshooting its own end
# point rather than part of the letter. `s` uses one.
OVERSHOOT_SAMPLES = 2

# How the app finally draws a composed path. Mirrored from src/composer.js and
# src/canvas.js so the join editor can show what will actually appear on screen;
# tool/test_glyphdata.py fails if these drift from the source they copy.
APP_GLYPH_SCALE = 2.2
APP_LINE_WIDTH = 12


def load_join(path=JOIN_FILE):
    return json.loads(path.read_text())


# How close the next letter sits to a letter that lifted the pen. Its own
# tunable rather than `gap`, and much smaller: `gap` is the room a connecting
# stroke needs, and a lift draws no connecting stroke, so spending the full gap
# there leaves a hole in the middle of the word. Read once — the join editor's
# slider edits `gap`, not this.
LIFT_GAP = load_join().get("liftGap", 0.0)


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


def lead_in_length(points, handover_y=HANDOVER_Y):
    """How many opening points are lead-in: the rise from the baseline up to
    the handover height. Dropping it is what lets two letters meet as one
    continuous line instead of doubling back to the baseline between them.
    0 when the glyph already starts at or above that height, as most of the
    capitals and the period do."""
    for i, (_x, y) in enumerate(points):
        if y <= handover_y:
            return i
    return 0


def suggest_lead_out(points):
    """Where a letter's tail should be cut when something follows it: the far
    end of the terminal rise, walking back from the exit while the stroke is
    still climbing and still below the baseline, so a descender loop cannot
    swallow the letter. The mirror of `lead_in_length` — between them the
    connecting stroke is drawn once, by the bridge, instead of half by each
    letter.

    1.0 (keep the whole tail) when the letter does not exit at the handover
    height. That is most of the capitals, whose exits run from y = 4.5 to
    y = 72: their last stroke is the letterform, not a lead-out, and cutting
    it back to the baseline takes the letter with it.
    """
    if not (X_HEIGHT_Y <= points[-1][1] <= BASELINE_Y):
        return 1.0

    # Start from the top of the rise, not from the last point. `s` overshoots on
    # its final bezier and comes back down and to the left over its last sample,
    # which is enough to stop the walk below on its first step and leave the
    # whole tail in place. Only a sample or two of that is ever an overshoot —
    # letters that genuinely end on a descent, `O P U` and the period, would
    # otherwise be walked back through half the letterform.
    i = len(points) - 1
    for _ in range(OVERSHOOT_SAMPLES):
        if i > 0 and points[i - 1][1] < points[i][1]:
            i -= 1

    while i > 0 and points[i - 1][1] >= points[i][1] and points[i - 1][1] < BASELINE_Y:
        i -= 1

    # The cut also has to stay the rightmost surviving point. The next letter is
    # placed relative to it, so cutting back behind ink this letter already laid
    # down drops the next letter straight on top of it — capitals C, E, J, S and
    # X sweep well to the right and return to the baseline before they exit.
    rightmost, running = [], -math.inf
    for x, _y in points:
        running = max(running, x)
        rightmost.append(running)
    while i < len(points) - 1 and points[i][0] < rightmost[i]:
        i += 1
    return round(i / (len(points) - 1), 4)


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
    `points` (its placed joining stroke, cut at both ends by its joins), `lead`
    (the stroke drawn before it, for a letter that joins from its second — K's
    spine, drawn and then lifted from), `trimmed` (the opening the join
    discarded), `bridge` (the connecting curve in from the previous letter) and
    `join` (the parameters that produced it, whether hand-tuned or derived, or
    None where the previous letter lifted the pen).
    """
    pairs = pairs or {}
    # A letter marked `liftAfter` hands over to nothing, so the pair it opens is
    # not a join at all and any tuning stored for it is ignored.
    joins = [None if glyphs[keys[i]][3] else pairs.get(keys[i] + keys[i + 1])
             for i in range(len(keys) - 1)]
    run = []
    exit_point = exit_dir = None
    lifted = False      # the letter before this one lifted the pen after itself
    prev_right = 0.0
    prev_from = 1.0
    for i, key in enumerate(keys):
        strokes = glyphs[key][1]
        joining = join_stroke(glyphs[key])
        full = _sample_stroke(strokes[joining]) if len(strokes) > joining else []
        if len(full) < 2:
            continue
        # The letter opens with whatever it draws first, and hands over from its
        # joining stroke; for most letters those are the same stroke.
        lead = _sample_stroke(strokes[0]) if joining else []
        opener = lead or full
        into = joins[i - 1] if i > 0 else None
        out_of = joins[i] if i < len(joins) else None

        if into:
            head = cut_index(opener, into["to"])
        elif exit_point and not lifted:
            head = lead_in_length(opener)
        else:
            head = 0
        if out_of:
            tail = cut_index(full, out_of["from"])
        elif i < len(keys) - 1 and not glyphs[key][3]:
            tail = cut_index(full, glyphs[key][2])
        else:
            tail = len(full) - 1
        if lead:
            lead, points = lead[head:], full[:tail + 1]
        else:
            points = full[head:max(tail, head + 1) + 1]
        trimmed = opener[:head + 1]

        if not exit_point:
            offset = 0.0
        elif lifted:
            # Nothing was cut, so there is no cut to place against — and these
            # letters' exits are not their rightmost ink. Measure from the ink,
            # and by LIFT_GAP: no connecting stroke is drawn here to make room
            # for, so the full join gap would read as a hole.
            offset = prev_right + LIFT_GAP - min(x for x, _ in lead + points)
        else:
            first = (lead or points)[0]
            offset = exit_point[0] + (into["dx"] if into else gap) - first[0]
        shift = lambda pts: [(x + offset, y) for x, y in pts]
        lead, points, trimmed = shift(lead), shift(points), shift(trimmed)

        bridge, used = [], None
        if exit_point and not lifted:
            opening = lead or points
            entry_dir = _direction(opening[0], opening[1])
            used = into or _auto_join(exit_point, exit_dir, opening[0], entry_dir,
                                      gap, opener, head, prev_from)
            bridge = _bridge_from(exit_point, opening[0], used)
        run.append({
            "key": key, "offset": offset, "points": points, "lead": lead,
            "trimmed": trimmed, "bridge": bridge, "join": used,
            "head": head, "tail": tail, "sample_count": len(full),
        })
        exit_point, exit_dir = points[-1], _direction(points[-2], points[-1])
        lifted = bool(glyphs[key][3])
        prev_right = max(x for x, _ in lead + points)
        prev_from = round(tail / max(1, len(full) - 1), 4)
    return run


def _auto_join(start, start_dir, end, end_dir, gap, full, head, prev_from):
    """The join the algorithm would make, expressed in the same shape a tuned
    pair uses — so tuning always begins from what the app already does. `from`
    is the previous letter's `leadOut`, since that is the letter whose tail
    this join cuts."""
    chord = math.hypot(end[0] - start[0], end[1] - start[1])
    h = chord / 3
    return {
        "from": prev_from,
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
        for field in ("points", "lead", "trimmed", "bridge"):
            item[field] = [(x + shift, y) for x, y in item[field]]
    return run
