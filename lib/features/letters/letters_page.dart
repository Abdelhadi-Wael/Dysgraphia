import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/app_data.dart';
import '../progress/practice_plan.dart';
import '../templates/letter_page.dart';
import '../templates/warmup_shapes.dart';
import '../words/word_page.dart';
import '../words/word_templates.dart';
import 'letter_stars_grid.dart';

/// Opens a letter or warm-up shape for the current profile; results are
/// saved.
void openLetter(
  BuildContext context,
  WidgetRef ref,
  String letter, {
  List<String> queue = const [],
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => LetterPage(
      letter: letter,
      queue: queue,
      onAttempt: ref.read(appDataProvider.notifier).addAttempt,
    ),
  ),
);

/// Opens a word (id "word-cat") for the current profile; results are saved.
void openWord(
  BuildContext context,
  WidgetRef ref,
  String id, {
  List<String> queue = const [],
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => WordPage(
      word: id,
      queue: queue,
      onAttempt: ref.read(appDataProvider.notifier).addAttempt,
    ),
  ),
);

/// Free practice: warm-up shapes, every letter and short words, with best
/// stars.
class LettersPage extends ConsumerWidget {
  const LettersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appDataProvider).requireValue.history;
    final text = Theme.of(context).textTheme;
    final shapeIds = warmUpShapes.keys.toList();
    final wordBest = bestStarsFor(history, practiceWords.keys);
    return Scaffold(
      appBar: AppBar(title: const Text('Practise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Warm-up', style: text.titleLarge)),
              TextButton.icon(
                onPressed: () => openLetter(
                  context,
                  ref,
                  shapeIds.first,
                  queue: shapeIds.sublist(1),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Do them all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LetterStarsGrid(
            templates: warmUpShapes.values.toList(),
            best: bestStarsFor(history, shapeIds),
            shrinkWrap: true,
            onTap: (id) => openLetter(context, ref, id),
          ),
          const SizedBox(height: 16),
          Text('Letters', style: text.titleLarge),
          const SizedBox(height: 4),
          LetterStarsGrid(
            best: bestStars(history),
            shrinkWrap: true,
            onTap: (l) => openLetter(context, ref, l),
          ),
          const SizedBox(height: 16),
          Text('Words', style: text.titleLarge),
          for (final g in wordGroups) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(g.name, style: text.titleSmall)),
                TextButton.icon(
                  onPressed: () => openWord(
                    context,
                    ref,
                    'word-${g.words.first}',
                    queue: [for (final w in g.words.skip(1)) 'word-$w'],
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Do them all'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in g.words)
                  WordTile(
                    word: w,
                    stars: wordBest['word-$w'],
                    onTap: () => openWord(context, ref, 'word-$w'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A practice word with its best stars.
class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.word,
    required this.stars,
    required this.onTap,
  });

  final String word;
  final int? stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: Key('word-tile-$word'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 104,
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word, style: text.headlineSmall),
              const SizedBox(height: 4),
              stars == null
                  ? Text('New', style: text.labelMedium)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var k = 1; k <= 3; k++)
                          Icon(
                            k <= stars!
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: Colors.amber.shade600,
                          ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
