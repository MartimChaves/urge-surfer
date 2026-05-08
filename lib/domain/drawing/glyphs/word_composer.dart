import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 20;
const double defaultGlyphScale = 3.0;

/// Default unit-coord cursor advance between words. Letter-to-letter advance
/// inside a word is set by each glyph's [CursiveGlyph.advanceWidth]; this
/// controls the visual gap between consecutive words on the canvas.
const double defaultUnitSpaceWidth = 30;

/// One traceable composition (single word or whole phrase), possibly with
/// multiple discrete strokes.
///
/// [points] is the dense path the controller advances along. The path is
/// segmented into strokes by [strokeStartIndices] — each stroke must be
/// completed (with the user's finger on the canvas) before the next can
/// begin. Between consecutive strokes the points list jumps in absolute
/// coords; the painter must `moveTo` rather than `lineTo` at those indices.
///
/// [letterStartIndices] / [letterEndIndices] mark the inclusive range of
/// [points] belonging to each letter, used by the canvas to compute
/// per-letter camera focus.
///
/// [letterCenterX] is the world-space horizontal center of each letter.
class ComposedPath {
  final List<Offset> points;
  final List<int> letterStartIndices;
  final List<int> letterEndIndices;
  final List<double> letterCenterX;
  final List<int> strokeStartIndices;
  const ComposedPath({
    required this.points,
    required this.letterStartIndices,
    required this.letterEndIndices,
    required this.letterCenterX,
    required this.strokeStartIndices,
  });

  bool get isEmpty => points.isEmpty;
}

/// Compose a single word as one continuous stroke.
///
/// Throws [ArgumentError] on any character without a glyph in [cursiveGlyphs].
ComposedPath composeWord(String word, {double scale = defaultGlyphScale}) {
  if (word.isEmpty) {
    return const ComposedPath(
      points: [],
      letterStartIndices: [],
      letterEndIndices: [],
      letterCenterX: [],
      strokeStartIndices: [],
    );
  }
  final points = <Offset>[];
  final letterStartIndices = <int>[];
  final letterEndIndices = <int>[];
  final letterCenterX = <double>[];
  _appendWord(
    word: word,
    scale: scale,
    cursorXStart: 0,
    points: points,
    letterStartIndices: letterStartIndices,
    letterEndIndices: letterEndIndices,
    letterCenterX: letterCenterX,
  );
  return ComposedPath(
    points: points,
    letterStartIndices: letterStartIndices,
    letterEndIndices: letterEndIndices,
    letterCenterX: letterCenterX,
    strokeStartIndices: const [0],
  );
}

/// Compose a whole phrase as a single multi-stroke traceable path.
///
/// Splits [phrase] on spaces and composes each word in absolute phrase coords.
/// Each word is one stroke; the user must lift their finger between words and
/// touch down again near the next word's start to begin tracing it.
///
/// Throws [ArgumentError] on any character without a glyph in [cursiveGlyphs].
ComposedPath composePhrase(
  String phrase, {
  double scale = defaultGlyphScale,
  double unitSpaceWidth = defaultUnitSpaceWidth,
}) {
  final words = phrase.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) {
    return const ComposedPath(
      points: [],
      letterStartIndices: [],
      letterEndIndices: [],
      letterCenterX: [],
      strokeStartIndices: [],
    );
  }

  final points = <Offset>[];
  final letterStartIndices = <int>[];
  final letterEndIndices = <int>[];
  final letterCenterX = <double>[];
  final strokeStartIndices = <int>[];

  double cursorX = 0;
  for (var w = 0; w < words.length; w++) {
    if (w > 0) cursorX += unitSpaceWidth;
    strokeStartIndices.add(points.length);
    cursorX = _appendWord(
      word: words[w],
      scale: scale,
      cursorXStart: cursorX,
      points: points,
      letterStartIndices: letterStartIndices,
      letterEndIndices: letterEndIndices,
      letterCenterX: letterCenterX,
    );
  }

  return ComposedPath(
    points: points,
    letterStartIndices: letterStartIndices,
    letterEndIndices: letterEndIndices,
    letterCenterX: letterCenterX,
    strokeStartIndices: strokeStartIndices,
  );
}

double _appendWord({
  required String word,
  required double scale,
  required double cursorXStart,
  required List<Offset> points,
  required List<int> letterStartIndices,
  required List<int> letterEndIndices,
  required List<double> letterCenterX,
}) {
  double cursorX = cursorXStart;
  bool atStrokeStart = true;
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
      // First bezier of the stroke: include the full sample (this is where
      // the stroke begins). Every subsequent bezier (including the first
      // bezier of a non-first letter within the stroke) shares its P0 with
      // the previous bezier's P3, so skip the duplicate sample.
      if (atStrokeStart) {
        points.addAll(sampled);
        atStrokeStart = false;
      } else {
        points.addAll(sampled.skip(1));
      }
    }
    letterEndIndices.add(points.length - 1);
    cursorX += glyph.advanceWidth;
  }
  return cursorX;
}
