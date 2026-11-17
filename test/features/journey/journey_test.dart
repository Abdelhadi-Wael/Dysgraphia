import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/journey/journey.dart';
import 'package:dysgraphia_app/features/progress/practice_plan.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt copy(String letter, int stars, {DateTime? at}) => Attempt(
  letter: letter,
  kind: PracticeKind.copy,
  stars: stars,
  overall: stars / 3,
  score: const {},
  drawing: Drawing([
    Stroke(const [StrokePoint(0, 0)]),
  ]),
  at: at,
);

History done(List<int> numbers, {List<Attempt> attempts = const []}) => History(
  attempts: attempts,
  challenges: [for (final n in numbers) ChallengeRecord(number: n, stars: 2)],
);

void main() {
  test('one challenge per letter, in teaching order, numbered from 1', () {
    expect(journey, hasLength(26));
    expect(journey.map((c) => c.letter).join(), teachingOrder);
    expect(journey.map((c) => c.number), [for (var i = 1; i <= 26; i++) i]);
  });

  test('levels A, B, C with 6, 9 and 11 challenges', () {
    final sizes = {
      for (final l in journeyLevels)
        l.id: journey.where((c) => c.level == l).length,
    };
    expect(sizes, {'A': 6, 'B': 9, 'C': 11});
  });

  test('every warm-up exists', () {
    for (final c in journey) {
      expect(warmUpShapes.containsKey(c.warmUp), isTrue, reason: c.letter);
    }
  });

  group('progress', () {
    test('a new learner starts at challenge 1, only it unlocked', () {
      final h = History.empty;
      expect(currentChallenge(h)?.number, 1);
      expect(isUnlocked(h, challengeNumber(1)), isTrue);
      expect(isUnlocked(h, challengeNumber(2)), isFalse);
    });

    test('finishing unlocks the next, whatever the stars', () {
      final h = History(challenges: [ChallengeRecord(number: 1, stars: 1)]);
      expect(currentChallenge(h)?.number, 2);
      expect(isUnlocked(h, challengeNumber(2)), isTrue);
      expect(isUnlocked(h, challengeNumber(3)), isFalse);
    });

    test('replays keep the best stars', () {
      final h = History(
        challenges: [
          ChallengeRecord(number: 1, stars: 1),
          ChallengeRecord(number: 1, stars: 3),
          ChallengeRecord(number: 1, stars: 2),
        ],
      );
      expect(challengeStars(h, 1), 3);
      expect(challengeStars(h, 2), isNull);
    });

    test('level progress and the end of the journey', () {
      final h = done([1, 2, 3]);
      expect(levelProgress(h, journeyLevels[0]), (3, 6));
      expect(levelProgress(h, journeyLevels[1]), (0, 9));
      final all = done([for (var i = 1; i <= 26; i++) i]);
      expect(currentChallenge(all), isNull);
      expect(isUnlocked(all, challengeNumber(26)), isTrue);
    });
  });

  group('review letter', () {
    test('none in the first challenge', () {
      expect(reviewLetter(History.empty, challengeNumber(1)), isNull);
    });

    test('the earlier letter with the fewest stars', () {
      // Challenge 4 (g): earlier letters c, a, d.
      final h = done(
        [1, 2, 3],
        attempts: [copy('c', 3), copy('a', 1), copy('d', 2)],
      );
      expect(reviewLetter(h, challengeNumber(4)), 'a');
    });

    test('ties go to the letter practised longest ago', () {
      final h = done(
        [1, 2, 3],
        attempts: [
          copy('c', 3, at: DateTime(2026, 11, 10)),
          copy('a', 3, at: DateTime(2026, 11, 12)),
          copy('d', 3, at: DateTime(2026, 11, 11)),
        ],
      );
      expect(reviewLetter(h, challengeNumber(4)), 'c');
    });
  });

  test('challenge records survive JSON', () {
    final h = History.fromJson(
      History().withChallenge(ChallengeRecord(number: 5, stars: 2)).toJson(),
    );
    expect(h.challenges.single.number, 5);
    expect(h.challenges.single.stars, 2);
  });
}
