import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/canvas/writing_canvas.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _open(WidgetTester tester, String letter) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TraceView(template: latinLowercase[letter]!),
        ),
      ),
    ),
  );
}

/// Screen position of a point in canvas line units.
Offset _px(WidgetTester tester, StrokePoint p) {
  final canvas = find.byType(WritingCanvas);
  final g = GuideGeometry(tester.getSize(canvas));
  return tester.getTopLeft(canvas) + g.toPixels(p);
}

/// Writes [points] with a simulated finger. Leaves the pen down if [lift]
/// is false, so the live state can be checked mid-stroke.
Future<TestGesture> _write(
  WidgetTester tester,
  List<StrokePoint> points, {
  bool lift = true,
}) async {
  final g = await tester.startGesture(_px(tester, points.first));
  for (var i = 1; i < points.length; i += 2) {
    await g.moveTo(_px(tester, points[i]));
  }
  await g.moveTo(_px(tester, points.last));
  if (lift) await g.up();
  await tester.pump();
  return g;
}

String _message(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('trace-message'))).data!;

Drawing _shape(String letter) => TraceView.shapeFor(latinLowercase[letter]!);

void main() {
  testWidgets('tracing every stroke correctly finishes the letter', (
    tester,
  ) async {
    await _open(tester, 'a');
    expect(_message(tester), 'Start at dot 1 and follow the arrow');

    final a = _shape('a');
    await _write(tester, a.strokes[0].points);
    expect(_message(tester), 'Good! Now stroke 2');

    await _write(tester, a.strokes[1].points);
    expect(_message(tester), 'Well done!');
    expect(find.text('Trace again'), findsOneWidget);

    // Traced exactly on the dotted letter: full marks.
    expect(find.byKey(const Key('star-3-on')), findsOneWidget);
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('Shape'), findsNothing);
    // Details open in a panel from the bottom; the card keeps its height.
    final card = tester.getRect(find.byKey(const Key('score-tip')));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Shape'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(4));
    expect(tester.getRect(find.byKey(const Key('score-tip'))), card);
    Navigator.of(tester.element(find.text('Shape'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trace again'));
    await tester.pump();
    expect(_message(tester), 'Start at dot 1 and follow the arrow');
    expect(find.byKey(const Key('star-1-on')), findsNothing);
  });

  testWidgets('a line written upwards is rejected with a hint', (tester) async {
    await _open(tester, 'l');
    final up = _shape('l').strokes.single.points.reversed.toList();
    await _write(tester, up);
    expect(_message(tester), 'Start at dot 1');
    expect(find.text('Trace again'), findsNothing);

    // The rejected stroke fades, then a correct one is accepted.
    await tester.pump(const Duration(seconds: 1));
    await _write(tester, _shape('l').strokes.single.points);
    expect(_message(tester), 'Well done! (1 retry)');
  });

  testWidgets('a clockwise o is flagged while still writing', (tester) async {
    await _open(tester, 'o');
    final cw = _shape('o').strokes.single.points.reversed.toList();
    final pen = await _write(
      tester,
      cw.sublist(0, cw.length ~/ 3),
      lift: false,
    );
    expect(_message(tester), 'Go the other way: follow the arrow');
    await pen.up();
    await tester.pump();
    expect(_message(tester), 'Go the other way: follow the arrow');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dot of i first is "not yet"', (tester) async {
    await _open(tester, 'i');
    await _write(tester, _shape('i').strokes[1].points);
    expect(_message(tester), 'Not yet: start with stroke 1');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('undo goes back one stroke and the hint follows', (tester) async {
    await _open(tester, 't');
    await _write(tester, _shape('t').strokes[0].points);
    expect(_message(tester), 'Good! Now stroke 2');
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    expect(_message(tester), 'Start at dot 1 and follow the arrow');
  });
}
