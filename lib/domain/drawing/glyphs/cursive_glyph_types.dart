import 'dart:ui' show Offset;

/// One traceable cursive glyph: a sequence of strokes (each a list of cubic
/// bezier curves) plus an advance width for letter spacing.
///
/// Coordinates use the project's normalized glyph system:
///   x in 0..advanceWidth (left to right)
///   y: baseline = 70, x-height top = 30, y grows downward
///   ascender region (y < 30) and descender region (y > 70) are open-ended
class CursiveGlyph {
  final List<CursiveStroke> strokes;
  final double advanceWidth;
  const CursiveGlyph({required this.strokes, required this.advanceWidth});
}

class CursiveStroke {
  final List<List<Offset>> beziers;
  const CursiveStroke({required this.beziers});
}
