import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/glyphs/word_composer.dart';

void main() {
  test('empty word yields empty composition', () {
    final composed = composeWord('');
    expect(composed.points, isEmpty);
    expect(composed.letterStartIndices, isEmpty);
    expect(composed.letterCenterX, isEmpty);
    expect(composed.isEmpty, isTrue);
  });

  test('single-letter word produces a non-trivial path with one boundary', () {
    final composed = composeWord('a');
    expect(composed.points.length, greaterThan(20));
    expect(composed.letterStartIndices, [0]);
    expect(composed.letterCenterX.length, 1);
    final maxX = composed.points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(maxX, lessThan(200));
  });

  test('multi-letter word path is wider than each individual letter', () {
    final aPoints = composeWord('a').points;
    final geePoints = composeWord('gentle').points;
    final aWidth = aPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final geeWidth = geePoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(geeWidth, greaterThan(aWidth));
  });

  test('letterStartIndices align with letter count and are monotonic', () {
    final composed = composeWord('gentle');
    expect(composed.letterStartIndices.length, 6);
    expect(composed.letterCenterX.length, 6);
    for (var i = 1; i < composed.letterStartIndices.length; i++) {
      expect(
        composed.letterStartIndices[i],
        greaterThan(composed.letterStartIndices[i - 1]),
      );
    }
    expect(composed.letterStartIndices.first, 0);
  });

  test('letterCenterX is monotonically increasing across the word', () {
    final composed = composeWord('gentle');
    for (var i = 1; i < composed.letterCenterX.length; i++) {
      expect(
        composed.letterCenterX[i],
        greaterThan(composed.letterCenterX[i - 1]),
      );
    }
  });

  test('consecutive points have no gaps wider than the advance threshold', () {
    // The WeightedTracingController defaults to advanceThreshold=8 in unit
    // coords, scaled here to 8 * defaultGlyphScale. Sample spacing must stay
    // well under that or the pen can't bridge gaps.
    final points = composeWord('gentle').points;
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
