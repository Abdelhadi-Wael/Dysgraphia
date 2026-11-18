import '../../core/models/history.dart';

/// The writing skills the scorers measure (see docs/scoring.md), as shown
/// in progress charts.
enum Skill {
  looks('Looks right', ['looks']),
  size('Size', ['size']),
  line('On the line', ['position', 'line']),
  spacing('Spacing', ['spacing']),
  movement('Written the right way', ['movement']);

  const Skill(this.label, this.keys);

  final String label;

  /// Where the value is in a saved score: letters say "position", words
  /// "line". Spacing only exists for words.
  final List<String> keys;

  double? valueIn(Map<String, dynamic> score) {
    for (final k in keys) {
      if (score[k] case final num v) return v.toDouble();
    }
    return null;
  }
}

/// One practice day's average for a skill (0..1).
class SkillPoint {
  const SkillPoint(this.day, this.value, this.count);

  /// Local calendar day.
  final DateTime day;
  final double value;

  /// Scored attempts behind the average.
  final int count;
}

/// Day-by-day average of each skill over copied letters and written words
/// (tracing is guided, so it is left out), for the last [days] days with
/// practice. Skills never measured (e.g. spacing before any word, or old
/// attempts saved before a measure existed) have no points.
Map<Skill, List<SkillPoint>> skillTrends(History h, {int days = 14}) {
  final sums = {for (final s in Skill.values) s: <DateTime, (double, int)>{}};
  for (final a in h.attempts) {
    if (a.kind == PracticeKind.trace) continue;
    final t = a.at.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    for (final s in Skill.values) {
      final v = s.valueIn(a.score);
      if (v == null) continue;
      final (sum, n) = sums[s]![day] ?? (0.0, 0);
      sums[s]![day] = (sum + v, n + 1);
    }
  }
  return {
    for (final s in Skill.values)
      s: () {
        final points = [
          for (final MapEntry(key: day, value: (sum, n)) in sums[s]!.entries)
            SkillPoint(day, sum / n, n),
        ]..sort((a, b) => a.day.compareTo(b.day));
        return points.length > days
            ? points.sublist(points.length - days)
            : points;
      }(),
  };
}

/// Where a skill stands: its recent level and how much it changed.
class SkillSummary {
  const SkillSummary(this.skill, this.recent, this.change);

  final Skill skill;

  /// Average of the last (up to) 3 practice days.
  final double recent;

  /// [recent] minus the average of the first (up to) 3 days shown; null
  /// with fewer than 2 days, when there is nothing to compare.
  final double? change;
}

SkillSummary? summarise(Skill s, List<SkillPoint> points) {
  if (points.isEmpty) return null;
  double mean(Iterable<SkillPoint> p) =>
      p.map((e) => e.value).reduce((a, b) => a + b) / p.length;
  final k = points.length >= 6 ? 3 : (points.length / 2).floor();
  return SkillSummary(
    s,
    mean(points.skip(points.length - (k == 0 ? 1 : k))),
    points.length < 2
        ? null
        : mean(points.skip(points.length - k)) - mean(points.take(k)),
  );
}

/// The skill that improved most (by at least 5 points), if any.
SkillSummary? mostImproved(Iterable<SkillSummary> all) {
  SkillSummary? best;
  for (final s in all) {
    final c = s.change;
    if (c != null && c >= 0.05 && (best == null || c > best.change!)) best = s;
  }
  return best;
}

/// The weakest skill lately, if it is below 80%.
SkillSummary? needsWork(Iterable<SkillSummary> all) {
  SkillSummary? worst;
  for (final s in all) {
    if (s.recent < 0.8 && (worst == null || s.recent < worst.recent)) {
      worst = s;
    }
  }
  return worst;
}
