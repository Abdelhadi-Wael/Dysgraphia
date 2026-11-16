import 'dart:convert';
import 'dart:io';

import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/assessment/assessment_page.dart';
import 'package:dysgraphia_app/features/assessment/assessment_result.dart';
import 'package:dysgraphia_app/features/assessment/assessment_task.dart';
import 'package:dysgraphia_app/features/canvas/writing_canvas.dart';
import 'package:dysgraphia_app/features/export/drawing_exporter.dart';
import 'package:dysgraphia_app/features/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _tabletView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scribble(WidgetTester tester) async {
  final canvas = find.byType(WritingCanvas);
  final g = await tester.startGesture(tester.getCenter(canvas));
  for (var i = 0; i < 5; i++) {
    await g.moveBy(const Offset(15, 4));
  }
  await g.up();
  await tester.pump();
}

void main() {
  group('AssessmentResult', () {
    test('has the documented shape', () {
      final task = defaultAssessmentTasks[1];
      final result = AssessmentResult(
        participant: 'P01',
        createdAt: DateTime.utc(2026, 11, 17, 9, 0, 0, 0, 999),
        tasks: [
          TaskResult(
            task: task,
            startedAt: DateTime.utc(2026, 11, 17, 9),
            duration: const Duration(milliseconds: 41250),
            drawing: Drawing([
              Stroke(const [StrokePoint(0, 0), StrokePoint(0.1, -0.2, t: 30)]),
            ]),
          ),
        ],
      );
      final j = result.toJson();
      expect(j['format'], 'dysgraphia-assessment');
      expect(j['version'], 1);
      expect(j['createdAt'], '2026-11-17T09:00:00.000Z');
      expect(j['participant'], 'P01');
      final t = (j['tasks'] as List).single as Map<String, dynamic>;
      expect(t['id'], 'alphabet_a_m');
      expect(t['target'], 'abcdefghijklm');
      expect(t['durationMs'], 41250);
      expect(t['skipped'], isFalse);
      expect((t['drawing']['strokes'] as List).single, hasLength(2));
      // Encodes cleanly as JSON text.
      expect(() => jsonEncode(j), returnsNormally);
    });

    test('an empty drawing counts as skipped', () {
      final r = TaskResult(
        task: defaultAssessmentTasks.first,
        startedAt: DateTime.now(),
        duration: Duration.zero,
        drawing: Drawing.empty,
      );
      expect(r.skipped, isTrue);
    });
  });

  test('default tasks have unique ids and targets', () {
    final ids = defaultAssessmentTasks.map((t) => t.id).toSet();
    expect(ids, hasLength(defaultAssessmentTasks.length));
    expect(defaultAssessmentTasks.every((t) => t.target != null), isTrue);
  });

  test('heightForUnit is the inverse of unit', () {
    final g = GuideGeometry(Size(800, GuideGeometry.heightForUnit(100)));
    expect(g.unit, closeTo(100, 1e-9));
  });

  testWidgets('full check: start screen, 4 tasks, one saved file', (
    tester,
  ) async {
    _tabletView(tester);
    final tmp = Directory.systemTemp.createTempSync('dys_assess');
    addTearDown(() => tmp.deleteSync(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          exporter: DrawingExporter(baseDirectory: () async => tmp),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), ' P07 ');
    await tester.tap(find.text('Start handwriting check'));
    await tester.pumpAndSettle();

    // Task 1: shapes, with a picture to copy and no guide lines.
    expect(find.text('Task 1 of 4'), findsOneWidget);
    expect(find.byKey(const Key('model-drawing')), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await _scribble(tester);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Task 2 starts empty: undo can't reach the previous task.
    expect(find.text('Task 2 of 4'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await _scribble(tester);
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Task 3: skipped.
    expect(find.text('Task 3 of 4'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();

    // Task 4: sentence to copy, then Finish (saves the file).
    expect(find.text('Task 4 of 4'), findsOneWidget);
    expect(find.byKey(const Key('model-text')), findsOneWidget);
    await _scribble(tester);
    expect(find.text('Finish'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Handwriting check complete'), findsOneWidget);
    expect(find.text('skipped'), findsOneWidget);
    expect(find.textContaining('Saved to'), findsOneWidget);

    final files = Directory('${tmp.path}/dysgraphia_exports').listSync();
    expect(files, hasLength(1));
    expect(files.single.uri.pathSegments.last, startsWith('assessment_P07_'));
    final j = jsonDecode(
      File(files.single.path).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(j['format'], 'dysgraphia-assessment');
    expect(j['participant'], 'P07');
    final tasks = (j['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks.map((t) => t['id']), [
      'shapes',
      'alphabet_a_m',
      'alphabet_n_z',
      'copy_sentence',
    ]);
    expect(tasks.map((t) => t['skipped']), [false, false, true, false]);

    await tester.tap(find.text('Back to start'));
    await tester.pumpAndSettle();
    expect(find.text('Start handwriting check'), findsOneWidget);
  });

  testWidgets('no participant code is saved as null', (tester) async {
    _tabletView(tester);
    final tmp = Directory.systemTemp.createTempSync('dys_assess_anon');
    addTearDown(() => tmp.deleteSync(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentPage(
          tasks: [defaultAssessmentTasks.last],
          exporter: DrawingExporter(baseDirectory: () async => tmp),
        ),
      ),
    );
    await _scribble(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final file = Directory('${tmp.path}/dysgraphia_exports').listSync().single;
    expect(file.uri.pathSegments.last, startsWith('assessment_anon_'));
    final j = jsonDecode(File(file.path).readAsStringSync());
    expect(j['participant'], isNull);
  });

  testWidgets('writing line shrinks so long tasks fit the screen width', (
    tester,
  ) async {
    _tabletView(tester);
    await tester.pumpWidget(
      MaterialApp(home: AssessmentPage(tasks: [defaultAssessmentTasks[1]])),
    );
    final size = tester.getSize(find.byType(WritingCanvas));
    final unit = GuideGeometry(size).unit;
    final needed = defaultAssessmentTasks[1].requiredWidthUnits * unit;
    expect(needed, lessThanOrEqualTo(size.width + 1));
  });
}
