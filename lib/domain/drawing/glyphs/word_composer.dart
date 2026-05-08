import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 20;
const double defaultGlyphScale = 3.0;

/// One word composed into a single continuous traceable stroke.
///
/// [points] is the dense path the controller advances along. [letterStartIndices]
/// gives the index in [points] where each letter begins; [letterCenterX] is the
/// world-space horizontal center of each letter. Both are aligned by index, so
/// `letterCenterX[i]` corresponds to the letter that begins at
/// `letterStartIndices[i]`.
class ComposedWord {
  final List<Offset> points;
  final List<int> letterStartIndices;
  final List<double> letterCenterX;
  const ComposedWord({
    required this.points,
    required this.letterStartIndices,
    required this.letterCenterX,
  });

  bool get isEmpty => points.isEmpty;
}

/// Compose a word into one continuous stroke as a dense list of points.
///
/// The output is sized so each letter is roughly 75–150 px wide at the default
/// scale of 3. Glyph entry/exit points are at the same y-height by design, so
/// adjacent letters connect cleanly without explicit connector strokes.
///
/// Throws [ArgumentError] if any character in [word] has no glyph defined in
/// [cursiveGlyphs] — the caller is responsible for filtering supported chars.
ComposedWord composeWord(String word, {double scale = defaultGlyphScale}) {
  if (word.isEmpty) {
    return const ComposedWord(
      points: [],
      letterStartIndices: [],
      letterCenterX: [],
    );
  }

  final points = <Offset>[];
  final letterStartIndices = <int>[];
  final letterCenterX = <double>[];
  double cursorX = 0;

  for (final char in word.split('')) {
    final glyph = cursiveGlyphs[char];
    if (glyph == null) {
      throw ArgumentError('No cursive glyph for character: "$char"');
    }

    letterStartIndices.add(points.length);
    letterCenterX.add((cursorX + glyph.advanceWidth / 2) * scale);

    for (var i = 0; i < glyph.beziers.length; i++) {
      final translated = glyph.beziers[i]
          .map((p) => Offset((p.dx + cursorX) * scale, p.dy * scale))
          .toList();
      final sampled = sampleCubic(translated, _pointsPerCurve);
      // Skip the first sample after the very first bezier — its start equals
      // the previous bezier's end, so we'd otherwise emit duplicate points.
      if (points.isEmpty) {
        points.addAll(sampled);
      } else {
        points.addAll(sampled.skip(1));
      }
    }
    cursorX += glyph.advanceWidth;
  }

  return ComposedWord(
    points: points,
    letterStartIndices: letterStartIndices,
    letterCenterX: letterCenterX,
  );
}
