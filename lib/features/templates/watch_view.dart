import 'package:material_ui/material_ui.dart';

import '../../core/audio/app_audio.dart';
import 'letter_template_view.dart';
import 'letter_templates.dart';
import 'stroke_timeline.dart';

/// Plays a template stroke by stroke ("watch how to write it"), with
/// "Watch again" and a button to move on.
class WatchView extends StatefulWidget {
  const WatchView({
    super.key,
    required this.template,
    required this.onNext,
    this.nextLabel = 'Trace it',
  });

  final LetterTemplate template;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  State<WatchView> createState() => _WatchViewState();
}

class _WatchViewState extends State<WatchView>
    with SingleTickerProviderStateMixin {
  late final _timeline = StrokeTimeline(widget.template.drawing);
  late final _animation = AnimationController(
    vsync: this,
    duration: _timeline.total,
  )..forward();

  String get _intro => widget.template.isShape
      ? 'Watch how to draw ${widget.template.label.toLowerCase()}.'
      : 'Watch how to write the letter ${widget.template.letter}.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppAudioScope.of(context).say(_intro);
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Watch how to ${widget.template.verb} it',
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
                template: widget.template,
                timeline: _timeline,
                seconds: _animation.value * _timeline.totalSeconds,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Wraps onto two lines on narrow screens instead of overflowing.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                _animation.forward(from: 0);
                AppAudioScope.of(context).say(_intro);
              },
              icon: const Icon(Icons.replay),
              label: const Text('Watch again'),
            ),
            FilledButton.icon(
              onPressed: widget.onNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(widget.nextLabel),
            ),
          ],
        ),
      ],
    );
  }
}
