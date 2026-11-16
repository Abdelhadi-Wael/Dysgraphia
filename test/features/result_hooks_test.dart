import 'dart:io';

import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/assessment/assessment_page.dart';
import 'package:dysgraphia_app/features/assessment/assessment_result.dart';
import 'package:dysgraphia_app/features/assessment/assessment_task.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/export/drawing_exporter.dart';
import 'package:dysgraphia_app/features/templates/letter_page.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _tablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Writes [d] on the canvas found by [canvas], shifted right by [dx].
Future<void> _write(
  WidgetTester tester,
  Finder canvas,
  Drawing d, {
  double dx = 0,
}) async {
  final g = GuideGeometry(tester.getSize(canvas));
  final origin = tester.getTopLeft(canvas);
  Offset px(StrokePoint p) => origin + g.toPixels(StrokePoint(p.x + dx, p.y));
  for (final s in d.strokes) {
    final pen = await tester.startGesture(px(s.start));
    for (final p in s.points.skip(1)) {
      await pen.moveTo(px(p));
    }
    await pen.up();
  }
  await tester.pump();
}

void main() {
  testWidgets('a finished trace is reported once as a trace attempt', (
    tester,
  ) async {
    _tablet(tester);
    final got = <Attempt>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LetterPage(
          letter: 'l',
          initialStep: LetterStep.trace,
          onAttempt: got.add,
        ),
      ),
    );
    await _write(
      tester,
      find.byKey(const Key('trace-canvas')),
      TraceView.shapeFor(latinLowercase['l']!),
    );
    expect(got, hasLength(1));
    expect(got.single.letter, 'l');
    expect(got.single.kind, PracticeKind.trace);
    expect(got.single.stars, 3);
    expect(got.single.retries, 0);
    expect(got.single.drawing.strokeCount, 1);
  });

  testWidgets('each checked copy is reported; then on to the next letter', (
    tester,
  ) async {
    _tablet(tester);
    final got = <Attempt>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LetterPage(
          letter: 'o',
          initialStep: LetterStep.copy,
          queue: const ['l', 'i'],
          onAttempt: got.add,
        ),
      ),
    );
    final o = latinLowercase['o']!.drawing;
    for (var box = 0; box < 3; box++) {
      await _write(tester, find.byKey(Key('copy-canvas-$box')), o, dx: 0.3);
      await tester.tap(find.text('Check'));
      await tester.pump();
    }
    expect(got.map((a) => a.kind), List.filled(3, PracticeKind.copy));
    expect(got.map((a) => a.letter), ['o', 'o', 'o']);
    expect(got.first.score['tip'], 'none');

    await tester.tap(find.text('Next letter: l'));
    await tester.pumpAndSettle();
    expect(find.text('Letter l'), findsOneWidget);
    // The rest of the queue and the saving carry over.
    final next = tester.widget<LetterPage>(find.byType(LetterPage));
    expect(next.queue, ['i']);
    expect(next.onAttempt, isNotNull);
  });

  testWidgets('without a queue, copy just offers "Copy again"', (tester) async {
    _tablet(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: LetterPage(letter: 'l', initialStep: LetterStep.copy),
      ),
    );
    final l = latinLowercase['l']!.drawing;
    for (var box = 0; box < 3; box++) {
      await _write(tester, find.byKey(Key('copy-canvas-$box')), l, dx: 0.3);
      await tester.tap(find.text('Check'));
      await tester.pump();
    }
    expect(find.text('Copy again'), findsOneWidget);
    expect(find.textContaining('Next letter'), findsNothing);
  });

  testWidgets('the handwriting check reports its result and file', (
    tester,
  ) async {
    _tablet(tester);
    final tmp = Directory.systemTemp.createTempSync('dys_hook');
    addTearDown(() => tmp.deleteSync(recursive: true));
    AssessmentResult? result;
    File? file;
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentPage(
          tasks: [defaultAssessmentTasks.last],
          exporter: DrawingExporter(baseDirectory: () async => tmp),
          onSaved: (r, f) {
            result = r;
            file = f;
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Skip'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(result?.tasks.single.skipped, isTrue);
    expect(file?.existsSync(), isTrue);
  });
}
