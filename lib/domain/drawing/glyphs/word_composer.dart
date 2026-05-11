import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 20;
const double defaultGlyphScale = 3.0;

/// Default unit-coord cursor advance between words. Letter-to-letter advance
/// inside a word is set by each glyph's [CursiveGlyph.advanceWidth]; this
/// controls the visual gap between consecutive words on the canvas.
const double defaultUnitSpaceWidth = 30;

/// Extra unit-coord spacing added after each letter's advance width, giving
/// breathing room between letter bodies that would otherwise sit too close
/// after lead-in/lead-out curve stripping.
const double defaultUnitLetterSpacing = 8.0;

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

/// Compose a single word as a multi-stroke traceable path.
///
/// Most letters contribute one continuous stroke. Letters with intrinsic
/// pen-lifts (i, j, t, x) contribute additional strokes; the canvas treats
/// those as required pen-up boundaries.
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
  final strokeStartIndices = <int>[0];
  _appendWord(
    word: word,
    scale: scale,
    cursorXStart: 0,
    points: points,
    letterStartIndices: letterStartIndices,
    letterEndIndices: letterEndIndices,
    letterCenterX: letterCenterX,
    strokeStartIndices: strokeStartIndices,
  );
  return ComposedPath(
    points: points,
    letterStartIndices: letterStartIndices,
    letterEndIndices: letterEndIndices,
    letterCenterX: letterCenterX,
    strokeStartIndices: strokeStartIndices,
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
      strokeStartIndices: strokeStartIndices,
      addBaselineApproach: true,
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
  required List<int> strokeStartIndices,
  bool addBaselineApproach = false,
  double unitLetterSpacing = defaultUnitLetterSpacing,
}) {
  // Two-pass composition:
  //   Pass 1 (main trace): walk letters in order, sampling each letter's
  //     strokes[0] (the joinable main stroke) and connecting them with short
  //     bridges. This produces the word's continuous main stroke, ready to be
  //     traced without a lift.
  //   Pass 2 (deferred): emit any strokes[1+] from multi-stroke letters
  //     (i/j dots, t crossbar, x's second diagonal) as separate strokes after
  //     the main trace. Each requires a tap to begin (canvas-side gating on
  //     proximity to the stroke's first point).
  //
  // This matches how cursive is conventionally written — body first, then go
  // back to dot the i's, cross the t's — and minimizes mid-word pen lifts.

  final deferred = <(double, CursiveStroke)>[];
  double cursorX = cursorXStart;

  for (var letterIdx = 0; letterIdx < word.length; letterIdx++) {
    final char = word[letterIdx];
    final glyph = cursiveGlyphs[char];
    if (glyph == null) {
      throw ArgumentError('No cursive glyph for character: "$char"');
    }
    letterStartIndices.add(points.length);
    letterCenterX.add((cursorX + glyph.advanceWidth / 2) * scale);

    final mainStroke = glyph.strokes.first;
    bool firstBezierOfStroke;

    if (letterIdx == 0 && addBaselineApproach && mainStroke.beziers.isNotEmpty) {
      // Prepend a straight approach from the baseline down to P0 so the stroke
      // starts at a natural pen-down point (baseline Y) rather than mid-letter.
      final firstP0 = mainStroke.beziers.first.first;
      final worldP0 = Offset((firstP0.dx + cursorX) * scale, firstP0.dy * scale);
      final baselineY = 70.0 * scale;
      if (worldP0.dy < baselineY - 1.0) {
        final approachStart = Offset(worldP0.dx, baselineY);
        points.add(approachStart);
        _appendStraightBridge(approachStart, worldP0, points);
        firstBezierOfStroke = false; // worldP0 already added by bridge
      } else {
        firstBezierOfStroke = true;
      }
    } else {
      final bool addBridge = letterIdx > 0 && mainStroke.beziers.isNotEmpty;
      if (addBridge) {
        final firstP0 = mainStroke.beziers.first.first;
        final bridgeEnd =
            Offset((firstP0.dx + cursorX) * scale, firstP0.dy * scale);
        _appendStraightBridge(points.last, bridgeEnd, points);
      }
      firstBezierOfStroke = !addBridge;
    }
    for (var i = 0; i < mainStroke.beziers.length; i++) {
      final translated = mainStroke.beziers[i]
          .map((p) => Offset((p.dx + cursorX) * scale, p.dy * scale))
          .toList();
      final sampled = sampleCubic(translated, _pointsPerCurve);
      if (firstBezierOfStroke) {
        points.addAll(sampled);
        firstBezierOfStroke = false;
      } else {
        points.addAll(sampled.skip(1));
      }
    }

    letterEndIndices.add(points.length - 1);

    for (var s = 1; s < glyph.strokes.length; s++) {
      deferred.add((cursorX, glyph.strokes[s]));
    }

    cursorX += glyph.advanceWidth + unitLetterSpacing;
  }

  for (final entry in deferred) {
    final deferredCursorX = entry.$1;
    final stroke = entry.$2;
    strokeStartIndices.add(points.length);
    bool firstBezierOfStroke = true;
    for (var i = 0; i < stroke.beziers.length; i++) {
      final translated = stroke.beziers[i]
          .map((p) =>
              Offset((p.dx + deferredCursorX) * scale, p.dy * scale))
          .toList();
      final sampled = sampleCubic(translated, _pointsPerCurve);
      if (firstBezierOfStroke) {
        points.addAll(sampled);
        firstBezierOfStroke = false;
      } else {
        points.addAll(sampled.skip(1));
      }
    }
  }

  return cursorX;
}

void _appendStraightBridge(Offset start, Offset end, List<Offset> points) {
  for (var i = 1; i < _pointsPerCurve; i++) {
    final t = i / (_pointsPerCurve - 1);
    points.add(Offset(
      start.dx + (end.dx - start.dx) * t,
      start.dy + (end.dy - start.dy) * t,
    ));
  }
}
