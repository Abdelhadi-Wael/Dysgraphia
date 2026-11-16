import 'dart:convert';
import 'dart:io';

import 'package:dysgraphia_app/app.dart';
import 'package:dysgraphia_app/core/models/drawing_export.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/canvas/canvas_playground_page.dart';
import 'package:dysgraphia_app/features/export/drawing_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final drawing = Drawing([
    Stroke(const [
      StrokePoint(0.1, -0.4, t: 0, pressure: 0.3),
      StrokePoint(0.2, -0.1, t: 40, pressure: 0.6),
    ]),
  ]);
  final created = DateTime.utc(2026, 11, 17, 10, 22, 31, 123);

  group('DrawingExport', () {
    test('has the documented shape', () {
      final j = DrawingExport(
        drawing: drawing,
        target: 'o',
        createdAt: created,
      ).toJson();
      expect(j['format'], 'dysgraphia-drawing');
      expect(j['version'], 1);
      expect(j['createdAt'], '2026-11-17T10:22:31.123Z');
      expect(j['target'], 'o');
      final point = (j['drawing']['strokes'] as List)[0][1] as Map;
      expect(point.keys, unorderedEquals(['x', 'y', 't', 'p']));
    });

    test('survives a JSON text round trip', () {
      final text = jsonEncode(
        DrawingExport(drawing: drawing, createdAt: created).toJson(),
      );
      final back = DrawingExport.fromJson(jsonDecode(text));
      expect(back.target, isNull);
      expect(back.createdAt, created);
      expect(back.drawing.strokes.single.points[1].t, 40);
    });

    test('rejects other formats and versions', () {
      final good = DrawingExport(drawing: drawing).toJson();
      expect(
        () => DrawingExport.fromJson({...good, 'format': 'something-else'}),
        throwsFormatException,
      );
      expect(
        () => DrawingExport.fromJson({...good, 'version': 2}),
        throwsFormatException,
      );
    });

    test('createdAt is always stored in UTC', () {
      final local = DateTime(2026, 11, 17, 12);
      expect(
        DrawingExport(drawing: drawing, createdAt: local).createdAt.isUtc,
        isTrue,
      );
    });

    test('createdAt is rounded to milliseconds', () {
      final precise = DateTime.utc(2026, 11, 17, 10, 22, 31, 123, 456);
      final j = DrawingExport(drawing: drawing, createdAt: precise).toJson();
      expect(j['createdAt'], '2026-11-17T10:22:31.123Z');
    });
  });

  group('DrawingExporter', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('dys_export'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('writes a readable file named after target and time', () async {
      final exporter = DrawingExporter(baseDirectory: () async => tmp);
      final file = await exporter.save(
        DrawingExport(drawing: drawing, target: 'o', createdAt: created),
      );
      expect(
        file.path,
        '${tmp.path}/dysgraphia_exports/o_2026-11-17T10-22-31.123Z.json',
      );
      final back = DrawingExport.fromJson(jsonDecode(file.readAsStringSync()));
      expect(back.drawing.strokeCount, 1);
    });

    test('free writing and unsafe targets get safe file names', () async {
      final exporter = DrawingExporter(baseDirectory: () async => tmp);
      final free = await exporter.save(DrawingExport(drawing: drawing));
      final odd = await exporter.save(
        DrawingExport(drawing: drawing, target: 'a/b c'),
      );
      expect(free.uri.pathSegments.last, startsWith('free_'));
      expect(odd.uri.pathSegments.last, startsWith('a_b_c_'));
    });
  });

  testWidgets('Export button saves the drawing and shows where', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('dys_export_ui');
    addTearDown(() => tmp.deleteSync(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: CanvasPlaygroundPage(
          exporter: DrawingExporter(baseDirectory: () async => tmp),
        ),
      ),
    );
    final export = find.byTooltip('Export JSON');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: export, matching: find.byType(IconButton)).first,
          )
          .onPressed,
      isNull,
      reason: 'nothing to export yet',
    );

    final canvas = find.byKey(const Key('writing-canvas'));
    final g = await tester.startGesture(tester.getCenter(canvas));
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(20, 5));
    }
    await g.up();
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(export);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final files = Directory('${tmp.path}/dysgraphia_exports').listSync();
    expect(files, hasLength(1));
    final saved = DrawingExport.fromJson(
      jsonDecode(File(files.single.path).readAsStringSync()),
    );
    expect(saved.target, 'o');
    expect(saved.drawing.strokeCount, 1);
    expect(find.textContaining('Saved to'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
  });

  test('app still builds with the default exporter', () {
    expect(const DysgraphiaApp(), isA<DysgraphiaApp>());
  });
}
