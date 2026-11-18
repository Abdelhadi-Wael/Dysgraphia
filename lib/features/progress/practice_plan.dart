import '../../core/models/history.dart';

/// Order in which new letters are suggested: by shared movements, as
/// handwriting programmes often group them, so each new letter builds on
/// the last. Round letters that start like "c" first, then straight-line
/// letters, then arches, then diagonals and the rest.
const teachingOrder =
    'cadgoq'
    'lit'
    'nmhrbp'
    'uyvw'
    'ejkfsxz';

final _letterIds = teachingOrder.split('').toSet();

/// Best stars per letter from copy attempts (copying is the real test;
/// tracing is guided). Letters never copied are missing. Warm-up shapes are
/// not letters and are left out.
Map<String, int> bestStars(History h) => bestStarsFor(h, _letterIds);

/// Best copy stars for the given template ids only (letters, shapes or
/// words).
Map<String, int> bestStarsFor(History h, Iterable<String> ids) {
  final wanted = ids.toSet();
  final best = <String, int>{};
  for (final a in h.attempts) {
    if (a.kind == PracticeKind.trace || !wanted.contains(a.letter)) continue;
    final old = best[a.letter];
    if (old == null || a.stars > old) best[a.letter] = a.stars;
  }
  return best;
}

/// Sum of the best stars of every letter (at most 3 × 26 = 78).
int totalStars(History h) => bestStars(h).values.fold(0, (a, b) => a + b);

/// Days in a row with any practice, counting back from [today]. Practising
/// yesterday but not yet today keeps the streak alive.
int streakDays(History h, {DateTime? today}) {
  final days = {
    for (final a in h.attempts) _day(a.at.toLocal()),
    for (final c in h.checks) _day(c.at.toLocal()),
    for (final g in h.games) _day(g.at.toLocal()),
  };
  var day = _day((today ?? DateTime.now()).toLocal());
  // Step back by calendar days, not 24 hours (daylight saving changes).
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Up to [count] letters to practise today: first letters already copied
/// that still need work (fewest stars first, least recently practised
/// first), then new letters in [teachingOrder]. At most two "needs work"
/// letters, so every day also brings something new while letters remain.
List<String> suggestLetters(History h, {int count = 3}) {
  final best = bestStars(h);
  final lastPractised = <String, DateTime>{};
  for (final a in h.attempts) {
    lastPractised[a.letter] = a.at;
  }

  final weak =
      [
        for (final e in best.entries)
          if (e.value < 3) e.key,
      ]..sort((a, b) {
        final byStars = best[a]!.compareTo(best[b]!);
        return byStars != 0
            ? byStars
            : lastPractised[a]!.compareTo(lastPractised[b]!);
      });
  final fresh = [
    for (final c in teachingOrder.split(''))
      if (!best.containsKey(c)) c,
  ];

  final pick = <String>[...weak.take(fresh.isEmpty ? count : 2)];
  for (final c in [...fresh, ...weak]) {
    if (pick.length >= count) break;
    if (!pick.contains(c)) pick.add(c);
  }
  return pick;
}

/// Best finger game score with these settings, if played before.
int? bestFingerScore(
  History h, {
  required String pattern,
  required String speed,
  required int seconds,
}) {
  int? best;
  for (final g in h.games) {
    if (g.pattern != pattern || g.speed != speed || g.seconds != seconds) {
      continue;
    }
    if (best == null || g.score > best) best = g.score;
  }
  return best;
}
