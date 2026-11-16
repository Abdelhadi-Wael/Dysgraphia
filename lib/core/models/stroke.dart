/// Raw handwriting data.
///
/// Coordinates are stored in **line units**, not pixels, so that the same
/// letter written large or small (or on a different screen) compares equally:
///   * y = 0    → baseline
///   * y = -1   → top line (height of capitals / tall letters like "l")
///   * y = -0.5 → midline (height of small letters like "a")
///   * y = 0.5  → descender line (bottom of "g", "p", "y")
///   * x grows to the right, in the same unit as y.
/// See [GuideGeometry] for the pixel ↔ line-unit conversion.
library;

import 'dart:math' as math;

class StrokePoint {
  const StrokePoint(this.x, this.y, {this.t = 0, this.pressure = 0.5});

  final double x;
  final double y;

  /// Milliseconds since the first point of the whole drawing.
  final int t;

  /// 0..1. Devices without pressure report a constant value.
  final double pressure;

  double distanceTo(StrokePoint o) =>
      math.sqrt(math.pow(x - o.x, 2) + math.pow(y - o.y, 2));

  Map<String, dynamic> toJson() => {
    'x': _r(x),
    'y': _r(y),
    't': t,
    'p': _r(pressure),
  };

  factory StrokePoint.fromJson(Map<String, dynamic> j) => StrokePoint(
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    t: (j['t'] as num?)?.toInt() ?? 0,
    pressure: (j['p'] as num?)?.toDouble() ?? 0.5,
  );

  @override
  String toString() =>
      'P(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, t=$t)';
}

/// One continuous pen-down → pen-up movement.
class Stroke {
  Stroke(List<StrokePoint> points) : points = List.unmodifiable(points);

  final List<StrokePoint> points;

  bool get isEmpty => points.isEmpty;
  StrokePoint get start => points.first;
  StrokePoint get end => points.last;

  /// Total path length in line units.
  double get length {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += points[i - 1].distanceTo(points[i]);
    }
    return sum;
  }

  /// Duration in milliseconds.
  int get duration => points.isEmpty ? 0 : points.last.t - points.first.t;

  List<Map<String, dynamic>> toJson() => [for (final p in points) p.toJson()];

  factory Stroke.fromJson(List<dynamic> j) => Stroke([
    for (final p in j) StrokePoint.fromJson(p as Map<String, dynamic>),
  ]);
}

/// Everything written in one attempt (one letter, word or drill), in order.
class Drawing {
  Drawing(List<Stroke> strokes) : strokes = List.unmodifiable(strokes);

  static final empty = Drawing(const []);

  final List<Stroke> strokes;

  bool get isEmpty => strokes.isEmpty;
  int get strokeCount => strokes.length;
  Iterable<StrokePoint> get allPoints => strokes.expand((s) => s.points);

  /// Bounding box as (minX, minY, maxX, maxY), or null when empty.
  (double, double, double, double)? get bounds {
    if (isEmpty) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in allPoints) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    return (minX, minY, maxX, maxY);
  }

  /// The same drawing moved by (dx, dy) line units, e.g. to centre a letter.
  Drawing shifted(double dx, double dy) => Drawing([
    for (final s in strokes)
      Stroke([
        for (final p in s.points)
          StrokePoint(p.x + dx, p.y + dy, t: p.t, pressure: p.pressure),
      ]),
  ]);

  Map<String, dynamic> toJson() => {
    'strokes': [for (final s in strokes) s.toJson()],
  };

  factory Drawing.fromJson(Map<String, dynamic> j) => Drawing([
    for (final s in j['strokes'] as List) Stroke.fromJson(s as List),
  ]);
}

double _r(double v) => (v * 10000).roundToDouble() / 10000;
