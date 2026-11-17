import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/exercises/copy/copy_view.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _tablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openCopy(WidgetTester tester, String letter) async {
  _tablet(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CopyView(template: latinLowercase[letter]!),
        ),
      ),
    ),
  );
}

/// Writes [d] in copy box [box], moved right a little and scaled by [k]
/// around the baseline, like a child writing freely in the box.
Future<void> _writeIn(
  WidgetTester tester,
  int box,
  Drawing d, {
  double k = 1,
}) async {
  final canvas = find.byKey(Key('copy-canvas-$box'));
  final g = GuideGeometry(tester.getSize(canvas));
  final origin = tester.getTopLeft(canvas);
  Offset px(StrokePoint p) =>
      origin + g.toPixels(StrokePoint(p.x * k + 0.3, p.y * k));
  for (final s in d.strokes) {
    final pen = await tester.startGesture(px(s.start));
    for (var i = 1; i < s.points.length; i += 2) {
      await pen.moveTo(px(s.points[i]));
    }
    await pen.moveTo(px(s.end));
    await pen.up();
  }
  await tester.pump();
}

String _message(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('copy-message'))).data!;

bool _checkEnabled(WidgetTester tester) =>
    tester
        .widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Check'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('three attempts, each scored, then copy again', (tester) async {
    await _openCopy(tester, 'o');
    final o = latinLowercase['o']!.drawing;
    expect(_message(tester), 'Look at the letter, then write it in box 1');
    expect(_checkEnabled(tester), isFalse, reason: 'nothing written yet');

    await _writeIn(tester, 0, o);
    expect(_checkEnabled(tester), isTrue);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.byKey(const Key('box-0-stars-3')), findsOneWidget);
    expect(find.text('Great job!'), findsOneWidget);
    expect(_message(tester), 'Now write it again in box 2');

    // Too big: the tip says so and box 2 shows its own stars.
    await _writeIn(tester, 1, o, k: 1.6);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Make it a little smaller'), findsOneWidget);
    expect(find.byKey(const Key('box-0-stars-3')), findsOneWidget);
    expect(find.textContaining('box 3'), findsOneWidget);

    // A different letter in box 3 gets 1 star.
    await _writeIn(tester, 2, latinLowercase['l']!.drawing);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.byKey(const Key('box-2-stars-1')), findsOneWidget);
    expect(_message(tester), 'All done! Best: ★★★');

    await tester.tap(find.text('Copy again'));
    await tester.pump();
    expect(_message(tester), 'Look at the letter, then write it in box 1');
    expect(find.byKey(const Key('box-0-stars-3')), findsNothing);
  });

  testWidgets('one box at a time, and the next opens in the same place', (
    tester,
  ) async {
    await _openCopy(tester, 'l');
    expect(find.byKey(const Key('copy-canvas-1')), findsNothing);
    final first = tester.getRect(find.byKey(const Key('copy-canvas-0')));
    expect(find.byKey(const Key('score-placeholder')), findsOneWidget);

    await _writeIn(tester, 0, latinLowercase['l']!.drawing);
    expect(_checkEnabled(tester), isTrue);
    await tester.tap(find.text('Check'));
    await tester.pump();

    // The score card fills the slot the hint held: nothing moves.
    expect(find.byKey(const Key('copy-canvas-0')), findsNothing);
    final second = tester.getRect(find.byKey(const Key('copy-canvas-1')));
    expect(second, first);
    expect(_checkEnabled(tester), isFalse, reason: 'box 2 starts empty');
  });
}
