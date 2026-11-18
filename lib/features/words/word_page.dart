import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/widgets/fit_or_scroll.dart';
import '../templates/watch_view.dart';
import 'word_templates.dart';
import 'word_view.dart';

enum WordStep { watch, write }

/// One word: watch it being written letter by letter, then write it.
class WordPage extends StatefulWidget {
  const WordPage({
    super.key,
    required this.word,
    this.initialStep = WordStep.watch,
    this.onAttempt,
    this.queue = const [],
  });

  /// Word id, e.g. "word-cat" (see [practiceWords]).
  final String word;
  final WordStep initialStep;

  /// Receives every checked word, e.g. to save it.
  final void Function(Attempt attempt)? onAttempt;

  /// Word ids to write after this one; when not empty, a checked word
  /// offers "Next word".
  final List<String> queue;

  @override
  State<WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  late final _word = practiceWords[widget.word]!;
  late var _step = widget.initialStep;

  void _next() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => WordPage(
        word: widget.queue.first,
        queue: widget.queue.sublist(1),
        onAttempt: widget.onAttempt,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(_word.model.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<WordStep>(
              key: const Key('word-steps'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: WordStep.watch,
                  icon: narrow ? null : const Icon(Icons.play_circle_outline),
                  label: const Text('Watch'),
                ),
                ButtonSegment(
                  value: WordStep.write,
                  icon: narrow ? null : const Icon(Icons.edit),
                  label: const Text('Write'),
                ),
              ],
              selected: {_step},
              onSelectionChanged: (s) => setState(() => _step = s.single),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pagePadding(context)),
        child: FitOrScroll(
          minHeight: _step == WordStep.watch
              ? ExerciseHeights.watch
              : ExerciseHeights.copy,
          child: switch (_step) {
            WordStep.watch => WatchView(
              template: _word.model,
              intro: 'Watch how to write the word ${_word.word}.',
              nextLabel: 'Write it',
              onNext: () => setState(() => _step = WordStep.write),
            ),
            WordStep.write => WordView(
              word: _word,
              onChecked: (drawing, score) => widget.onAttempt?.call(
                Attempt(
                  letter: _word.id,
                  kind: PracticeKind.word,
                  stars: score.stars,
                  overall: score.overall,
                  score: score.toJson(),
                  drawing: drawing,
                ),
              ),
              nextLabel: widget.queue.isEmpty
                  ? null
                  : 'Next word: ${practiceWords[widget.queue.first]!.word}',
              onNext: widget.queue.isEmpty ? null : _next,
            ),
          },
        ),
      ),
    );
  }
}
