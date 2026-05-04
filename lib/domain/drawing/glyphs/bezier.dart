import 'dart:ui' show Offset;

Offset cubicBezierAt(
  double t,
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
) {
  final u = 1 - t;
  return p0 * (u * u * u) +
      p1 * (3 * u * u * t) +
      p2 * (3 * u * t * t) +
      p3 * (t * t * t);
}

List<Offset> sampleCubic(List<Offset> curve, int points) {
  assert(curve.length == 4, 'A cubic curve needs exactly 4 control points.');
  assert(points >= 2, 'Need at least 2 sample points.');
  return List<Offset>.generate(points, (i) {
    final t = i / (points - 1);
    return cubicBezierAt(t, curve[0], curve[1], curve[2], curve[3]);
  });
}
