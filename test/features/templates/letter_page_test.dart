import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/features/exercises/copy/copy_view.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/templates/letter_page.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _tablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('everything fits on a small landscape screen', (tester) async {
    tester.view.physicalSize = const Size(900, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LetterPage(letter: 'g', initialStep: LetterStep.copy),
      ),
    );
    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.byKey(const Key('copy-model')), findsOneWidget);
  });

  testWidgets('letter page: trace, then "Copy it", and step buttons', (
    tester,
  ) async {
    _tablet(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: LetterPage(letter: 'l', initialStep: LetterStep.trace),
      ),
    );
    expect(find.byType(TraceView), findsOneWidget);

    // Trace the l correctly.
    final canvas = find.byKey(const Key('trace-canvas'));
    final g = GuideGeometry(tester.getSize(canvas));
    final origin = tester.getTopLeft(canvas);
    final l = TraceView.shapeFor(latinLowercase['l']!).strokes.single;
    final pen = await tester.startGesture(origin + g.toPixels(l.start));
    for (final p in l.points.skip(1)) {
      await pen.moveTo(origin + g.toPixels(p));
    }
    await pen.up();
    await tester.pump();

    await tester.tap(find.text('Copy it'));
    await tester.pumpAndSettle();
    expect(find.byType(CopyView), findsOneWidget);

    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('letter-animation')), findsOneWidget);
  });
}
