import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/canvas/writing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WritingController c;
  setUp(() => c = WritingController());

  void line(double x0, double x1, int t0) {
    c.beginStroke(StrokePoint(x0, 0, t: t0));
    c.addPoint(StrokePoint((x0 + x1) / 2, 0, t: t0 + 10));
    c.addPoint(StrokePoint(x1, 0, t: t0 + 20));
    c.endStroke();
  }

  test('records strokes with times relative to the first point', () {
    line(0, 1, 5000);
    line(2, 3, 5100);
    final d = c.drawing;
    expect(d.strokeCount, 2);
    expect(d.strokes[0].start.t, 0);
    expect(d.strokes[1].start.t, 100);
    expect(d.strokes[1].end.t, 120);
  });

  test('stroke in progress is visible but not part of the drawing', () {
    c.beginStroke(const StrokePoint(0, 0, t: 0));
    c.addPoint(const StrokePoint(0.5, 0, t: 10));
    expect(c.isWriting, isTrue);
    expect(c.strokes, hasLength(1));
    expect(c.drawing.isEmpty, isTrue);
  });

  test('drops jitter points closer than the minimum distance', () {
    c.beginStroke(const StrokePoint(0, 0, t: 0));
    c.addPoint(const StrokePoint(0.001, 0, t: 1));
    c.addPoint(const StrokePoint(0.1, 0, t: 2));
    c.endStroke();
    expect(c.drawing.strokes.single.points, hasLength(2));
  });

  test('undo removes the last stroke, clear removes all and resets time', () {
    line(0, 1, 1000);
    line(2, 3, 2000);
    c.undo();
    expect(c.drawing.strokeCount, 1);
    c.clear();
    expect(c.isEmpty, isTrue);
    line(0, 1, 9000);
    expect(c.drawing.strokes.single.start.t, 0);
  });

  test('cancel discards the stroke in progress', () {
    c.beginStroke(const StrokePoint(0, 0, t: 0));
    c.cancelStroke();
    expect(c.isEmpty, isTrue);
  });

  test('redo brings back undone strokes in order', () {
    line(0, 1, 1000);
    line(2, 3, 1100);
    c.undo();
    c.undo();
    expect(c.isEmpty, isTrue);
    expect(c.canRedo, isTrue);
    c.redo();
    c.redo();
    expect(c.drawing.strokeCount, 2);
    expect(c.drawing.strokes[1].start.x, 2);
    expect(c.canRedo, isFalse);
  });

  test('a new stroke after undo clears the redo history', () {
    line(0, 1, 0);
    c.undo();
    line(5, 6, 500);
    expect(c.canRedo, isFalse);
    c.redo();
    expect(c.drawing.strokeCount, 1);
    expect(c.drawing.strokes.single.start.x, 5);
  });

  test('clear can be undone and redone', () {
    line(0, 1, 0);
    line(2, 3, 100);
    c.clear();
    expect(c.isEmpty, isTrue);
    c.undo();
    expect(c.drawing.strokeCount, 2);
    c.redo();
    expect(c.isEmpty, isTrue);
  });

  test('strokes restored by undo keep consistent times with new strokes', () {
    line(0, 1, 1000);
    c.clear();
    c.undo(); // stroke back, written at t=0
    line(2, 3, 1500); // half a second after the first one
    expect(c.drawing.strokes[1].start.t, 500);
  });

  test('nothing to undo or redo on a fresh canvas', () {
    expect(c.canUndo, isFalse);
    expect(c.canRedo, isFalse);
    c.undo();
    c.redo();
    expect(c.isEmpty, isTrue);
  });

  test('notifies listeners on changes', () {
    var calls = 0;
    c.addListener(() => calls++);
    line(0, 1, 0);
    expect(calls, greaterThanOrEqualTo(3));
  });
}
