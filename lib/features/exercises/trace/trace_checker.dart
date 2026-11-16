import 'dart:math' as math;

import '../../../core/models/stroke.dart';

/// What is wrong with a traced stroke, if anything.
enum TraceIssue {
  none,

  /// Pen went down far from where the stroke should start.
  wrongStart,

  /// Started a later stroke first (e.g. the dot of "i" before the line).
  wrongOrder,

  /// Moving against the stroke's direction.
  wrongDirection,

  /// Drifted too far from the dotted line.
  offPath,

  /// Lifted the pen before finishing the stroke.
  tooShort,
}

class StrokeCheck {
  const StrokeCheck(this.issue, {this.coverage = 0});

  final TraceIssue issue;

  /// How much of the expected stroke was followed, 0..1.
  final double coverage;

  bool get ok => issue == TraceIssue.none;
}

/// Live, on-device checks for tracing a letter template: the quick
/// "start here / wrong way / stay on the line" feedback while writing.
/// Detailed scoring happens separately, after the letter.
///
/// All distances are in line units (the x-height is 0.5).
class TraceChecker {
  TraceChecker(
    this.template, {
    this.startTolerance = 0.15,
    this.pathTolerance = 0.15,
    this.minCoverage = 0.75,
  });

  /// The template, positioned where it is drawn on the canvas.
  final Drawing template;
  final double startTolerance;
  final double pathTolerance;
  final double minCoverage;

  /// How many points backwards (net) count as the wrong direction. Template
  /// points are ~0.03 units apart, so 5 points ≈ 0.15 units.
  static const _backwardLimit = 5;

  /// How far to look around the current position when following the pen.
  static const _window = 10;

  /// The stroke to write next, given how many strokes are already accepted.
  /// Null when the letter is complete.
  Stroke? expected(int acceptedStrokes) =>
      acceptedStrokes < template.strokeCount
      ? template.strokes[acceptedStrokes]
      : null;

  bool isComplete(int acceptedStrokes) =>
      acceptedStrokes >= template.strokeCount;

  /// Checks a stroke while it is being written: start point, path and
  /// direction. Does not complain about it being unfinished.
  StrokeCheck checkLive(Stroke s, int acceptedStrokes) =>
      _check(s, acceptedStrokes, finished: false);

  /// Checks a stroke when the pen lifts; also requires it to be complete.
  StrokeCheck checkFinished(Stroke s, int acceptedStrokes) =>
      _check(s, acceptedStrokes, finished: true);

  StrokeCheck _check(Stroke s, int accepted, {required bool finished}) {
    final target = expected(accepted);
    if (target == null || s.isEmpty) {
      return const StrokeCheck(TraceIssue.offPath);
    }

    if (s.start.distanceTo(target.start) > startTolerance) {
      final startsALaterStroke = template.strokes
          .skip(accepted + 1)
          .any((later) => s.start.distanceTo(later.start) <= startTolerance);
      return StrokeCheck(
        startsALaterStroke ? TraceIssue.wrongOrder : TraceIssue.wrongStart,
      );
    }

    // A dot: one short tap near the right place.
    if (target.points.length == 1) {
      return s.length <= startTolerance
          ? const StrokeCheck(TraceIssue.none, coverage: 1)
          : const StrokeCheck(TraceIssue.offPath);
    }

    final t = target.points;
    final n = t.length;
    final closed = t.first.distanceTo(t.last) < startTolerance;

    // Follow the pen along the template: for each pen point, find the
    // nearest template point close to the current position. Moving to lower
    // indices means going backwards along the stroke.
    var cur = 0;
    var forward = 0, backward = 0;
    for (final p in s.points) {
      var best = cur, bestD = double.infinity;
      for (var k = -_window; k <= _window; k++) {
        var j = cur + k;
        if (closed) {
          j %= n;
        } else if (j < 0 || j >= n) {
          continue;
        }
        final d = p.distanceTo(t[j]);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      if (bestD > pathTolerance) return const StrokeCheck(TraceIssue.offPath);

      var step = best - cur;
      if (closed) {
        // Shortest way round the loop.
        if (step > n / 2) step -= n;
        if (step < -n / 2) step += n;
      }
      if (step > 0) forward += step;
      if (step < 0) backward -= step;
      cur = best;

      if (backward - forward >= _backwardLimit) {
        return const StrokeCheck(TraceIssue.wrongDirection);
      }
    }

    final coverage = math.min(1.0, (forward - backward) / (n - 1));
    if (finished && coverage < minCoverage) {
      return StrokeCheck(TraceIssue.tooShort, coverage: math.max(0, coverage));
    }
    return StrokeCheck(TraceIssue.none, coverage: math.max(0, coverage));
  }
}
