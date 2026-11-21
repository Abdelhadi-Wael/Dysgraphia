import 'package:dysgraphia_app/core/audio/app_audio.dart';
import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/journey/challenge_page.dart';
import 'package:dysgraphia_app/features/journey/journey.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Writes [d] on [canvas], shifted right by [dx] line units.
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

Future<void> _trace(WidgetTester tester, String id) => _write(
  tester,
  find.byKey(const Key('trace-canvas')),
  TraceView.shapeFor(templateFor(id)),
);

Future<void> _copy(WidgetTester tester, String id, int boxes) async {
  for (var b = 0; b < boxes; b++) {
    await _write(
      tester,
      find.byKey(Key('copy-canvas-$b')),
      templateFor(id).drawing,
      dx: 0.3,
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
  }
}

/// Records what would be said and played.
class _FakeAudio implements AppAudio {
  final said = <String>[];
  final played = <Sfx>[];
  @override
  Future<void> say(String text) async => said.add(text);
  @override
  Future<void> play(Sfx sfx) async => played.add(sfx);
  @override
  Future<void> stop() async {}
}

String _stepLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('challenge-step'))).data!;

void main() {
  testWidgets('a full challenge: warm-up, letter, review, celebration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final attempts = <Attempt>[];
    final audio = _FakeAudio();
    int? completedStars;
    final challenge = challengeNumber(2); // letter a, warm-up circles
    await tester.pumpWidget(
      MaterialApp(
        home: AppAudioScope(
          audio: audio,
          child: ChallengePage(
            challenge: challenge,
            review: 'c',
            onAttempt: attempts.add,
            onComplete: (s) => completedStars = s,
          ),
        ),
      ),
    );

    expect(find.text('Challenge 2 · letter a'), findsOneWidget);
    expect(_stepLabel(tester), 'Step 1 of 5 · Warm-up: Circles');
    await _trace(tester, challenge.warmUp);
    await tester.tap(find.text('Next: letter a'));
    await tester.pumpAndSettle();

    expect(_stepLabel(tester), 'Step 2 of 5 · Watch');
    await tester.tap(find.text('Trace it'));
    await tester.pumpAndSettle();

    // A fresh trace view: the warm-up's strokes are not carried over.
    expect(_stepLabel(tester), 'Step 3 of 5 · Trace');
    expect(find.text('Start at dot 1 and follow the arrow'), findsOneWidget);
    await _trace(tester, 'a');
    await tester.tap(find.text('Copy it'));
    await tester.pumpAndSettle();

    expect(_stepLabel(tester), 'Step 4 of 5 · Copy');
    await _copy(tester, 'a', 3);
    await tester.tap(find.text('Next: review'));
    await tester.pumpAndSettle();

    expect(_stepLabel(tester), 'Step 5 of 5 · Review');
    expect(find.text('Letter c'), findsNothing); // shown as a copy step
    await _copy(tester, 'c', 1);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Challenge 2 complete!'), findsOneWidget);
    expect(find.byKey(const Key('celebration-stars-3')), findsOneWidget);
    expect(find.text('Challenge 3 is now open.'), findsOneWidget);
    expect(completedStars, 3);
    expect(audio.played.last, Sfx.success);
    expect(audio.said.last, 'Challenge 2 complete! You got 3 stars.');
    expect(attempts.map((a) => '${a.letter}:${a.kind.name}'), [
      'warmup-circle:trace',
      'a:trace',
      'a:copy',
      'a:copy',
      'a:copy',
      'c:copy',
    ]);
  });

  testWidgets('without a review the copy step leads to the finish', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ChallengePage(challenge: challengeNumber(1))),
    );
    expect(_stepLabel(tester), 'Step 1 of 4 · Warm-up: Circles');
  });

  testWidgets('going back a step and forward again', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final attempts = <Attempt>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ChallengePage(
          challenge: challengeNumber(2),
          onAttempt: attempts.add,
        ),
      ),
    );
    final back = find.byKey(const Key('previous-step'));
    expect(tester.widget<IconButton>(back).onPressed, isNull);

    await _trace(tester, 'warmup-circle');
    await tester.tap(find.text('Next: letter a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trace it'));
    await tester.pumpAndSettle();
    expect(_stepLabel(tester), 'Step 3 of 4 · Trace');

    // Back to watch the letter again: the animation plays from the start.
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(_stepLabel(tester), 'Step 2 of 4 · Watch');
    await tester.tap(find.text('Trace it'));
    await tester.pumpAndSettle();
    expect(_stepLabel(tester), 'Step 3 of 4 · Trace');
    expect(find.text('Start at dot 1 and follow the arrow'), findsOneWidget);

    // Back to the warm-up: its earlier result stays saved.
    await tester.tap(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(_stepLabel(tester), 'Step 1 of 4 · Warm-up: Circles');
    expect(attempts.map((a) => a.letter), ['warmup-circle']);
  });
}
