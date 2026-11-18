import 'dart:math' as math;

import '../../core/models/stroke.dart';
import '../words/word_templates.dart';
import 'letter_scorer.dart';

/// What to work on next in a word.
enum WordTipKind {
  none,
  looks, // one letter does not look like the model
  movement, // one letter was written the wrong way
  tooBig,
  tooSmall,
  unevenSize, // one letter is bigger or smaller than the others
  offLine, // one letter floats above or sinks below the line
  tooClose, // letters touch or nearly touch
  tooFar,
  unevenSpacing,
}

class WordTip {
  const WordTip(this.kind, {this.letter, this.below = false});

  static const none = WordTip(WordTipKind.none);

  final WordTipKind kind;

  /// The letter the tip is about, when there is one.
  final String? letter;

  /// For [WordTipKind.offLine]: the letter sinks below the line (otherwise
  /// it floats above it).
  final bool below;

  String get text {
    final l = letter == null ? 'letter' : '"$letter"';
    final tail = letter != null && 'gjpqy'.contains(letter!);
    return switch (kind) {
      WordTipKind.none => 'Great job!',
      WordTipKind.looks => 'Look closely at the $l in the model',
      WordTipKind.movement => 'Write the $l the way the animation shows',
      WordTipKind.tooBig => 'Make the word a little smaller',
      WordTipKind.tooSmall => 'Make the word a little bigger',
      WordTipKind.unevenSize => 'Make the $l the same size as the others',
      WordTipKind.offLine when tail =>
        below
            ? 'Keep the tail of the $l on the bottom line'
            : 'Bring the tail of the $l down to the bottom line',
      WordTipKind.offLine =>
        below
            ? 'Sit the $l on the baseline, not below it'
            : 'Sit the $l on the baseline',
      WordTipKind.tooClose => 'Leave a small gap between the letters',
      WordTipKind.tooFar => 'Keep the letters closer together',
      WordTipKind.unevenSpacing => 'Keep the gaps between letters the same',
    };
  }
}

/// How well a written word matches its model. Every measure is 0..1; see
/// docs/scoring.md.
class WordScore {
  const WordScore({
    required this.looks,
    required this.movement,
    required this.size,
    required this.line,
    required this.spacing,
    required this.letters,
    required this.gaps,
    required this.tip,
  });

  final double looks, movement, size, line, spacing;

  /// Each letter's own score, left to right, or null when the writing could
  /// not be split into the word's letters (they touch).
  final List<LetterScore>? letters;

  /// Gaps between neighbouring letters, in line units at model size.
  final List<double> gaps;

  final WordTip tip;

  static const weights = (
    looks: 0.35,
    movement: 0.1,
    size: 0.15,
    line: 0.2,
    spacing: 0.2,
  );

  double get overall =>
      looks * weights.looks +
      movement * weights.movement +
      size * weights.size +
      line * weights.line +
      spacing * weights.spacing;

  int get stars => overall >= 0.85 ? 3 : (overall >= 0.6 ? 2 : 1);

  Map<String, dynamic> toJson() => {
    'overall': _r(overall),
    'stars': stars,
    'looks': _r(looks),
    'movement': _r(movement),
    'size': _r(size),
    'line': _r(line),
    'spacing': _r(spacing),
    'gaps': [for (final g in gaps) _r(g)],
    'split': letters != null,
    'letters': [for (final l in letters ?? const <LetterScore>[]) l.toJson()],
    'tip': tip.kind.name,
    'tipLetter': tip.letter,
  };
}

double _r(double v) => (v * 1000).roundToDouble() / 1000;

/// Scores a written word in two passes: split the strokes into letters by
/// where they sit left to right, score each letter with [LetterScorer], then
/// judge what only a word has: even size, a shared baseline and spacing.
class WordScorer {
  const WordScorer({
    this.letterScorer = const LetterScorer(),
    this.touching = 0.04,
    this.unevenZero = 0.35,
    this.gapGood = (0.07, 0.35),
    this.gapZero = (0.0, 0.7),
    this.tipBelow = 0.8,
  });

  final LetterScorer letterScorer;

  /// Strokes closer than this (line units) side by side belong to the same
  /// letter.
  final double touching;

  /// Spread of letter sizes (standard deviation / mean) that scores 0.
  final double unevenZero;

  /// Gap between letters (line units, at model size) that scores 1, and
  /// where the score reaches 0. The model uses [letterGap] = 0.15.
  final (double, double) gapGood, gapZero;

  final double tipBelow;

