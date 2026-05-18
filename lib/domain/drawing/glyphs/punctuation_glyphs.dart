// Hand-authored punctuation glyphs. Same coord system as the lowercase /
// uppercase files; see `uppercase_glyphs.dart` for a worked example.

import 'dart:ui' show Offset;

import 'cursive_glyph_types.dart';

const Map<String, CursiveGlyph> punctuationGlyphs = {
  '.': CursiveGlyph(
    advanceWidth: 15,
    strokes: [
      CursiveStroke(beziers: [
        [Offset(0, 65), Offset(3, 68), Offset(5, 70), Offset(7, 70)],
        [Offset(7, 70), Offset(10, 70), Offset(12, 68), Offset(10, 65)],
        [Offset(10, 65), Offset(12, 65), Offset(13, 65), Offset(15, 65)],
      ]),
    ],
  ),
};
