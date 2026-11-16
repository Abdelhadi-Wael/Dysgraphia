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
        ScoreTip.shape => 'Look at the dotted letter and match its shape',
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

  @override
  State<ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<ScoreCard> {
  var _details = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.score;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 3; i++)
                  Icon(
                    i <= s.stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    key: Key('star-$i-${i <= s.stars ? 'on' : 'off'}'),
                    color: Colors.amber.shade600,
                    size: 36,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ScoreCard.tipText(s.tip, hasDescender: widget.hasDescender),
                    key: const Key('score-tip'),
                    style: text.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _details = !_details),
                  child: Text(_details ? 'Hide details' : 'Details'),
                ),
              ],
            ),
            if (_details) ...[
              const SizedBox(height: 8),
              _bar(context, 'Shape', s.shape),
              _bar(context, 'Size', s.size),
              _bar(context, 'On the line', s.position),
              _bar(context, 'Strokes', s.strokes),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
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
