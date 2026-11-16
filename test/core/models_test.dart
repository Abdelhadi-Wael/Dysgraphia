import 'dart:ui';

import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drawing', () {
    final drawing = Drawing([
      Stroke(const [
        StrokePoint(0, 0, t: 0),
        StrokePoint(0.3, -0.4, t: 50, pressure: 0.8),
      ]),
      Stroke(const [StrokePoint(1, -1, t: 200)]),
    ]);

    test('survives a JSON round trip', () {
      final copy = Drawing.fromJson(drawing.toJson());
      expect(copy.strokeCount, 2);
      expect(copy.strokes[0].points[1].x, closeTo(0.3, 1e-4));
      expect(copy.strokes[0].points[1].pressure, closeTo(0.8, 1e-4));
      expect(copy.strokes[1].start.t, 200);
    });

    test('computes length, duration and bounds', () {
      expect(drawing.strokes[0].length, closeTo(0.5, 1e-9));
      expect(drawing.strokes[0].duration, 50);
      expect(drawing.bounds, (0.0, -1.0, 1.0, 0.0));
      expect(Drawing.empty.bounds, isNull);
    });
  });

  group('GuideGeometry', () {
    final g = GuideGeometry(const Size(800, 300));

    test('guide lines are ordered top to bottom and evenly scaled', () {
      expect(g.topLineY, lessThan(g.midlineY));
      expect(g.midlineY, lessThan(g.baselineY));
      expect(g.baselineY, lessThan(g.descenderY));
      expect(g.baselineY - g.topLineY, closeTo(g.unit, 1e-9));
      expect(g.descenderY - g.baselineY, closeTo(g.unit / 2, 1e-9));
    });

    test('baseline maps to y=0 and top line to y=-1', () {
      expect(g.toLine(Offset(100, g.baselineY)).y, closeTo(0, 1e-9));
      expect(g.toLine(Offset(100, g.topLineY)).y, closeTo(-1, 1e-9));
    });

    test('pixel ↔ line conversion round-trips', () {
      const px = Offset(321.5, 123.25);
      final back = g.toPixels(g.toLine(px));
      expect(back.dx, closeTo(px.dx, 1e-9));
      expect(back.dy, closeTo(px.dy, 1e-9));
    });

    test('same letter in a bigger box gives the same line coordinates', () {
      final big = GuideGeometry(const Size(1600, 600));
      final a = g.toLine(Offset(g.originX + g.unit * 0.4, g.midlineY));
      final b = big.toLine(Offset(big.originX + big.unit * 0.4, big.midlineY));
      expect(a.x, closeTo(b.x, 1e-9));
      expect(a.y, closeTo(b.y, 1e-9));
    });
  });
}
