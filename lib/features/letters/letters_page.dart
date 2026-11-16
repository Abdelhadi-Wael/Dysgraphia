import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/app_data.dart';
import '../progress/practice_plan.dart';
import '../templates/letter_page.dart';
import 'letter_stars_grid.dart';

/// Opens a letter for the current profile; its results are saved.
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

/// Every letter with its best stars so far.
class LettersPage extends ConsumerWidget {
  const LettersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appDataProvider).requireValue.history;
    return Scaffold(
      appBar: AppBar(title: const Text('Letters')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LetterStarsGrid(
          best: bestStars(history),
          highlight: suggestLetters(history).toSet(),
          onTap: (l) => openLetter(context, ref, l),
        ),
      ),
    );
  }
}
