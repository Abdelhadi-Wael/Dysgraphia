import 'dart:math' as math;

import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/scoring/letter_scorer.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';

const scorer = LetterScorer();

Drawing tpl(String c) => latinLowercase[c]!.drawing;

/// Each point moved by (dx, dy), scaled by [k] around the baseline start,
/// with an optional wobble.
Drawing transform(
  Drawing d, {
  double dx = 0,
  double dy = 0,
  double k = 1,
  double wobble = 0,
}) => Drawing([
  for (final s in d.strokes)
    Stroke([
      for (var i = 0; i < s.points.length; i++)
        StrokePoint(
          s.points[i].x * k + dx + wobble * math.sin(i / 3),
          s.points[i].y * k + dy + wobble * math.cos(i / 4),
        ),
    ]),
]);

void main() {
  test('the template itself is perfect: 3 stars, no tip', () {
    for (final t in latinLowercase.values) {
      final s = scorer.score(t.drawing, t.drawing);
      expect(s.overall, closeTo(1, 1e-9), reason: t.letter);
      expect(s.stars, 3);
      expect(s.tip, ScoreTip.none);
    }
  });

  test('a slightly wobbly letter in the right place still gets 3 stars', () {
    final s = scorer.score(transform(tpl('a'), wobble: 0.02), tpl('a'));
    expect(s.stars, 3);
    expect(s.looks, greaterThan(0.9));
  });

  test('moving sideways does not matter', () {
    final s = scorer.score(transform(tpl('n'), dx: 3), tpl('n'));
    expect(s.overall, closeTo(1, 1e-9));
  });

  test('a different letter scores low on looks', () {
    final s = scorer.score(tpl('l'), tpl('o'));
    expect(s.looks, lessThan(0.3));
    expect(s.tip, ScoreTip.looks);
    expect(s.stars, 1);
  });

  test('similar letters are still told apart', () {
    for (final (a, b) in [('b', 'h'), ('l', 'i'), ('g', 'q'), ('n', 'u')]) {
      expect(scorer.score(tpl(a), tpl(b)).looks, lessThan(0.8), reason: a + b);
    }
  });

  test('o written clockwise looks right but was written the wrong way', () {
    final cw = Drawing([
      Stroke(tpl('o').strokes.single.points.reversed.toList()),
    ]);
    final s = scorer.score(cw, tpl('o'));
    expect(s.looks, closeTo(1, 1e-6));
    expect(s.movement, 0.5);
    expect(s.issue, MovementIssue.direction);
    expect(s.tip, ScoreTip.roundDirection);
    expect(s.stars, 3, reason: 'a good-looking letter keeps its stars');
  });

  test('every stroke reversed is caught, for every letter and shape', () {
    for (final t in [...latinLowercase.values]) {
      final rev = Drawing([
        for (final s in t.drawing.strokes) Stroke(s.points.reversed.toList()),
      ]);
      expect(
        scorer.score(rev, t.drawing).issue,
        MovementIssue.direction,
        reason: t.letter,
      );
    }
  });

  test('strokes in the wrong order are caught', () {
    for (final t in latinLowercase.values.where((t) => t.strokeCount > 1)) {
      final swapped = Drawing(t.drawing.strokes.reversed.toList());
      expect(
        scorer.score(swapped, t.drawing).issue,
        MovementIssue.order,
        reason: t.letter,
      );
    }
    final i = tpl('i');
    final dotFirst = Drawing(i.strokes.reversed.toList());
    expect(scorer.score(dotFirst, i).tip, ScoreTip.dotLast);
  });

  test('an o started at the bottom is told where to start', () {
    final o = tpl('o').strokes.single.points;
    final half = o.length ~/ 2;
    final fromBottom = Drawing([
      Stroke([...o.sublist(half), ...o.sublist(1, half + 1)]),
    ]);
    final s = scorer.score(fromBottom, tpl('o'));
    expect(s.issue, MovementIssue.start);
    expect(s.tip, ScoreTip.start);
  });

  test('wobbly writing is not mistaken for a wrong movement', () {
    for (final t in latinLowercase.values) {
      final s = scorer.score(transform(t.drawing, wobble: 0.03), t.drawing);
      expect(s.issue, MovementIssue.none, reason: t.letter);
    }
  });

  test('too big and too small are named, with the right size ratio', () {
    // Scaled around the origin, which sits on the baseline.
    final big = scorer.score(transform(tpl('o'), k: 1.6), tpl('o'));
    expect(big.sizeRatio, closeTo(1.6, 1e-6));
    expect(big.looks, closeTo(1, 1e-6), reason: 'looks ignore size');
    expect(big.tip, ScoreTip.tooBig);

    final small = scorer.score(transform(tpl('o'), k: 0.5), tpl('o'));
    expect(small.tip, ScoreTip.tooSmall);
    expect(small.size, closeTo(0, 1e-6), reason: 'half size scores 0');
  });

  test('floating above or sinking below the baseline', () {
    final high = scorer.score(transform(tpl('e'), dy: -0.15), tpl('e'));
    expect(high.baselineOffset, closeTo(-0.15, 1e-6));
    expect(high.position, closeTo(0.4, 1e-6));
    expect(high.tip, ScoreTip.tooHigh);

    final low = scorer.score(transform(tpl('e'), dy: 0.15), tpl('e'));
    expect(low.tip, ScoreTip.tooLow);
  });

  test('descender letters are measured against the descender line', () {
    final g = scorer.score(tpl('g'), tpl('g'));
    expect(g.baselineOffset, closeTo(0, 1e-9));
    // A "g" whose tail stops at the baseline is too high.
    final shortTail = scorer.score(transform(tpl('g'), dy: -0.2), tpl('g'));
    expect(shortTail.tip, ScoreTip.tooHigh);
  });

  test('an n written in one stroke (retraced) loses only a little', () {
    final n = tpl('n');
    final oneStroke = Drawing([
      Stroke([...n.strokes[0].points.reversed, ...n.strokes[1].points]),
    ]);
    final s = scorer.score(oneStroke, n);
    expect(s.strokeDifference, -1);
    expect(s.movement, 0.5);
    expect(s.tip, ScoreTip.strokeCount);
  });

  test('score survives a JSON export', () {
    final j = scorer.score(transform(tpl('a'), k: 1.2), tpl('a')).toJson();
    expect(j['stars'], isA<int>());
    expect(j['tip'], 'tooBig');
    expect(j.keys, containsAll(['looks', 'size', 'position', 'movement']));
  });
}
