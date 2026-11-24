import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/progress/skill_charts.dart';
import 'package:dysgraphia_app/features/progress/skill_trends.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Attempt _a(
  int day,
  Map<String, dynamic> score, {
  PracticeKind kind = PracticeKind.copy,
  int hour = 10,
}) => Attempt(
  letter: kind == PracticeKind.word ? 'word-cat' : 'a',
  kind: kind,
  stars: 2,
  overall: 0.7,
  score: score,
  drawing: Drawing([
    Stroke(const [StrokePoint(0, 0)]),
  ]),
  at: DateTime(2026, 11, day, hour),
);

/// A letter score with every measure at [v], except [over].
Map<String, dynamic> _letter(
  double v, [
  Map<String, dynamic> over = const {},
]) => {'looks': v, 'size': v, 'position': v, 'movement': v, ...over};

void main() {
  test('one point per practice day, averaged', () {
    final h = History(
      attempts: [
        _a(10, _letter(0.4)),
        _a(10, _letter(0.6), hour: 15),
        _a(12, _letter(0.9)),
      ],
    );
    final looks = skillTrends(h)[Skill.looks]!;
    expect(looks.map((p) => p.value), [closeTo(0.5, 1e-9), 0.9]);
    expect(looks.first.count, 2);
    expect(looks.first.day, DateTime(2026, 11, 10));
  });

  test('tracing is left out; words add spacing and "line"', () {
    final h = History(
      attempts: [
        _a(10, _letter(0.1), kind: PracticeKind.trace),
        _a(11, {
          'looks': 0.8,
          'line': 0.6,
          'spacing': 0.5,
        }, kind: PracticeKind.word),
      ],
    );
    final t = skillTrends(h);
    expect(t[Skill.looks]!.single.value, 0.8);
    expect(t[Skill.line]!.single.value, 0.6);
    expect(t[Skill.spacing]!.single.value, 0.5);
    expect(t[Skill.size], isEmpty);
  });

  test('old attempts without the new measures still count where they can', () {
    final h = History(
      attempts: [
        _a(10, {'shape': 0.7, 'size': 0.5, 'position': 0.9, 'strokes': 1}),
      ],
    );
    final t = skillTrends(h);
    expect(t[Skill.looks], isEmpty);
    expect(t[Skill.size]!.single.value, 0.5);
  });

  test('only the last practice days are shown', () {
    final h = History(
      attempts: [for (var d = 1; d <= 20; d++) _a(d, _letter(d / 20))],
    );
    final looks = skillTrends(h, days: 14)[Skill.looks]!;
    expect(looks, hasLength(14));
    expect(looks.first.day, DateTime(2026, 11, 7));
  });

  test('change compares the last 3 days with the first 3', () {
    final points = [
      for (final (i, v) in [0.4, 0.5, 0.6, 0.7, 0.8, 0.9].indexed)
        SkillPoint(DateTime(2026, 11, i + 1), v, 1),
    ];
    final s = summarise(Skill.size, points)!;
    expect(s.recent, closeTo(0.8, 1e-9));
    expect(s.change, closeTo(0.3, 1e-9));
    expect(summarise(Skill.size, points.take(1).toList())!.change, isNull);
    expect(summarise(Skill.size, const []), isNull);
  });

  test('most improved and practise next', () {
    final h = History(
      attempts: [
        _a(10, _letter(0.5, {'position': 0.3})),
        _a(11, _letter(0.55, {'position': 0.9})),
      ],
    );
    final sums = [
      for (final e in skillTrends(h).entries) ?summarise(e.key, e.value),
    ];
    expect(mostImproved(sums)!.skill, Skill.line);
    expect(needsWork(sums)!.skill, isNot(Skill.line));
    expect(needsWork(sums)!.recent, closeTo(0.55, 1e-9));
  });

  for (final width in [360.0, 1000.0]) {
    testWidgets('charts fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = History(
        attempts: [
          for (var d = 1; d <= 8; d++) _a(d, _letter(0.4 + d * 0.06)),
          _a(9, {
            'looks': 0.8,
            'line': 0.7,
            'spacing': 0.5,
          }, kind: PracticeKind.word),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SkillCharts(trends: skillTrends(h)),
            ),
          ),
        ),
      );
      for (final s in Skill.values) {
        expect(find.byKey(Key('skill-${s.name}')), findsOneWidget);
      }
      expect(find.byKey(const Key('most-improved')), findsOneWidget);
      expect(find.text('Practise next: Spacing (50%)'), findsOneWidget);
      final looks = tester.getRect(find.byKey(const Key('skill-looks')));
      final size = tester.getRect(find.byKey(const Key('skill-size')));
      // Two columns on wide screens, one on phones.
      expect(looks.top == size.top, width > 600);
    });
  }

  testWidgets('no practice yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SkillCharts(trends: skillTrends(History.empty))),
      ),
    );
    expect(
      find.text('Copy a letter or write a word to see your skills here.'),
      findsOneWidget,
    );
  });

  testWidgets('one skill both most improved and weakest is said once', (
    tester,
  ) async {
    final h = History(
      attempts: [
        _a(10, _letter(0.9, {'position': 0.3})),
        _a(11, _letter(0.9, {'position': 0.6})),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillCharts(trends: skillTrends(h)),
          ),
        ),
      ),
    );
    expect(
      find.text('Most improved: On the line +30%, keep practising it'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('needs-work')), findsNothing);
  });
}
