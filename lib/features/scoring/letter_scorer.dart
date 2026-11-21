import 'dart:math' as math;

import '../../core/models/stroke.dart';
import 'geometry.dart';

/// The one thing to work on next, from the weakest measure.
enum ScoreTip {
  none,
  looks,
  tooBig,
  tooSmall,
  tooHigh,
  tooLow,
  strokeCount,
  order,
  dotLast,
  direction,
  roundDirection,
  start,
}

/// What was wrong with how the letter was written, if anything. Checked in
/// this order; only the first problem found becomes the tip.
enum MovementIssue { none, strokeCount, order, direction, start }

/// How well one written letter matches its template. Every measure is
/// 0 (poor) to 1 (matches); see docs/scoring.md.
class LetterScore {
  const LetterScore({
    required this.looks,
    required this.size,
    required this.position,
    required this.movement,
    required this.lookDistance,
    required this.orderedDistance,
    required this.sizeRatio,
    required this.baselineOffset,
    required this.strokeDifference,
    required this.issue,
    required this.tip,
  });

  /// Does it look like the model (however it was written)?
  final double looks;
  final double size, position;

  /// Was it written the right way: strokes, their order, direction and
  /// start?
  final double movement;

  /// Raw values behind the measures, for reports and research.
  final double lookDistance; // order-free, on normalised shapes
  final double orderedDistance; // DTW in writing order, for reference
  final double sizeRatio; // written height / template height
  final double baselineOffset; // line units, + = too low, - = too high
  final int strokeDifference; // written strokes - template strokes
  final MovementIssue issue;

  final ScoreTip tip;

  static const weights = (
    looks: 0.45,
    size: 0.2,
    position: 0.2,
    movement: 0.15,
  );

  double get overall =>
      looks * weights.looks +
      size * weights.size +
      position * weights.position +
      movement * weights.movement;

  /// 1-3 stars. Never 0: every attempt earns something.
  int get stars => overall >= 0.85 ? 3 : (overall >= 0.6 ? 2 : 1);

  Map<String, dynamic> toJson() => {
    'overall': _r(overall),
    'stars': stars,
    'looks': _r(looks),
    'size': _r(size),
    'position': _r(position),
    'movement': _r(movement),
    'lookDistance': _r(lookDistance),
    'orderedDistance': _r(orderedDistance),
    'sizeRatio': _r(sizeRatio),
    'baselineOffset': _r(baselineOffset),
    'strokeDifference': strokeDifference,
    'issue': issue.name,
    'tip': tip.name,
  };
}

double _r(double v) => (v * 1000).roundToDouble() / 1000;

/// Scores letters against templates with simple, explainable rules.
/// Thresholds were set from measured distances between all template pairs
/// and noisy copies (see docs/scoring.md); tune them with real data.
class LetterScorer {
  const LetterScorer({
    this.looksGood = 0.05,
    this.looksBad = 0.25,
    this.sizeZeroRatio = 2.0,
    this.positionZero = 0.25,
    this.tipBelow = 0.8,
  });

  /// Look distance that still counts as a perfect shape / that scores 0.
  final double looksGood, looksBad;

  /// Size ratio (bigger or smaller) at which the size score reaches 0.
  final double sizeZeroRatio;

  /// Baseline offset (line units) at which the position score reaches 0.
  /// The x-height is 0.5, so 0.25 is half a small letter.
  final double positionZero;

  /// Measures below this get a tip.
  final double tipBelow;

  LetterScore score(Drawing written, Drawing template) {
    assert(!written.isEmpty && !template.isEmpty);

    final w = normalise(resampleDrawing(written));
    final t = normalise(resampleDrawing(template));
    final look = lookDistance(w, t);
    final looks = _clamp(1 - (look - looksGood) / (looksBad - looksGood));

    final (_, wTop, _, wBottom) = written.bounds!;
    final (_, tTop, _, tBottom) = template.bounds!;
    final ratio =
        math.max(wBottom - wTop, 1e-6) / math.max(tBottom - tTop, 1e-6);
    final size = _clamp(1 - math.log(ratio).abs() / math.log(sizeZeroRatio));

    // Does the letter sit where it should: on the baseline, or for g, j, p,
    // q, y on the descender line?
    final offset = wBottom - tBottom;
    final position = _clamp(1 - offset.abs() / positionZero);

    final m = _movement(written, template);

    // Tip for the weakest measure below the bar; ties go to the earlier,
    // more important one.
    final candidates = <(double, ScoreTip)>[
      (looks, ScoreTip.looks),
      (position, offset > 0 ? ScoreTip.tooLow : ScoreTip.tooHigh),
      (size, ratio > 1 ? ScoreTip.tooBig : ScoreTip.tooSmall),
      (m.score, m.tip),
    ];
    var tip = ScoreTip.none;
    var worst = tipBelow;
    for (final (value, t) in candidates) {
      if (value < worst) {
        worst = value;
        tip = t;
      }
    }

    return LetterScore(
      looks: looks,
      size: size,
      position: position,
      movement: m.score,
      lookDistance: look,
      orderedDistance: dtw(w, t),
      sizeRatio: ratio,
      baselineOffset: offset,
      strokeDifference: written.strokeCount - template.strokeCount,
      issue: m.issue,
      tip: tip,
    );
  }

