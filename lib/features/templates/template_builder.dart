/// Small drawing language for letter templates, in line units
/// (baseline y = 0, midline -0.5, top line -1, descender line +0.5;
/// y grows downwards, see docs/stroke-format.md).
library;

import 'dart:math' as math;

import '../../core/models/stroke.dart';

/// Points along part of a stroke.
typedef Segment = List<StrokePoint>;

/// Distance between generated points, in line units.
const _step = 0.03;

/// Straight line from (x1, y1) to (x2, y2).
Segment line(double x1, double y1, double x2, double y2) {
  final len = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  final n = math.max(1, (len / _step).ceil());
  return [
    for (var i = 0; i <= n; i++)
      StrokePoint(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n),
  ];
}

/// Circular (or, with [ry], elliptical) arc around (cx, cy).
///
/// Angles are in degrees **as seen on screen**: 0 = right (3 o'clock),
/// 90 = top (12 o'clock), 180 = left. A positive [sweepDeg] goes
/// counter-clockwise on screen, a negative one clockwise.
Segment arc(
  double cx,
  double cy,
  double r,
  double startDeg,
  double sweepDeg, {
  double? ry,
}) {
  final rY = ry ?? r;
  final len = sweepDeg.abs() * math.pi / 180 * math.max(r, rY);
  final n = math.max(2, (len / _step).ceil());
  return [
    for (var i = 0; i <= n; i++)
      () {
        final a = (startDeg + sweepDeg * i / n) * math.pi / 180;
        // Minus: y grows downwards, so "up" on screen is negative y.
        return StrokePoint(cx + r * math.cos(a), cy - rY * math.sin(a));
      }(),
  ];
}

/// A single tap, e.g. the dot on "i".
Segment dot(double x, double y) => [StrokePoint(x, y)];

/// Joins segments drawn without lifting the pen into one stroke.
Stroke stroke(List<Segment> segments) {
  final pts = <StrokePoint>[];
  for (final s in segments) {
    for (final p in s) {
      if (pts.isNotEmpty && pts.last.distanceTo(p) < 1e-9) continue;
      pts.add(p);
    }
  }
  return Stroke(pts);
}
