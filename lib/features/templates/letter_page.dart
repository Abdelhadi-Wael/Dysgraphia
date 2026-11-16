import 'package:material_ui/material_ui.dart';

import '../canvas/canvas_playground_page.dart';
import 'letter_template_view.dart';
import 'letter_templates.dart';
import 'stroke_timeline.dart';

/// One letter: watch it being written stroke by stroke, then trace it.
class LetterPage extends StatefulWidget {
  const LetterPage({super.key, required this.letter});

  final String letter;

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
  )..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Letter ${widget.letter}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CanvasPlaygroundPage(letter: widget.letter),
                    ),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Trace it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
