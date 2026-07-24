import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 30;

/// A middle-ground size for the restored centerline alphabet: large enough
/// to feel expressive, while leaving room for ascenders and descenders in
/// the responsive tracing viewport.
const double defaultGlyphScale = 2.2;

/// Default unit-coord cursor advance between words. Letter-to-letter advance
/// inside a word is set by each glyph's [CursiveGlyph.advanceWidth]; this
/// controls the visual gap between consecutive words on the canvas.
const double defaultUnitSpaceWidth = 30;

/// Extra unit-coord spacing added after each letter's advance width, giving
/// breathing room between letter bodies that would otherwise sit too close
/// after lead-in/lead-out curve stripping.
const double defaultUnitLetterSpacing = 8.0;

/// Italic-style forward lean applied to the whole composition after letter
/// composition. Shear pivots around the baseline so x-stays-anchored there
/// while ascenders lean right and descenders trail left.
const double defaultSlantDegrees = 10.0;

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
ComposedPath composeWord(
  String word, {
  double scale = defaultGlyphScale,
  double slantDegrees = defaultSlantDegrees,
}) {
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
  _applySlant(points, scale, slantDegrees);
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
  double slantDegrees = defaultSlantDegrees,
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
    );
  }

  _applySlant(points, scale, slantDegrees);

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
    // Each word's stroke begins at its first letter's P0 — the glyph's own
    // anchor #1 — not at the baseline. Subsequent letters within the same
    // word are joined to the previous letter via a curved bridge that
    // matches exit and entry tangents.
    final bool addBridge = letterIdx > 0 && mainStroke.beziers.isNotEmpty;
    if (addBridge) {
      final firstP0 = mainStroke.beziers.first.first;
      final bridgeEnd = Offset(
        (firstP0.dx + cursorX) * scale,
        firstP0.dy * scale,
      );
      final prevGlyph = cursiveGlyphs[word[letterIdx - 1]]!;
      _appendCurvedBridge(
        points.last,
        bridgeEnd,
        _glyphExitTangent(prevGlyph),
        _glyphEntryTangent(glyph),
        points,
      );
    }
    bool firstBezierOfStroke = !addBridge;
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
          .map((p) => Offset((p.dx + deferredCursorX) * scale, p.dy * scale))
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

/// Bezier bridge from `start` to `end` that leaves `start` along `exitTangent`
/// and arrives at `end` along `entryTangent` (both unit vectors in world
/// coords). Adds 29 sampled points (skipping `start`, including `end`).
void _appendCurvedBridge(
  Offset start,
  Offset end,
  Offset exitTangent,
  Offset entryTangent,
  List<Offset> points,
) {
  final chord = end - start;
  final chordLen = chord.distance;
  if (chordLen < 0.001) return;
  final handleLen = chordLen / 3;
  final p1 = start + exitTangent * handleLen;
  final p2 = end - entryTangent * handleLen;
  final sampled = sampleCubic([start, p1, p2, end], _pointsPerCurve);
  for (var i = 1; i < sampled.length; i++) {
    points.add(sampled[i]);
  }
}

/// Unit tangent at the entry of a glyph's main stroke: direction from
/// P0 toward P1 of the first bezier. Same direction in glyph and world
/// coords (uniform scale).
Offset _glyphEntryTangent(CursiveGlyph glyph) {
  final b = glyph.strokes.first.beziers.first;
  final dir = b[1] - b[0];
  final len = dir.distance;
  return len < 0.001 ? const Offset(1, 0) : dir / len;
}

/// Unit tangent at the exit of a glyph's main stroke: direction from
/// P2 toward P3 of the last bezier.
Offset _glyphExitTangent(CursiveGlyph glyph) {
  final b = glyph.strokes.first.beziers.last;
  final dir = b[3] - b[2];
  final len = dir.distance;
  return len < 0.001 ? const Offset(1, 0) : dir / len;
}

/// Apply a baseline-anchored horizontal shear (italic slant) to all points
/// in place. Points above the baseline (smaller y) shift right; descenders
/// shift left. `letterCenterX` is measured at the baseline so it remains
/// correct without modification.
void _applySlant(List<Offset> points, double scale, double slantDegrees) {
  if (slantDegrees == 0 || points.isEmpty) return;
  final baselineY = 70.0 * scale;
  final tan = math.tan(slantDegrees * math.pi / 180);
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    points[i] = Offset(p.dx + (baselineY - p.dy) * tan, p.dy);
  }
}
