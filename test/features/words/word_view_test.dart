import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/scoring/word_scorer.dart';
import 'package:dysgraphia_app/features/words/word_templates.dart';
import 'package:dysgraphia_app/features/words/word_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _open(
  WidgetTester tester,
  String word, {
  void Function(Drawing, WordScore)? onChecked,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: WordView(
            word: practiceWords['word-$word']!,
            onChecked: onChecked,
          ),
        ),
      ),
    ),
  );
}

Future<void> _write(WidgetTester tester, Drawing d) async {
  final canvas = find.byKey(const Key('word-canvas'));
  final g = GuideGeometry(tester.getSize(canvas));
  final origin = tester.getTopLeft(canvas);
  for (final s in d.strokes) {
    final pen = await tester.startGesture(origin + g.toPixels(s.start));
    for (final p in s.points.skip(1)) {
      await pen.moveTo(origin + g.toPixels(p));
    }
    await pen.up();
  }
  await tester.pump();
}

String _message(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('word-message'))).data!;

void main() {
  testWidgets('a neat word gets stars for every letter', (tester) async {
    WordScore? saved;
    await _open(tester, 'cat', onChecked: (_, s) => saved = s);
    expect(
      _message(tester),
      'Look at the word "cat", then write it in the box',
    );
    final box = tester.getRect(find.byKey(const Key('word-canvas')));

    await _write(tester, practiceWords['word-cat']!.drawing.shifted(0.3, 0));
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(saved!.stars, 3);
    expect(_message(tester), 'Well done!');
    expect(find.text('Great job!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('letter-$i-stars-3')), findsOneWidget);
    }
    // The score fills its slot: the box does not move.
    expect(tester.getRect(find.byKey(const Key('word-canvas'))), box);

    await tester.tap(find.text('Write again'));
    await tester.pump();
    expect(find.byKey(const Key('letter-0-none')), findsOneWidget);
    expect(find.byKey(const Key('score-placeholder')), findsOneWidget);
  });

  testWidgets('squashed letters get a spacing tip', (tester) async {
    await _open(tester, 'go');
    // "g" and "o" written on top of each other.
    final g = practiceWords['word-go']!.letters[0].drawing;
    final o = practiceWords['word-go']!.letters[1].template.drawing;
    await _write(
      tester,
      Drawing([...g.strokes, ...o.shifted(0.35, 0).strokes]).shifted(0.3, 0),
    );
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Leave a small gap between the letters'), findsOneWidget);
  });
}
