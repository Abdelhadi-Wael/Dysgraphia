import 'package:dysgraphia_app/features/home/home_page.dart';
import 'package:dysgraphia_app/features/templates/letter_gallery_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('gallery shows every letter and opens it for tracing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    await tester.pumpAndSettle();
    expect(find.text('Writing canvas: g'), findsOneWidget);
  });
}
