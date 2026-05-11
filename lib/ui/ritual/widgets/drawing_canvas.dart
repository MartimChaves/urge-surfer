import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/drawing/glyphs/word_composer.dart';
import '../../../domain/drawing/weighted_tracing_controller.dart';

/// Time constant (seconds) for the camera-pan low-pass.
const double _panTimeConstant = 0.25;

/// World-space radius (pixels) within which a touch is accepted as the
/// start of the next stroke. Outside this radius, the touch is ignored.
const double _nextStrokeTouchGate = 100.0;

class DrawingCanvas extends StatefulWidget {
  final ComposedPath path;
  final VoidCallback onLetterComplete;
  final double width;
  final double height;

  const DrawingCanvas({
    super.key,
    required this.path,
    required this.onLetterComplete,
    this.width = 320,
    this.height = 320,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas>
    with SingleTickerProviderStateMixin {
  late final WeightedTracingController _controller;
  late final Ticker _ticker;
  late double _panOffsetX;
  Offset? _fingerWorld;
  Duration _lastElapsed = Duration.zero;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    final ys = widget.path.points.map((p) => p.dy);
    final yMin = ys.reduce((a, b) => a < b ? a : b);
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final dy = widget.height / 2 - (yMin + yMax) / 2;
    final centered = widget.path.points
        .map((p) => Offset(p.dx, p.dy + dy))
        .toList();
    _controller = WeightedTracingController(
      templatePoints: centered,
      strokeStartIndices: widget.path.strokeStartIndices,
      advanceThreshold: 8.0 * defaultGlyphScale,
    );
    _panOffsetX = widget.width / 2 - widget.path.letterCenterX.first;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _controller.tick(dt);

    final dtSec = dt.inMicroseconds / 1e6;
    if (dtSec > 0) {
      final target = widget.width / 2 - _cameraTargetWorldX();
      final alpha = 1 - math.exp(-dtSec / _panTimeConstant);
      _panOffsetX = _panOffsetX + (target - _panOffsetX) * alpha;
    }

    setState(() {});
    if (_controller.letterComplete && !_completedFired) {
      _completedFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLetterComplete();
      });
    }
  }

  /// Camera target tracks the letter the pen is currently inside. Between
  /// strokes (current stroke complete, next not yet started), the target
  /// hops to the next stroke's first letter so the user can see where to
  /// tap. Deferred strokes (i dots, t crossbars) don't begin at letter
  /// starts; for those, target the stroke's first point's x directly.
  double _cameraTargetWorldX() {
    final ti = _controller.templateIndex;
    final starts = widget.path.letterStartIndices;
    final ends = widget.path.letterEndIndices;
    if (_controller.currentStrokeComplete && _controller.hasNextStroke) {
      final nextStart =
          widget.path.strokeStartIndices[_controller.currentStrokeIndex + 1];
      for (var i = 0; i < starts.length; i++) {
        if (starts[i] == nextStart) return widget.path.letterCenterX[i];
      }
      return widget.path.points[nextStart].dx;
    }
    for (var i = 0; i < starts.length; i++) {
      if (ti >= starts[i] && ti <= ends[i]) {
        return widget.path.letterCenterX[i];
      }
    }
    return _controller.penPosition.dx;
  }

  Offset _toWorld(Offset local) => Offset(local.dx - _panOffsetX, local.dy);

  void _onPointerDown(PointerDownEvent e) {
    final worldFinger = _toWorld(e.localPosition);
    if (_controller.currentStrokeComplete && _controller.hasNextStroke) {
      final gateDistance =
          (worldFinger - _controller.nextStrokeStartPoint).distance;
      if (gateDistance > _nextStrokeTouchGate) return;
      _controller.advanceStroke();
    }
    _controller.setFingerTarget(worldFinger);
    _controller.penDown();
    setState(() => _fingerWorld = worldFinger);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final worldFinger = _toWorld(e.localPosition);
    _controller.setFingerTarget(worldFinger);
    setState(() => _fingerWorld = worldFinger);
  }

