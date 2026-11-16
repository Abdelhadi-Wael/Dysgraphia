import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/stroke.dart';

/// Shows a [Drawing] (in line units) scaled to fit its box, e.g. a model
/// shape to copy or a past attempt in a results list.
class DrawingPreview extends StatelessWidget {
  const DrawingPreview({
    super.key,
    required this.drawing,
    this.strokeWidth = 3,
  });

  final Drawing drawing;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _PreviewPainter(
      drawing,
      Theme.of(context).colorScheme.onSurface,
      strokeWidth,
    ),
  );
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.drawing, this.color, this.strokeWidth);

  final Drawing drawing;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final b = drawing.bounds;
    if (b == null) return;
    final (minX, minY, maxX, maxY) = b;
    final pad = strokeWidth;
    final w = math.max(maxX - minX, 1e-6), h = math.max(maxY - minY, 1e-6);
    final scale = math.min(
      (size.width - 2 * pad) / w,
      (size.height - 2 * pad) / h,
    );
    // Centre the drawing in the box.
    final dx = (size.width - w * scale) / 2 - minX * scale;
    final dy = (size.height - h * scale) / 2 - minY * scale;
    Offset px(StrokePoint p) => Offset(dx + p.x * scale, dy + p.y * scale);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in drawing.strokes) {
      if (s.points.length == 1) {
        canvas.drawCircle(px(s.start), strokeWidth / 2, paint);
        continue;
      }
      final path = Path()..moveTo(px(s.start).dx, px(s.start).dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(px(p).dx, px(p).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.drawing != drawing || old.color != color;
}
