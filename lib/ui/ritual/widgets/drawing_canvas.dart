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

/// Half-window (template points) used for local-curvature corner detection.
/// A corner is registered when the path turns sharply within this window.
const int _cornerWindow = 5;

/// Minimum local turn angle (radians) to count as a corner. Below this, a
/// turn is treated as a smooth curve and no boundary is placed.
const double _cornerAngleThresholdRad = math.pi / 2; // 90 degrees

/// How long the engorge-and-fade flash plays after a chevron is passed.
const double _chevronFlashSec = 0.6;

/// Largest square tracing viewport. Callers may reduce this to the horizontal
/// space available on compact phones.
const double maximumTracingCanvasSize = 320.0;

class DrawingCanvas extends StatefulWidget {
  final ComposedPath path;
  final VoidCallback onLetterComplete;
  final double width;
  final double height;
  final bool lagEnabled;

  const DrawingCanvas({
    super.key,
    required this.path,
    required this.onLetterComplete,
    this.width = maximumTracingCanvasSize,
    this.height = maximumTracingCanvasSize,
    this.lagEnabled = true,
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

  // Per-stroke segment data. Segments are auto-detected at construction by
  // accumulating tangent rotation along the path; one chevron per segment,
  // placed at the segment's midpoint, pointing in the chord direction.
  late final List<List<int>> _segmentEndsByStroke;
  late final List<List<int>> _segmentMidByStroke;
  late final List<List<Offset>> _segmentDirByStroke;

  // Chevron flash state. On a segment (or stroke) transition, the newly-
  // active chevron pulses: engorged + bright, easing back to normal style
  // over [_chevronFlashSec]. The just-completed chevron simply disappears.
  Duration _flashStartElapsed = Duration.zero;
  double _flashProgress = 1.0;
  int _prevCurrentSegment = -1;
  int _prevStrokeIdx = 0;

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
      penSpeed: widget.lagEnabled ? 100.0 : double.infinity,
    );
    _computeSegments(centered);
    _panOffsetX = widget.width / 2 - widget.path.letterCenterX.first;
    _ticker = createTicker(_onTick)..start();
  }

  void _computeSegments(List<Offset> points) {
    final starts = widget.path.strokeStartIndices;
    _segmentEndsByStroke = [];
    _segmentMidByStroke = [];
    _segmentDirByStroke = [];
    for (var s = 0; s < starts.length; s++) {
      final sStart = starts[s];
      final sEnd = s + 1 < starts.length
          ? starts[s + 1] - 1
          : points.length - 1;
      final corners = _detectCorners(points, sStart, sEnd);
      final ends = [...corners, sEnd];

      final mids = <int>[];
      final dirs = <Offset>[];
      var segStart = sStart;
      for (final e in ends) {
        final mid = (segStart + e) ~/ 2;
        mids.add(mid);
        // Local tangent at the chevron's midpoint position, clamped to the
        // segment's bounds. More meaningful than the chord for curved
        // segments where chord can be small or oddly directed.
        final ta = math.max(mid - 2, segStart);
        final tb = math.min(mid + 2, e);
        final tangent = points[tb] - points[ta];
        final tlen = tangent.distance;
        dirs.add(tlen < 0.001 ? const Offset(1, 0) : tangent / tlen);
        segStart = e + 1;
      }
      _segmentEndsByStroke.add(ends);
      _segmentMidByStroke.add(mids);
      _segmentDirByStroke.add(dirs);
    }
  }

  /// Find corner template indices within `[start, end]` of `points`. A corner
  /// is a local peak of the angle between the chord `points[i] - points[i-W]`
  /// and `points[i+W] - points[i]` that exceeds [_cornerAngleThresholdRad].
  /// Consecutive above-threshold indices are collapsed to one (the peak).
  List<int> _detectCorners(List<Offset> points, int start, int end) {
    const w = _cornerWindow;
    final corners = <int>[];
    var inRegion = false;
    var peakI = -1;
    var peakAngle = 0.0;
    for (var i = start + w; i + w <= end; i++) {
      final t1 = points[i] - points[i - w];
      final t2 = points[i + w] - points[i];
      final l1 = t1.distance;
      final l2 = t2.distance;
      if (l1 < 0.001 || l2 < 0.001) continue;
      final cos = ((t1.dx * t2.dx + t1.dy * t2.dy) / (l1 * l2)).clamp(
        -1.0,
        1.0,
      );
      final angle = math.acos(cos);
      if (angle >= _cornerAngleThresholdRad) {
        if (!inRegion || angle > peakAngle) {
          peakI = i;
          peakAngle = angle;
        }
        inRegion = true;
      } else if (inRegion) {
        corners.add(peakI);
        inRegion = false;
        peakAngle = 0;
      }
    }
    if (inRegion) corners.add(peakI);
    return corners;
  }

