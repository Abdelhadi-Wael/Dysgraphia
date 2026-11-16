import 'package:dysgraphia_app/app.dart';
import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/core/state/app_data.dart';
import 'package:dysgraphia_app/core/storage/progress_store.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
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

Future<void> _writeIn(WidgetTester tester, Finder canvas, Drawing d) async {
  final g = GuideGeometry(tester.getSize(canvas));
  final origin = tester.getTopLeft(canvas);
  Offset px(StrokePoint p) => origin + g.toPixels(StrokePoint(p.x + 0.3, p.y));
  for (final s in d.strokes) {
    final pen = await tester.startGesture(px(s.start));
    for (final p in s.points.skip(1)) {
      await pen.moveTo(px(p));
    }
    await pen.up();
  }
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

void main() {
  testWidgets('first launch to first stars', (tester) async {
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

    // Home with today's practice for a beginner.
    expect(find.text('Hi, Sami!'), findsOneWidget);
    expect(store.profiles.single.avatar, 2);
    for (final l in ['c', 'a', 'd']) {
      expect(find.byKey(Key('today-$l')), findsOneWidget);
    }

    // Start → letter c → copy it three times.
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Letter c'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    final c = latinLowercase['c']!.drawing;
    for (var box = 0; box < 3; box++) {
      await _writeIn(tester, find.byKey(Key('copy-canvas-$box')), c);
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Next letter: a'), findsOneWidget);

    // Saved for Sami.
    final id = store.profiles.single.id;
    expect(store.histories[id]!.attempts, hasLength(3));

    // Back home: c now has stars and is no longer suggested.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Hi, Sami!'), findsOneWidget);
    expect(find.byKey(const Key('today-c')), findsNothing);
    expect(find.byKey(const Key('today-g')), findsOneWidget);
  });

  testWidgets('two people: pick who is practising', (tester) async {
    final store = MemoryStore()
      ..profiles = [
        Profile.create(name: 'Sami'),
        Profile.create(name: 'Nora', mode: ProfileMode.adult),
      ];
    await _launch(tester, store);

    expect(find.text("Who's practising?"), findsOneWidget);
    await tester.tap(find.text('Nora'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Nora'), findsOneWidget);

    // Settings → switch person → back to the picker.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch person'));
    await tester.pumpAndSettle();
    expect(find.text("Who's practising?"), findsOneWidget);
  });

  testWidgets('add someone from settings, then edit and delete', (
    tester,
  ) async {
    final store = MemoryStore()..profiles = [Profile.create(name: 'Sami')];
    await _launch(tester, store);
    expect(find.text('Hi, Sami!'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
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

    // Delete her: back to Sami as the only one... via the picker.
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Delete profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.profiles.map((p) => p.name), ['Sami']);
    expect(find.text("Who's practising?"), findsOneWidget);
  });
}
