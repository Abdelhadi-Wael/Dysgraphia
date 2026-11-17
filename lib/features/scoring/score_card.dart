import 'package:material_ui/material_ui.dart';

import 'letter_scorer.dart';

/// Stars, one tip, and an optional breakdown of the four measures.
class ScoreCard extends StatefulWidget {
  const ScoreCard({super.key, required this.score, this.hasDescender = false});

  final LetterScore score;

  /// The letter goes below the baseline (g, j, p, q, y): tips about
  /// position then talk about the bottom line.
  final bool hasDescender;

  static String tipText(ScoreTip tip, {bool hasDescender = false}) =>
      switch (tip) {
        ScoreTip.none => 'Great job!',
        ScoreTip.shape => 'Look closely at the model and match its shape',
        ScoreTip.tooBig => 'Make it a little smaller',
        ScoreTip.tooSmall => 'Make it a little bigger',
        ScoreTip.tooHigh =>
          hasDescender
              ? 'Bring the tail down to the bottom line'
              : 'Sit the letter on the baseline',
        ScoreTip.tooLow =>
          hasDescender
              ? 'Keep the tail on the bottom line'
              : 'Keep the letter on the baseline, not below it',
        ScoreTip.strokeCount => 'Lift your pen like in the animation',
      };

  /// Height of the card's content; with the card's margins the card takes
  /// [height] + 8, always.
  static const height = 56.0;

  @override
  State<ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<ScoreCard> {
  /// The breakdown opens in a panel from the bottom, so the card itself
  /// never changes height and nothing around it moves.
  void _showDetails() {
    final s = widget.score;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ScoreCard.tipText(s.tip, hasDescender: widget.hasDescender),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _bar(context, 'Shape', s.shape),
              _bar(context, 'Size', s.size),
              _bar(context, 'On the line', s.position),
              _bar(context, 'Strokes', s.strokes),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.score;
    final text = Theme.of(context).textTheme;
    return Card(
      child: SizedBox(
        height: ScoreCard.height,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              for (var i = 1; i <= 3; i++)
                Icon(
                  i <= s.stars ? Icons.star_rounded : Icons.star_border_rounded,
                  key: Key('star-$i-${i <= s.stars ? 'on' : 'off'}'),
                  color: Colors.amber.shade600,
                  size: 30,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ScoreCard.tipText(s.tip, hasDescender: widget.hasDescender),
                  key: const Key('score-tip'),
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: _showDetails, child: const Text('Details')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${(value * 100).round()}%', textAlign: TextAlign.end),
        ),
      ],
    ),
  );
}