  void _onPointerUp(PointerEvent e) {
    _controller.penUp();
    setState(() => _fingerWorld = null);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showNextStrokeTarget =
        _controller.currentStrokeComplete && _controller.hasNextStroke;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRect(
          child: CustomPaint(
            painter: _TracingPainter(
              templatePoints: _controller.templatePoints,
              strokeStartIndices: _controller.strokeStartIndices,
              penPosition: _controller.penPosition,
              templateIndex: _controller.templateIndex,
              currentStrokeIndex: _controller.currentStrokeIndex,
              fingerWorld: _fingerWorld,
              nextStrokeTarget: showNextStrokeTarget
                  ? _controller.nextStrokeStartPoint
                  : null,
              panOffsetX: _panOffsetX,
              seedColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TracingPainter extends CustomPainter {
  final List<Offset> templatePoints;
  final List<int> strokeStartIndices;
  final Offset penPosition;
  final int templateIndex;
  final int currentStrokeIndex;
  final Offset? fingerWorld;
  final Offset? nextStrokeTarget;
  final double panOffsetX;
  final Color seedColor;

  _TracingPainter({
    required this.templatePoints,
    required this.strokeStartIndices,
    required this.penPosition,
    required this.templateIndex,
    required this.currentStrokeIndex,
    required this.fingerWorld,
    required this.nextStrokeTarget,
    required this.panOffsetX,
    required this.seedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (templatePoints.length < 2) return;

    canvas.save();
    canvas.translate(panOffsetX, 0);

    _drawTemplate(canvas);
    _drawDirectionArrows(canvas);
    _drawCompleted(canvas);
    _drawNextStrokeTarget(canvas);
    _drawPen(canvas);
    _drawFingerCursor(canvas);

    canvas.restore();
  }

  void _drawTemplate(Canvas canvas) {
    final paint = Paint()
      ..color = seedColor.withValues(alpha: 0.35)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = _buildMultiStrokePath(0, templatePoints.length - 1);
    canvas.drawPath(path, paint);
  }

  void _drawDirectionArrows(Canvas canvas) {
    const spacing = 30;
    const arrowSize = 8.0;
    const halfAngle = 0.45;

    final strokeStart = strokeStartIndices[currentStrokeIndex];
    final strokeEnd = currentStrokeIndex + 1 < strokeStartIndices.length
        ? strokeStartIndices[currentStrokeIndex + 1] - 1
        : templatePoints.length - 1;

    // Next chevron position strictly ahead of the current template index.
    final i = strokeStart +
        ((templateIndex - strokeStart) ~/ spacing + 1) * spacing;
    if (i >= strokeEnd) return;

    final prev = templatePoints[math.max(i - 2, strokeStart)];
    final next = templatePoints[math.min(i + 2, strokeEnd)];
    final dx = next.dx - prev.dx;
    final dy = next.dy - prev.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final ux = dx / len;
    final uy = dy / len;
    final tip = templatePoints[i];
    final cos = math.cos(halfAngle);
    final sin = math.sin(halfAngle);
    final bx = -ux;
    final by = -uy;
    final paint = Paint()
      ..color = seedColor.withValues(alpha: 0.55)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(
          tip.dx + (bx * cos - by * sin) * arrowSize,
          tip.dy + (bx * sin + by * cos) * arrowSize)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
          tip.dx + (bx * cos + by * sin) * arrowSize,
          tip.dy + (-bx * sin + by * cos) * arrowSize);
    canvas.drawPath(path, paint);
  }

  void _drawCompleted(Canvas canvas) {
    if (templateIndex < 1) return;
    final paint = Paint()
      ..color = seedColor.withValues(alpha: 0.7)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = _buildMultiStrokePath(0, templateIndex);
    canvas.drawPath(path, paint);
  }

  /// Builds a [Path] that connects [templatePoints] from index `from` to
  /// `to` (inclusive) using `lineTo`, but emits a `moveTo` at every stroke
  /// boundary so consecutive strokes are not visually connected.
  Path _buildMultiStrokePath(int from, int to) {
    final path = Path();
    if (to < from) return path;
    path.moveTo(templatePoints[from].dx, templatePoints[from].dy);
    for (var i = from + 1; i <= to; i++) {
      if (strokeStartIndices.contains(i)) {
        path.moveTo(templatePoints[i].dx, templatePoints[i].dy);
      } else {
        path.lineTo(templatePoints[i].dx, templatePoints[i].dy);
      }
    }
    return path;
  }

  void _drawNextStrokeTarget(Canvas canvas) {
    if (nextStrokeTarget == null) return;
    final ringPaint = Paint()
      ..color = seedColor.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(nextStrokeTarget!, 18, ringPaint);
  }

  void _drawPen(Canvas canvas) {
    canvas.drawCircle(
      penPosition,
      10,
      Paint()..color = seedColor,
    );
  }

  void _drawFingerCursor(Canvas canvas) {
    if (fingerWorld == null) return;
    final paint = Paint()
      ..color = seedColor.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(fingerWorld!, 6, paint);
  }

  @override
  bool shouldRepaint(covariant _TracingPainter old) {
    return old.penPosition != penPosition ||
        old.templateIndex != templateIndex ||
        old.currentStrokeIndex != currentStrokeIndex ||
        old.templatePoints != templatePoints ||
        old.fingerWorld != fingerWorld ||
        old.nextStrokeTarget != nextStrokeTarget ||
        old.panOffsetX != panOffsetX ||
        old.seedColor != seedColor;
  }
}
