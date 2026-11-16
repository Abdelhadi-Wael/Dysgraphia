import 'dart:math' as math;

import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/scoring/geometry.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';

double _d(Pt a, Pt b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

void main() {
  group('resampleStroke', () {
    test('gives exactly n evenly spaced points, first and last kept', () {
      final s = Stroke(const [
        StrokePoint(0, 0),
        StrokePoint(0.1, 0),
        StrokePoint(1, 0), // uneven input spacing
      ]);
      final r = resampleStroke(s, 11);
      expect(r, hasLength(11));
      expect(r.first.x, closeTo(0, 1e-9));
      expect(r.last.x, closeTo(1, 1e-6));
      for (var i = 1; i < r.length; i++) {
        expect(_d(r[i - 1], r[i]), closeTo(0.1, 1e-6));
      }
    });

    test('works along curves', () {
      final o = latinLowercase['o']!.drawing.strokes.single;
      final r = resampleStroke(o, 32);
      expect(r, hasLength(32));
      final step = o.length / 31;
      for (var i = 1; i < r.length; i++) {
        // Chords are slightly shorter than arcs on a curve.
        expect(_d(r[i - 1], r[i]), closeTo(step, step * 0.05));
      }
    });

    test('a dot gives n copies', () {
      final r = resampleStroke(Stroke(const [StrokePoint(2, 3)]), 5);
      expect(r, everyElement(equals((x: 2.0, y: 3.0))));
    });
  });

  test('resampleDrawing shares points by stroke length', () {
    final i = latinLowercase['i']!.drawing; // line + dot
    final r = resampleDrawing(i, total: 64);
    expect(r.length, inInclusiveRange(64, 68));
    expect(r.last, equals((x: 0.0, y: -0.75)), reason: 'dot comes last');
  });

  test('normalise centres and scales, keeping proportions', () {
    final n = normalise([(x: 2, y: 2), (x: 4, y: 3)]);
    expect(n.first.x, closeTo(-0.5, 1e-9));
    expect(n.last.x, closeTo(0.5, 1e-9));
    expect(n.first.y, closeTo(-0.25, 1e-9)); // half as tall as wide
  });

  group('dtw', () {
    final o = normalise(resampleDrawing(latinLowercase['o']!.drawing));

    test('identical sequences are 0 apart', () {
      expect(dtw(o, o), closeTo(0, 1e-12));
    });

    test('tolerates different speeds along the same path', () {
      final s = latinLowercase['o']!.drawing.strokes.single;
      final fast = normalise(resampleStroke(s, 30));
      final slow = normalise(resampleStroke(s, 90));
      // What remains is only the sampling resolution: matched points can be
      // up to half of the coarser spacing (perimeter ~3.1 / 30 ≈ 0.1) apart.
      expect(dtw(fast, slow), lessThan(0.04));
    });

    test('is symmetric enough and grows with difference', () {
      final c = normalise(resampleDrawing(latinLowercase['c']!.drawing));
      final l = normalise(resampleDrawing(latinLowercase['l']!.drawing));
      expect(dtw(o, c), lessThan(dtw(o, l)));
      expect(dtw(o, l), closeTo(dtw(l, o), 0.02));
    });
  });
}
