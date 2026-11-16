import 'package:dysgraphia_app/features/canvas/canvas_playground_page.dart';
import 'package:dysgraphia_app/features/canvas/writing_canvas.dart';
import 'package:dysgraphia_app/features/canvas/writing_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(WritingController c) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 800,
      height: 300,
      child: WritingCanvas(controller: c),
    ),
  ),
);

Future<void> _drag(
  WidgetTester tester,
  Offset from,
  Offset delta, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
  int pointer = 1,
}) async {
  final g = await tester.startGesture(from, kind: kind, pointer: pointer);
  for (var i = 1; i <= 5; i++) {
    await g.moveBy(delta / 5);
  }
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('dragging on the canvas records one stroke', (tester) async {
    final c = WritingController();
    await tester.pumpWidget(_host(c));
    final center = tester.getCenter(find.byType(WritingCanvas));

    await _drag(tester, center, const Offset(120, 0));

    expect(c.drawing.strokeCount, 1);
    final s = c.drawing.strokes.single;
    expect(s.points.length, greaterThan(3));
    expect(s.end.x, greaterThan(s.start.x));
  });

  testWidgets('a second finger during a stroke is ignored', (tester) async {
    final c = WritingController();
    await tester.pumpWidget(_host(c));
    final center = tester.getCenter(find.byType(WritingCanvas));

    final first = await tester.startGesture(center, pointer: 1);
    final second = await tester.startGesture(
      center + const Offset(50, 50),
      pointer: 2,
    );
    await second.moveBy(const Offset(40, 0));
    await second.up();
    await first.moveBy(const Offset(60, 0));
    await first.up();
    await tester.pump();

    expect(c.drawing.strokeCount, 1);
  });

  testWidgets('after a stylus is used, touch (palm) is ignored', (
    tester,
  ) async {
    final c = WritingController();
    await tester.pumpWidget(_host(c));
    final center = tester.getCenter(find.byType(WritingCanvas));

    await _drag(
      tester,
      center,
      const Offset(80, 0),
      kind: PointerDeviceKind.stylus,
    );
    await _drag(
      tester,
      center + const Offset(0, 40),
      const Offset(80, 0),
      pointer: 2,
    );

    expect(c.drawing.strokeCount, 1);
  });

  testWidgets('playground shows stats and undo works', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CanvasPlaygroundPage()));
    final canvas = find.byKey(const Key('writing-canvas'));
    await _drag(tester, tester.getCenter(canvas), const Offset(100, 20));
    expect(find.textContaining('Strokes: 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    expect(find.textContaining('Strokes: 0'), findsOneWidget);

    await tester.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
    await tester.pump();
    expect(find.textContaining('Strokes: 1'), findsOneWidget);
  });

  testWidgets('Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y undo and redo', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CanvasPlaygroundPage()));
    await tester.pump();
    final canvas = find.byKey(const Key('writing-canvas'));
    await _drag(tester, tester.getCenter(canvas), const Offset(100, 20));
    await _drag(tester, tester.getCenter(canvas), const Offset(0, 60));
    expect(find.textContaining('Strokes: 2'), findsOneWidget);

    Future<void> keys(
      List<LogicalKeyboardKey> mods,
      LogicalKeyboardKey key,
    ) async {
      for (final m in mods) {
        await tester.sendKeyDownEvent(m);
      }
      await tester.sendKeyEvent(key);
      for (final m in mods.reversed) {
        await tester.sendKeyUpEvent(m);
      }
      await tester.pump();
    }

    const ctrl = LogicalKeyboardKey.controlLeft;
    const shift = LogicalKeyboardKey.shiftLeft;

    await keys([ctrl], LogicalKeyboardKey.keyZ);
    expect(find.textContaining('Strokes: 1'), findsOneWidget);
    await keys([ctrl], LogicalKeyboardKey.keyZ);
    expect(find.textContaining('Strokes: 0'), findsOneWidget);
    await keys([ctrl, shift], LogicalKeyboardKey.keyZ);
    expect(find.textContaining('Strokes: 1'), findsOneWidget);
    await keys([ctrl], LogicalKeyboardKey.keyY);
    expect(find.textContaining('Strokes: 2'), findsOneWidget);
  });
}
