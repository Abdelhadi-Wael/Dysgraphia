import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/models/profile.dart';
import '../../core/state/app_data.dart';
import '../profiles/profile_avatar.dart';
import '../progress/practice_plan.dart';
import 'challenge_page.dart';
import 'journey.dart';

/// Opens challenge [c] for the current profile; results are saved.
void openChallenge(BuildContext context, WidgetRef ref, Challenge c) {
  final data = ref.read(appDataProvider.notifier);
  final h = ref.read(appDataProvider).requireValue.history;
  // A "locked" message from the journey would otherwise stay on screen and
  // cover the challenge's buttons.
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChallengePage(
        challenge: c,
        review: reviewLetter(h, c),
        hasNext: c.number < journey.length,
        onAttempt: data.addAttempt,
        onComplete: (stars) =>
            data.addChallenge(ChallengeRecord(number: c.number, stars: stars)),
      ),
    ),
  );
}

/// The home tab: a path of challenges, level by level.
class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({super.key});

  static const rowHeight = 150.0;
  static const levelHeaderHeight = 72.0;

  /// Horizontal position of each node (0 = left, 1 = right): a gentle zigzag.
  static double nodeX(int i) => const [0.5, 0.64, 0.5, 0.36][i % 4];

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage> {
  /// Created on the first build, when we know where the current challenge
  /// is, so the path opens scrolled to it.
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider).requireValue;
    final p = data.current!;
    final h = data.history;
    final current = currentChallenge(h);
    final level = current?.level ?? journeyLevels.last;
    final (done, total) = levelProgress(h, level);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Start scrolled so the current challenge is in view.
    final currentIndex = (current?.number ?? journey.length) - 1;
    final levelsBefore = journeyLevels.indexOf(level) + 1;
    _scroll ??= ScrollController(
      initialScrollOffset:
          (currentIndex * JourneyPage.rowHeight +
                  levelsBefore * JourneyPage.levelHeaderHeight -
                  200)
              .clamp(0.0, double.infinity),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ProfileAvatar(avatar: p.avatar, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.mode == ProfileMode.kid
                                  ? "${p.name}'s writing journey"
                                  : 'Your writing journey',
                              style: text.titleLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber.shade600,
                            size: 28,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${totalStars(h)}',
                            key: const Key('journey-stars'),
                            style: text.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              current == null
                                  ? 'Journey complete!'
                                  : 'Level ${level.id} · ${level.name}',
                              style: text.titleSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Text(
                            '$done of $total',
                            key: const Key('level-progress'),
                            style: text.titleSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: done / total,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: scheme.surface.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('journey-path'),
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (final lv in journeyLevels) ...[
                    _LevelHeader(level: lv, history: h),
                    for (final c in journey.where((c) => c.level == lv))
                      _PathRow(
                        challenge: c,
                        history: h,
                        isCurrent: c.number == current?.number,
                        avatar: p.avatar,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level, required this.history});

  final JourneyLevel level;
  final History history;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (done, total) = levelProgress(history, level);
    return SizedBox(
      height: JourneyPage.levelHeaderHeight,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Level ${level.id} · ${level.name} · $done/$total',
            style: text.titleSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// One challenge on the path, with the connecting line from the previous.
class _PathRow extends ConsumerWidget {
  const _PathRow({
    required this.challenge,
    required this.history,
    required this.isCurrent,
    required this.avatar,
  });

  final Challenge challenge;
  final History history;
  final bool isCurrent;
  final int avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final i = challenge.number - 1;
    final x = JourneyPage.nodeX(i);
    final firstInLevel = journey.firstWhere((c) => c.level == challenge.level);
    final stars = challengeStars(history, challenge.number);
    final unlocked = isUnlocked(history, challenge);
    final size = isCurrent ? 84.0 : 68.0;

    final (bg, fg, border) = stars != null
        ? (scheme.primaryContainer, scheme.onPrimaryContainer, scheme.primary)
        : isCurrent
        ? (scheme.primary, scheme.onPrimary, scheme.tertiary)
        : (
            scheme.surfaceContainerHighest,
            scheme.outline,
            scheme.outlineVariant,
          );

    final node = GestureDetector(
      key: Key('challenge-${challenge.number}'),
      onTap: () {
        if (unlocked) {
          openChallenge(context, ref, challenge);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Finish challenge ${currentChallenge(history)!.number} '
                  'to open this one',
                ),
              ),
            );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: border, width: isCurrent ? 5 : 3),
            ),
            child: Center(
              child: unlocked
                  ? Text(
                      challenge.letter,
                      style:
                          (isCurrent ? text.displaySmall : text.headlineMedium)
                              ?.copyWith(color: fg),
                    )
                  : Icon(Icons.lock_outline, color: fg),
            ),
          ),
          const SizedBox(height: 2),
          if (stars != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 1; k <= 3; k++)
                  Icon(
                    k <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: Colors.amber.shade600,
                  ),
              ],
            )
          else
            Text(
              isCurrent ? 'Start!' : '${challenge.number}',
              style: text.labelMedium?.copyWith(
                color: isCurrent ? scheme.primary : scheme.outline,
                fontWeight: isCurrent ? FontWeight.bold : null,
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      height: JourneyPage.rowHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final cx = box.maxWidth * x;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (challenge != firstInLevel)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConnectorPainter(
                      fromX: box.maxWidth * JourneyPage.nodeX(i - 1),
                      toX: cx,
                      toY: (JourneyPage.rowHeight - size) / 2 - 16,
                      color: stars != null || isCurrent
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                ),
              Positioned(
                left: cx - 60,
                width: 120,
                top: (JourneyPage.rowHeight - size) / 2 - 8,
                child: node,
              ),
              if (isCurrent)
                Positioned(
                  left: cx + size / 2 + 4,
                  top: JourneyPage.rowHeight / 2 - 30,
                  child: ProfileAvatar(avatar: avatar, size: 40),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Dotted curve from the previous node (above) to this one.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.fromX,
    required this.toX,
    required this.toY,
    required this.color,
  });

  final double fromX, toX, toY;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(fromX, -22)
      ..cubicTo(fromX, toY / 2, toX, toY / 2, toX, toY);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 18) {
        canvas.drawPath(m.extractPath(d, d + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fromX != fromX ||
      old.toX != toX ||
      old.toY != toY ||
      old.color != color;
}
