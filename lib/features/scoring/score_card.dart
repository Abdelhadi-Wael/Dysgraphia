import 'package:material_ui/material_ui.dart';

import 'letter_scorer.dart';
import 'word_scorer.dart';

/// Stars, one tip, and a breakdown of the measures behind them.
class ScoreCard extends StatefulWidget {
  /// A letter's score. With [hasDescender] (g, j, p, q, y), tips about
  /// position talk about the bottom line.
  ScoreCard({super.key, required LetterScore score, bool hasDescender = false})
    : stars = score.stars,
      tip = tipText(score.tip, hasDescender: hasDescender),
      measures = [
        ('Shape', score.shape),
        ('Size', score.size),
        ('On the line', score.position),
        ('Strokes', score.strokes),
      ];

  /// A word's score.
  ScoreCard.word({super.key, required WordScore score})
    : stars = score.stars,
      tip = score.tip.text,
      measures = [
        ('Shape', score.shape),
        ('Size', score.size),
        ('On the line', score.line),
        ('Spacing', score.spacing),
      ];

  final int stars;
  final String tip;

  /// Label and 0..1 value of each measure, shown in the details.
  final List<(String, double)> measures;

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
              Text(widget.tip, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final (label, value) in widget.measures)
                _bar(context, label, value),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.stars;
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
                  i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                  key: Key('star-$i-${i <= stars ? 'on' : 'off'}'),
                  color: Colors.amber.shade600,
                  size: 30,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.tip,
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
