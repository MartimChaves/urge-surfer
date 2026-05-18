#!/usr/bin/env python3
"""Convert vendored letterpaths cursive JSON files into a Dart const map.

Usage:
    python3 tool/letterpaths_to_dart.py > lib/domain/drawing/glyphs/lowercase_glyphs.dart

Input:  vendor/letterpaths/entry-low/{a..z}-lower-cursive-bezier-entry-low.json
Output: `lowercase_glyphs.dart` declaring `lowercaseGlyphs: Map<String, CursiveGlyph>`.

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

Uppercase glyphs are hand-authored in `uppercase_glyphs.dart`; punctuation in
`punctuation_glyphs.dart`. The aggregator `cursive_glyphs.dart` merges all
three maps into the public `cursiveGlyphs`.
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


HEADER = """// GENERATED FILE — initial seed from letterpaths. Hand-editable.
// Regenerate via: python3 tool/letterpaths_to_dart.py
//   (Re-running OVERWRITES this file. Back up tweaks if you've hand-tuned.)
//
// Lowercase a-z glyphs are initially derived from the letterpaths cursive
// dataset (MIT-licensed, github.com/RobinL/letterpaths). License preserved
// in vendor/letterpaths/LICENSE.
//
// Coord system (same as uppercase / punctuation):
//   x in 0..advanceWidth (left to right)
//   y: baseline = 70, x-height top = 30, y grows downward
//   ascender region (y < 30) and descender region (y > 70) are open-ended

import 'dart:ui' show Offset;

import 'cursive_glyph_types.dart';

const Map<String, CursiveGlyph> lowercaseGlyphs = {
"""


def main() -> None:
    print(HEADER, end="")
    for letter in "abcdefghijklmnopqrstuvwxyz":
        print(emit_letter(letter))
    print("};")


if __name__ == "__main__":
    main()
