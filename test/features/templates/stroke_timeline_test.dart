import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:dysgraphia_app/features/templates/stroke_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one stroke: duration follows length and pen speed', () {
    final o = latinLowercase['o']!;
    final tl = StrokeTimeline(o.drawing, speed: 0.5);
    final length = o.drawing.strokes.single.length;
    expect(tl.totalSeconds, closeTo(length / 0.5, 1e-9));
    expect(tl.drawn(0, 0), 0);
    expect(tl.drawn(0, tl.totalSeconds / 2), closeTo(0.5, 1e-9));
    expect(tl.drawn(0, tl.totalSeconds), 1);
  });

  test('strokes run in order with a pause between them', () {
    final a = latinLowercase['a']!;
    final tl = StrokeTimeline(a.drawing, pauseSeconds: 0.4);
    final circleEnd = a.drawing.strokes[0].length / tl.speed;

    expect(tl.drawn(1, circleEnd), 0, reason: 'line waits for the circle');
    expect(tl.started(1, circleEnd + 0.2), isFalse, reason: 'still pausing');
    expect(tl.started(1, circleEnd + 0.4), isTrue);
    expect(tl.drawn(0, circleEnd + 0.2), 1);
    expect(tl.drawn(1, tl.totalSeconds), 1);
  });

  test('a dot takes a fixed short time', () {
    final i = latinLowercase['i']!;
    final tl = StrokeTimeline(i.drawing, dotSeconds: 0.3, pauseSeconds: 0.4);
    final stem = i.drawing.strokes[0].length / tl.speed;
    expect(tl.totalSeconds, closeTo(stem + 0.4 + 0.3, 1e-9));
  });

  test('every letter animates in a child-friendly time', () {
    for (final t in latinLowercase.values) {
      final s = StrokeTimeline(t.drawing).totalSeconds;
      expect(s, inInclusiveRange(0.8, 6), reason: t.letter);
    }
  });
}
