import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/weighted_tracing_controller.dart';

void main() {
  // A simple horizontal path: 11 points from (0,0) to (100,0), 10px apart.
  final straightPath = List<Offset>.generate(11, (i) => Offset(i * 10.0, 0));

  group('WeightedTracingController initial state', () {
    test('pen starts at the first template point and is up by default', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      expect(c.penPosition, straightPath.first);
      expect(c.templateIndex, 0);
      expect(c.isPenDown, isFalse);
      expect(c.letterComplete, isFalse);
      expect(c.progress, 0.0);
    });

    test('asserts when constructed with fewer than 2 points', () {
      expect(
        () => WeightedTracingController(
          templatePoints: const [Offset(0, 0)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when strokeStartIndices does not begin at 0', () {
      expect(
        () => WeightedTracingController(
          templatePoints: straightPath,
          strokeStartIndices: const [1],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WeightedTracingController pen up/down', () {
    test('tick is a no-op while pen is up', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.setFingerTarget(const Offset(100, 0));
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.penPosition, straightPath.first);
      expect(c.templateIndex, 0);
    });

    test('setFingerTarget is ignored while pen is up', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.setFingerTarget(const Offset(100, 0));
      // Now drop the pen and tick — pen target was ignored, so it should
      // still be at the start (target = templatePoints.first).
      c.penDown();
      c.tick(const Duration(milliseconds: 16));
      expect(c.penPosition, straightPath.first);
    });

    test('penDown then setFingerTarget resumes tracing', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.penDown();
      c.setFingerTarget(straightPath.last);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
        if (c.letterComplete) break;
      }
      expect(c.letterComplete, isTrue);
    });

    test('penUp mid-trace freezes pen and templateIndex', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.penDown();
      c.setFingerTarget(straightPath.last);
      // Trace partway.
      for (var i = 0; i < 30; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      final pausedPen = c.penPosition;
      final pausedIndex = c.templateIndex;
      expect(pausedIndex, greaterThan(0));
      expect(c.letterComplete, isFalse);

      // Lift, then tick a bunch — nothing should change.
      c.penUp();
      for (var i = 0; i < 100; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.penPosition, pausedPen);
      expect(c.templateIndex, pausedIndex);
    });
  });

  group('WeightedTracingController pen physics', () {
    test('finger held far away with one short tick leaves pen mostly behind',
        () {
      final c = WeightedTracingController(
        templatePoints: straightPath,
        timeConstant: 0.4,
      )..penDown();
      c.setFingerTarget(const Offset(100, 0));
      c.tick(const Duration(milliseconds: 16));
      // alpha = 1 - exp(-0.016/0.4) ≈ 0.0392, so pen ≈ (3.92, 0).
      expect(c.penPosition.dx, lessThan(5));
      expect(c.penPosition.dx, greaterThan(3));
    });

    test('finger at end + many ticks drives pen to end and completes letter',
        () {
      final c = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      c.setFingerTarget(straightPath.last);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
        if (c.letterComplete) break;
      }
      expect(c.letterComplete, isTrue);
      expect(c.templateIndex, straightPath.length - 1);
      expect(c.progress, closeTo(1.0, 1e-9));
    });

    test('frame-rate independence: 60Hz and 120Hz converge identically', () {
      final a = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      final b = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      const target = Offset(50, 0);
      a.setFingerTarget(target);
      b.setFingerTarget(target);

      for (var i = 0; i < 60; i++) {
        a.tick(const Duration(microseconds: 16667));
      }
      for (var i = 0; i < 120; i++) {
        b.tick(const Duration(microseconds: 8333));
      }

      expect(
        (a.penPosition - b.penPosition).distance,
        lessThan(0.01),
        reason: 'pen positions diverge across frame rates: '
            'a=${a.penPosition} b=${b.penPosition}',
      );
    });
  });

  group('WeightedTracingController template advancement', () {
    test('finger held off the path does not advance the index', () {
      final c = WeightedTracingController(
        templatePoints: straightPath,
        advanceThreshold: 8.0,
      )..penDown();
      c.setFingerTarget(const Offset(50, 200));
      for (var i = 0; i < 200; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.templateIndex, 0);
      expect(c.letterComplete, isFalse);
    });

    test('templateIndex is monotonically non-decreasing under noisy input', () {
      final c = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      var lastIndex = c.templateIndex;
      final targets = [
        const Offset(20, 0),
        const Offset(5, 30),
        const Offset(40, 0),
        const Offset(0, 100),
        const Offset(80, 0),
        const Offset(100, 0),
      ];
      for (final t in targets) {
        c.setFingerTarget(t);
        for (var i = 0; i < 100; i++) {
          c.tick(const Duration(milliseconds: 16));
          expect(c.templateIndex, greaterThanOrEqualTo(lastIndex));
          lastIndex = c.templateIndex;
        }
      }
    });

    test('re-trace after completion does not decrease templateIndex', () {
      final c = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      c.setFingerTarget(straightPath.last);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
        if (c.letterComplete) break;
      }
      expect(c.letterComplete, isTrue);
      final maxIndex = c.templateIndex;

      c.setFingerTarget(straightPath.first);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.templateIndex, maxIndex);
      expect(c.letterComplete, isTrue);
    });
  });

  group('WeightedTracingController multi-stroke', () {
    // Two-stroke path: stroke 0 = points 0-5 (x from 0 to 50), stroke 1 =
    // points 6-10 (x from 200 to 240). Big gap so the controller can't
    // accidentally cross.
    final twoStrokes = [
      ...List<Offset>.generate(6, (i) => Offset(i * 10.0, 0)),
      ...List<Offset>.generate(5, (i) => Offset(200.0 + i * 10.0, 0)),
    ];
    const strokeStarts = [0, 6];

    test('completing stroke 0 does not auto-cross into stroke 1', () {
      final c = WeightedTracingController(
        templatePoints: twoStrokes,
        strokeStartIndices: strokeStarts,
      )..penDown();
      c.setFingerTarget(twoStrokes[5]); // end of stroke 0
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
        if (c.currentStrokeComplete) break;
      }
      expect(c.currentStrokeComplete, isTrue);
      expect(c.letterComplete, isFalse);
      expect(c.currentStrokeIndex, 0);
      // Now drag finger toward stroke 1 — index should NOT advance past 5.
      c.setFingerTarget(twoStrokes.last);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.templateIndex, 5);
    });

    test('advanceStroke teleports pen to stroke 1 start', () {
      final c = WeightedTracingController(
        templatePoints: twoStrokes,
        strokeStartIndices: strokeStarts,
      )..penDown();
      c.setFingerTarget(twoStrokes[5]);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      c.penUp();
      c.advanceStroke();
      expect(c.currentStrokeIndex, 1);
      expect(c.penPosition, twoStrokes[6]);
      expect(c.templateIndex, 6);
    });

    test('advanceStroke is a no-op on the last stroke', () {
      final c = WeightedTracingController(
        templatePoints: twoStrokes,
        strokeStartIndices: strokeStarts,
      );
      c.advanceStroke();
      expect(c.currentStrokeIndex, 1);
      c.advanceStroke();
      expect(c.currentStrokeIndex, 1);
    });

    test('letterComplete only fires after last stroke last point', () {
      final c = WeightedTracingController(
        templatePoints: twoStrokes,
        strokeStartIndices: strokeStarts,
      )..penDown();
      c.setFingerTarget(twoStrokes[5]);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.letterComplete, isFalse);
      c.advanceStroke();
      c.setFingerTarget(twoStrokes.last);
      for (var i = 0; i < 500; i++) {
        c.tick(const Duration(milliseconds: 16));
        if (c.letterComplete) break;
      }
      expect(c.letterComplete, isTrue);
    });
  });

  group('WeightedTracingController defensive behavior', () {
    test('zero dt is a no-op', () {
      final c = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      c.setFingerTarget(const Offset(100, 0));
      final before = c.penPosition;
      c.tick(Duration.zero);
      expect(c.penPosition, before);
      expect(c.templateIndex, 0);
    });

    test('negative dt is a no-op', () {
      final c = WeightedTracingController(templatePoints: straightPath)
        ..penDown();
      c.setFingerTarget(const Offset(100, 0));
      final before = c.penPosition;
      c.tick(const Duration(microseconds: -100));
      expect(c.penPosition, before);
      expect(c.templateIndex, 0);
    });
  });
}
