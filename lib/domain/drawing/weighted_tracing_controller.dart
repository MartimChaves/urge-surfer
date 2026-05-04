import 'dart:math' as math;
import 'dart:ui' show Offset;

class WeightedTracingController {
  final List<Offset> templatePoints;
  final double timeConstant;
  final double advanceThreshold;

  Offset _penPosition;
  Offset _fingerTarget;
  int _templateIndex = 0;

  WeightedTracingController({
    required this.templatePoints,
    this.timeConstant = 0.4,
    this.advanceThreshold = 8.0,
  })  : assert(
          templatePoints.length >= 2,
          'Template needs at least 2 points (start and end).',
        ),
        assert(timeConstant > 0, 'timeConstant must be positive.'),
        assert(advanceThreshold > 0, 'advanceThreshold must be positive.'),
        _penPosition = templatePoints.first,
        _fingerTarget = templatePoints.first;

  Offset get penPosition => _penPosition;
  int get templateIndex => _templateIndex;
  bool get letterComplete => _templateIndex >= templatePoints.length - 1;
  double get progress => _templateIndex / (templatePoints.length - 1);

  void setFingerTarget(Offset finger) {
    _fingerTarget = finger;
  }

  void tick(Duration dt) {
    final dtSec = dt.inMicroseconds / 1e6;
    if (dtSec <= 0) return;

    final alpha = 1 - math.exp(-dtSec / timeConstant);
    _penPosition = Offset.lerp(_penPosition, _fingerTarget, alpha)!;

    while (_templateIndex < templatePoints.length - 1 &&
        (_penPosition - templatePoints[_templateIndex + 1]).distance <
            advanceThreshold) {
      _templateIndex++;
    }
  }
}