  WordScore score(Drawing written, WordTemplate word) {
    assert(!written.isEmpty);
    final n = word.letters.length;
    final groups = splitLetters(written, n);
    if (groups.length < n) return _touching(written, word);

    final scores = [
      for (var i = 0; i < n; i++)
        letterScorer.score(groups[i], word.letters[i].template.drawing),
    ];
    String letter(int i) => word.letters[i].template.letter;
    int worst(double Function(LetterScore) f) {
      var w = 0;
      for (var i = 1; i < n; i++) {
        if (f(scores[i]) < f(scores[w])) w = i;
      }
      return w;
    }

    final looks = _mean(scores.map((s) => s.looks));
    final movement = _mean(scores.map((s) => s.movement));

    // Size: right overall, and the same for every letter.
    final ratios = [for (final s in scores) s.sizeRatio];
    final meanRatio = _mean(ratios);
    final spread = n < 2 ? 0.0 : _std(ratios) / meanRatio;
    final evenSize = _clamp(1 - spread / unevenZero);
    final rightSize = _clamp(
      1 - math.log(meanRatio).abs() / math.log(letterScorer.sizeZeroRatio),
    );
    final size = (evenSize + rightSize) / 2;

    final line = _mean(scores.map((s) => s.position));

    // Spacing, measured at the model's size so big writing is not
    // penalised for proportionally big gaps.
    final gaps = <double>[
      for (var i = 0; i + 1 < n; i++)
        (groups[i + 1].bounds!.$1 - groups[i].bounds!.$3) / meanRatio,
    ];
    final gapScores = [for (final g in gaps) _gapScore(g)];
    final evenGaps = gaps.length < 2
        ? 1.0
        : _clamp(
            1 - (gaps.reduce(math.max) - gaps.reduce(math.min) - 0.1) / 0.3,
          );
    final spacing = gaps.isEmpty
        ? 1.0
        : 0.7 * _mean(gapScores) + 0.3 * evenGaps;

    // One tip, for the weakest measure below the bar.
    final w = worst((s) => s.looks);
    final moveWorst = worst((s) => s.movement);
    final sizeOdd = _oddOneOut(ratios);
    final lineWorst = worst((s) => s.position);
    final gapWorst = gaps.isEmpty ? 0 : _argMin(gapScores);
    final candidates = <(double, WordTip)>[
      // Looks and movement are about single letters: judged by the worst
      // one, not the mean, so one wrong letter is worth a tip.
      (scores[w].looks, WordTip(WordTipKind.looks, letter: letter(w))),
      (
        line,
        WordTip(
          WordTipKind.offLine,
          letter: letter(lineWorst),
          below: scores[lineWorst].baselineOffset > 0,
        ),
      ),
      (
        rightSize,
        WordTip(meanRatio > 1 ? WordTipKind.tooBig : WordTipKind.tooSmall),
      ),
      (evenSize, WordTip(WordTipKind.unevenSize, letter: letter(sizeOdd))),
      if (gaps.isNotEmpty) ...[
        (
          _mean(gapScores),
          WordTip(
            gaps[gapWorst] < gapGood.$1
                ? WordTipKind.tooClose
                : WordTipKind.tooFar,
          ),
        ),
        (evenGaps, const WordTip(WordTipKind.unevenSpacing)),
      ],
      (
        scores[moveWorst].movement,
        WordTip(WordTipKind.movement, letter: letter(moveWorst)),
      ),
    ];
    var tip = WordTip.none;
    var bar = tipBelow;
    for (final (value, t) in candidates) {
      if (value < bar) {
        bar = value;
        tip = t;
      }
    }

    return WordScore(
      looks: looks,
      movement: movement,
      size: size,
      line: line,
      spacing: spacing,
      letters: scores,
      gaps: gaps,
      tip: tip,
    );
  }

  /// Letters touch, so they cannot be told apart: judge the word as one
  /// shape, and ask for gaps.
  WordScore _touching(Drawing written, WordTemplate word) {
    final s = letterScorer.score(written, word.drawing);
    return WordScore(
      looks: s.looks,
      movement: s.movement,
      size: s.size,
      line: s.position,
      spacing: 0.2,
      letters: null,
      gaps: const [],
      tip: const WordTip(WordTipKind.tooClose),
    );
  }

  double _gapScore(double g) {
    final (good0, good1) = gapGood;
    final (zero0, zero1) = gapZero;
    if (g < good0) return _clamp((g - zero0) / (good0 - zero0));
    if (g > good1) return _clamp((zero1 - g) / (zero1 - good1));
    return 1;
  }

  /// Splits [written] into letters, left to right. Strokes whose
  /// horizontal extents overlap or nearly touch form one letter (a dot sits
  /// over its "i", a crossbar over its "t"). If that gives more groups than
  /// [letters] (e.g. a "k" written with a gap), the closest neighbours are
  /// joined until the count fits. Fewer groups means letters touch.
  List<Drawing> splitLetters(Drawing written, int letters) {
    final strokes = [...written.strokes]
      ..sort((a, b) => _minX(a).compareTo(_minX(b)));
    final groups = <List<Stroke>>[];
    var right = -double.infinity;
    for (final s in strokes) {
      if (groups.isEmpty || _minX(s) > right + touching) {
        groups.add([s]);
        right = _maxX(s);
      } else {
        groups.last.add(s);
        right = math.max(right, _maxX(s));
      }
    }
    while (groups.length > letters) {
      var join = 0;
      var smallest = double.infinity;
      for (var i = 0; i + 1 < groups.length; i++) {
        final gap =
            groups[i + 1].map(_minX).reduce(math.min) -
            groups[i].map(_maxX).reduce(math.max);
        if (gap < smallest) {
          smallest = gap;
          join = i;
        }
      }
      groups[join].addAll(groups.removeAt(join + 1));
    }
    // Keep the writing order inside each letter (stroke order matters).
    final order = {for (final (i, s) in written.strokes.indexed) s: i};
    return [
      for (final g in groups)
        Drawing(g..sort((a, b) => order[a]!.compareTo(order[b]!))),
    ];
  }
}

double _minX(Stroke s) => s.points.map((p) => p.x).reduce(math.min);
double _maxX(Stroke s) => s.points.map((p) => p.x).reduce(math.max);

double _mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;

double _std(List<double> v) {
  final m = _mean(v);
  return math.sqrt(_mean(v.map((x) => (x - m) * (x - m))));
}

int _argMin(List<double> v) {
  var w = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] < v[w]) w = i;
  }
  return w;
}

/// The value furthest from the median: the letter that stands out.
int _oddOneOut(List<double> v) {
  final sorted = [...v]..sort();
  final median = sorted[sorted.length ~/ 2];
  var w = 0;
  for (var i = 1; i < v.length; i++) {
    if ((math.log(v[i] / median)).abs() > (math.log(v[w] / median)).abs()) {
      w = i;
    }
  }
  return w;
}

double _clamp(double v) => v.clamp(0.0, 1.0);
