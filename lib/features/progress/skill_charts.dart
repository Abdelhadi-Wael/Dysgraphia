import 'package:material_ui/material_ui.dart';

import 'skill_trends.dart';

/// One card per skill: its recent level, the change since the start, and a
/// small line chart of the last practice days. Two columns when there is
/// room, one on phones.
class SkillCharts extends StatelessWidget {
  const SkillCharts({super.key, required this.trends});

  final Map<Skill, List<SkillPoint>> trends;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summaries = {
      for (final s in Skill.values) s: ?summarise(s, trends[s]!),
    };
    if (summaries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Copy a letter or write a word to see your skills here.'),
      );
    }
    final improved = mostImproved(summaries.values);
    var weak = needsWork(summaries.values);
    // The same skill can be both: say it once.
    final both = improved != null && weak?.skill == improved.skill;
    if (both) weak = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (improved != null || weak != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (improved != null)
                _Highlight(
                  key: const Key('most-improved'),
                  icon: Icons.trending_up,
                  text:
                      'Most improved: ${improved.skill.label} '
                      '${_signed(improved.change!)}'
                      '${both ? ', keep practising it' : ''}',
                ),
              if (weak != null)
                _Highlight(
                  key: const Key('needs-work'),
                  icon: Icons.flag_outlined,
                  text:
                      'Practise next: ${weak.skill.label} '
                      '(${_percent(weak.recent)})',
                ),
            ],
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final w = box.maxWidth >= 560
                ? (box.maxWidth - gap) / 2
                : box.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final MapEntry(key: skill, value: sum)
                    in summaries.entries)
                  SizedBox(
                    width: w,
                    child: _SkillCard(summary: sum, points: trends[skill]!),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Each point is one practice day (copied letters and written '
          'words).',
          style: text.bodySmall,
        ),
      ],
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

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _percent(double v) => '${(v * 100).round()}%';

String _signed(double v) {
  final p = (v * 100).round();
  return p >= 0 ? '+$p%' : '−${-p}%';
}

class _Highlight extends StatelessWidget {
  const _Highlight({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Not a Chip: chips do not wrap, and this text is long on phones.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.primary, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.summary, required this.points});

  final SkillSummary summary;
  final List<SkillPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final change = summary.change;
    final axis = text.labelSmall?.copyWith(color: scheme.outline);
    return Card(
      key: Key('skill-${summary.skill.name}'),
      color: scheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.skill.label,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(_percent(summary.recent), style: text.titleLarge),
                if (change != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _signed(change),
                    key: Key('change-${summary.skill.name}'),
                    style: text.labelLarge?.copyWith(
                      color: change >= 0.005
                          ? scheme.primary
                          : change <= -0.005
                          ? scheme.error
                          : scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 100% / 50% / 0% beside the grid lines.
                  SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final l in ['100%', '50%', '0%'])
                          Text(l, style: axis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CustomPaint(
                      painter: _LinePainter(
                        values: [for (final p in points) p.value],
                        line: scheme.primary,
                        grid: scheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                mainAxisAlignment: points.length == 1
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  Text(_day(points.first.day), style: axis),
                  if (points.length > 1)
                    Text(_day(points.last.day), style: axis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Values 0..1 left to right, with faint lines at 0%, 50% and 100%. A
/// single value is a dot.
class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.line, required this.grid});

  final List<double> values;
  final Color line, grid;

  @override
  void paint(Canvas canvas, Size size) {
    // The labels beside the chart sit at the top, middle and bottom: the
    // lines for 100%, 50% and 0% must line up with them.
    const pad = 7.0;
    final h = size.height - 2 * pad;
    double y(double v) => pad + (1 - v.clamp(0.0, 1.0)) * h;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)), gridPaint);
    }
    final n = values.length;
    double x(int i) =>
        n == 1 ? size.width / 2 : pad + (size.width - 2 * pad) * i / (n - 1);
    final dot = Paint()..color = line;
    if (n > 1) {
      final path = Path()..moveTo(x(0), y(values[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(values[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.line != line || old.grid != grid;
}
