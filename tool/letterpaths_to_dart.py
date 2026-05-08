#!/usr/bin/env python3
"""Convert vendored letterpaths cursive JSON files into a Dart const map.

Usage:
    python3 tool/letterpaths_to_dart.py > lib/domain/drawing/glyphs/cursive_glyphs.dart

Input:  vendor/letterpaths/entry-low/{a..z}-lower-cursive-bezier-entry-low.json
Output: a Dart source file declaring `cursiveGlyphs: Map<String, CursiveGlyph>`.

Coordinate normalization (per letter, since each letterpaths JSON uses its own
guides): every letter's points are transformed so its baseline maps to y=70 and
its x-height top maps to y=30, with leftSidebearing -> x=0. The same scale is
used for x and y to preserve aspect ratio. The glyph's advance width is
(rightSidebearing - leftSidebearing) * scale.

Stroke handling: consecutive 'main' phase strokes whose endpoints match
(letterpaths splits some letters' continuous motion across multiple stroke
records) are merged into a single stroke. Non-continuous main strokes (e.g. x's
two diagonals) and 'deferred' strokes (i and j dots, t crossbar) are kept as
separate strokes; the canvas treats stroke boundaries as required pen lifts.

Uppercase 'I' and the period '.' are hand-authored in the same coordinate
system and appended unchanged.
"""
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VENDOR_DIR = REPO_ROOT / "vendor" / "letterpaths" / "entry-low"

# Conventions in our coord system:
#   baseline  = y 70
#   x-height  = y 30
#   x in 0..advanceWidth, y growing downward
OUR_BASELINE = 70.0
OUR_XHEIGHT = 30.0
OUR_BODY_HEIGHT = OUR_BASELINE - OUR_XHEIGHT  # 40


def points_match(a: dict, b: dict, eps: float = 0.5) -> bool:
    return abs(a["x"] - b["x"]) < eps and abs(a["y"] - b["y"]) < eps


def strip_leads(curves: list[dict]) -> list[dict]:
    """Drop 'lead-in' curves at the start and 'lead-out' curves at the end of
    a stroke. The composer adds short bridges between consecutive letters
    within a word, so the lead flourishes (which extend past the letter's
    advance width) would otherwise force the pen to traverse backwards."""
    start = 0
    end = len(curves)
    while start < end and curves[start].get("segment") == "lead-in":
        start += 1
    while end > start and curves[end - 1].get("segment") == "lead-out":
        end -= 1
    return curves[start:end]


def merge_continuous_mains(raw_strokes: list[dict]) -> list[tuple[str, list]]:
    """Group strokes by phase, merging adjacent 'main' strokes that are
    physically continuous (last p3 == next p0). Lead-in/lead-out curves are
    stripped before continuity is evaluated so internal connection points
    drive the merge. Returns a list of (phase, curves) tuples.
    """
    grouped: list[tuple[str, list]] = []
    current_main: list | None = None
    for s in raw_strokes:
        phase = s.get("phase", "main")
        curves = strip_leads(list(s["curves"]))
        if not curves:
            continue
        if phase == "main":
            if current_main is None:
                current_main = curves
            else:
                last_p3 = current_main[-1]["p3"]
                first_p0 = curves[0]["p0"]
                if points_match(last_p3, first_p0):
                    current_main.extend(curves)
                else:
                    grouped.append(("main", current_main))
                    current_main = curves
        else:
            if current_main is not None:
                grouped.append(("main", current_main))
                current_main = None
            grouped.append((phase, curves))
    if current_main is not None:
        grouped.append(("main", current_main))
    return grouped


def emit_letter(letter: str) -> str:
    path = VENDOR_DIR / f"{letter}.json"
    with path.open() as f:
        d = json.load(f)
    g = d["guides"]
    xh = g["xHeight"]
    bl = g["baseline"]
    lsb = g["leftSidebearing"]
    rsb = g["rightSidebearing"]
    scale = OUR_BODY_HEIGHT / (bl - xh)
    advance = (rsb - lsb) * scale

    def t(p: dict) -> str:
        x = (p["x"] - lsb) * scale
        y = (p["y"] - xh) * scale + OUR_XHEIGHT
        return f"Offset({x:.2f}, {y:.2f})"

    grouped = merge_continuous_mains(d["strokes"])

    out = [
        f"  '{letter}': CursiveGlyph(",
        f"    advanceWidth: {advance:.2f},",
        f"    strokes: [",
    ]
    for phase, curves in grouped:
        out.append(f"      CursiveStroke(beziers: [  // {phase}")
        for c in curves:
            out.append(
                f"        [{t(c['p0'])}, {t(c['p1'])}, {t(c['p2'])}, {t(c['p3'])}],"
            )
        out.append("      ]),")
    out.append("    ],")
    out.append("  ),")
    return "\n".join(out)


HAND_AUTHORED_TAIL = """  'I': CursiveGlyph(
    advanceWidth: 25,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0, 65), Offset(3, 40), Offset(8, 20), Offset(12, 10)],
        [Offset(12, 10), Offset(18, 8), Offset(20, 12), Offset(15, 18)],
        [Offset(15, 18), Offset(13, 35), Offset(11, 55), Offset(8, 70)],
        [Offset(8, 70), Offset(15, 73), Offset(22, 68), Offset(25, 65)],
      ]),
    ],
  ),
  '.': CursiveGlyph(
    advanceWidth: 15,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0, 65), Offset(3, 68), Offset(5, 70), Offset(7, 70)],
        [Offset(7, 70), Offset(10, 70), Offset(12, 68), Offset(10, 65)],
        [Offset(10, 65), Offset(12, 65), Offset(13, 65), Offset(15, 65)],
      ]),
    ],
  ),"""

HEADER = """// GENERATED FILE — do not edit by hand.
// Regenerate via: python3 tool/letterpaths_to_dart.py > lib/domain/drawing/glyphs/cursive_glyphs.dart
//
// Lowercase a-z glyphs are derived from the letterpaths cursive dataset
// (MIT-licensed, github.com/RobinL/letterpaths). License preserved in
// vendor/letterpaths/LICENSE.
//
// Each letter is normalized into our coord system:
//   x in 0..advanceWidth (left to right)
//   y baseline = 70, x-height top = 30, y grows downward
//   ascender region (y < 30) and descender region (y > 70) are open-ended
//
// 'I' and '.' are hand-authored in the same coord system.

import 'dart:ui' show Offset;

class CursiveGlyph {
  final List<CursiveStroke> strokes;
  final double advanceWidth;
  const CursiveGlyph({required this.strokes, required this.advanceWidth});
}

class CursiveStroke {
  final List<List<Offset>> beziers;
  const CursiveStroke({required this.beziers});
}

const Map<String, CursiveGlyph> cursiveGlyphs = {
"""


def main() -> None:
    print(HEADER, end="")
    for letter in "abcdefghijklmnopqrstuvwxyz":
        print(emit_letter(letter))
    print(HAND_AUTHORED_TAIL)
    print("};")


if __name__ == "__main__":
    main()
