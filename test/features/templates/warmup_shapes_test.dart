import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_checker.dart';
import 'package:dysgraphia_app/features/scoring/letter_scorer.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:dysgraphia_app/features/templates/stroke_timeline.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Negative = counter-clockwise on screen (y grows downwards).
double signedArea(Stroke s) {
  var sum = 0.0;
  final p = s.points;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}

void main() {
  final shapes = warmUpShapes.values.toList();

  test('six named shapes, all marked as shapes', () {
    expect(shapes, hasLength(6));
    for (final s in shapes) {
      expect(s.isShape, isTrue);
      expect(s.label, isNot(startsWith('Letter')));
      expect(s.letter, startsWith('warmup-'));
      expect(s.verb, 'draw');
    }
  });

  test('every shape fits the writing area and the copy boxes', () {
    for (final s in shapes) {
      final (minX, minY, maxX, maxY) = s.drawing.bounds!;
      expect(minX, closeTo(0, 0.01), reason: s.label);
      expect(maxX, lessThanOrEqualTo(1.2 + 1e-9), reason: s.label);
      expect(minY, greaterThanOrEqualTo(-1), reason: s.label);
      expect(maxY, lessThanOrEqualTo(0.01), reason: s.label);
    }
  });

  test('taught directions: down, left to right, counter-clockwise circle', () {
    for (final st in warmUpShapes['warmup-down']!.drawing.strokes) {
      expect(st.start.y, lessThan(st.end.y));
    }
    for (final st in warmUpShapes['warmup-across']!.drawing.strokes) {
      expect(st.start.x, lessThan(st.end.x));
    }
    final circle = warmUpShapes['warmup-circle']!.drawing.strokes.single;
    expect(signedArea(circle), lessThan(0));
    final waves = warmUpShapes['warmup-waves']!.drawing.strokes.single;
    expect(waves.start.x, lessThan(waves.end.x));
  });

  test('tracing a shape exactly is accepted, stroke by stroke', () {
    for (final s in shapes) {
      final c = TraceChecker(s.drawing);
      for (var i = 0; i < s.strokeCount; i++) {
        final r = c.checkFinished(s.drawing.strokes[i], i);
        expect(r.ok, isTrue, reason: '${s.label} stroke $i: ${r.issue}');
      }
    }
  });

  test('copying a shape exactly gets 3 stars; animations are short', () {
    for (final s in shapes) {
      expect(const LetterScorer().score(s.drawing, s.drawing).stars, 3);
      final secs = StrokeTimeline(s.drawing).totalSeconds;
      expect(secs, inInclusiveRange(1, 8), reason: s.label);
    }
  });

  test('templateFor finds letters and shapes', () {
    expect(templateFor('a'), same(latinLowercase['a']));
    expect(templateFor('warmup-waves').label, 'Waves');
  });
}
