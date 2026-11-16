import 'package:material_ui/material_ui.dart';

import '../templates/letter_template_view.dart';
import '../templates/letter_templates.dart';

/// All letters a-z with their best stars; tap one to open it.
class LetterStarsGrid extends StatelessWidget {
  const LetterStarsGrid({
    super.key,
    required this.best,
    required this.onTap,
    this.highlight = const {},
    this.shrinkWrap = false,
  });

  /// Best stars per letter; letters not in the map are new.
  final Map<String, int> best;
  final void Function(String letter) onTap;

  /// Letters to point out, e.g. today's practice.
  final Set<String> highlight;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final letters = latinLowercase.values.toList();
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: letters.length,
      itemBuilder: (context, i) {
        final t = letters[i];
        final stars = best[t.letter];
        return Card(
          key: Key('letter-tile-${t.letter}'),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: highlight.contains(t.letter)
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => onTap(t.letter),
            child: Column(
              children: [
                Expanded(
                  child: LetterTemplateView(template: t, showHints: false),
                ),
                SizedBox(
                  height: 28,
                  child: stars == null
                      ? Center(child: Text('New', style: text.labelMedium))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 1; k <= 3; k++)
                              Icon(
                                k <= stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 18,
                                color: Colors.amber.shade600,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
