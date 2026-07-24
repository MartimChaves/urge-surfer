// Hand-authored uppercase cursive glyphs.
//
// Coord system (same as the rest of the glyph pipeline):
//   x in 0..advanceWidth (left to right)
//   y: baseline = 70, x-height top = 30, y grows downward
//   ascender top ~ y=0, descender bottom ~ y=100
//
// Each glyph is a list of strokes; each stroke is a list of cubic beziers
// `[P0, P1, P2, P3]`. The pipeline samples each bezier into a dense point
// list and treats adjacent beziers (where the previous P3 = the next P0) as
// one continuous template path.
//
// Most letters below are starting shapes only — recognisable but rough.
// Refine via the desktop editor: `python3 tool/glyph_editor.py` (or just
// edit this file directly).

import 'dart:ui' show Offset;

import 'cursive_glyph_types.dart';

const Map<String, CursiveGlyph> uppercaseGlyphs = {
  'A': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(1.11, 61.05), Offset(2.02, 73.49), Offset(8.25, 70.75), Offset(8.25, 61.96)],
        [Offset(8.25, 61.96), Offset(16.34, 27.93), Offset(18.68, 9.07), Offset(21.67, 0.24)],
        [Offset(21.67, 0.24), Offset(26.36, 13.65), Offset(33.27, 45.12), Offset(35.70, 69.28)],
        [Offset(35.70, 69.28), Offset(36.52, 70.68), Offset(5.13, 25.73), Offset(3.30, 43.84)],
        [Offset(3.30, 43.84), Offset(10.44, 59.22), Offset(22.52, 58.30), Offset(41.74, 55.74)],
      ]),
    ],
  ),
  'B': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(-6.03, 22.80), Offset(-8.23, 4.68), Offset(5.68, 1.38), Offset(14.83, -0.45)],
        [Offset(14.83, -0.45), Offset(28.93, 3.76), Offset(28.01, 35.79), Offset(7.33, 31.58)],
        [Offset(7.33, 31.58), Offset(22.55, 19.43), Offset(34.23, 35.61), Offset(31.31, 61.05)],
        [Offset(31.31, 61.05), Offset(33.14, 60.13), Offset(22.15, 87.40), Offset(2.02, 53.18)],
        [Offset(2.02, 53.18), Offset(10.44, 34.69), Offset(-2.19, 27.19), Offset(11.54, 5.59)],
        [Offset(11.54, 5.59), Offset(-2, 23.71), Offset(10.63, 35.06), Offset(1.47, 53.18)],
        [Offset(1.47, 53.18), Offset(1.11, 54.64), Offset(-7.13, 86.12), Offset(-20.67, 58.30)],
        [Offset(-20.67, 58.30), Offset(-13.17, 70.20), Offset(-8.23, 79.35), Offset(2.39, 53.18)],
        [Offset(2.39, 53.18), Offset(8.54, 66.59), Offset(25.45, 83.19), Offset(41.74, 55.01)],
      ]),
    ],
  ),
  'C': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(-1.27, 11.08), Offset(-4.93, 25.54), Offset(37.89, 12.37), Offset(35.51, 0.84)],
        [Offset(35.51, 0.84), Offset(19.78, -0.63), Offset(4.04, 15.11), Offset(4.77, 52.99)],
        [Offset(4.77, 52.99), Offset(4.04, 87.03), Offset(34.60, 59.03), Offset(39.54, 54.82)],
      ]),
    ],
  ),
  'D': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(-8.74, 16.69), Offset(24.80, -50.90), Offset(102.67, 43.81), Offset(30.16, 69.75)],
        [Offset(30.16, 69.75), Offset(14.25, 77.11), Offset(0.10, 39.68), Offset(0.69, 68.57)],
        [Offset(0.69, 68.57), Offset(28.40, 60.90), Offset(9.83, 22.59), Offset(31.05, 12.57)],
      ]),
    ],
  ),
  'E': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(-11.39, 2.25), Offset(23.09, -12.19), Offset(29.87, 12.27), Offset(43.72, -1.58)],
        [Offset(43.72, -1.58), Offset(21.91, -6.30), Offset(-41.46, 32.02), Offset(40.19, 28.78)],
        [Offset(40.19, 28.78), Offset(-29.08, 6.67), Offset(2.75, 109.83), Offset(55.81, 47.64)],
      ]),
    ],
  ),
  'F': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(-1.37, 5.49), Offset(0.10, -24.87), Offset(62.00, 11.39), Offset(46.38, -5.41)],
        [Offset(46.38, -5.41), Offset(37.53, -18.68), Offset(14.54, 21.41), Offset(20.14, 36.44)],
        [Offset(20.14, 36.44), Offset(29.57, 84.48), Offset(-12.39, 71.00), Offset(-25.84, 62.67)],
      ]),
    ],
  ),
  'G': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(38, 16), Offset(28, -2), Offset(8, 4), Offset(4, 30)],
        [Offset(4, 30), Offset(4, 60), Offset(18, 75), Offset(40, 60)],
        [Offset(40, 60), Offset(35, 45), Offset(28, 50), Offset(38, 55)],
        [Offset(38, 55), Offset(42, 60), Offset(44, 62), Offset(46, 65)],
      ]),
    ],
  ),
  'H': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 70), Offset(3, 45), Offset(5, 20), Offset(8, 4)],
        [Offset(8, 4), Offset(8, 30), Offset(38, 25), Offset(38, 4)],
        [Offset(38, 4), Offset(38, 30), Offset(38, 50), Offset(38, 70)],
        [Offset(38, 70), Offset(42, 73), Offset(45, 68), Offset(46, 65)],
      ]),
    ],
  ),
  'I': CursiveGlyph(
    advanceWidth: 34,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(7.45, 30.43), Offset(-15.06, 18.35), Offset(23.19, 10.48), Offset(26.67, 0.42)],
        [Offset(26.67, 0.42), Offset(22.83, 8.29), Offset(21.36, 46.54), Offset(15.32, 67.95)],
        [Offset(15.32, 67.95), Offset(6.36, 73.44), Offset(-2.06, 65.39), Offset(2.51, 58.07)],
      ]),
    ],
  ),
  'J': CursiveGlyph(
    advanceWidth: 36,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(6.59, 56.51), Offset(-3.99, -7.62), Offset(36.09, -18.51), Offset(32.91, 31.40)],
        [Offset(32.91, 31.40), Offset(28.83, 48.79), Offset(36.09, 82.67), Offset(10.83, 90.69)],
        [Offset(10.83, 90.69), Offset(-2.78, 89.93), Offset(11.89, 68.27), Offset(40.48, 50.29)],
      ]),
    ],
  ),
  'K': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 70), Offset(3, 45), Offset(3, 20), Offset(5, 4)],
        [Offset(5, 4), Offset(5, 30), Offset(35, 5), Offset(30, 35)],
        [Offset(30, 35), Offset(20, 38), Offset(38, 60), Offset(32, 70)],
        [Offset(32, 70), Offset(38, 73), Offset(42, 68), Offset(46, 65)],
      ]),
    ],
  ),
  'L': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(5, 25), Offset(3, 50), Offset(8, 70)],
        [Offset(8, 70), Offset(15, 65), Offset(25, 70), Offset(35, 68)],
        [Offset(35, 68), Offset(38, 65), Offset(40, 65), Offset(42, 62)],
      ]),
    ],
  ),
  'M': CursiveGlyph(
    advanceWidth: 50,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 70), Offset(5, 30), Offset(10, 5), Offset(15, 12)],
        [Offset(15, 12), Offset(18, 30), Offset(22, 50), Offset(25, 35)],
        [Offset(25, 35), Offset(28, 15), Offset(32, 8), Offset(35, 28)],
        [Offset(35, 28), Offset(38, 48), Offset(42, 30), Offset(42, 70)],
        [Offset(42, 70), Offset(46, 73), Offset(50, 68), Offset(52, 62)],
      ]),
    ],
  ),
  'N': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 70), Offset(5, 30), Offset(10, 5), Offset(15, 15)],
        [Offset(15, 15), Offset(20, 40), Offset(28, 65), Offset(35, 25)],
        [Offset(35, 25), Offset(38, 10), Offset(40, 30), Offset(40, 70)],
        [Offset(40, 70), Offset(44, 73), Offset(46, 68), Offset(48, 62)],
      ]),
    ],
  ),
  'O': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(22, 4), Offset(5, 4), Offset(3, 35), Offset(8, 60)],
        [Offset(8, 60), Offset(15, 75), Offset(38, 70), Offset(42, 45)],
        [Offset(42, 45), Offset(44, 20), Offset(32, 4), Offset(24, 6)],
        [Offset(24, 6), Offset(28, 8), Offset(38, 15), Offset(44, 30)],
      ]),
    ],
  ),
  'P': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(8, 70), Offset(5, 45), Offset(5, 20), Offset(8, 4)],
        [Offset(8, 4), Offset(28, -2), Offset(40, 12), Offset(12, 38)],
        [Offset(12, 38), Offset(18, 40), Offset(22, 42), Offset(26, 42)],
      ]),
    ],
  ),
  'Q': CursiveGlyph(
    advanceWidth: 46,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(22, 4), Offset(5, 4), Offset(3, 35), Offset(8, 60)],
        [Offset(8, 60), Offset(15, 75), Offset(38, 70), Offset(42, 45)],
        [Offset(42, 45), Offset(44, 20), Offset(32, 4), Offset(24, 6)],
        [Offset(24, 6), Offset(28, 8), Offset(35, 35), Offset(30, 60)],
        [Offset(30, 60), Offset(35, 75), Offset(45, 78), Offset(50, 72)],
      ]),
    ],
  ),
  'R': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 70), Offset(3, 45), Offset(3, 20), Offset(8, 4)],
        [Offset(8, 4), Offset(28, -2), Offset(38, 10), Offset(12, 38)],
        [Offset(12, 38), Offset(22, 38), Offset(35, 50), Offset(38, 70)],
        [Offset(38, 70), Offset(42, 73), Offset(46, 68), Offset(48, 62)],
      ]),
    ],
  ),
  'S': CursiveGlyph(
    advanceWidth: 40,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(38, 12), Offset(32, 0), Offset(15, 0), Offset(5, 15)],
        [Offset(5, 15), Offset(-2, 35), Offset(38, 32), Offset(35, 55)],
        [Offset(35, 55), Offset(32, 75), Offset(15, 75), Offset(8, 68)],
        [Offset(8, 68), Offset(15, 72), Offset(28, 68), Offset(40, 60)],
      ]),
    ],
  ),
  'T': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0.50, 6.75), Offset(15, 0), Offset(10, 17.12), Offset(43.38, 4.50)],
      ]),
      CursiveStroke(beziers: [
        [Offset(24.62, 9.25), Offset(15, 14.62), Offset(36.12, 61.25), Offset(14.38, 69.88)],
        [Offset(14.38, 69.88), Offset(9.41, 70.49), Offset(0.75, 68.12), Offset(1, 62.75)],
        [Offset(1, 62.75), Offset(2.50, 66.62), Offset(2.88, 69.88), Offset(14.38, 69.88)],
        [Offset(14.38, 69.88), Offset(21.88, 70.12), Offset(23.38, 70), Offset(44, 55.62)],
      ]),
    ],
  ),
  'U': CursiveGlyph(
    advanceWidth: 44,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(3, 25), Offset(3, 50), Offset(10, 70)],
        [Offset(10, 70), Offset(20, 78), Offset(35, 75), Offset(40, 50)],
        [Offset(40, 50), Offset(40, 25), Offset(40, 10), Offset(42, 5)],
        [Offset(42, 5), Offset(44, 25), Offset(44, 50), Offset(46, 70)],
      ]),
    ],
  ),
  'V': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(8, 30), Offset(15, 55), Offset(20, 70)],
        [Offset(20, 70), Offset(25, 75), Offset(28, 70), Offset(35, 30)],
        [Offset(35, 30), Offset(38, 15), Offset(42, 5), Offset(44, 8)],
      ]),
    ],
  ),
  'W': CursiveGlyph(
    advanceWidth: 54,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(8, 30), Offset(12, 55), Offset(15, 70)],
        [Offset(15, 70), Offset(20, 75), Offset(22, 70), Offset(25, 30)],
        [Offset(25, 30), Offset(28, 50), Offset(30, 70), Offset(32, 70)],
        [Offset(32, 70), Offset(35, 75), Offset(38, 70), Offset(42, 30)],
        [Offset(42, 30), Offset(45, 15), Offset(50, 5), Offset(54, 8)],
      ]),
    ],
  ),
  'X': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(10, 25), Offset(15, 35), Offset(20, 38)],
        [Offset(20, 38), Offset(28, 30), Offset(35, 18), Offset(38, 8)],
        [Offset(38, 8), Offset(35, 25), Offset(28, 50), Offset(38, 70)],
        [Offset(38, 70), Offset(35, 60), Offset(15, 50), Offset(5, 70)],
        [Offset(5, 70), Offset(15, 73), Offset(28, 68), Offset(42, 62)],
      ]),
    ],
  ),
  'Y': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(10, 25), Offset(15, 35), Offset(20, 40)],
        [Offset(20, 40), Offset(25, 35), Offset(35, 15), Offset(40, 5)],
        [Offset(40, 5), Offset(35, 35), Offset(25, 60), Offset(15, 80)],
        [Offset(15, 80), Offset(8, 84), Offset(3, 76), Offset(5, 68)],
      ]),
    ],
  ),
  'Z': CursiveGlyph(
    advanceWidth: 42,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(5, 5), Offset(15, 0), Offset(35, 5), Offset(40, 12)],
        [Offset(40, 12), Offset(28, 25), Offset(10, 50), Offset(5, 65)],
        [Offset(5, 65), Offset(15, 70), Offset(35, 65), Offset(42, 70)],
        [Offset(42, 70), Offset(44, 70), Offset(46, 68), Offset(46, 65)],
      ]),
    ],
  ),
};
