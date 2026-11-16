import 'package:material_ui/material_ui.dart';

import '../exercises/copy/copy_view.dart';
import '../exercises/trace/trace_view.dart';
import 'letter_template_view.dart';
import 'letter_templates.dart';
import 'stroke_timeline.dart';

enum LetterStep { watch, trace, copy }

/// One letter, in three steps: watch it being written, trace it over the
/// dotted letter, then copy it from a model without help.
class LetterPage extends StatefulWidget {
  const LetterPage({
    super.key,
    required this.letter,
    this.initialStep = LetterStep.watch,
  });

  final String letter;
  final LetterStep initialStep;

  @override
  State<LetterPage> createState() => _LetterPageState();
}

class _LetterPageState extends State<LetterPage>
    with SingleTickerProviderStateMixin {
  late final _template = latinLowercase[widget.letter]!;
  late final _timeline = StrokeTimeline(_template.drawing);
  late final _animation = AnimationController(
    vsync: this,
    duration: _timeline.total,
  );
  late var _step = widget.initialStep;

  @override
  void initState() {
    super.initState();
    if (_step == LetterStep.watch) _animation.forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _go(LetterStep step) {
    setState(() => _step = step);
    if (step == LetterStep.watch) _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Letter ${widget.letter}'),
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
          LetterStep.watch => _buildWatch(context),
          LetterStep.trace => TraceView(
            template: _template,
            onCopy: () => _go(LetterStep.copy),
          ),
          LetterStep.copy => CopyView(template: _template),
        },
      ),
    );
  }

  Widget _buildWatch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Watch how to write it',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => LetterTemplateView(
                key: const Key('letter-animation'),
                template: _template,
                timeline: _timeline,
                seconds: _animation.value * _timeline.totalSeconds,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _animation.forward(from: 0),
              icon: const Icon(Icons.replay),
              label: const Text('Watch again'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _go(LetterStep.trace),
              icon: const Icon(Icons.gesture),
              label: const Text('Trace it'),
            ),
          ],
        ),
      ],
    );
  }
}
