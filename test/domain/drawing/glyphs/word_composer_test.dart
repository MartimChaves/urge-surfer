import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/glyphs/word_composer.dart';

void main() {
  test('empty word yields empty list', () {
    expect(composeWord(''), isEmpty);
  });

  test('single-letter word produces a non-trivial path', () {
    final points = composeWord('a');
    expect(points.length, greaterThan(20));
    // Path stays within reasonable bounds for one scaled letter.
    final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(maxX, lessThan(200));
  });

  test('multi-letter word path is wider than each individual letter', () {
    final aPoints = composeWord('a');
    final geePoints = composeWord('gentle');
    final aWidth = aPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final geeWidth = geePoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(geeWidth, greaterThan(aWidth));
  });

  test('consecutive points have no gaps wider than the advance threshold', () {
    // The WeightedTracingController defaults to advanceThreshold=8 in unit
    // coords, scaled here to 8 * defaultGlyphScale. Sample spacing must stay
    // well under that or the pen can't bridge gaps.
    final points = composeWord('gentle');
    const maxAllowedGap = 8 * defaultGlyphScale;
    for (var i = 1; i < points.length; i++) {
      final gap = (points[i] - points[i - 1]).distance;
      expect(
        gap,
        lessThan(maxAllowedGap),
        reason: 'gap of $gap between points $i-1 and $i exceeds '
            'advanceThreshold-scale of $maxAllowedGap',
      );
    }
  });

  test('throws on unsupported character', () {
    expect(() => composeWord('z'), throwsArgumentError);
  });

  test('all phrase characters in "I can be gentle." resolve', () {
    expect(() => composeWord('I'), returnsNormally);
    expect(() => composeWord('can'), returnsNormally);
    expect(() => composeWord('be'), returnsNormally);
    expect(() => composeWord('gentle.'), returnsNormally);
  });
}
