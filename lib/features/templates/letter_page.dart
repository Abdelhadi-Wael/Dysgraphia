import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/models/stroke.dart';
import '../exercises/copy/copy_view.dart';
import '../exercises/trace/trace_view.dart';
import '../scoring/letter_scorer.dart';
import 'warmup_shapes.dart';
import 'watch_view.dart';

enum LetterStep { watch, trace, copy }

/// One letter, in three steps: watch it being written, trace it over the
/// dotted letter, then copy it from a model without help.
class LetterPage extends StatefulWidget {
  const LetterPage({
    super.key,
    required this.letter,
    this.initialStep = LetterStep.watch,
    this.onAttempt,
    this.queue = const [],
  });

  final String letter;
  final LetterStep initialStep;

  /// Receives every finished trace and checked copy, e.g. to save it. The
  /// page itself saves nothing.
  final void Function(Attempt attempt)? onAttempt;

  /// Letters to practise after this one (today's practice). When not
  /// empty, finishing the copy step offers "Next letter".
  final List<String> queue;

  @override
  State<LetterPage> createState() => _LetterPageState();
}

class _LetterPageState extends State<LetterPage> {
  late final _template = templateFor(widget.letter);
  late var _step = widget.initialStep;

  void _go(LetterStep step) => setState(() => _step = step);

  String get _nextLabel {
    final next = templateFor(widget.queue.first);
    return next.isShape ? 'Next: ${next.label}' : 'Next letter: ${next.letter}';
  }

  void _report(
    PracticeKind kind,
    Drawing drawing,
    LetterScore score, {
    int retries = 0,
  }) => widget.onAttempt?.call(
    Attempt(
      letter: widget.letter,
      kind: kind,
      stars: score.stars,
      overall: score.overall,
      score: score.toJson(),
      retries: retries,
      drawing: drawing,
    ),
  );

  void _nextLetter() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => LetterPage(
        letter: widget.queue.first,
        queue: widget.queue.sublist(1),
        onAttempt: widget.onAttempt,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_template.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<LetterStep>(
              key: const Key('letter-steps'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: LetterStep.watch,
                  icon: Icon(Icons.play_circle_outline),
                  label: Text('Watch'),
                ),
                ButtonSegment(
                  value: LetterStep.trace,
                  icon: Icon(Icons.gesture),
                  label: Text('Trace'),
                ),
                ButtonSegment(
                  value: LetterStep.copy,
                  icon: Icon(Icons.edit),
                  label: Text('Copy'),
                ),
              ],
              selected: {_step},
              onSelectionChanged: (s) => _go(s.single),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_step) {
          LetterStep.watch => WatchView(
            template: _template,
            onNext: () => _go(LetterStep.trace),
          ),
          LetterStep.trace => TraceView(
            template: _template,
            onNext: () => _go(LetterStep.copy),
            onFinished: (drawing, score, retries) =>
                _report(PracticeKind.trace, drawing, score, retries: retries),
          ),
          LetterStep.copy => CopyView(
            template: _template,
            onChecked: (drawing, score) =>
                _report(PracticeKind.copy, drawing, score),
            nextLabel: widget.queue.isEmpty ? null : _nextLabel,
            onNext: widget.queue.isEmpty ? null : _nextLetter,
          ),
        },
      ),
    );
  }
}
