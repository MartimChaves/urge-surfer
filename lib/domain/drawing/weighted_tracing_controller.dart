import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Drives the lagged "pen" along a multi-stroke template path while the user's
/// finger is on the canvas.
///
/// State machine:
/// - **Pen up** (default at construction, also after [penUp]): the pen is
///   frozen at its current position, [setFingerTarget] is ignored, and
///   [tick] is a no-op. The user must touch the canvas to make any progress.
/// - **Pen down** (after [penDown]): the pen low-pass-filters toward the
///   finger target, and [templateIndex] advances within the current stroke
///   when the pen reaches each next template point.
///
/// Strokes are demarcated by [strokeStartIndices]. Within a stroke, the pen
/// advances continuously. Between strokes, the user must lift their finger
/// and call [advanceStroke] to teleport the pen to the next stroke's first
/// point — typically gated by the canvas on a touch landing near that point.
class WeightedTracingController {
  final List<Offset> templatePoints;
  final List<int> strokeStartIndices;
  double timeConstant;
  final double advanceThreshold;

  Offset _penPosition;
  Offset _fingerTarget;
  int _templateIndex = 0;
  int _currentStrokeIndex = 0;
  bool _isPenDown = false;

  WeightedTracingController({
    required this.templatePoints,
    List<int>? strokeStartIndices,
    this.timeConstant = 0.4,
    this.advanceThreshold = 8.0,
  })  : assert(
          templatePoints.length >= 2,
          'Template needs at least 2 points (start and end).',
        ),
        assert(timeConstant > 0, 'timeConstant must be positive.'),
        assert(advanceThreshold > 0, 'advanceThreshold must be positive.'),
        strokeStartIndices = strokeStartIndices ?? const [0],
        _penPosition = templatePoints.first,
        _fingerTarget = templatePoints.first {
    assert(
      this.strokeStartIndices.isNotEmpty && this.strokeStartIndices.first == 0,
      'strokeStartIndices must start at 0.',
    );
  }

  Offset get penPosition => _penPosition;
  int get templateIndex => _templateIndex;
  int get currentStrokeIndex => _currentStrokeIndex;
  bool get isPenDown => _isPenDown;

  /// True when the entire path has been traced (last stroke, last point).
  bool get letterComplete =>
      _currentStrokeIndex >= strokeStartIndices.length - 1 &&
      _templateIndex >= templatePoints.length - 1;

  /// True when the pen has reached the last point of the current stroke.
  bool get currentStrokeComplete =>
      _templateIndex >= _strokeEndIndex(_currentStrokeIndex);

  bool get hasNextStroke =>
      _currentStrokeIndex + 1 < strokeStartIndices.length;

  /// First template point of the next stroke (in template-coord space — i.e.
  /// the same space [templatePoints] uses, including any vertical centering
  /// the canvas applies at construction time).
  Offset get nextStrokeStartPoint =>
      hasNextStroke ? templatePoints[strokeStartIndices[_currentStrokeIndex + 1]]
                    : templatePoints.last;

  double get progress => _templateIndex / (templatePoints.length - 1);

  int _strokeEndIndex(int strokeIdx) {
    if (strokeIdx + 1 < strokeStartIndices.length) {
      return strokeStartIndices[strokeIdx + 1] - 1;
    }
    return templatePoints.length - 1;
  }

  void penDown() {
    _isPenDown = true;
  }

  void penUp() {
    _isPenDown = false;
  }

  /// Advance to the next stroke, teleporting the pen to its start point.
  /// Caller is responsible for gating this on a touch landing near
  /// [nextStrokeStartPoint] before invoking. No-op if already on the last
  /// stroke.
  void advanceStroke() {
    if (!hasNextStroke) return;
    _currentStrokeIndex++;
    _templateIndex = strokeStartIndices[_currentStrokeIndex];
    _penPosition = templatePoints[_templateIndex];
    _fingerTarget = _penPosition;
  }

  void setFingerTarget(Offset finger) {
    if (!_isPenDown) return;
    _fingerTarget = finger;
  }

  void tick(Duration dt) {
    if (!_isPenDown) return;
    final dtSec = dt.inMicroseconds / 1e6;
    if (dtSec <= 0) return;

    final alpha = 1 - math.exp(-dtSec / timeConstant);
    _penPosition = Offset.lerp(_penPosition, _fingerTarget, alpha)!;

    final strokeEnd = _strokeEndIndex(_currentStrokeIndex);
    while (_templateIndex < strokeEnd &&
        (_penPosition - templatePoints[_templateIndex + 1]).distance <
            advanceThreshold) {
      _templateIndex++;
    }
  }
}
