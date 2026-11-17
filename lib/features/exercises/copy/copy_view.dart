import 'package:material_ui/material_ui.dart';

import '../../../core/audio/app_audio.dart';
import '../../../core/models/stroke.dart';
import '../../canvas/writing_canvas.dart';
import '../../canvas/writing_controller.dart';
import '../../canvas/writing_shortcuts.dart';
import '../../scoring/letter_scorer.dart';
import '../../scoring/score_card.dart';
import '../../templates/letter_template_view.dart';
import '../../templates/letter_templates.dart';

/// Copy a letter from a model, without dotted help, three times. Each
/// attempt is checked on its own, so the tip can help the next one.
class CopyView extends StatefulWidget {
  const CopyView({
    super.key,
    required this.template,
    this.attempts = 3,
    this.onChecked,
    this.nextLabel,
    this.onNext,
  });

  final LetterTemplate template;
  final int attempts;

  /// Called for every checked box with what was written and its score.
  final void Function(Drawing drawing, LetterScore score)? onChecked;

  /// When set, the finished view offers this as the main button (e.g.
  /// "Next letter: d"), next to "Copy again".
  final String? nextLabel;
  final VoidCallback? onNext;

  /// Width / height of the model and of each writing box. They share the
  /// same guide lines and scale, so the model shows the right size too.
  static const aspect = 0.9;

  @override
  State<CopyView> createState() => _CopyViewState();
}

class _CopyViewState extends State<CopyView> {
  static const _scorer = LetterScorer();

  late List<WritingController> _boxes;
  late List<LetterScore?> _scores;
  var _active = 0;

  bool get _finished => _active >= widget.attempts;
  bool get _hasDescender => widget.template.drawing.bounds!.$4 > 0.2;

  @override
  void initState() {
    super.initState();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppAudioScope.of(context).say(_message);
    });
  }

  void _reset() {
    _boxes = [for (var i = 0; i < widget.attempts; i++) WritingController()];
    _scores = List.filled(widget.attempts, null);
    _active = 0;
  }

  @override
  void dispose() {
    for (final b in _boxes) {
      b.dispose();
    }
    super.dispose();
  }

  void _check() {
    final drawing = _boxes[_active].drawing;
    if (drawing.isEmpty) return;
    final score = _scorer.score(drawing, widget.template.drawing);
    setState(() {
      _scores[_active] = score;
      _active++;
    });
    widget.onChecked?.call(drawing, score);
    final audio = AppAudioScope.of(context);
    final tip = ScoreCard.tipText(score.tip, hasDescender: _hasDescender);
    if (_finished) {
      audio.play(Sfx.success);
      audio.say('$tip All done!');
    } else {
      audio.play(Sfx.star);
      audio.say('$tip $_message.');
    }
  }

  void _again() {
    final old = _boxes;
    setState(_reset);
    AppAudioScope.of(context).say(_message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final b in old) {
        b.dispose();
      }
    });
  }

  LetterScore? get _latest => _active == 0 ? null : _scores[_active - 1];

  String get _message {
    if (_finished) {
      final best = _scores.map((s) => s!.stars).reduce((a, b) => a > b ? a : b);
      return 'All done! Best: ${'★' * best}';
    }
    if (_active == 0) {
      final t = widget.template;
      return 'Look at the ${t.noun}, then ${t.verb} it in box 1';
    }
    return 'Now ${widget.template.verb} it again in box ${_active + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final latest = _latest;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_message, key: const Key('copy-message'), style: text.titleLarge),
        if (latest != null) ...[
          const SizedBox(height: 8),
          ScoreCard(
            key: ValueKey('score-${_active - 1}'),
            score: latest,
            hasDescender: _hasDescender,
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // Fit model + boxes in both directions: the width limits the
              // columns, the height (minus label and stars rows) the boxes.
              final columns = widget.attempts + 1;
              final byWidth = box.maxWidth / columns - 8;
              final byHeight =
                  (box.maxHeight - _labelH - _footerH - 8) * CopyView.aspect;
              final w = byWidth < byHeight ? byWidth : byHeight;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _column(
                    width: w,
                    label: 'Look',
                    child: Card(
                      color: scheme.surfaceContainerHighest,
                      clipBehavior: Clip.antiAlias,
                      child: LetterTemplateView(
                        key: const Key('copy-model'),
                        template: widget.template,
                        showHints: false,
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.attempts; i++)
                    _column(
                      width: w,
                      label: 'Box ${i + 1}',
                      footer: _stars(i),
                      child: _box(i, scheme),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buttons(),
      ],
    );

    return _finished
        ? body
        : WritingShortcuts(controller: _boxes[_active], child: body);
  }

  static const _labelH = 24.0, _footerH = 28.0;

  Widget _column({
    required double width,
    required String label,
    required Widget child,
    Widget? footer,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: _labelH,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          SizedBox(width: width, height: width / CopyView.aspect, child: child),
          SizedBox(height: _footerH, child: footer),
        ],
      ),
    ),
  );

  Widget _box(int i, ColorScheme scheme) {
    final active = i == _active;
    final future = i > _active;
    return Opacity(
      opacity: future ? 0.35 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: active
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: IgnorePointer(
          ignoring: !active,
          child: WritingCanvas(
            key: Key('copy-canvas-$i'),
            controller: _boxes[i],
          ),
        ),
      ),
    );
  }

  Widget? _stars(int i) {
    final s = _scores[i];
    if (s == null) return null;
    return Row(
      key: Key('box-$i-stars-${s.stars}'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 1; k <= 3; k++)
          Icon(
            k <= s.stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber.shade600,
            size: 24,
          ),
      ],
    );
  }

  Widget _buttons() {
    if (_finished) {
      // Wraps onto two lines on narrow screens.
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (widget.onNext == null)
            FilledButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: const Text('Copy again'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: const Text('Copy again'),
            ),
            FilledButton.icon(
              onPressed: widget.onNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(widget.nextLabel ?? 'Next'),
            ),
          ],
        ],
      );
    }
    final c = _boxes[_active];
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Row(
        children: [
          IconButton(
            tooltip: 'Undo (Ctrl+Z)',
            icon: const Icon(Icons.undo),
            onPressed: c.canUndo ? c.undo : null,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: c.isEmpty ? null : c.clear,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: c.drawing.isEmpty ? null : _check,
            icon: const Icon(Icons.check),
            label: const Text('Check'),
          ),
        ],
      ),
    );
  }
}
