import '../../core/models/stroke.dart';

/// When each stroke of a template is drawn during the "watch" animation.
///
/// Strokes are drawn one after another at a steady pen speed, with a short
/// pause between them (the pen lifts and moves to the next start).
class StrokeTimeline {
  StrokeTimeline(
    Drawing drawing, {
    this.speed = 0.7,
    this.dotSeconds = 0.3,
    this.pauseSeconds = 0.4,
  }) {
    var t = 0.0;
    for (var i = 0; i < drawing.strokes.length; i++) {
      if (i > 0) t += pauseSeconds;
      final s = drawing.strokes[i];
      final d = s.points.length < 2 ? dotSeconds : s.length / speed;
      _spans.add((t, t + d));
      t += d;
    }
    totalSeconds = t;
  }

  /// Pen speed in line units per second (an "o" takes about 2 seconds).
  final double speed;
  final double dotSeconds;
  final double pauseSeconds;

  final _spans = <(double, double)>[];
  late final double totalSeconds;

  Duration get total => Duration(milliseconds: (totalSeconds * 1000).round());

  int get strokeCount => _spans.length;

  /// How much of stroke [i] is drawn at [seconds]: 0 = not started,
  /// 1 = finished.
  double drawn(int i, double seconds) {
    final (start, end) = _spans[i];
    if (seconds <= start) return 0;
    if (seconds >= end) return 1;
    return (seconds - start) / (end - start);
  }

  /// Whether stroke [i] has started (its start dot should be visible).
  bool started(int i, double seconds) => seconds >= _spans[i].$1;
}