  @override
  void didUpdateWidget(DrawingCanvas old) {
    super.didUpdateWidget(old);
    if (old.lagEnabled != widget.lagEnabled) {
      _controller.penSpeed = widget.lagEnabled ? 100.0 : double.infinity;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _controller.tick(dt);

    _updateChevronFlash(elapsed);

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

  /// Index of the segment within the current stroke that contains the
  /// controller's current `templateIndex`. -1 if there are no segments
  /// (degenerate stroke).
  int _currentSegmentIdx() {
    final si = _controller.currentStrokeIndex;
    final ends = _segmentEndsByStroke[si];
    final ti = _controller.templateIndex;
    for (var k = 0; k < ends.length; k++) {
      if (ti <= ends[k]) return k;
    }
    return ends.isEmpty ? -1 : ends.length - 1;
  }

  void _updateChevronFlash(Duration elapsed) {
    final currentStroke = _controller.currentStrokeIndex;
    if (currentStroke != _prevStrokeIdx) {
      _prevCurrentSegment = -1;
      _prevStrokeIdx = currentStroke;
      _flashStartElapsed = elapsed;
    }
    final segIdx = _currentSegmentIdx();
    if (segIdx != _prevCurrentSegment) {
      _flashStartElapsed = elapsed;
    }
    _prevCurrentSegment = segIdx;

    final since = (elapsed - _flashStartElapsed).inMicroseconds / 1e6;
    _flashProgress = (since / _chevronFlashSec).clamp(0.0, 1.0);
  }

  /// Camera target. Between strokes (current stroke complete, next not yet
  /// started), the target hops to the next stroke's first letter so the
  /// user can see where to tap. Within a stroke, the target tracks the
  /// leading edge of template progress, so the camera moves only when the
  /// user is actually advancing.
  double _cameraTargetWorldX() {
    final starts = widget.path.letterStartIndices;
    if (_controller.currentStrokeComplete && _controller.hasNextStroke) {
      final nextStart =
          widget.path.strokeStartIndices[_controller.currentStrokeIndex + 1];
      for (var i = 0; i < starts.length; i++) {
        if (starts[i] == nextStart) return widget.path.letterCenterX[i];
      }
      return widget.path.points[nextStart].dx;
    }
    return widget.path.points[_controller.templateIndex].dx;
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
    final si = _controller.currentStrokeIndex;
    final segIdx = _prevCurrentSegment;
    final mids = _segmentMidByStroke[si];
    final dirs = _segmentDirByStroke[si];
    final nextChevronIdx = (segIdx >= 0 && segIdx < mids.length)
        ? mids[segIdx]
        : -1;
    final nextChevronDir = (segIdx >= 0 && segIdx < dirs.length)
        ? dirs[segIdx]
        : Offset.zero;
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
              nextChevronIdx: nextChevronIdx,
              nextChevronDir: nextChevronDir,
              flashProgress: _flashProgress,
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
  final int nextChevronIdx;
  final Offset nextChevronDir;
  final double flashProgress;
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
    required this.nextChevronIdx,
    required this.nextChevronDir,
    required this.flashProgress,
    required this.panOffsetX,
    required this.seedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (templatePoints.length < 2) return;

    canvas.save();
    canvas.translate(panOffsetX, 0);

    _drawTemplate(canvas);
    _drawCompleted(canvas);
    _drawChevrons(canvas);
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

  void _drawChevrons(Canvas canvas) {
    if (nextChevronIdx < 0) return;
    // The newly-active chevron starts engorged + bright and eases back to
    // normal style over [_chevronFlashSec].
    final t = flashProgress;
    const baseAlpha = 0.55;
    final sizeMul = 2.0 - t;
    final alpha = 1.0 - (1.0 - baseAlpha) * t;
    _drawChevronAt(canvas, nextChevronIdx, nextChevronDir, sizeMul, alpha);
  }

  void _drawChevronAt(
    Canvas canvas,
    int idx,
    Offset dir,
    double sizeMul,
    double alpha,
  ) {
    if (alpha <= 0) return;
    if (idx < 0 || idx >= templatePoints.length) return;
    final dirLen = dir.distance;
    if (dirLen < 0.001) return;
    const baseSize = 8.0;
    const halfAngle = 0.45;

    final ux = dir.dx / dirLen;
    final uy = dir.dy / dirLen;
    final tip = templatePoints[idx];
    final cos = math.cos(halfAngle);
    final sin = math.sin(halfAngle);
    final bx = -ux;
    final by = -uy;
    final size = baseSize * sizeMul;
    final paint = Paint()
      ..color = seedColor.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = 2.0 * sizeMul
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(
        tip.dx + (bx * cos - by * sin) * size,
        tip.dy + (bx * sin + by * cos) * size,
      )
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx + (bx * cos + by * sin) * size,
        tip.dy + (-bx * sin + by * cos) * size,
      );
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
    canvas.drawCircle(penPosition, 10, Paint()..color = seedColor);
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
        old.nextChevronIdx != nextChevronIdx ||
        old.nextChevronDir != nextChevronDir ||
        old.flashProgress != flashProgress ||
        old.panOffsetX != panOffsetX ||
        old.seedColor != seedColor;
  }
}
