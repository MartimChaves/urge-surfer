import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/drawing/glyphs/word_composer.dart';
import '../../../domain/drawing/weighted_tracing_controller.dart';

class DrawingCanvas extends StatefulWidget {
  final List<Offset> templatePoints;
  final VoidCallback onLetterComplete;
  final double width;
  final double height;

  const DrawingCanvas({
    super.key,
    required this.templatePoints,
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
  Duration _lastElapsed = Duration.zero;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    // Vertically center the path within the canvas. Horizontal positioning is
    // handled per-frame by the pan-scroll transform — the path stays in world
    // coords (x=0 is the start of the word).
    final ys = widget.templatePoints.map((p) => p.dy);
    final yMin = ys.reduce((a, b) => a < b ? a : b);
    final yMax = ys.reduce((a, b) => a > b ? a : b);
    final dy = widget.height / 2 - (yMin + yMax) / 2;
    final centered = widget.templatePoints
        .map((p) => Offset(p.dx, p.dy + dy))
        .toList();
    _controller = WeightedTracingController(
      templatePoints: centered,
      // advanceThreshold scales with the glyph scale so the pen advances at
      // the same perceived rate regardless of how points are scaled up.
      advanceThreshold: 8.0 * defaultGlyphScale,
    );
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _controller.tick(dt);
    setState(() {});
    if (_controller.letterComplete && !_completedFired) {
      _completedFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLetterComplete();
      });
    }
  }

  double get _panOffsetX => widget.width / 2 - _controller.penPosition.dx;

  Offset _toWorld(Offset local) =>
      Offset(local.dx - _panOffsetX, local.dy);

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
