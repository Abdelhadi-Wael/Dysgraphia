import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/app_data.dart';
import '../progress/practice_plan.dart';
import '../templates/warmup_shapes.dart';
import 'letter_stars_grid.dart';
import 'letters_page.dart';

/// Warm-up shapes: the basic movements of letters, practised on their own.
class WarmUpPage extends ConsumerWidget {
  const WarmUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appDataProvider).requireValue.history;
    final ids = warmUpShapes.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Warm-up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Loosen up with the movements letters are made of.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => openLetter(
                    context,
                    ref,
                    ids.first,
                    queue: ids.sublist(1),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Do them all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LetterStarsGrid(
                templates: warmUpShapes.values.toList(),
                best: bestStarsFor(history, ids),
                onTap: (id) => openLetter(context, ref, id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
