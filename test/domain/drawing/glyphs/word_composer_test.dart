import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/glyphs/word_composer.dart';

void main() {
  group('composeWord', () {
    test('empty word yields empty composition', () {
      final composed = composeWord('');
      expect(composed.points, isEmpty);
      expect(composed.letterStartIndices, isEmpty);
      expect(composed.letterEndIndices, isEmpty);
      expect(composed.letterCenterX, isEmpty);
      expect(composed.isEmpty, isTrue);
    });

    test('single-letter word produces a non-trivial path with one boundary', () {
      final composed = composeWord('a');
      expect(composed.points.length, greaterThan(20));
      expect(composed.letterStartIndices, [0]);
      expect(composed.letterEndIndices, [composed.points.length - 1]);
      expect(composed.letterCenterX.length, 1);
      final maxX =
          composed.points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      expect(maxX, lessThan(200));
    });

    test('multi-letter word path is wider than each individual letter', () {
      final aPoints = composeWord('a').points;
      final geePoints = composeWord('gentle').points;
      final aWidth = aPoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final geeWidth = geePoints.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      expect(geeWidth, greaterThan(aWidth));
    });

    test('letter start/end indices align with letter count and are monotonic', () {
      final composed = composeWord('gentle');
      expect(composed.letterStartIndices.length, 6);
      expect(composed.letterEndIndices.length, 6);
      expect(composed.letterCenterX.length, 6);
      for (var i = 0; i < composed.letterStartIndices.length; i++) {
        expect(
          composed.letterEndIndices[i],
          greaterThanOrEqualTo(composed.letterStartIndices[i]),
        );
      }
      for (var i = 1; i < composed.letterStartIndices.length; i++) {
        expect(
          composed.letterStartIndices[i],
          greaterThan(composed.letterStartIndices[i - 1]),
        );
      }
      expect(composed.letterStartIndices.first, 0);
      expect(composed.letterEndIndices.last, composed.points.length - 1);
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
  });

  group('composePhrase', () {
    test('empty phrase yields empty composition', () {
      expect(composePhrase('').isEmpty, isTrue);
      expect(composePhrase('   ').isEmpty, isTrue);
    });

    test('single-word phrase matches composeWord shape', () {
      final phrase = composePhrase('gentle');
      final word = composeWord('gentle');
      expect(phrase.points.length, word.points.length);
      expect(phrase.letterStartIndices, word.letterStartIndices);
      expect(phrase.letterEndIndices, word.letterEndIndices);
      expect(phrase.letterCenterX, word.letterCenterX);
    });

    test('multi-word phrase has bridge points between words', () {
      final phrase = composePhrase('be gentle');
      // Bridge sits between the end of "be" and the start of "gentle":
      // letterEndIndices[1] (end of "e" in "be") + 1 .. letterStartIndices[2]
      // (start of "g") - 1.
      final endOfBe = phrase.letterEndIndices[1];
      final startOfGentle = phrase.letterStartIndices[2];
      expect(
        startOfGentle - endOfBe,
        greaterThan(1),
        reason: 'expected at least one bridge sample between words',
      );
    });

    test('letterCenterX of second word is to the right of first word', () {
      final phrase = composePhrase('be gentle');
      final lastOfBe = phrase.letterCenterX[1];
      final firstOfGentle = phrase.letterCenterX[2];
      expect(firstOfGentle, greaterThan(lastOfBe));
    });

    test('full phrase bridge gap respects advance threshold', () {
      final points = composePhrase('I can be gentle.').points;
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

    test('all phrase characters in "I can be gentle." resolve', () {
      expect(() => composePhrase('I can be gentle.'), returnsNormally);
    });

    test('throws on unsupported character', () {
      expect(() => composePhrase('be brave'), throwsArgumentError);
    });
  });
}
