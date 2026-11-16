import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:dysgraphia_app/features/templates/template_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const eps = 1e-6;

/// Shoelace area of a stroke (closed back to its start). With y growing
/// downwards, a NEGATIVE value means counter-clockwise as seen on screen.
double signedArea(Stroke s) {
  var sum = 0.0;
  final p = s.points;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}

bool isCounterClockwise(Stroke s) => signedArea(s) < 0;

LetterTemplate t(String c) => latinLowercase[c]!;

void main() {
  group('builder', () {
    test('arc angles are as seen on screen: 90 degrees is the top', () {
      final top = arc(0, 0, 1, 90, 0.0001).first;
      expect(top.x, closeTo(0, eps));
      expect(top.y, closeTo(-1, eps)); // up = negative y
    });

    test('positive sweep is counter-clockwise on screen', () {
      expect(isCounterClockwise(stroke([arc(0, 0, 1, 0, 360)])), isTrue);
      expect(isCounterClockwise(stroke([arc(0, 0, 1, 0, -360)])), isFalse);
    });

    test('joining segments drops the duplicated joint point', () {
      final s = stroke([line(0, 0, 1, 0), line(1, 0, 1, 1)]);
      for (var i = 1; i < s.points.length; i++) {
        expect(s.points[i].distanceTo(s.points[i - 1]), greaterThan(0));
      }
      expect(s.end.y, closeTo(1, eps));
    });
  });

  test('all 26 lowercase letters exist', () {
    expect(latinLowercase.keys.join(), 'abcdefghijklmnopqrstuvwxyz');
  });

  group('size and position on the guide lines', () {
    test('every letter starts at x = 0 and stays inside the writing zone', () {
      for (final tpl in latinLowercase.values) {
        final (minX, minY, _, maxY) = tpl.drawing.bounds!;
        expect(minX, closeTo(0, 0.02), reason: tpl.letter);
        expect(minY, greaterThanOrEqualTo(-1 - eps), reason: tpl.letter);
        expect(maxY, lessThanOrEqualTo(0.5 + eps), reason: tpl.letter);
      }
    });

    test('small letters sit between the midline and the baseline', () {
      for (final c in 'acemnorsuvwxz'.split('')) {
        final (_, minY, _, maxY) = t(c).drawing.bounds!;
        expect(minY, closeTo(-0.5, 0.02), reason: '$c should touch midline');
        expect(maxY, closeTo(0, 0.02), reason: '$c should sit on baseline');
      }
    });

    test('tall letters reach up towards the top line', () {
      for (final c in 'bdfhkl'.split('')) {
        expect(t(c).drawing.bounds!.$2, lessThanOrEqualTo(-0.95), reason: c);
      }
      expect(t('t').drawing.bounds!.$2, closeTo(-0.85, eps)); // t is shorter
    });

    test('descender letters go below the baseline', () {
      for (final c in 'gjpqy'.split('')) {
        expect(t(c).drawing.bounds!.$4, closeTo(0.5, 0.02), reason: c);
      }
    });
  });

  group('direction and order, as taught', () {
    test('o starts at the top right and goes counter-clockwise', () {
      final s = t('o').drawing.strokes.single;
      expect(s.start.x, greaterThan(0.25));
      expect(s.start.y, lessThan(-0.25));
      expect(isCounterClockwise(s), isTrue);
    });

    test('round letters circle counter-clockwise', () {
      for (final c in 'acdegoq'.split('')) {
        expect(
          isCounterClockwise(t(c).drawing.strokes.first),
          isTrue,
          reason: c,
        );
      }
    });

    test('b and p bowls go clockwise, after the stem', () {
      for (final c in 'bp'.split('')) {
        final strokes = t(c).drawing.strokes;
        expect(strokes.first.start.x, closeTo(0, eps)); // stem first
        expect(isCounterClockwise(strokes[1]), isFalse, reason: c);
      }
    });

    test('straight stems are written top to bottom', () {
      for (final c in 'bhiklmnprt'.split('')) {
        final s = t(c).drawing.strokes.first;
        expect(s.start.y, lessThan(s.end.y), reason: c);
      }
      expect(t('a').drawing.strokes[1].start.y, -0.5);
      expect(t('d').drawing.strokes[1].start.y, -1);
    });

    test('dots and crossbars come last', () {
      expect(t('i').drawing.strokes.last.points, hasLength(1));
      expect(t('j').drawing.strokes.last.points, hasLength(1));
      for (final c in 'ft'.split('')) {
        final bar = t(c).drawing.strokes.last;
        expect(bar.start.y, closeTo(bar.end.y, eps), reason: '$c bar flat');
        expect(bar.start.x, lessThan(bar.end.x), reason: '$c bar left→right');
      }
    });

    test('stroke counts', () {
      const expected = {
        'a': 2,
        'b': 2,
        'c': 1,
        'd': 2,
        'e': 1,
        'f': 2,
        'g': 2,
        'h': 2,
        'i': 2,
        'j': 2,
        'k': 2,
        'l': 1,
        'm': 3,
        'n': 2,
        'o': 1,
        'p': 2,
        'q': 2,
        'r': 2,
        's': 1,
        't': 2,
        'u': 2,
        'v': 1,
        'w': 1,
        'x': 2,
        'y': 2,
        'z': 1,
      };
      expect({
        for (final e in latinLowercase.entries) e.key: e.value.strokeCount,
      }, expected);
    });
  });

  test('points are evenly spaced (about 0.03 units apart)', () {
    for (final tpl in latinLowercase.values) {
      for (final s in tpl.drawing.strokes.where((s) => s.points.length > 1)) {
        for (var i = 1; i < s.points.length; i++) {
          expect(
            s.points[i].distanceTo(s.points[i - 1]),
            lessThan(0.035),
            reason: tpl.letter,
          );
        }
      }
    }
  });
}
