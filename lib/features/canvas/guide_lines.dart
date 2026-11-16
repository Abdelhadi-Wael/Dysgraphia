import 'dart:ui';

import '../../core/models/guide_geometry.dart';

/// Standard handwriting-paper lines, all in one colour. Each style has one
/// meaning:
///   * thin solid  → outer limits (top line, descender line)
///   * dashed      → midline, the height of small letters
///   * bold solid  → baseline, where every letter sits
/// The band between midline and baseline is lightly tinted: that is where
/// the body of every lowercase letter goes.
///
/// [scale] shrinks line widths and dashes for small previews.
void paintGuideLines(
  Canvas canvas,
  Size size,
  GuideGeometry geometry, {
  required Color guideColor,
  required Color zoneColor,
  double scale = 1,
}) {
  canvas.drawRect(
    Rect.fromLTRB(0, geometry.midlineY, size.width, geometry.baselineY),
    Paint()..color = zoneColor.withValues(alpha: 0.07),
  );

  final thin = Paint()
    ..color = guideColor.withValues(alpha: 0.5)
    ..strokeWidth = 1.5 * scale;
  final bold = Paint()
    ..color = guideColor.withValues(alpha: 0.9)
    ..strokeWidth = 3 * scale;

  void line(double y, Paint p) =>
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);

  line(geometry.topLineY, thin);
  final dash = 10.0 * scale, gap = 8.0 * scale;
  for (var x = 0.0; x < size.width; x += dash + gap) {
    canvas.drawLine(
      Offset(x, geometry.midlineY),
      Offset((x + dash).clamp(0, size.width), geometry.midlineY),
      thin,
    );
  }
  line(geometry.baselineY, bold);
  line(geometry.descenderY, thin);
}
