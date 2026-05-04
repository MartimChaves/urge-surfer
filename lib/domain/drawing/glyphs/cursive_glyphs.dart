import 'dart:ui' show Offset;

// Cursive glyph definitions in unit coordinates:
//   x = 0..advanceWidth (right)
//   y = 0..100 (down)
//   baseline                 = y 70
//   x-height (top of a/c/e)  = y 30
//   ascender top (b/l/t/I)   = y 10
//   descender bottom (g)     = y 95
// Entry point of each glyph is at (0, ~65) and exit is at (advanceWidth, ~65),
// so adjacent letters connect at a consistent baseline-ish y-height with no
// explicit connector strokes needed.
//
// Each glyph is a list of cubic Bezier curves (4 control points each). They
// are written as one continuous stroke per glyph — even letters that are
// traditionally multi-stroke in school cursive (t, i, f, x, j) are stylized as
// continuous loops here. See docs.md "Cursive glyph layer" for the rationale.

class CursiveGlyph {
  final List<List<Offset>> beziers;
  final double advanceWidth;
  const CursiveGlyph({required this.beziers, required this.advanceWidth});
}

const Map<String, CursiveGlyph> cursiveGlyphs = {
  'a': CursiveGlyph(
    advanceWidth: 45,
    beziers: [
      [Offset(0, 65), Offset(10, 50), Offset(30, 30), Offset(38, 30)],
      [Offset(38, 30), Offset(35, 25), Offset(10, 25), Offset(8, 35)],
      [Offset(8, 35), Offset(5, 50), Offset(8, 65), Offset(15, 70)],
      [Offset(15, 70), Offset(25, 72), Offset(35, 70), Offset(38, 65)],
      [Offset(38, 65), Offset(40, 50), Offset(40, 35), Offset(38, 30)],
      [Offset(38, 30), Offset(40, 50), Offset(42, 60), Offset(45, 65)],
    ],
  ),
  'b': CursiveGlyph(
    advanceWidth: 35,
    beziers: [
      [Offset(0, 65), Offset(3, 45), Offset(6, 25), Offset(8, 10)],
      [Offset(8, 10), Offset(8, 30), Offset(8, 50), Offset(8, 70)],
      [Offset(8, 70), Offset(28, 75), Offset(35, 65), Offset(30, 50)],
      [Offset(30, 50), Offset(25, 35), Offset(12, 40), Offset(8, 50)],
      [Offset(8, 50), Offset(20, 55), Offset(28, 60), Offset(35, 65)],
    ],
  ),
  'c': CursiveGlyph(
    advanceWidth: 35,
    beziers: [
      [Offset(0, 65), Offset(8, 50), Offset(25, 28), Offset(33, 32)],
      [Offset(33, 32), Offset(10, 28), Offset(5, 60), Offset(20, 70)],
      [Offset(20, 70), Offset(28, 72), Offset(33, 70), Offset(35, 65)],
    ],
  ),
  'e': CursiveGlyph(
    advanceWidth: 35,
    beziers: [
      [Offset(0, 65), Offset(8, 55), Offset(15, 50), Offset(28, 50)],
      [Offset(28, 50), Offset(33, 50), Offset(33, 32), Offset(20, 30)],
      [Offset(20, 30), Offset(8, 30), Offset(5, 60), Offset(15, 70)],
      [Offset(15, 70), Offset(28, 72), Offset(33, 68), Offset(35, 65)],
    ],
  ),
  'g': CursiveGlyph(
    advanceWidth: 40,
    beziers: [
      [Offset(0, 65), Offset(10, 50), Offset(28, 30), Offset(35, 30)],
      [Offset(35, 30), Offset(33, 25), Offset(10, 25), Offset(8, 35)],
      [Offset(8, 35), Offset(5, 50), Offset(8, 65), Offset(15, 70)],
      [Offset(15, 70), Offset(25, 72), Offset(33, 70), Offset(35, 65)],
      [Offset(35, 65), Offset(37, 50), Offset(37, 35), Offset(35, 30)],
      [Offset(35, 30), Offset(35, 55), Offset(35, 80), Offset(20, 92)],
      [Offset(20, 92), Offset(8, 92), Offset(5, 85), Offset(15, 80)],
      [Offset(15, 80), Offset(25, 75), Offset(35, 68), Offset(40, 65)],
    ],
  ),
  'l': CursiveGlyph(
    advanceWidth: 25,
    beziers: [
      [Offset(0, 65), Offset(2, 45), Offset(8, 25), Offset(15, 10)],
      [Offset(15, 10), Offset(20, 30), Offset(8, 50), Offset(8, 70)],
      [Offset(8, 70), Offset(15, 70), Offset(20, 67), Offset(25, 65)],
    ],
  ),
  'n': CursiveGlyph(
    advanceWidth: 40,
    beziers: [
      [Offset(0, 65), Offset(3, 50), Offset(8, 32), Offset(10, 30)],
      [Offset(10, 30), Offset(8, 45), Offset(10, 60), Offset(12, 65)],
      [Offset(12, 65), Offset(10, 30), Offset(35, 25), Offset(33, 50)],
      [Offset(33, 50), Offset(33, 65), Offset(38, 65), Offset(40, 65)],
    ],
  ),
  't': CursiveGlyph(
    advanceWidth: 30,
    beziers: [
      [Offset(0, 65), Offset(3, 45), Offset(8, 25), Offset(12, 12)],
      [Offset(12, 12), Offset(11, 30), Offset(11, 50), Offset(11, 70)],
      [Offset(11, 70), Offset(8, 72), Offset(8, 75), Offset(12, 75)],
      [Offset(12, 75), Offset(15, 60), Offset(15, 40), Offset(20, 30)],
      [Offset(20, 30), Offset(25, 32), Offset(28, 50), Offset(30, 65)],
    ],
  ),
  'I': CursiveGlyph(
    advanceWidth: 25,
    beziers: [
      [Offset(0, 65), Offset(3, 40), Offset(8, 20), Offset(12, 10)],
      [Offset(12, 10), Offset(18, 8), Offset(20, 12), Offset(15, 18)],
      [Offset(15, 18), Offset(13, 35), Offset(11, 55), Offset(8, 70)],
      [Offset(8, 70), Offset(15, 73), Offset(22, 68), Offset(25, 65)],
    ],
  ),
  '.': CursiveGlyph(
    advanceWidth: 15,
    beziers: [
      [Offset(0, 65), Offset(3, 68), Offset(5, 70), Offset(7, 70)],
      [Offset(7, 70), Offset(10, 70), Offset(12, 68), Offset(10, 65)],
      [Offset(10, 65), Offset(12, 65), Offset(13, 65), Offset(15, 65)],
    ],
  ),
};
