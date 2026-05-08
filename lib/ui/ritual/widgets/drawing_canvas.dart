import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/drawing/glyphs/word_composer.dart';
import '../../../domain/drawing/weighted_tracing_controller.dart';

/// Time constant (seconds) for the camera-pan low-pass. Smaller = camera
/// catches up to the active letter / pen position faster.
const double _panTimeConstant = 0.25;

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
  Duration _lastElapsed = Duration.zero;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    // Vertically center the path within the canvas. Horizontal positioning is
    // handled per-frame by the pan transform — points stay in absolute
    // phrase-world coords (x=0 is the start of the phrase).
    final ys = widget.path.points.map((p) => p.dy);
    final yMin = ys.reduce((a, b) => a < b ? a : b);
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final dy = widget.height / 2 - (yMin + yMax) / 2;
    final centered = widget.path.points
        .map((p) => Offset(p.dx, p.dy + dy))
        .toList();
    _controller = WeightedTracingController(
      templatePoints: centered,
      // advanceThreshold scales with the glyph scale so the pen advances at
      // the same perceived rate regardless of how points are scaled up.
      advanceThreshold: 8.0 * defaultGlyphScale,
    );
    // Start the camera centered on the first letter so the user opens onto a
    // still frame, not a scroll-in animation.
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

  /// While the pen is inside a letter's range, the camera target is that
  /// letter's center (camera sits still as the user traces). While the pen
  /// is in a between-words bridge, the camera follows the pen position
  /// directly so the user sees the canvas scroll smoothly across the gap.
  double _cameraTargetWorldX() {
    final ti = _controller.templateIndex;
    final starts = widget.path.letterStartIndices;
    final ends = widget.path.letterEndIndices;
    for (var i = 0; i < starts.length; i++) {
      if (ti >= starts[i] && ti <= ends[i]) {
        return widget.path.letterCenterX[i];
      }
    }
    return _controller.penPosition.dx;
  }

  Offset _toWorld(Offset local) => Offset(local.dx - _panOffsetX, local.dy);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _controller.setFingerTarget(_toWorld(d.localPosition)),
      onPanUpdate: (d) => _controller.setFingerTarget(_toWorld(d.localPosition)),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRect(
          child: CustomPaint(
            painter: _TracingPainter(
              templatePoints: _controller.templatePoints,
              penPosition: _controller.penPosition,
              templateIndex: _controller.templateIndex,
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
  final Offset penPosition;
  final int templateIndex;
  final double panOffsetX;
  final Color seedColor;

  _TracingPainter({
    required this.templatePoints,
    required this.penPosition,
    required this.templateIndex,
    required this.panOffsetX,
    required this.seedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (templatePoints.length < 2) return;

    canvas.save();
    canvas.translate(panOffsetX, 0);

    final templatePaint = Paint()
      ..color = seedColor.withValues(alpha: 0.18)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fullPath = Path()
      ..moveTo(templatePoints.first.dx, templatePoints.first.dy);
    for (var i = 1; i < templatePoints.length; i++) {
      fullPath.lineTo(templatePoints[i].dx, templatePoints[i].dy);
    }
    canvas.drawPath(fullPath, templatePaint);

    if (templateIndex >= 1) {
      final completedPaint = Paint()
        ..color = seedColor.withValues(alpha: 0.7)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final donePath = Path()
        ..moveTo(templatePoints.first.dx, templatePoints.first.dy);
      for (var i = 1; i <= templateIndex; i++) {
        donePath.lineTo(templatePoints[i].dx, templatePoints[i].dy);
      }
      canvas.drawPath(donePath, completedPaint);
    }

    canvas.drawCircle(
      penPosition,
      10,
      Paint()..color = seedColor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TracingPainter old) {
    return old.penPosition != penPosition ||
        old.templateIndex != templateIndex ||
        old.templatePoints != templatePoints ||
        old.panOffsetX != panOffsetX ||
        old.seedColor != seedColor;
  }
}
