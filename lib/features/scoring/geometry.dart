/// Basic shape operations for scoring: resampling, normalising and DTW.
/// Pure Dart, no Flutter, so it can be tested and reused anywhere.
library;

import 'dart:math' as math;

import '../../core/models/stroke.dart';

/// A plain 2D point.
typedef Pt = ({double x, double y});

double _dist(Pt a, Pt b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// [n] points spread evenly along the stroke by distance, so a slow and a
/// fast writer (who produce different numbers of points) compare fairly.
/// A dot gives [n] copies of its point.
List<Pt> resampleStroke(Stroke s, int n) {
  assert(n >= 2);
  final pts = [for (final p in s.points) (x: p.x, y: p.y)];
  final total = s.length;
  if (pts.length < 2 || total == 0) return List.filled(n, pts.first);

  final out = <Pt>[pts.first];
  final step = total / (n - 1);
  var carried = 0.0; // distance since the last emitted point
  for (var i = 1; i < pts.length && out.length < n; i++) {
    var a = pts[i - 1];
    final b = pts[i];
    var seg = _dist(a, b);
    while (carried + seg >= step && out.length < n) {
      final t = (step - carried) / seg;
      a = (x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);
      out.add(a);
      seg = _dist(a, b);
      carried = 0;
    }
    carried += seg;
  }
  while (out.length < n) {
    out.add(pts.last); // rounding can leave the last point missing
  }
  return out;
}

/// All strokes resampled into about [total] points in writing order. Each
/// stroke gets points in proportion to its length (at least 4, so dots and
/// tiny strokes still count).
List<Pt> resampleDrawing(Drawing d, {int total = 64}) {
  final lengths = [for (final s in d.strokes) s.length];
  final sum = lengths.fold(0.0, (a, b) => a + b);
  return [
    for (var i = 0; i < d.strokes.length; i++)
      ...resampleStroke(
        d.strokes[i],
        math.max(4, sum == 0 ? 4 : (total * lengths[i] / sum).round()),
      ),
  ];
}

/// Moves the points so their bounding box is centred on (0, 0) and scales
/// them so its larger side is 1. Keeps the aspect ratio, so a tall thin
/// "l" stays different from a round "o".
List<Pt> normalise(List<Pt> pts) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  final size = math.max(maxX - minX, maxY - minY);
  final scale = size < 1e-9 ? 1.0 : 1 / size;
  return [for (final p in pts) (x: (p.x - cx) * scale, y: (p.y - cy) * scale)];
}

/// Dynamic time warping: the average distance between matched points when
/// the two sequences are aligned as well as possible, allowing one to be
/// locally faster or slower than the other. 0 = identical.
double dtw(List<Pt> a, List<Pt> b) {
  final n = a.length, m = b.length;
  const inf = double.infinity;
  var prev = List<double>.filled(m + 1, inf)..[0] = 0;
  // Track the path length too, to report an average per matched pair.
  var prevLen = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    final cur = List<double>.filled(m + 1, inf);
    final curLen = List<int>.filled(m + 1, 0);
    for (var j = 1; j <= m; j++) {
      final cost = _dist(a[i - 1], b[j - 1]);
      // Best of: diagonal, from above, from the left.
      var best = prev[j - 1], len = prevLen[j - 1];
      if (prev[j] < best) {
        best = prev[j];
        len = prevLen[j];
      }
      if (cur[j - 1] < best) {
        best = cur[j - 1];
        len = curLen[j - 1];
      }
      cur[j] = best + cost;
      curLen[j] = len + 1;
    }
    prev = cur;
    prevLen = curLen;
  }
  return prev[m] / prevLen[m];
}

/// How different two point sets look, ignoring the order of the points:
/// for each point, the distance to the nearest point of the other set.
/// Averages the worst quarter of those distances (so a missing or extra
/// part counts, not only the overall outline) and takes the worse of the
/// two directions. 0 = the same picture, however it was drawn.
double lookDistance(List<Pt> a, List<Pt> b) {
  double oneWay(List<Pt> from, List<Pt> to) {
    final near = [
      for (final p in from) to.map((q) => _dist(p, q)).reduce(math.min),
    ]..sort();
    final worst = near.sublist(near.length * 3 ~/ 4);
    return worst.reduce((x, y) => x + y) / worst.length;
  }

  return math.max(oneWay(a, b), oneWay(b, a));
}

/// Each stroke resampled to [perStroke] points, all normalised together
/// (one bounding box for the whole drawing, larger side 1), so strokes
/// keep their places relative to each other.
List<List<Pt>> normaliseStrokes(Drawing d, {int perStroke = 24}) {
  final strokes = [for (final s in d.strokes) resampleStroke(s, perStroke)];
  final flat = normalise([for (final s in strokes) ...s]);
  return [
    for (var i = 0; i < strokes.length; i++)
      flat.sublist(i * perStroke, (i + 1) * perStroke),
  ];
}

double distance(Pt a, Pt b) => _dist(a, b);

/// Signed area enclosed by a stroke (shoelace formula), in screen
/// coordinates where y grows down: positive = clockwise on screen.
double signedArea(List<Pt> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}
