import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 20;
const double defaultGlyphScale = 3.0;

/// Compose a word into one continuous stroke as a dense list of points.
///
/// The output is sized so each letter is roughly 75–150 px wide at the default
/// scale of 3. Glyph entry/exit points are at the same y-height by design, so
/// adjacent letters connect cleanly without explicit connector strokes.
///
/// Throws [ArgumentError] if any character in [word] has no glyph defined in
/// [cursiveGlyphs] — the caller is responsible for filtering supported chars.
List<Offset> composeWord(String word, {double scale = defaultGlyphScale}) {
  if (word.isEmpty) return const [];

  final result = <Offset>[];
  double cursorX = 0;

  for (final char in word.split('')) {
    final glyph = cursiveGlyphs[char];
    if (glyph == null) {
      throw ArgumentError('No cursive glyph for character: "$char"');
    }

    for (var i = 0; i < glyph.beziers.length; i++) {
      final translated = glyph.beziers[i]
          .map((p) => Offset((p.dx + cursorX) * scale, p.dy * scale))
          .toList();
      final sampled = sampleCubic(translated, _pointsPerCurve);
      // Skip the first sample after the very first bezier — its start equals
      // the previous bezier's end, so we'd otherwise emit duplicate points.
      if (result.isEmpty) {
        result.addAll(sampled);
      } else {
        result.addAll(sampled.skip(1));
      }
    }
    cursorX += glyph.advanceWidth;
  }

  return result;
}
