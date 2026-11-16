import 'package:dysgraphia_app/features/exercises/trace/trace_view.dart';
import 'package:dysgraphia_app/features/home/home_page.dart';
import 'package:dysgraphia_app/features/templates/letter_gallery_page.dart';
import 'package:dysgraphia_app/features/templates/letter_page.dart';
import 'package:dysgraphia_app/features/templates/letter_template_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('gallery shows every letter and opens the letter page', (
    tester,
  ) async {
    _bigView(tester);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.tap(find.text('Letter templates'));
    await tester.pumpAndSettle();

    expect(find.byType(LetterGalleryPage), findsOneWidget);
    for (final c in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
      expect(find.byKey(Key('letter-$c')), findsOneWidget, reason: c);
    }
    expect(find.text('m · 3 strokes'), findsOneWidget);
    expect(find.text('o · 1 stroke'), findsOneWidget);

    await tester.tap(find.byKey(const Key('letter-g')));
    await tester.pumpAndSettle(); // lets the watch animation finish
    expect(find.text('Letter g'), findsOneWidget);

    await tester.tap(find.text('Trace it'));
    await tester.pumpAndSettle();
    expect(find.byType(TraceView), findsOneWidget);
    expect(find.text('Start at dot 1 and follow the arrow'), findsOneWidget);
  });

  testWidgets('watch animation plays stroke by stroke and can replay', (
    tester,
  ) async {
    _bigView(tester);
    await tester.pumpWidget(const MaterialApp(home: LetterPage(letter: 'a')));

    double? seconds() => tester
        .widget<LetterTemplateView>(find.byKey(const Key('letter-animation')))
        .seconds;

    expect(seconds(), 0);
    await tester.pump(const Duration(seconds: 1));
    final mid = seconds()!;
    expect(mid, closeTo(1, 0.05));

    await tester.pumpAndSettle();
    final end = seconds()!;
    expect(end, greaterThan(mid));

    await tester.tap(find.text('Watch again'));
    await tester.pump();
    expect(seconds(), 0);
    await tester.pumpAndSettle();
    expect(seconds(), closeTo(end, 1e-6));
  });
}
