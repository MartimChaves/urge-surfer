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

    test('single-letter single-stroke word produces a single-stroke path', () {
      final composed = composeWord('a');
      expect(composed.points.length, greaterThan(20));
      expect(composed.letterStartIndices, [0]);
      expect(composed.letterEndIndices, [composed.points.length - 1]);
      expect(composed.strokeStartIndices, [0]);
    });

    test('single-letter multi-stroke word adds an extra stroke boundary', () {
      // 'i' has body + dot — two strokes per letter.
      final composed = composeWord('i');
      expect(composed.strokeStartIndices.length, 2);
      expect(composed.strokeStartIndices.first, 0);
    });

    test('multi-letter word with all single-stroke letters has one stroke', () {
      // "can": c, a, n are all single-stroke in the dataset.
      final composed = composeWord('can');
      expect(composed.strokeStartIndices, [0]);
      expect(composed.letterStartIndices.length, 3);
    });

    test('letter start/end indices are monotonic and bracket main strokes', () {
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
      // Letter ranges cover the main trace; any deferred strokes (e.g. the
      // 't' crossbar in "gentle") are appended past the last letter's end.
      expect(composed.letterEndIndices.last,
          lessThanOrEqualTo(composed.points.length - 1));
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

    test('within-stroke gaps stay under the advance threshold', () {
      // Skip the gap immediately before each stroke boundary — those are
      // intentional pen lifts and the canvas uses strokeStartIndices to
      // require a tap rather than tracing across.
      final composed = composeWord('gentle');
      const maxAllowedGap = 8 * defaultGlyphScale;
      final strokeStarts = composed.strokeStartIndices.toSet();
      for (var i = 1; i < composed.points.length; i++) {
        if (strokeStarts.contains(i)) continue;
        final gap = (composed.points[i] - composed.points[i - 1]).distance;
        expect(
          gap,
          lessThan(maxAllowedGap),
          reason: 'within-stroke gap of $gap between points ${i - 1} and $i '
              'exceeds threshold $maxAllowedGap',
        );
      }
    });

    test('throws on unsupported character', () {
      // '@' is not a glyph in any phrase content nor in cursiveGlyphs.
      expect(() => composeWord('a@b'), throwsArgumentError);
    });
  });

  group('composePhrase', () {
    test('empty phrase yields empty composition', () {
      expect(composePhrase('').isEmpty, isTrue);
      expect(composePhrase('   ').isEmpty, isTrue);
    });

    test('single-word phrase with multi-stroke letter defers to end', () {
      final phrase = composePhrase('gentle');
      // "gentle" main trace + t-crossbar (deferred to end) = 2 strokes.
      expect(phrase.strokeStartIndices.length, 2);
      expect(phrase.strokeStartIndices.first, 0);
    });

    test('strokes count equals words count plus deferred strokes', () {
      final clean = composePhrase('be can');
      // "be" + "can", both with all single-stroke letters = 2 word strokes.
      expect(clean.strokeStartIndices.length, 2);
      // "I can be gentle." has 4 words and 1 deferred (t-crossbar in gentle)
      // = 5 strokes total.
      final phrase = composePhrase('I can be gentle.');
      expect(phrase.strokeStartIndices.length, 5);
    });

    test('between-words gap exists in absolute coords', () {
      final phrase = composePhrase('be gentle');
      // The first stroke boundary after 0 is the start of "gentle".
      final stroke1 = phrase.strokeStartIndices[1];
      final endOfBe = phrase.points[stroke1 - 1];
      final startOfGentle = phrase.points[stroke1];
      final gap = (startOfGentle - endOfBe).distance;
      expect(gap, greaterThan(50),
          reason: 'no bridge between words — there should be a visible gap');
    });

    test('within-stroke gaps stay under advance threshold', () {
      final phrase = composePhrase('I can be gentle.');
      const maxAllowedGap = 8 * defaultGlyphScale;
      final strokeStarts = phrase.strokeStartIndices.toSet();
      for (var i = 1; i < phrase.points.length; i++) {
        if (strokeStarts.contains(i)) continue;
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
      // '@' is not a glyph in cursiveGlyphs.
      expect(() => composePhrase('be br@ve'), throwsArgumentError);
    });
  });
}
