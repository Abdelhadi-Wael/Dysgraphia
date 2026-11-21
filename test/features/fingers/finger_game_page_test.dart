import 'dart:async';

import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/features/fingers/finger_game.dart';
import 'package:dysgraphia_app/features/fingers/finger_game_page.dart';
import 'package:dysgraphia_app/features/fingers/hand_frame.dart';
import 'package:dysgraphia_app/features/fingers/hand_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_hands.dart';

/// Frames pushed by the test instead of the camera.
class FakeHandSource implements HandSource {
  FakeHandSource({this.problem});

  final HandSourceProblem? problem;
  final _frames = StreamController<HandFrame>.broadcast();
  var started = false, stopped = false;

  void push(HandFrame f) => _frames.add(f);

  @override
  Stream<HandFrame> get frames => _frames.stream;
  @override
  final ValueListenable<Size?> imageSize = ValueNotifier(const Size(4, 4));
  @override
  Widget? preview() => null;
  @override
  bool get mirrored => true;
  @override
  Future<void> start() async {
    if (problem != null) throw HandSourceException(problem!);
    started = true;
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  late FakeHandSource source;
  late List<FingerGameRecord> saved;
  var ms = 0;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    HandSourceProblem? problem,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    source = FakeHandSource(problem: problem);
    saved = [];
    ms = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FingerGamePage(
          source: () => source,
          onFinished: saved.add,
          bestScore: (_) => 1,
        ),
      ),
    );
  }

  /// A hand frame [step] ms after the last one.
  Future<void> frame(
    WidgetTester tester, {
    Finger? pinch,
    bool hand = true,
    int step = 100,
  }) async {
    ms += step;
    source.push(hand ? fake(ms, pinch) : noHand(ms));
    await tester.pump();
  }

  /// Pinches [f] (two frames to count), then opens the hand.
  Future<void> tap(WidgetTester tester, Finger f) async {
    await frame(tester, pinch: f);
    await frame(tester, pinch: f);
    await frame(tester);
  }

  testWidgets('a short round: hits, a wrong finger, then the results', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text('Touch your thumb to the finger with the same colour.'),
      findsOneWidget,
    );
    await tester.tap(find.text('30 s'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(source.started, isTrue);

    await frame(tester); // first frame starts the clock
    expect(find.byKey(const Key('target-pointer')), findsOneWidget);
    await tap(tester, Finger.pointer);
    expect(find.byKey(const Key('target-middle')), findsOneWidget);
    await tap(tester, Finger.pinky); // wrong: the target stays
    expect(find.byKey(const Key('target-middle')), findsOneWidget);
    await tap(tester, Finger.middle);
    expect(tester.widget<Text>(find.byKey(const Key('score'))).data, '2');

    // Hand away: the clock stops and "Show your hand" appears.
    await frame(tester, hand: false, step: 20000);
    expect(find.byKey(const Key('show-hand')), findsOneWidget);

    // Play out the rest of the 30 s with an open hand.
    while (saved.isEmpty) {
      await frame(tester, step: 500);
    }
    await tester.pumpAndSettle();
    expect(source.stopped, isTrue, reason: 'camera off after the round');
    expect(find.text('New best!'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('final-score'))).data, '2');
    final r = saved.single;
    expect((r.hits, r.wrong, r.seconds), (2, 1, 30));
    expect(r.missed, greaterThan(0));
    expect(r.pattern, PinchPattern.inOrder.name);
  });

  testWidgets('no camera: a friendly message, nothing saved', (tester) async {
    await open(tester, problem: HandSourceProblem.denied);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('The camera is not allowed'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(saved, isEmpty);
  });

  for (final size in const [Size(360, 740), Size(800, 369), Size(1280, 800)]) {
    testWidgets('fits at $size', (tester) async {
      await open(tester, size: size);
      await tester.scrollUntilVisible(find.text('Start'), 100);
      await tester.ensureVisible(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await frame(tester);
      await frame(tester, pinch: Finger.pointer);
      expect(find.byKey(const Key('score')), findsOneWidget);
    });
  }
}

/// [hand] from fake_hands, scaled to the fake 4×4 image.
HandFrame fake(int ms, Finger? pinch) =>
    hand(ms, pinch: pinch, scale: 0.8, dx: 2);
