import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/models/profile.dart';
import '../../core/state/app_data.dart';
import '../assessment/assessment_page.dart';
import '../letters/letters_page.dart';
import '../letters/warmup_page.dart';
import '../profiles/profile_avatar.dart';
import '../progress/practice_plan.dart';
import '../progress/progress_page.dart';
import '../settings/settings_page.dart';
import '../templates/letter_template_view.dart';
import '../templates/letter_templates.dart';

/// The main screen: what to practise today and where to go next.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).requireValue;
    final p = data.current!;
    final h = data.history;
    final text = Theme.of(context).textTheme;
    void push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ProfileAvatar(avatar: p.avatar),
        ),
        title: Text(
          p.mode == ProfileMode.kid
              ? 'Hi, ${p.name}!'
              : 'Welcome back, ${p.name}',
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(const SettingsPage()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  StatCard(
                    icon: Icons.star_rounded,
                    label: 'Stars',
                    value: '${totalStars(h)}',
                  ),
                  StatCard(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Days in a row',
                    value: '${streakDays(h)}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TodayCard(history: h),
              const SizedBox(height: 16),
              Text('More', style: text.titleMedium),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, box) {
                  final tiles = [
                    _Tile(
                      icon: Icons.gesture,
                      title: 'Warm-up',
                      subtitle: 'Lines, circles, waves',
                      onTap: () => push(const WarmUpPage()),
                    ),
                    _Tile(
                      icon: Icons.abc,
                      title: 'Letters',
                      subtitle: '${bestStars(h).length} of 26 copied',
                      onTap: () => push(const LettersPage()),
                    ),
                    _Tile(
                      icon: Icons.assignment_outlined,
                      title: 'Writing check',
                      subtitle: h.checks.isEmpty
                          ? 'About 5 minutes, not done yet'
                          : 'Last: ${formatWhen(h.checks.last.at)}',
                      onTap: () => push(
                        AssessmentPage(
                          participant: p.researchCode,
                          onSaved: (result, file) => ref
                              .read(appDataProvider.notifier)
                              .addCheck(
                                CheckRecord(
                                  tasks: result.tasks.length,
                                  skipped: result.tasks
                                      .where((t) => t.skipped)
                                      .length,
                                  file: file?.path,
                                ),
                              ),
                        ),
                      ),
                    ),
                    _Tile(
                      icon: Icons.insights,
                      title: 'My progress',
                      subtitle: h.attempts.length == 1
                          ? '1 exercise done'
                          : '${h.attempts.length} exercises done',
                      onTap: () => push(const ProgressPage()),
                    ),
                  ];
                  // Side by side when there is room, otherwise stacked.
                  return box.maxWidth > 600
                      // Same height for all tiles, even if one subtitle
                      // wraps onto two lines.
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final t in tiles) Expanded(child: t),
                            ],
                          ),
                        )
                      : Column(children: tiles);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.history});

  final History history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final letters = suggestLetters(history);

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's practice",
              style: text.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              letters.isEmpty
                  ? 'Every letter has 3 stars. Practise any letter you like.'
                  : 'Watch, trace and copy ${letters.length} letters',
              style: text.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final l in letters)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      key: Key('today-$l'),
                      width: 72,
                      height: 80,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: LetterTemplateView(
                          template: latinLowercase[l]!,
                          showHints: false,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 52),
                  ),
                  onPressed: letters.isEmpty
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LettersPage(),
                          ),
                        )
                      : () => openLetter(
                          context,
                          ref,
                          letters.first,
                          queue: letters.sublist(1),
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(letters.isEmpty ? 'Choose a letter' : 'Start'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: scheme.primary),
              const SizedBox(height: 12),
              Text(title, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
