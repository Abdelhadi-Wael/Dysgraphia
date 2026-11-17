// Every screen must fit on phones (portrait and landscape) and tablets.
// Flutter tests fail on any layout overflow, so opening each screen at each
// size is enough to catch "A RenderFlex overflowed …" errors.
import 'package:dysgraphia_app/app.dart';
import 'package:dysgraphia_app/core/models/guide_geometry.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/core/state/app_data.dart';
import 'package:dysgraphia_app/features/assessment/assessment_page.dart';
import 'package:dysgraphia_app/features/assessment/assessment_task.dart';
import 'package:dysgraphia_app/features/dev/dev_tools_page.dart';
import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/home/main_shell.dart';
import 'package:dysgraphia_app/features/journey/challenge_page.dart';
import 'package:dysgraphia_app/features/journey/journey.dart';
import 'package:dysgraphia_app/features/profiles/profile_form_page.dart';
import 'package:dysgraphia_app/features/profiles/profile_picker_page.dart';
import 'package:dysgraphia_app/features/templates/letter_gallery_page.dart';
import 'package:dysgraphia_app/features/templates/letter_page.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../app_flow_test.dart' show MemoryStore;

const sizes = {
  'small phone': Size(360, 740),
  'phone portrait': Size(411, 891),
  'phone landscape': Size(800, 369),
  'tablet': Size(1280, 800),
};

Future<void> _open(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = MemoryStore()..profiles = [Profile.create(name: 'Sami')];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: DysgraphiaApp.theme(Brightness.light),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 6)); // animations finish
}

/// Writes [d] (canvas line units) on [canvas].
Future<void> _write(WidgetTester tester, Finder canvas, Drawing d) async {
  await tester.ensureVisible(canvas);
  await tester.pump();
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

class _Shell extends ConsumerWidget {
  const _Shell();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(appDataProvider).hasValue
      ? const MainShell()
      : const SizedBox();
}

void main() {
  final sami = Profile.create(name: 'Sami');
  final screens = <String, Widget Function()>{
    'welcome': () => const ProfileFormPage(firstRun: true),
    'edit profile': () => ProfileFormPage(profile: sami),
    'picker': () => ProfilePickerPage(
      profiles: [
        sami,
        Profile.create(name: 'Nora Alexandra'),
      ],
    ),
    'main tabs': () => const _Shell(),
    'letter watch': () => const LetterPage(letter: 'm'),
    'letter trace': () =>
        const LetterPage(letter: 'm', initialStep: LetterStep.trace),
    'letter copy': () =>
        const LetterPage(letter: 'm', initialStep: LetterStep.copy),
    'shape copy': () => const LetterPage(
      letter: 'warmup-waves',
      initialStep: LetterStep.copy,
      queue: ['warmup-zigzag'],
    ),
    'challenge': () =>
        ChallengePage(challenge: challengeNumber(9), review: 'a'),
    'check shapes': () => AssessmentPage(tasks: [defaultAssessmentTasks[0]]),
    'check sentence': () => AssessmentPage(tasks: [defaultAssessmentTasks[3]]),
    'dev tools': () => const DevToolsPage(),
    'letter gallery': () => const LetterGalleryPage(),
  };

  for (final size in sizes.entries) {
    group(size.key, () {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} fits', (tester) async {
          await _open(tester, size.value, screen.value());
        });
      }

      testWidgets('tracing works and the score card fits', (tester) async {
        await _open(
          tester,
          size.value,
          const LetterPage(letter: 'm', initialStep: LetterStep.trace),
        );
        await _write(
          tester,
          find.byKey(const Key('trace-canvas')),
          TraceView.shapeFor(templateFor('m')),
        );
        await tester.pump(const Duration(seconds: 1));
        // Completing the trace needs every stroke accepted: the page must
        // not scroll under the pen, even on a short screen.
        expect(find.text('Details'), findsOneWidget);
      });

      testWidgets('copying works and the score card fits', (tester) async {
        await _open(
          tester,
          size.value,
          const LetterPage(letter: 'm', initialStep: LetterStep.copy),
        );
        await _write(
          tester,
          find.byKey(const Key('copy-canvas-0')),
          templateFor('m').drawing.shifted(0.2, 0),
        );
        await tester.ensureVisible(find.text('Check'));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Details'), findsOneWidget);
      });
    });
  }
}
