import 'dart:math' as math;

import '../../core/models/stroke.dart';
import 'geometry.dart';

/// The one thing to work on next, from the weakest measure.
enum ScoreTip { none, shape, tooBig, tooSmall, tooHigh, tooLow, strokeCount }

/// How well one written letter matches its template. Every measure is
/// 0 (poor) to 1 (matches); see docs/scoring.md.
class LetterScore {
  const LetterScore({
    required this.shape,
    required this.size,
    required this.position,
    required this.strokes,
    required this.shapeDistance,
    required this.sizeRatio,
    required this.baselineOffset,
    required this.strokeDifference,
    required this.tip,
  });

  final double shape, size, position, strokes;

  /// Raw values behind the measures, for reports and research.
  final double shapeDistance; // DTW on normalised shapes
  final double sizeRatio; // written height / template height
  final double baselineOffset; // line units, + = too low, - = too high
  final int strokeDifference; // written strokes - template strokes

  final ScoreTip tip;

  static const weights = (shape: 0.5, size: 0.2, position: 0.2, strokes: 0.1);

  double get overall =>
      shape * weights.shape +
      size * weights.size +
      position * weights.position +
      strokes * weights.strokes;

  /// 1-3 stars. Never 0: every attempt earns something.
  int get stars => overall >= 0.85 ? 3 : (overall >= 0.6 ? 2 : 1);

  Map<String, dynamic> toJson() => {
    'overall': _r(overall),
    'stars': stars,
    'shape': _r(shape),
    'size': _r(size),
    'position': _r(position),
    'strokes': _r(strokes),
    'shapeDistance': _r(shapeDistance),
    'sizeRatio': _r(sizeRatio),
    'baselineOffset': _r(baselineOffset),
    'strokeDifference': strokeDifference,
    'tip': tip.name,
  };
}

double _r(double v) => (v * 1000).roundToDouble() / 1000;

/// Scores letters against templates with simple, explainable rules.
/// Thresholds were set from measured distances between all template pairs
/// and noisy copies (see docs/scoring.md); tune them with real data.
class LetterScorer {
  const LetterScorer({
    this.shapeGood = 0.05,
    this.shapeBad = 0.30,
    this.sizeZeroRatio = 2.0,
    this.positionZero = 0.25,
    this.tipBelow = 0.8,
  });

  /// DTW distance that still counts as a perfect shape / that scores 0.
  final double shapeGood, shapeBad;

  /// Size ratio (bigger or smaller) at which the size score reaches 0.
  final double sizeZeroRatio;

  /// Baseline offset (line units) at which the position score reaches 0.
  /// The x-height is 0.5, so 0.25 is half a small letter.
  final double positionZero;

  /// Measures below this get a tip.
  final double tipBelow;

  LetterScore score(Drawing written, Drawing template) {
    assert(!written.isEmpty && !template.isEmpty);

    final d = dtw(
      normalise(resampleDrawing(written)),
      normalise(resampleDrawing(template)),
    );
    final shape = _clamp(1 - (d - shapeGood) / (shapeBad - shapeGood));

    final (_, wTop, _, wBottom) = written.bounds!;
    final (_, tTop, _, tBottom) = template.bounds!;
    final ratio =
        math.max(wBottom - wTop, 1e-6) / math.max(tBottom - tTop, 1e-6);
    final size = _clamp(1 - math.log(ratio).abs() / math.log(sizeZeroRatio));

    // Does the letter sit where it should: on the baseline, or for g, j, p,
    // q, y on the descender line?
    final offset = wBottom - tBottom;
    final position = _clamp(1 - offset.abs() / positionZero);

    final diff = written.strokeCount - template.strokeCount;
    final strokes = switch (diff.abs()) {
      0 => 1.0,
      1 => 0.6,
      _ => 0.2,
    };

    // Tip for the weakest measure below the bar; ties go to the earlier,
    // more important one.
    final candidates = <(double, ScoreTip)>[
      (shape, ScoreTip.shape),
      (position, offset > 0 ? ScoreTip.tooLow : ScoreTip.tooHigh),
      (size, ratio > 1 ? ScoreTip.tooBig : ScoreTip.tooSmall),
      (strokes, ScoreTip.strokeCount),
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
      shape: shape,
      size: size,
      position: position,
      strokes: strokes,
      shapeDistance: d,
      sizeRatio: ratio,
      baselineOffset: offset,
      strokeDifference: diff,
      tip: tip,
    );
  }
}

double _clamp(double v) => v.clamp(0.0, 1.0);
