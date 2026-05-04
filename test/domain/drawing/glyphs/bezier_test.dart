import 'package:flutter_test/flutter_test.dart';
import 'package:urge_surfer/domain/drawing/glyphs/bezier.dart';

void main() {
  group('cubicBezierAt', () {
    const p0 = Offset(0, 0);
    const p1 = Offset(10, 100);
    const p2 = Offset(90, 100);
    const p3 = Offset(100, 0);

    test('t=0 returns the first control point', () {
      expect(cubicBezierAt(0, p0, p1, p2, p3), p0);
    });

    test('t=1 returns the last control point', () {
      expect(cubicBezierAt(1, p0, p1, p2, p3), p3);
    });

    test('midpoint of a straight-line bezier is the geometric midpoint', () {
      const a = Offset(0, 0);
      const b = Offset(100, 0);
      // All control points on the line a->b: bezier collapses to the line.
      const c1 = Offset(33, 0);
      const c2 = Offset(67, 0);
      final mid = cubicBezierAt(0.5, a, c1, c2, b);
      expect(mid.dx, closeTo(50, 0.001));
      expect(mid.dy, closeTo(0, 0.001));
    });
  });

  group('sampleCubic', () {
    const curve = [
      Offset(0, 0),
      Offset(10, 100),
      Offset(90, 100),
      Offset(100, 0),
    ];

    test('produces exactly N points', () {
      expect(sampleCubic(curve, 20).length, 20);
      expect(sampleCubic(curve, 2).length, 2);
    });

    test('first sample is P0, last sample is P3', () {
      final points = sampleCubic(curve, 30);
      expect(points.first, curve[0]);
      expect(points.last, curve[3]);
    });
  });
}
