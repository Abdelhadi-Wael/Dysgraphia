import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/state/app_data.dart';
import '../letters/letter_stars_grid.dart';
import '../letters/letters_page.dart';
import 'practice_plan.dart';
import 'skill_charts.dart';
import 'skill_trends.dart';

/// Summary, skills over time, best stars per letter and recent practice.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(appDataProvider).requireValue.history;
    final text = Theme.of(context).textTheme;
    final best = bestStars(h);
    final recent = h.attempts.reversed.take(12).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My progress')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(
                    icon: Icons.star_rounded,
                    label: 'Stars',
                    value: '${totalStars(h)} of 78',
                  ),
                  StatCard(
                    icon: Icons.abc,
                    label: 'Letters copied',
                    value: '${best.length} of 26',
                  ),
                  StatCard(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Days in a row',
                    value: '${streakDays(h)}',
                  ),
                  StatCard(
                    icon: Icons.assignment_outlined,
                    label: 'Writing checks',
                    value: '${h.checks.length}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Skills', style: text.titleLarge),
              const SizedBox(height: 8),
              SkillCharts(trends: skillTrends(h)),
              const SizedBox(height: 24),
              Text('Letters', style: text.titleLarge),
              const SizedBox(height: 8),
              LetterStarsGrid(
                best: best,
                shrinkWrap: true,
                onTap: (l) => openLetter(context, ref, l),
              ),
              const SizedBox(height: 24),
              Text('Recent practice', style: text.titleLarge),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Your practice will show up here.'),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final a in recent)
                        ListTile(
                          leading: CircleAvatar(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: FittedBox(
                                child: Text(a.letter.replaceFirst('word-', '')),
                              ),
                            ),
                          ),
                          title: Text(switch (a.kind) {
                            PracticeKind.copy => 'Copied',
                            PracticeKind.trace => 'Traced',
                            PracticeKind.word => 'Wrote a word',
                          }),
                          subtitle: Text(formatWhen(a.at)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var k = 1; k <= 3; k++)
                                Icon(
                                  k <= a.stars
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 20,
                                  color: Colors.amber.shade600,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small labelled number, e.g. "Stars: 12 of 78".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: Card(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelMedium),
                    Text(value, style: text.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "17 Nov, 14:05" in local time.
String formatWhen(DateTime t) {
  final l = t.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${_months[l.month - 1]}, $hh:$mm';
}
