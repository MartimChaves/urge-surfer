import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    this.width = 280,
    this.height = 240,
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
    final pathWidth = widget.templatePoints.last.dx -
        widget.templatePoints.first.dx;
    final dx = (widget.width - pathWidth) / 2;
    final dy = widget.height / 2;
    final centered = widget.templatePoints
        .map((p) => Offset(p.dx + dx, p.dy + dy))
        .toList();
    _controller = WeightedTracingController(templatePoints: centered);
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

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _controller.setFingerTarget(d.localPosition),
      onPanUpdate: (d) => _controller.setFingerTarget(d.localPosition),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _TracingPainter(
            templatePoints: _controller.templatePoints,
            penPosition: _controller.penPosition,
            templateIndex: _controller.templateIndex,
            seedColor: Theme.of(context).colorScheme.primary,
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
  final Color seedColor;

  _TracingPainter({
    required this.templatePoints,
    required this.penPosition,
    required this.templateIndex,
    required this.seedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (templatePoints.length < 2) return;

    final templatePaint = Paint()
      ..color = seedColor.withValues(alpha: 0.18)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
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
      9,
      Paint()..color = seedColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TracingPainter old) {
    return old.penPosition != penPosition ||
        old.templateIndex != templateIndex ||
        old.templatePoints != templatePoints ||
        old.seedColor != seedColor;
  }
}
