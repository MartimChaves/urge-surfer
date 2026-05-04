import 'dart:ui' show Offset;

const int _samplePoints = 20;
const double _glyphWidth = 80.0;

/// Placeholder template path for any character: a horizontal line from
/// (0, 0) to (_glyphWidth, 0), sampled at _samplePoints points. Real
/// per-character paths land in a later step; until then every letter is
/// drawn as the same horizontal trace.
List<Offset> stubTemplateForChar(String char) {
  return List<Offset>.generate(
    _samplePoints,
    (i) => Offset(i * (_glyphWidth / (_samplePoints - 1)), 0),
  );
}
