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
      expect(composed.strokeStartIndices, isEmpty);
      expect(composed.isEmpty, isTrue);
    });

    test('single-letter word produces a single-stroke path', () {
      final composed = composeWord('a');
      expect(composed.points.length, greaterThan(20));
      expect(composed.letterStartIndices, [0]);
      expect(composed.letterEndIndices, [composed.points.length - 1]);
      expect(composed.strokeStartIndices, [0]);
      final maxX =
          composed.points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      expect(maxX, lessThan(200));
    });

    test('multi-letter word is one stroke', () {
      final composed = composeWord('gentle');
      expect(composed.strokeStartIndices, [0]);
      expect(composed.letterStartIndices.length, 6);
      expect(composed.letterEndIndices.length, 6);
    });

    test('letter start/end indices are monotonic and bracket points', () {
      final composed = composeWord('gentle');
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

    test('single-word phrase has one stroke', () {
      final phrase = composePhrase('gentle');
      expect(phrase.strokeStartIndices, [0]);
      expect(phrase.points.length, composeWord('gentle').points.length);
    });

    test('multi-word phrase has one stroke per word', () {
      final phrase = composePhrase('I can be gentle.');
      expect(phrase.strokeStartIndices.length, 4);
      expect(phrase.strokeStartIndices.first, 0);
      // Subsequent stroke starts must be strictly increasing and align with
      // letterStartIndices entries (each stroke begins at a letter start).
      for (var i = 1; i < phrase.strokeStartIndices.length; i++) {
        expect(phrase.strokeStartIndices[i],
            greaterThan(phrase.strokeStartIndices[i - 1]));
        expect(phrase.letterStartIndices,
            contains(phrase.strokeStartIndices[i]));
      }
    });

    test('between-strokes gap exists in absolute coords', () {
      final phrase = composePhrase('be gentle');
      // Last point of stroke 0 to first point of stroke 1 should be roughly
      // unitSpaceWidth-scaled apart (with no bridge points between them).
      final stroke1Start = phrase.strokeStartIndices[1];
      final endOfStroke0 = phrase.points[stroke1Start - 1];
      final startOfStroke1 = phrase.points[stroke1Start];
      final gap = (startOfStroke1 - endOfStroke0).distance;
      expect(gap, greaterThan(50),
          reason: 'no bridge — there should be a visible gap between words');
    });

    test('within-stroke gaps stay under advance threshold', () {
      final phrase = composePhrase('I can be gentle.');
      const maxAllowedGap = 8 * defaultGlyphScale;
      for (var i = 1; i < phrase.points.length; i++) {
        if (phrase.strokeStartIndices.contains(i)) continue;
        final gap = (phrase.points[i] - phrase.points[i - 1]).distance;
        expect(
          gap,
          lessThan(maxAllowedGap),
          reason: 'within-stroke gap of $gap at index $i exceeds threshold',
        );
      }
    });

    test('letterCenterX of second word is to the right of first word', () {
      final phrase = composePhrase('be gentle');
      final lastOfBe = phrase.letterCenterX[1];
      final firstOfGentle = phrase.letterCenterX[2];
      expect(firstOfGentle, greaterThan(lastOfBe));
    });

    test('all phrase characters in "I can be gentle." resolve', () {
      expect(() => composePhrase('I can be gentle.'), returnsNormally);
    });

    test('throws on unsupported character', () {
      expect(() => composePhrase('be brave'), throwsArgumentError);
    });
  });
}
