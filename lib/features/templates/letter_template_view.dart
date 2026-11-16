import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/guide_geometry.dart';
import '../../core/models/stroke.dart';
import '../canvas/guide_lines.dart';
import 'letter_templates.dart';
import 'stroke_timeline.dart';

/// Draws a letter template on guide lines with stroke-order hints: a
/// numbered dot where each stroke starts and an arrow showing its direction.
/// This is what a child sees to learn how a letter is written.
///
/// With [seconds] and [timeline], shows the letter part-way through the
/// "watch" animation: a faint full letter underneath, finished strokes in
/// ink, the current stroke growing with a pen dot at its tip.
class LetterTemplateView extends StatelessWidget {
  const LetterTemplateView({
    super.key,
    required this.template,
    this.seconds,
    this.timeline,
    this.showHints = true,
  }) : assert(seconds == null || timeline != null);

  final LetterTemplate template;
  final double? seconds;
  final StrokeTimeline? timeline;

  /// Numbered start dots and direction arrows. Off for a clean model to
  /// copy from.
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.infinite,
      painter: _TemplatePainter(
        template,
        seconds: seconds,
        timeline: timeline,
        showHints: showHints,
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
    required this.seconds,
    required this.timeline,
    required this.showHints,
    required this.ink,
    required this.hint,
    required this.onHint,
    required this.guide,
    required this.zone,
  });

  final LetterTemplate template;
  final double? seconds;
  final StrokeTimeline? timeline;
  final bool showHints;
  final Color ink, hint, onHint, guide, zone;

  bool get _animating => seconds != null;
  double _drawn(int i) => _animating ? timeline!.drawn(i, seconds!) : 1;
  bool _started(int i) => !_animating || timeline!.started(i, seconds!);

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

    final width = math.max(2.0, unit * 0.05);
    final strokes = template.drawing.strokes;

    if (_animating) {
      final faint = ink.withValues(alpha: 0.15);
      for (final s in strokes) {
        _drawStroke(canvas, s, 1, px, faint, width);
      }
    }

    Offset? pen;
    for (var i = 0; i < strokes.length; i++) {
      final f = _drawn(i);
      if (f == 0) continue;
      final tip = _drawStroke(canvas, strokes[i], f, px, ink, width);
      if (f == 1) {
        if (showHints) _arrow(canvas, strokes[i], px, unit);
      } else {
        pen = tip;
      }
    }
    if (!showHints) return;

    // Numbered start dots on top, each appearing when its stroke starts.
    final r = math.max(7.0, unit * 0.07);
    final placed = <Offset>[];
    for (var i = 0; i < strokes.length; i++) {
      final c = _clearOf(placed, px(strokes[i].start), r);
      placed.add(c);
      if (!_started(i)) continue;
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

    if (pen != null) {
      canvas.drawCircle(pen, r * 0.9, Paint()..color = hint);
      canvas.drawCircle(
        pen,
        r * 0.9,
        Paint()
          ..color = onHint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Draws the first [fraction] of [s] (by length); returns where it ends.
  Offset _drawStroke(
    Canvas canvas,
    Stroke s,
    double fraction,
    Offset Function(StrokePoint) px,
    Color color,
    double width,
  ) {
    if (s.points.length == 1) {
      canvas.drawCircle(px(s.start), width, Paint()..color = color);
      return px(s.start);
    }
    final limit = s.length * fraction;
    var travelled = 0.0;
    var tip = px(s.start);
    final path = Path()..moveTo(tip.dx, tip.dy);
    for (var i = 1; i < s.points.length; i++) {
      final seg = s.points[i - 1].distanceTo(s.points[i]);
      if (travelled + seg >= limit) {
        final t = seg == 0 ? 1.0 : (limit - travelled) / seg;
        tip = Offset.lerp(px(s.points[i - 1]), px(s.points[i]), t)!;
        path.lineTo(tip.dx, tip.dy);
        break;
      }
      travelled += seg;
      tip = px(s.points[i]);
      path.lineTo(tip.dx, tip.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    return tip;
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
    if (s.points.length < 2) return;
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
      final a = tip - dir * size + normal * size * 0.6;
      final b = tip - dir * size - normal * size * 0.6;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..close(),
        Paint()..color = hint,
      );
      return;
    }
  }

  @override
  bool shouldRepaint(_TemplatePainter old) =>
      old.template != template ||
      old.seconds != seconds ||
      old.showHints != showHints ||
      old.ink != ink ||
      old.hint != hint;
}
