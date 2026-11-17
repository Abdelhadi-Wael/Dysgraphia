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
    // One box at a time, as big as the screen allows, next to (or under) a
    // model of the same size. The header keeps a fixed slot for the score,
    // so nothing moves when the first score appears.
    final shown = _finished ? widget.attempts - 1 : _active;
    final body = LayoutBuilder(
      builder: (context, outer) {
        final wide = outer.maxWidth > outer.maxHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(wide),
            const SizedBox(height: 8),
            // Landscape: buttons beside the boxes, so the boxes get the
            // full height. Portrait: strip and buttons below.
            if (wide)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pair(shown)),
                    const SizedBox(width: 12),
                    _buttons(vertical: true),
                  ],
                ),
              )
            else ...[
              Expanded(child: _pair(shown)),
              const SizedBox(height: 8),
              _strip(),
              const SizedBox(height: 8),
              _buttons(vertical: false),
            ],
          ],
        );
      },
    );

    return _finished
        ? body
        : WritingShortcuts(controller: _boxes[_active], child: body);
  }

  /// Message and score. Portrait: stacked. Landscape: side by side with the
  /// attempts strip, to leave the height to the boxes.
  Widget _header(bool wide) {
    final text = Theme.of(context).textTheme;
    final message = Text(
      _message,
      key: const Key('copy-message'),
      style: text.titleMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Align(alignment: Alignment.centerLeft, child: message),
          ),
          _scoreSlot(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: message),
        const SizedBox(width: 12),
        _strip(),
        const SizedBox(width: 12),
        SizedBox(width: 340, child: _scoreSlot()),
      ],
    );
  }

  /// Always the same height: a hint until the first check, then the score
  /// of the latest box (which can grow when its details are opened).
  Widget _scoreSlot() {
    final latest = _latest;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _scoreSlotHeight,
      child: latest != null
          ? ScoreCard(
              key: ValueKey('score-${_active - 1}'),
              score: latest,
              hasDescender: _hasDescender,
            )
          : Card(
              key: const Key('score-placeholder'),
              child: SizedBox(
                height: ScoreCard.height,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      Icons.star_border_rounded,
                      color: scheme.outline,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your writing to earn stars',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static const _scoreSlotHeight = ScoreCard.height + 8;
  static const _labelH = 22.0;

  /// The model and box [i], the same size, as big as fits: side by side or
  /// one above the other, whichever gives bigger boxes.
  Widget _pair(int i) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0, a = CopyView.aspect;
        // Box width when side by side, and when stacked.
        final sideW = [
          (box.maxWidth - gap) / 2,
          (box.maxHeight - _labelH) * a,
        ].reduce((x, y) => x < y ? x : y);
        final stackW = [
          box.maxWidth,
          (box.maxHeight - 2 * _labelH - gap) / 2 * a,
        ].reduce((x, y) => x < y ? x : y);
        final side = sideW >= stackW;
        final w = (side ? sideW : stackW).clamp(0.0, double.infinity);

        final model = _panel(
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
        );
        final writing = _panel(
          width: w,
          label: _finished
              ? 'Box ${i + 1} of ${widget.attempts}'
              : 'Box ${i + 1} of ${widget.attempts}: write here',
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _finished ? scheme.outlineVariant : scheme.primary,
                width: 2,
              ),
            ),
            child: IgnorePointer(
              ignoring: _finished,
              child: WritingCanvas(
                key: Key('copy-canvas-$i'),
                controller: _boxes[i],
              ),
            ),
          ),
        );
        return Center(
          child: side
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    model,
                    const SizedBox(width: gap),
                    writing,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    model,
                    const SizedBox(height: gap),
                    writing,
                  ],
                ),
        );
      },
    );
  }

  Widget _panel({
    required double width,
    required String label,
    required Widget child,
  }) => SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _labelH,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: width, height: width / CopyView.aspect, child: child),
      ],
    ),
  );

  /// Stars for every attempt so far; the current box is outlined.
  Widget _strip() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.attempts; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: i == _active ? scheme.primary : scheme.outlineVariant,
                width: i == _active ? 2 : 1,
              ),
            ),
            child: Row(
              key: _scores[i] == null
                  ? Key('box-$i-empty')
                  : Key('box-$i-stars-${_scores[i]!.stars}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${i + 1} ',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                for (var k = 1; k <= 3; k++)
                  Icon(
                    _scores[i] != null && k <= _scores[i]!.stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _scores[i] == null
                        ? scheme.outlineVariant
                        : Colors.amber.shade600,
                    size: 16,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buttons({required bool vertical}) {
    if (_finished) {
      // Wraps onto two lines on narrow screens; a column in landscape.
      return Wrap(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
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
      builder: (context, _) {
        final undo = IconButton(
          tooltip: 'Undo (Ctrl+Z)',
          icon: const Icon(Icons.undo),
          onPressed: c.canUndo ? c.undo : null,
        );
        final clear = IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.delete_outline),
          onPressed: c.isEmpty ? null : c.clear,
        );
        final check = FilledButton.icon(
          onPressed: c.drawing.isEmpty ? null : _check,
          icon: const Icon(Icons.check),
          label: const Text('Check'),
        );
        return vertical
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [undo, clear]),
                  const SizedBox(height: 8),
                  check,
                ],
              )
            : Row(children: [undo, clear, const Spacer(), check]);
      },
    );
  }
}
