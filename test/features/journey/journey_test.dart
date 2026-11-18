import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/journey/journey.dart';
import 'package:dysgraphia_app/features/progress/practice_plan.dart';
import 'package:dysgraphia_app/features/templates/warmup_shapes.dart';
import 'package:dysgraphia_app/features/words/word_templates.dart';
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
  test('one challenge per letter in teaching order, then words', () {
    expect(journey, hasLength(34));
    expect(journey.take(26).map((c) => c.letter).join(), teachingOrder);
    expect(journey.map((c) => c.number), [for (var i = 1; i <= 34; i++) i]);
    final words = journey.skip(26).toList();
    expect(words.every((c) => c.isWords && c.level == wordsLevel), isTrue);
    expect(words.first.name, 'go, dog');
    expect(words.expand((c) => c.words), hasLength(16));
  });

  test('every word only uses letters taught before it', () {
    for (final (i, g) in wordGroups.indexed) {
      final taught = journeyLevels.take(i + 1).map((l) => l.letters).join();
      for (final w in g.words) {
        for (final c in w.split('')) {
          expect(taught, contains(c), reason: w);
        }
      }
    }
  });

  test('levels A, B, C, D with 6, 9, 11 and 8 challenges', () {
    final sizes = {
      for (final l in journeyLevels)
        l.id: journey.where((c) => c.level == l).length,
    };
    expect(sizes, {'A': 6, 'B': 9, 'C': 11, 'D': 8});
  });

  test('every warm-up exists', () {
    for (final c in journey.where((c) => !c.isWords)) {
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
      final all = done([for (var i = 1; i <= 34; i++) i]);
      expect(currentChallenge(all), isNull);
      expect(isUnlocked(all, challengeNumber(34)), isTrue);
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
