import 'package:dysgraphia_app/core/audio/app_audio.dart';
import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/exercises/copy/copy_view.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:dysgraphia_app/features/templates/watch_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Records what would be said and played.
class FakeAudio implements AppAudio {
  final said = <String>[];
  final played = <Sfx>[];

  @override
  Future<void> say(String text) async => said.add(text);
  @override
  Future<void> play(Sfx sfx) async => played.add(sfx);
  @override
  Future<void> stop() async {}
}

Future<FakeAudio> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audio = FakeAudio();
  await tester.pumpWidget(
    MaterialApp(
      home: AppAudioScope(
        audio: audio,
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  return audio;
}

Future<void> _write(
  WidgetTester tester,
  Finder canvas,
  List<StrokePoint> points, {
  bool lift = true,
  double dx = 0,
}) async {
  final g = GuideGeometry(tester.getSize(canvas));
  final origin = tester.getTopLeft(canvas);
  Offset px(StrokePoint p) => origin + g.toPixels(StrokePoint(p.x + dx, p.y));
  final pen = await tester.startGesture(px(points.first));
  for (final p in points.skip(1)) {
    await pen.moveTo(px(p));
  }
  if (lift) await pen.up();
  await tester.pump();
}

void main() {
  group('trace', () {
    testWidgets('reads the first instruction, then each change', (
      tester,
    ) async {
      final l = templateFor('l');
      final audio = await _pump(tester, TraceView(template: l));
      expect(audio.said, ['Start at dot 1 and follow the arrow']);

      // An upward line: rejected, with a gentle sound and the reason.
      final shape = TraceView.shapeFor(l).strokes.single.points;
      final canvas = find.byKey(const Key('trace-canvas'));
      await _write(tester, canvas, shape.reversed.toList());
      expect(audio.played, [Sfx.oops]);
      expect(audio.said.last, 'Start at dot 1');

      // Correct: success sound and praise with the tip.
      await tester.pump(const Duration(seconds: 1));
      await _write(tester, canvas, shape);
      expect(audio.played.last, Sfx.success);
      expect(audio.said.last, 'Well done! Great job!');
    });

    testWidgets('stays quiet while writing well, speaks up on a mistake', (
      tester,
    ) async {
      final o = templateFor('o');
      final audio = await _pump(tester, TraceView(template: o));
      final shape = TraceView.shapeFor(o).strokes.single.points;
      final canvas = find.byKey(const Key('trace-canvas'));

      // First half of a correct o, pen still down: nothing new said.
      await _write(tester, canvas, shape.sublist(0, 20), lift: false);
      expect(audio.said, ['Start at dot 1 and follow the arrow']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a clockwise o is called out while writing', (tester) async {
      final o = templateFor('o');
      final audio = await _pump(tester, TraceView(template: o));
      final cw = TraceView.shapeFor(o).strokes.single.points.reversed.toList();
      await _write(
        tester,
        find.byKey(const Key('trace-canvas')),
        cw.sublist(0, cw.length ~/ 3),
        lift: false,
      );
      expect(audio.said.last, 'Go the other way: follow the arrow');
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('copy: instruction, then star sound with tip and next box', (
    tester,
  ) async {
    final o = templateFor('o');
    final audio = await _pump(tester, CopyView(template: o, attempts: 2));
    expect(audio.said, ['Look at the letter, then write it in box 1']);

    // Too big in box 1.
    final big = [
      for (final p in o.drawing.strokes.single.points)
        StrokePoint(p.x * 1.6, p.y * 1.6),
    ];
    await _write(tester, find.byKey(const Key('copy-canvas-0')), big, dx: 0.2);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(audio.played, [Sfx.star]);
    expect(
      audio.said.last,
      'Make it a little smaller Now write it again in box 2.',
    );

    await _write(
      tester,
      find.byKey(const Key('copy-canvas-1')),
      o.drawing.strokes.single.points,
      dx: 0.3,
    );
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(audio.played.last, Sfx.success);
    expect(audio.said.last, 'Great job! All done!');
  });

  testWidgets('watch says which letter', (tester) async {
    final audio = await _pump(
      tester,
      WatchView(template: templateFor('a'), onNext: () {}),
    );
    expect(audio.said, ['Watch how to write the letter a.']);
    await tester.pumpAndSettle();
  });

  testWidgets('watch says which shape', (tester) async {
    final audio = await _pump(
      tester,
      WatchView(template: templateFor('warmup-waves'), onNext: () {}),
    );
    expect(audio.said, ['Watch how to draw waves.']);
    await tester.pumpAndSettle();
  });

  test('profile audio defaults: on for children, speech off for adults', () {
    final kid = Profile.create(name: 'Sami');
    final adult = Profile.create(name: 'Nora', mode: ProfileMode.adult);
    expect((kid.readAloud, kid.sounds), (true, true));
    expect((adult.readAloud, adult.sounds), (false, true));
    // Older saved profiles without the fields get the defaults.
    final old = Profile.fromJson(
      {...kid.toJson()}
        ..remove('readAloud')
        ..remove('sounds'),
    );
    expect((old.readAloud, old.sounds), (true, true));
    final quiet = kid.copyWith(readAloud: false, sounds: false);
    final back = Profile.fromJson(quiet.toJson());
    expect((back.readAloud, back.sounds), (false, false));
  });

  test('silent audio and a scope-less context do nothing', () async {
    const silent = SilentAudio();
    await silent.say('hello');
    await silent.play(Sfx.star);
    await silent.stop();
  });
}
