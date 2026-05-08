import 'dart:ui' show Offset;

import 'bezier.dart';
import 'cursive_glyphs.dart';

const int _pointsPerCurve = 20;
const double defaultGlyphScale = 3.0;

/// Default unit-coord width of a space between words. At [defaultGlyphScale]
/// this is roughly an "n"-width gap, larger than letter-to-letter spacing
/// within a word.
const double defaultUnitSpaceWidth = 30;

/// One traceable composition (single word or whole phrase).
///
/// [points] is the dense path the controller advances along — letters plus
/// any bridging strokes between words.
///
/// [letterStartIndices] / [letterEndIndices] mark the inclusive range of
/// [points] belonging to each letter. The bridge between consecutive words
/// occupies the indices `letterEndIndices[i] + 1 .. letterStartIndices[i+1] - 1`
/// when those two letters straddle a word boundary.
///
/// [letterCenterX] is the world-space horizontal center of each letter, used
/// as the camera target while the pen is inside that letter's range.
class ComposedPath {
  final List<Offset> points;
  final List<int> letterStartIndices;
  final List<int> letterEndIndices;
  final List<double> letterCenterX;
  const ComposedPath({
    required this.points,
    required this.letterStartIndices,
    required this.letterEndIndices,
    required this.letterCenterX,
  });

  bool get isEmpty => points.isEmpty;
}

/// Compose a single word as one continuous stroke.
///
/// Throws [ArgumentError] on any character without a glyph in [cursiveGlyphs].
ComposedPath composeWord(String word, {double scale = defaultGlyphScale}) {
  final points = <Offset>[];
  final letterStartIndices = <int>[];
  final letterEndIndices = <int>[];
  final letterCenterX = <double>[];
  if (word.isEmpty) {
    return const ComposedPath(
      points: [],
      letterStartIndices: [],
      letterEndIndices: [],
      letterCenterX: [],
    );
  }
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
  );
}

/// Compose a whole phrase as a single continuous traceable path.
///
/// Splits [phrase] on spaces, composes each word in absolute phrase coords,
/// and inserts a horizontal sampled bridge between consecutive words so the
/// controller can advance through the gap. The bridge is `unitSpaceWidth`
/// wide in unit coords (scaled by [scale] at sampling time).
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
    );
  }

  final points = <Offset>[];
  final letterStartIndices = <int>[];
  final letterEndIndices = <int>[];
  final letterCenterX = <double>[];

  double cursorX = 0;
  for (var w = 0; w < words.length; w++) {
    if (w > 0) {
      // Bridge from the previous word's last sample to where the next word
      // will start. Glyph entries/exits are at y≈65 in unit coords by
      // convention, so the bridge is ~horizontal — using the previous end's
      // y keeps it geometrically continuous with whatever exit y the last
      // glyph actually emitted.
      final prevEnd = points.last;
      cursorX += unitSpaceWidth;
      final bridgeEnd = Offset(cursorX * scale, prevEnd.dy);
      _appendStraightBridge(prevEnd, bridgeEnd, points);
    }
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
  );
}

/// Appends [word]'s sampled points starting at horizontal cursor [cursorXStart]
/// (in unit coords). Returns the cursor X after the word (i.e. the rightmost
/// advance in unit coords).
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
      // The first sample of every bezier after the first equals the previous
      // bezier's last sample; skip to avoid duplicate points.
      if (points.isEmpty) {
        points.addAll(sampled);
      } else {
        points.addAll(sampled.skip(1));
      }
    }
    letterEndIndices.add(points.length - 1);
    cursorX += glyph.advanceWidth;
  }
  return cursorX;
}

void _appendStraightBridge(Offset start, Offset end, List<Offset> points) {
  // Sample density matches glyph beziers so the pen never has a gap larger
  // than a within-letter gap to bridge.
  for (var i = 1; i < _pointsPerCurve; i++) {
    final t = i / (_pointsPerCurve - 1);
    points.add(Offset(
      start.dx + (end.dx - start.dx) * t,
      start.dy + (end.dy - start.dy) * t,
    ));
  }
}
