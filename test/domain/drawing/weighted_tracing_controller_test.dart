import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/weighted_tracing_controller.dart';

void main() {
  // A simple horizontal path: 11 points from (0,0) to (100,0), 10px apart.
  final straightPath = List<Offset>.generate(11, (i) => Offset(i * 10.0, 0));

  group('WeightedTracingController initial state', () {
    test('pen starts at the first template point', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      expect(c.penPosition, straightPath.first);
      expect(c.templateIndex, 0);
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
  });

  group('WeightedTracingController pen physics', () {
    test('finger held far away with one short tick leaves pen mostly behind',
        () {
      final c = WeightedTracingController(
        templatePoints: straightPath,
        timeConstant: 0.4,
      );
      c.setFingerTarget(const Offset(100, 0));
      c.tick(const Duration(milliseconds: 16));
      // alpha = 1 - exp(-0.016/0.4) ≈ 0.0392, so pen ≈ (3.92, 0).
      expect(c.penPosition.dx, lessThan(5));
      expect(c.penPosition.dx, greaterThan(3));
    });

    test('finger at end + many ticks drives pen to end and completes letter',
        () {
      final c = WeightedTracingController(templatePoints: straightPath);
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
      final a = WeightedTracingController(templatePoints: straightPath);
      final b = WeightedTracingController(templatePoints: straightPath);
      const target = Offset(50, 0);
      a.setFingerTarget(target);
      b.setFingerTarget(target);

      // 60Hz: 60 ticks of 16667us = 1.00002s total.
      for (var i = 0; i < 60; i++) {
        a.tick(const Duration(microseconds: 16667));
      }
      // 120Hz: 120 ticks of 8333us = 0.99996s total. Close enough — both
      // controllers should have the same pen position to a tight tolerance.
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
      );
      c.setFingerTarget(const Offset(50, 200));
      for (var i = 0; i < 200; i++) {
        c.tick(const Duration(milliseconds: 16));
      }
      expect(c.templateIndex, 0);
      expect(c.letterComplete, isFalse);
    });

    test('templateIndex is monotonically non-decreasing under noisy input', () {
      final c = WeightedTracingController(templatePoints: straightPath);
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
      final c = WeightedTracingController(templatePoints: straightPath);
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

  group('WeightedTracingController defensive behavior', () {
    test('zero dt is a no-op', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.setFingerTarget(const Offset(100, 0));
      final before = c.penPosition;
      c.tick(Duration.zero);
      expect(c.penPosition, before);
      expect(c.templateIndex, 0);
    });

    test('negative dt is a no-op', () {
      final c = WeightedTracingController(templatePoints: straightPath);
      c.setFingerTarget(const Offset(100, 0));
      final before = c.penPosition;
      c.tick(const Duration(microseconds: -100));
      expect(c.penPosition, before);
      expect(c.templateIndex, 0);
    });
  });
}
