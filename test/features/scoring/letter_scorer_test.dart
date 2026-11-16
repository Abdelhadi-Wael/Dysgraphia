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
    expect(s.shape, greaterThan(0.9));
  });

  test('moving sideways does not matter', () {
    final s = scorer.score(transform(tpl('n'), dx: 3), tpl('n'));
    expect(s.overall, closeTo(1, 1e-9));
  });

  test('a different letter scores low on shape', () {
    final s = scorer.score(tpl('l'), tpl('o'));
    expect(s.shape, lessThan(0.3));
    expect(s.tip, ScoreTip.shape);
    expect(s.stars, 1);
  });

  test('o written clockwise: right shape, wrong way, low shape score', () {
    final cw = Drawing([
      Stroke(tpl('o').strokes.single.points.reversed.toList()),
    ]);
    expect(scorer.score(cw, tpl('o')).shape, lessThan(0.1));
  });

  test('too big and too small are named, with the right size ratio', () {
    // Scaled around the origin, which sits on the baseline.
    final big = scorer.score(transform(tpl('o'), k: 1.6), tpl('o'));
    expect(big.sizeRatio, closeTo(1.6, 1e-6));
    expect(big.shape, closeTo(1, 1e-6), reason: 'shape ignores size');
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
    expect(s.strokes, 0.6);
  });

  test('score survives a JSON export', () {
    final j = scorer.score(transform(tpl('a'), k: 1.2), tpl('a')).toJson();
    expect(j['stars'], isA<int>());
    expect(j['tip'], 'tooBig');
    expect(j.keys, containsAll(['shape', 'size', 'position', 'strokes']));
  });
}
