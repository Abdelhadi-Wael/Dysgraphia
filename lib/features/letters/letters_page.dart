import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/app_data.dart';
import '../progress/practice_plan.dart';
import '../templates/letter_page.dart';
import '../templates/warmup_shapes.dart';
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

/// Free practice: warm-up shapes and every letter, with best stars.
class LettersPage extends ConsumerWidget {
  const LettersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appDataProvider).requireValue.history;
    final text = Theme.of(context).textTheme;
    final shapeIds = warmUpShapes.keys.toList();
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
        ],
      ),
    );
  }
}
