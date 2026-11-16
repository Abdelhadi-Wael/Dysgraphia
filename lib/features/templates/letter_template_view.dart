import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/guide_geometry.dart';
import '../../core/models/stroke.dart';
import '../canvas/guide_lines.dart';
import 'letter_templates.dart';

/// Draws a letter template on guide lines with stroke-order hints: a
/// numbered dot where each stroke starts and an arrow showing its direction.
/// This is what a child sees to learn how a letter is written.
class LetterTemplateView extends StatelessWidget {
  const LetterTemplateView({super.key, required this.template});

  final LetterTemplate template;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.infinite,
      painter: _TemplatePainter(
        template,
        ink: scheme.onSurface,
        hint: scheme.primary,
        onHint: scheme.onPrimary,
        guide: scheme.outline,
        zone: scheme.primary,
      ),
    );
  }
}

class _TemplatePainter extends CustomPainter {
  _TemplatePainter(
    this.template, {
    required this.ink,
    required this.hint,
    required this.onHint,
    required this.guide,
    required this.zone,
  });

  final LetterTemplate template;
  final Color ink, hint, onHint, guide, zone;

  @override
  void paint(Canvas canvas, Size size) {
    final g = GuideGeometry(size);
    final unit = g.unit;
    paintGuideLines(
      canvas,
      size,
      g,
      guideColor: guide,
      zoneColor: zone,
      scale: 0.6,
    );

    // Centre the letter horizontally; y follows the guide lines.
    final left = size.width / 2 - template.width / 2 * unit;
    Offset px(StrokePoint p) =>
        Offset(left + p.x * unit, g.baselineY + p.y * unit);

    final inkPaint = Paint()
      ..color = ink
      ..strokeWidth = math.max(2, unit * 0.05)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final strokes = template.drawing.strokes;

    for (final s in strokes) {
      if (s.points.length == 1) {
        canvas.drawCircle(
          px(s.start),
          inkPaint.strokeWidth,
          Paint()..color = ink,
        );
        continue;
      }
      final path = Path()..moveTo(px(s.start).dx, px(s.start).dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(px(p).dx, px(p).dy);
      }
      canvas.drawPath(path, inkPaint);
      _arrow(canvas, s, px, unit);
    }

    // Numbered start dots last, so they sit on top.
    final r = math.max(7.0, unit * 0.07);
    final placed = <Offset>[];
    for (var i = 0; i < strokes.length; i++) {
      final c = _clearOf(placed, px(strokes[i].start), r);
      placed.add(c);
      canvas.drawCircle(c, r, Paint()..color = hint);
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: onHint,
            fontSize: r * 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c - Offset(label.width / 2, label.height / 2));
    }
  }

  /// Moves a badge away from earlier ones it would cover (e.g. "a", where the
  /// circle and the line start close together), so every number stays
  /// readable. Earlier badges keep their exact start points.
  static Offset _clearOf(List<Offset> placed, Offset c, double r) {
    final minGap = r * 2.1;
    for (final p in placed) {
      final d = c - p;
      if (d.distance >= minGap) continue;
      final dir = d.distance > 0
          ? d / d.distance
          : const Offset(1, -1) / math.sqrt2;
      c = p + dir * minGap;
    }
    return c;
  }

  /// Arrowhead about 60% along the stroke, pointing the way it is written.
  void _arrow(
    Canvas canvas,
    Stroke s,
    Offset Function(StrokePoint) px,
    double unit,
  ) {
    final target = s.length * 0.6;
    var travelled = 0.0;
    for (var i = 1; i < s.points.length; i++) {
      travelled += s.points[i - 1].distanceTo(s.points[i]);
      if (travelled < target) continue;
      final from = px(s.points[math.max(0, i - 2)]);
      final to = px(s.points[math.min(s.points.length - 1, i + 1)]);
      final d = to - from;
      if (d.distance == 0) return;
      final dir = d / d.distance;
      final normal = Offset(-dir.dy, dir.dx);
      final size = math.max(6.0, unit * 0.09);
      final tip = px(s.points[i]) + dir * size * 0.6;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (tip - dir * size + normal * size * 0.6).dx,
          (tip - dir * size + normal * size * 0.6).dy,
        )
        ..lineTo(
          (tip - dir * size - normal * size * 0.6).dx,
          (tip - dir * size - normal * size * 0.6).dy,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = hint);
      return;
    }
  }

  @override
  bool shouldRepaint(_TemplatePainter old) =>
      old.template != template || old.ink != ink || old.hint != hint;
}
