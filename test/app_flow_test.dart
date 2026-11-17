import 'package:dysgraphia_app/app.dart';
import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/core/state/app_data.dart';
import 'package:dysgraphia_app/core/storage/progress_store.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps everything in memory, so widget tests need no real files.
class MemoryStore extends ProgressStore {
  List<Profile> profiles = [];
  final histories = <String, History>{};

  @override
  Future<List<Profile>> loadProfiles() async => [...profiles];
  @override
  Future<void> saveProfiles(List<Profile> p) async => profiles = [...p];
  @override
  Future<History> loadHistory(String id) async =>
      histories[id] ?? History.empty;
  @override
  Future<void> saveHistory(String id, History h) async => histories[id] = h;
  @override
  Future<void> deleteHistory(String id) async => histories.remove(id);
}

Future<void> _launch(WidgetTester tester, MemoryStore store) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: const DysgraphiaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

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

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

/// Taps a bottom navigation tab by its icon.
Future<void> _tab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets('first launch to the first finished challenge', (tester) async {
    final store = MemoryStore();
    await _launch(tester, store);

    // Welcome: a name is required.
    expect(find.text('Welcome to Handwriting Helper'), findsOneWidget);
    await _tapText(tester, "Let's start");
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Sami');
    await tester.tap(find.byKey(const Key('avatar-2')));
    await _tapText(tester, "Let's start");
    await tester.pumpAndSettle();

    // The journey: challenge 1 (letter c) is open, 2 is locked.
    expect(find.text("Sami's writing journey"), findsOneWidget);
    expect(find.text('Level A · Round letters'), findsOneWidget);
    expect(_textOf(tester, 'level-progress'), '0 of 6');
    expect(find.text('Start!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('challenge-2')));
    await tester.pump();
    expect(find.text('Finish challenge 1 to open this one'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Play challenge 1: warm-up circle, watch, trace and copy c.
    await tester.tap(find.byKey(const Key('challenge-1')));
    await tester.pumpAndSettle();
    expect(find.text('Challenge 1 · letter c'), findsOneWidget);
    await _trace(tester, 'warmup-circle');
    await tester.tap(find.text('Next: letter c'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trace it'));
    await tester.pumpAndSettle();
    await _trace(tester, 'c');
    await tester.tap(find.text('Copy it'));
    await tester.pumpAndSettle();
    await _copy(tester, 'c', 3);
    await tester.tap(find.text('Finish')); // no review in the first one
    await tester.pumpAndSettle();
    expect(find.text('Challenge 1 complete!'), findsOneWidget);

    await tester.tap(find.text('Back to journey'));
    await tester.pumpAndSettle();

    // Saved, and the journey moved on.
    final h = store.histories[store.profiles.single.id]!;
    expect(h.challenges.single.number, 1);
    expect(h.challenges.single.stars, 3);
    expect(_textOf(tester, 'level-progress'), '1 of 6');
    expect(_textOf(tester, 'journey-stars'), '3');
    expect(find.text('Start!'), findsOneWidget); // now on challenge 2
  });

  testWidgets('two people: pick who is practising, switch from Me', (
    tester,
  ) async {
    final store = MemoryStore()
      ..profiles = [
        Profile.create(name: 'Sami'),
        Profile.create(name: 'Nora', mode: ProfileMode.adult),
      ];
    await _launch(tester, store);

    expect(find.text("Who's practising?"), findsOneWidget);
    await tester.tap(find.text('Nora'));
    await tester.pumpAndSettle();
    expect(find.text('Your writing journey'), findsOneWidget);

    await _tab(tester, Icons.person_outline);
    await tester.tap(find.text('Switch person'));
    await tester.pumpAndSettle();
    expect(find.text("Who's practising?"), findsOneWidget);
  });

  testWidgets('add someone from Me, then edit and delete', (tester) async {
    final store = MemoryStore()..profiles = [Profile.create(name: 'Sami')];
    await _launch(tester, store);
    expect(find.text("Sami's writing journey"), findsOneWidget);

    await _tab(tester, Icons.person_outline);
    await tester.tap(find.text('Add someone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Lina');
    await _tapText(tester, 'Add');
    await tester.pumpAndSettle();
    expect(store.profiles.map((p) => p.name), ['Sami', 'Lina']);

    // The new person is now current; rename her.
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Lina M');
    await _tapText(tester, 'Save changes');
    await tester.pumpAndSettle();
    expect(store.profiles.last.name, 'Lina M');

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Delete profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.profiles.map((p) => p.name), ['Sami']);
    expect(find.text("Who's practising?"), findsOneWidget);
  });

  testWidgets('warm-ups from Practise are saved but are not letters', (
    tester,
  ) async {
    final store = MemoryStore()..profiles = [Profile.create(name: 'Sami')];
    await _launch(tester, store);
    await _tab(tester, Icons.draw_outlined);
    expect(find.byKey(const Key('letter-tile-warmup-circle')), findsOneWidget);
    expect(find.byKey(const Key('letter-tile-a')), findsOneWidget);

    await tester.tap(find.text('Do them all'));
    await tester.pumpAndSettle();
    expect(find.text('Lines down'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(
      find.text('Look at the shape, then draw it in box 1'),
      findsOneWidget,
    );
    await _copy(tester, 'warmup-down', 3);
    expect(find.text('Next: Lines across'), findsOneWidget);

    final h = store.histories[store.profiles.single.id]!;
    expect(h.attempts.map((a) => a.letter).toSet(), {'warmup-down'});

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tab(tester, Icons.route_outlined);
    expect(_textOf(tester, 'journey-stars'), '0');
  });
}
