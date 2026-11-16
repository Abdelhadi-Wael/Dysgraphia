import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/progress/practice_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt a(
  String letter,
  int stars, {
  PracticeKind kind = PracticeKind.copy,
  DateTime? at,
}) => Attempt(
  letter: letter,
  kind: kind,
  stars: stars,
  overall: stars / 3,
  score: const {},
  drawing: Drawing([
    Stroke(const [StrokePoint(0, 0)]),
  ]),
  at: at,
);

History h(List<Attempt> attempts, {List<CheckRecord> checks = const []}) =>
    History(attempts: attempts, checks: checks);

void main() {
  test('teaching order has every letter exactly once', () {
    expect(teachingOrder.split('').toSet(), hasLength(26));
    expect(teachingOrder.length, 26);
  });

  group('stars', () {
    test('best copy stars per letter; tracing does not count', () {
      final hist = h([
        a('a', 1),
        a('a', 3),
        a('a', 2),
        a('b', 3, kind: PracticeKind.trace),
      ]);
      expect(bestStars(hist), {'a': 3});
      expect(totalStars(hist), 3);
    });
  });

  group('streak', () {
    final today = DateTime(2026, 11, 17, 15);
    DateTime daysAgo(int n) => DateTime(2026, 11, 17 - n, 10);

    test('counts consecutive days up to today', () {
      final hist = h([
        a('a', 1, at: daysAgo(0)),
        a('a', 1, at: daysAgo(1)),
        a('a', 1, at: daysAgo(2)),
        a('a', 1, at: daysAgo(4)),
      ]);
      expect(streakDays(hist, today: today), 3);
    });

    test('yesterday still counts if today is not done yet', () {
      final hist = h([a('a', 1, at: daysAgo(1)), a('a', 1, at: daysAgo(2))]);
      expect(streakDays(hist, today: today), 2);
    });

    test('a gap of two days resets it; checks count as practice', () {
      expect(streakDays(h([a('a', 1, at: daysAgo(2))]), today: today), 0);
      final check = CheckRecord(tasks: 4, skipped: 0, at: daysAgo(0));
      expect(streakDays(h([], checks: [check]), today: today), 1);
    });

    test('nothing done: 0', () {
      expect(streakDays(History.empty, today: today), 0);
    });
  });

  group('suggestions', () {
    test('a new learner starts with the first letters of the order', () {
      expect(suggestLetters(History.empty), ['c', 'a', 'd']);
    });

    test('weak letters first, fewest stars first, then new ones', () {
      final t0 = DateTime(2026, 11, 1);
      final hist = h([
        a('c', 3, at: t0),
        a('a', 2, at: t0),
        a('d', 1, at: t0.add(const Duration(hours: 1))),
        a('g', 1, at: t0),
      ]);
      // d and g both have 1 star; g was practised longer ago.
      expect(suggestLetters(hist), ['g', 'd', 'o']);
    });

    test('mastered letters are not suggested while others remain', () {
      final hist = h([for (final c in 'cadgoq'.split('')) a(c, 3)]);
      expect(suggestLetters(hist), ['l', 'i', 't']);
    });

    test('when every letter is copied, only those below 3 stars', () {
      final allThree = h([for (final c in teachingOrder.split('')) a(c, 3)]);
      expect(suggestLetters(allThree), isEmpty);

      final someWeak = h([
        for (final c in teachingOrder.split(''))
          a(c, switch (c) {
            'k' => 2,
            's' => 1,
            _ => 3,
          }),
      ]);
      expect(suggestLetters(someWeak), ['s', 'k']);
    });
  });
}