  /// Checks how the letter was written, stroke by stroke, in a shared
  /// normalised frame: number of strokes, then their order, then each
  /// stroke's direction, then where round strokes start.
  ({double score, MovementIssue issue, ScoreTip tip}) _movement(
    Drawing written,
    Drawing template,
  ) {
    final diff = written.strokeCount - template.strokeCount;
    if (diff != 0) {
      return (
        score: diff.abs() == 1 ? 0.5 : 0.2,
        issue: MovementIssue.strokeCount,
        tip: ScoreTip.strokeCount,
      );
    }
    final w = normaliseStrokes(written);
    final t = normaliseStrokes(template);
    final n = w.length;

    // Order: does each written stroke look most like the template stroke
    // in the same place in the order?
    var orderWrong = false, dotFirst = false;
    for (var i = 0; i < n; i++) {
      final own = _strokeDistance(w[i], t[i]);
      for (var j = 0; j < n; j++) {
        if (j != i && _strokeDistance(w[i], t[j]) < own - 0.08) {
          orderWrong = true;
          if (_isDot(t[j])) dotFirst = true;
        }
      }
    }
    if (orderWrong) {
      return (
        score: 0.5,
        issue: MovementIssue.order,
        tip: dotFirst ? ScoreTip.dotLast : ScoreTip.order,
      );
    }

    var reversed = 0, roundReversed = false, badStart = false;
    for (var i = 0; i < n; i++) {
      final a = w[i], b = t[i];
      if (_isDot(a) || _isDot(b)) continue;
      if (_isLoop(b)) {
        final wa = signedArea(a), ta = signedArea(b);
        if (wa.abs() > 0.02 && wa.sign != ta.sign) {
          reversed++;
          roundReversed = true;
        } else if (distance(a.first, b.first) > 0.5) {
          badStart = true;
        }
      } else {
        final forward = distance(a.first, b.first) + distance(a.last, b.last);
        final backward = distance(a.first, b.last) + distance(a.last, b.first);
        if (forward > 0.3 && backward < forward * 0.6) reversed++;
      }
    }
    if (reversed > 0) {
      return (
        score: _clamp(1 - 0.5 * reversed),
        issue: MovementIssue.direction,
        tip: roundReversed ? ScoreTip.roundDirection : ScoreTip.direction,
      );
    }
    if (badStart) {
      return (score: 0.7, issue: MovementIssue.start, tip: ScoreTip.start);
    }
    return (score: 1.0, issue: MovementIssue.none, tip: ScoreTip.none);
  }
}

/// Mean distance from each point of [a] to the nearest point of [b] and
/// back: how close two strokes are, whichever way they were drawn.
double _strokeDistance(List<Pt> a, List<Pt> b) {
  double oneWay(List<Pt> from, List<Pt> to) =>
      from
          .map((p) => to.map((q) => distance(p, q)).reduce(math.min))
          .reduce((x, y) => x + y) /
      from.length;
  return (oneWay(a, b) + oneWay(b, a)) / 2;
}

double _extent(List<Pt> s) {
  final xs = s.map((p) => p.x), ys = s.map((p) => p.y);
  return math.max(
    xs.reduce(math.max) - xs.reduce(math.min),
    ys.reduce(math.max) - ys.reduce(math.min),
  );
}

bool _isDot(List<Pt> s) => _extent(s) < 0.08;

/// A stroke that ends near where it started (o, the bowl of a, b, d...).
bool _isLoop(List<Pt> s) => distance(s.first, s.last) < 0.3 * _extent(s);

double _clamp(double v) => v.clamp(0.0, 1.0);
