import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/guide_geometry.dart';
import '../../core/models/stroke.dart';
import 'guide_lines.dart';
import 'writing_controller.dart';

/// A writing surface with handwriting guide lines.
///
/// * Records one pointer at a time (extra fingers are ignored).
/// * Palm rejection: once a stylus has been used, touch input is ignored.
/// * Optionally shows a dotted [ghost] drawing to trace over.
class WritingCanvas extends StatefulWidget {
  const WritingCanvas({
    super.key,
    required this.controller,
    this.ghost,
    this.showGuides = true,
    this.inkWidth = 0.06,
    this.onStrokeEnd,
    this.inkColorOf,
  });

  final WritingController controller;

  /// Optional colour per stroke (index into [WritingController.strokes],
  /// which includes the stroke in progress); null means the normal ink.
  /// Read at paint time, so it can reflect live checks while writing.
  final Color? Function(int index, Stroke stroke)? inkColorOf;

  /// Template to trace over, in line units.
  final Drawing? ghost;
  final bool showGuides;

  /// Ink thickness in line units (scales with the box size).
  final double inkWidth;
  final ValueChanged<Stroke>? onStrokeEnd;

  @override
  State<WritingCanvas> createState() => _WritingCanvasState();
}

class _WritingCanvasState extends State<WritingCanvas> {
  int? _activePointer;
  bool _stylusSeen = false;
  GuideGeometry? _geometry;

  bool _accepts(PointerEvent e) {
    if (e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus) {
      _stylusSeen = true;
      return true;
    }
    return !(_stylusSeen && e.kind == PointerDeviceKind.touch);
  }

  StrokePoint _point(PointerEvent e) {
    final range = e.pressureMax - e.pressureMin;
    final pressure = range > 0
        ? ((e.pressure - e.pressureMin) / range).clamp(0.0, 1.0)
        : 0.5;
    return _geometry!.toLine(
      e.localPosition,
      t: e.timeStamp.inMilliseconds,
      pressure: pressure,
    );
  }

  void _down(PointerDownEvent e) {
    if (_activePointer != null || _geometry == null || !_accepts(e)) return;
    _activePointer = e.pointer;
    widget.controller.beginStroke(_point(e));
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;
    widget.controller.addPoint(_point(e));
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    final stroke = widget.controller.endStroke();
    if (stroke != null) widget.onStrokeEnd?.call(stroke);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    widget.controller.cancelStroke();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _geometry = GuideGeometry(constraints.biggest);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: CustomPaint(
            size: constraints.biggest,
            painter: _WritingPainter(
              controller: widget.controller,
              geometry: _geometry!,
              ghost: widget.ghost,
              showGuides: widget.showGuides,
              inkWidth: widget.inkWidth,
              inkColor: scheme.primary,
              guideColor: scheme.outline,
              zoneColor: scheme.primary,
              ghostColor: scheme.outline,
              inkColorOf: widget.inkColorOf,
            ),
          ),
        );
      },
    );
  }
}

class _WritingPainter extends CustomPainter {
  _WritingPainter({
    required this.controller,
    required this.geometry,
    required this.ghost,
    required this.showGuides,
    required this.inkWidth,
    required this.inkColor,
    required this.guideColor,
    required this.zoneColor,
    required this.ghostColor,
    this.inkColorOf,
  }) : super(repaint: controller);

  final WritingController controller;
  final GuideGeometry geometry;
  final Drawing? ghost;
  final bool showGuides;
  final double inkWidth;
  final Color inkColor, guideColor, zoneColor, ghostColor;
  final Color? Function(int index, Stroke stroke)? inkColorOf;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGuides) {
      paintGuideLines(
        canvas,
        size,
        geometry,
        guideColor: guideColor,
        zoneColor: zoneColor,
      );
    }

    final g = ghost;
    if (g != null) {
      // Evenly spaced round dots, smaller than the ink so the child's line
      // covers them when traced correctly.
      final r = geometry.unit * inkWidth * 0.42;
      final dot = Paint()
        ..color = ghostColor.withValues(alpha: 0.7)
        ..isAntiAlias = true;
      for (final s in g.strokes) {
        _paintDotted(canvas, _path(s), dot, radius: r, spacing: r * 3.2);
      }
    }

    final ink = _inkPaint(inkColor, geometry.unit * inkWidth);
    final strokes = controller.strokes;
    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      ink.color = inkColorOf?.call(i, s) ?? inkColor;
      if (s.points.length == 1) {
        canvas.drawCircle(
          geometry.toPixels(s.start),
          ink.strokeWidth / 2,
          ink..style = PaintingStyle.fill,
        );
        ink.style = PaintingStyle.stroke;
      } else {
        canvas.drawPath(_path(s), ink);
      }
    }
  }

  /// Smooth path through the points using midpoint quadratic curves.
  Path _path(Stroke s) {
    final pts = [for (final p in s.points) geometry.toPixels(p)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) return path..lineTo(pts[1].dx, pts[1].dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    return path..lineTo(pts.last.dx, pts.last.dy);
  }

  /// Dots at equal distances along the path. The spacing is stretched
  /// slightly so a whole number of gaps fits the path exactly, which keeps
  /// the spacing even where a closed shape (like "o") meets itself.
  void _paintDotted(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double radius,
    required double spacing,
  }) {
    for (final metric in path.computeMetrics()) {
      final gaps = math.max(1, (metric.length / spacing).round());
      final step = metric.length / gaps;
      // On a closed shape the last dot would land on the first one.
      final count = _isClosedLoop(metric, radius) ? gaps : gaps + 1;
      for (var i = 0; i < count; i++) {
        final pos = metric.getTangentForOffset(i * step)!.position;
        canvas.drawCircle(pos, radius, paint);
      }
    }
  }

  bool _isClosedLoop(PathMetric m, double tolerance) {
    final a = m.getTangentForOffset(0)!.position;
    final b = m.getTangentForOffset(m.length)!.position;
    return (a - b).distance < tolerance;
  }

  Paint _inkPaint(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(_WritingPainter old) =>
      old.geometry.size != geometry.size ||
      old.ghost != ghost ||
      old.showGuides != showGuides ||
      old.inkWidth != inkWidth ||
      old.inkColor != inkColor ||
      old.guideColor != guideColor;
}
