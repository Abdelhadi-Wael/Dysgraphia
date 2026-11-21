import '../../core/models/history.dart';
import '../progress/practice_plan.dart';
import '../words/word_templates.dart';

/// A stage of the writing journey: letters that share movements.
class JourneyLevel {
  const JourneyLevel(this.id, this.name, this.letters);

  final String id;
  final String name;

  /// New letters introduced in this level, in order (empty for words).
  final String letters;
}

/// After the letters: putting them together in words.
const wordsLevel = JourneyLevel('D', 'Words', '');

/// Words practised in each challenge of [wordsLevel], two at a time, in the
/// order of [wordGroups] (easiest letters first).
final List<List<String>> wordChallenges = [
  for (final g in wordGroups)
    for (var i = 0; i < g.words.length; i += 2)
      [for (final w in g.words.skip(i).take(2)) 'word-$w'],
];

/// The letter levels follow [teachingOrder]: round letters, then straight
/// lines and arches, then slants and the rest. Then words.
const journeyLevels = [
  JourneyLevel('A', 'Round letters', 'cadgoq'),
  JourneyLevel('B', 'Lines and arches', 'litnmhrbp'),
  JourneyLevel('C', 'Slants and more', 'uyvwejkfsxz'),
  wordsLevel,
];

/// One stop on the journey: a short session. A letter challenge warms up
/// with a shape, teaches one new letter and reviews an earlier one; a word
/// challenge writes two words and reviews a letter.
class Challenge {
  const Challenge({
    required this.number,
    required this.level,
    this.letter,
    this.warmUp,
    this.words = const [],
  });

  /// 1-based, across all levels.
  final int number;
  final JourneyLevel level;

  /// The new letter, for a letter challenge.
  final String? letter;

  /// Id of the warm-up shape that trains this letter's main movement.
  final String? warmUp;

  /// Word ids ("word-cat"), for a word challenge.
  final List<String> words;

  bool get isWords => words.isNotEmpty;

  /// What the challenge is about, in a few characters: "a" or "go, dog".
  String get name => letter ?? words.map(practiceWordText).join(', ');
}

/// Warm-up shape for each letter: the movement it relies on most.
const _warmUpFor = {
  'c': 'warmup-circle',
  'a': 'warmup-circle',
  'd': 'warmup-down',
  'g': 'warmup-waves',
  'o': 'warmup-circle',
  'q': 'warmup-down',
  'l': 'warmup-down',
  'i': 'warmup-down',
  't': 'warmup-across',
  'n': 'warmup-waves',
  'm': 'warmup-waves',
  'h': 'warmup-down',
  'r': 'warmup-waves',
  'b': 'warmup-circle',
  'p': 'warmup-down',
  'u': 'warmup-waves',
  'y': 'warmup-slants',
  'v': 'warmup-slants',
  'w': 'warmup-zigzag',
  'e': 'warmup-across',
  'j': 'warmup-down',
  'k': 'warmup-slants',
  'f': 'warmup-across',
  's': 'warmup-waves',
  'x': 'warmup-slants',
  'z': 'warmup-zigzag',
};

/// All challenges in order: one per letter, then the word challenges.
final List<Challenge> journey = () {
  final out = <Challenge>[];
  for (final level in journeyLevels) {
    for (final l in level.letters.split('').where((l) => l.isNotEmpty)) {
      out.add(
        Challenge(
          number: out.length + 1,
          level: level,
          letter: l,
          warmUp: _warmUpFor[l]!,
        ),
      );
    }
  }
  for (final words in wordChallenges) {
    out.add(Challenge(number: out.length + 1, level: wordsLevel, words: words));
  }
  return List<Challenge>.unmodifiable(out);
}();

Challenge challengeNumber(int n) => journey[n - 1];

Set<int> completedChallenges(History h) => {
  for (final c in h.challenges) c.number,
};

/// The next challenge to do: the first one not finished yet. Null when the
/// whole journey is done.
Challenge? currentChallenge(History h) {
  final done = completedChallenges(h);
  for (final c in journey) {
    if (!done.contains(c.number)) return c;
  }
  return null;
}

/// Finishing a challenge unlocks the next one, whatever the stars, so a
/// child who struggles is never stuck; weak letters come back as reviews.
bool isUnlocked(History h, Challenge c) {
  final current = currentChallenge(h);
  return current == null || c.number <= current.number;
}

/// Best stars ever earned in challenge [n], or null if not finished.
int? challengeStars(History h, int n) {
  int? best;
  for (final c in h.challenges) {
    if (c.number == n && (best == null || c.stars > best)) best = c.stars;
  }
  return best;
}

/// Which earlier letter to review in [c]: the one with the fewest best
/// stars, and among equals the one practised longest ago. Null in the
/// first challenge.
String? reviewLetter(History h, Challenge c) {
  final earlier = [
    for (final e in journey)
      if (e.number < c.number && e.letter != null) e.letter!,
  ];
  if (earlier.isEmpty) return null;
  final best = bestStars(h);
  final last = <String, DateTime>{};
  for (final a in h.attempts) {
    last[a.letter] = a.at;
  }
  final never = DateTime.fromMillisecondsSinceEpoch(0);
  earlier.sort((a, b) {
    final byStars = (best[a] ?? 0).compareTo(best[b] ?? 0);
    if (byStars != 0) return byStars;
    return (last[a] ?? never).compareTo(last[b] ?? never);
  });
  return earlier.first;
}

/// Progress through [level]: (finished challenges, total).
(int, int) levelProgress(History h, JourneyLevel level) {
  final inLevel = journey.where((c) => c.level == level);
  final done = completedChallenges(h);
  return (inLevel.where((c) => done.contains(c.number)).length, inLevel.length);
}
