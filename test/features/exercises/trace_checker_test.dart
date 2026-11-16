import 'dart:math' as math;

import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_checker.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';

TraceChecker checker(String letter) =>
    TraceChecker(latinLowercase[letter]!.drawing);

Stroke tplStroke(String letter, int i) =>
    latinLowercase[letter]!.drawing.strokes[i];

/// A copy of [s] moved and with a gentle wobble, like a child's tracing.
Stroke wobbly(Stroke s, {double dx = 0, double dy = 0, double amp = 0.04}) =>
    Stroke([
      for (var i = 0; i < s.points.length; i++)
        StrokePoint(
          s.points[i].x + dx + amp * math.sin(i / 3),
          s.points[i].y + dy + amp * math.cos(i / 4),
        ),
    ]);

Stroke reversed(Stroke s) => Stroke(s.points.reversed.toList());

Stroke firstPart(Stroke s, double fraction) =>
    Stroke(s.points.take((s.points.length * fraction).round()).toList());

void main() {
  group('correct tracing is accepted', () {
    test('every stroke of every letter, traced exactly', () {
      for (final tpl in latinLowercase.values) {
        final c = TraceChecker(tpl.drawing);
        for (var i = 0; i < tpl.strokeCount; i++) {
          final r = c.checkFinished(tpl.drawing.strokes[i], i);
          expect(r.issue, TraceIssue.none, reason: '${tpl.letter} stroke $i');
          expect(r.coverage, closeTo(1, 0.05), reason: tpl.letter);
        }
        expect(c.isComplete(tpl.strokeCount), isTrue);
      }
    });

    test('a wobbly, slightly shifted o is still fine', () {
      final r = checker('o')
          .checkFinished(wobbly(tplStroke('o', 0), dx: 0.05, dy: -0.04), 0);
      expect(r.issue, TraceIssue.none);
    });
  });

  group('mistakes are recognised', () {
    test('starting far from the start dot', () {
      final r = checker('l')
          .checkLive(wobbly(tplStroke('l', 0), dx: 0.3, amp: 0), 0);
      expect(r.issue, TraceIssue.wrongStart);
    });

    test('writing a straight line upwards (starting at the bottom)', () {
      final r = checker('l').checkLive(reversed(tplStroke('l', 0)), 0);
      expect(r.issue, TraceIssue.wrongStart);
    });

    test('o written clockwise: same start, wrong direction', () {
      final cw = reversed(tplStroke('o', 0));
      // The pen is caught going the wrong way early, not only at the end.
      final r = checker('o').checkLive(firstPart(cw, 0.25), 0);
      expect(r.issue, TraceIssue.wrongDirection);
    });

    test('dot of i before its line, crossbar of t before its stem', () {
      expect(
        checker('i').checkLive(tplStroke('i', 1), 0).issue,
        TraceIssue.wrongOrder,
      );
      expect(
        checker('t').checkLive(tplStroke('t', 1), 0).issue,
        TraceIssue.wrongOrder,
      );
    });

    test('drifting away from the dotted line', () {
      final l = tplStroke('l', 0);
      final drift = Stroke([
        for (var i = 0; i < l.points.length; i++)
          StrokePoint(l.points[i].x + i * 0.01, l.points[i].y),
      ]);
      expect(checker('l').checkLive(drift, 0).issue, TraceIssue.offPath);
    });

    test('lifting the pen half way', () {
      final half = firstPart(tplStroke('l', 0), 0.5);
      final c = checker('l');
      expect(c.checkLive(half, 0).issue, TraceIssue.none);
      final done = c.checkFinished(half, 0);
      expect(done.issue, TraceIssue.tooShort);
      expect(done.coverage, closeTo(0.5, 0.06));
    });

    test('a long line where a dot should be', () {
      final fromDot = Stroke([
        tplStroke('i', 1).start,
        StrokePoint(tplStroke('i', 1).start.x + 0.4, -0.75),
      ]);
      expect(checker('i').checkFinished(fromDot, 1).issue, TraceIssue.offPath);
    });
  });

  test('expected stroke follows how many are accepted', () {
    final c = checker('a');
    expect(c.expected(0), same(tplStroke('a', 0)));
    expect(c.expected(1), same(tplStroke('a', 1)));
    expect(c.expected(2), isNull);
    expect(c.isComplete(1), isFalse);
    expect(c.isComplete(2), isTrue);
  });

  test('works on a template moved on the canvas', () {
    final moved = latinLowercase['o']!.drawing.shifted(0.7, 0);
    final c = TraceChecker(moved);
    expect(c.checkFinished(moved.strokes.single, 0).ok, isTrue);
    expect(
      c.checkLive(tplStroke('o', 0), 0).issue,
      TraceIssue.wrongStart,
      reason: 'the unmoved letter is in the wrong place',
    );
  });
}
