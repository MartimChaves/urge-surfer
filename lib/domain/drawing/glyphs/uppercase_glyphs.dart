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
// Add new capitals here — see 'I' below for a worked example. The glyph
// editor (debug screen, /glyph-editor) makes visual tuning easier; copy its
// "Copy as Dart" output back into this file.

import 'dart:ui' show Offset;

import 'cursive_glyph_types.dart';

const Map<String, CursiveGlyph> uppercaseGlyphs = {
  'I': CursiveGlyph(
    advanceWidth: 34,
    strokes: [
      CursiveStroke(beziers: [
        // Sweep up from baseline-left to top of ascender
        [Offset(2, 70), Offset(-2, 48), Offset(5, 18), Offset(13, 4)],
        // Broad arch over the top: right across to ~x=30, then back left to x=20
        [Offset(13, 4), Offset(26, -4), Offset(34, 10), Offset(21, 24)],
        // Descend back through to baseline
        [Offset(21, 24), Offset(13, 44), Offset(9, 60), Offset(11, 70)],
        // Exit flourish to the right
        [Offset(11, 70), Offset(19, 76), Offset(28, 70), Offset(34, 65)],
      ]),
    ],
  ),
};
