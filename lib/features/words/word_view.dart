import 'package:material_ui/material_ui.dart';

import '../../core/audio/app_audio.dart';
import '../../core/models/guide_geometry.dart';
import '../../core/models/stroke.dart';
import '../canvas/writing_canvas.dart';
import '../canvas/writing_controller.dart';
import '../canvas/writing_shortcuts.dart';
import '../scoring/score_card.dart';
import '../scoring/word_scorer.dart';
import '../templates/letter_template_view.dart';
import 'word_templates.dart';

/// Write a whole word from a model, then see how each letter did and one
/// tip for the word (size, line, spacing).
class WordView extends StatefulWidget {
  const WordView({
    super.key,
    required this.word,
    this.onChecked,
    this.nextLabel,
    this.onNext,
  });

  final WordTemplate word;

  /// Called with what was written and its score after every check.
  final void Function(Drawing drawing, WordScore score)? onChecked;

  /// When set, a checked word offers this as the main button.
  final String? nextLabel;
  final VoidCallback? onNext;

  /// Width / height of the model and the writing box: the word plus room
  /// on both sides, so a slightly bigger word still fits.
  static double aspectFor(WordTemplate w) =>
      (w.width + 1.1) / GuideGeometry.heightForUnit(1);

  @override
  State<WordView> createState() => _WordViewState();
}

class _WordViewState extends State<WordView> {
  static const _scorer = WordScorer();

  var _box = WritingController();
  WordScore? _score;

  String get _word => widget.word.word;

  String get _message => _score == null
      ? 'Look at the word "$_word", then write it in the box'
      : (_score!.stars == 3 ? 'Well done!' : 'Good try! One thing to work on:');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppAudioScope.of(context).say(_message);
    });
  }

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  void _check() {
    final drawing = _box.drawing;
    if (drawing.isEmpty) return;
    final score = _scorer.score(drawing, widget.word);
    setState(() => _score = score);
    widget.onChecked?.call(drawing, score);
    final audio = AppAudioScope.of(context);
    audio.play(score.stars == 3 ? Sfx.success : Sfx.star);
    audio.say(score.tip.text);
  }

  void _again() {
    final old = _box;
    setState(() {
      _box = WritingController();
      _score = null;
    });
    AppAudioScope.of(context).say(_message);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, outer) {
        final wide = outer.maxWidth > outer.maxHeight * 1.2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(wide),
            const SizedBox(height: 8),
            if (wide)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pair()),
                    const SizedBox(width: 12),
                    // Fixed width: the boxes keep their size when the
                    // buttons change after checking.
                    SizedBox(width: 200, child: _buttons(vertical: true)),
                  ],
                ),
              )
            else ...[
              Expanded(child: _pair()),
              const SizedBox(height: 8),
              _letters(),
              const SizedBox(height: 8),
              _buttons(vertical: false),
            ],
          ],
        );
      },
    );
    return _score != null
        ? body
        : WritingShortcuts(controller: _box, child: body);
  }

  Widget _header(bool wide) {
    final message = Text(
      _message,
      key: const Key('word-message'),
      style: Theme.of(context).textTheme.titleMedium,
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
      children: [
        Expanded(child: message),
        const SizedBox(width: 12),
        _letters(),
        const SizedBox(width: 12),
        SizedBox(width: 340, child: _scoreSlot()),
      ],
    );
  }

  /// Always the same height, so the boxes never move.
  Widget _scoreSlot() {
    final scheme = Theme.of(context).colorScheme;
    final s = _score;
    return SizedBox(
      height: ScoreCard.height + 8,
      child: s != null
          ? ScoreCard.word(score: s)
          : Card(
              key: const Key('score-placeholder'),
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
    );
  }

  static const _labelH = 22.0;

  /// Model and writing box, the same size, side by side or stacked:
  /// whichever makes them bigger.
  Widget _pair() {
    final scheme = Theme.of(context).colorScheme;
    final a = WordView.aspectFor(widget.word);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        double min(double x, double y) => x < y ? x : y;
        final sideW = min(
          (box.maxWidth - gap) / 2,
          (box.maxHeight - _labelH) * a,
        );
        final stackW = min(
          box.maxWidth,
          (box.maxHeight - 2 * _labelH - gap) / 2 * a,
        );
        final side = sideW > stackW;
        final w = (side ? sideW : stackW).clamp(0.0, double.infinity);
        final h = w / a;

        final model = _panel(
          w,
          h,
          'Look',
          Card(
            color: scheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            child: LetterTemplateView(
              key: const Key('word-model'),
              template: widget.word.model,
              showHints: false,
            ),
          ),
        );
        final done = _score != null;
        final writing = _panel(
          w,
          h,
          done ? 'Your word' : 'Write here',
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: done ? scheme.outlineVariant : scheme.primary,
                width: 2,
              ),
            ),
            child: IgnorePointer(
              ignoring: done,
              child: WritingCanvas(
                key: const Key('word-canvas'),
                controller: _box,
              ),
            ),
          ),
        );
        final children = [
          model,
          side ? const SizedBox(width: gap) : const SizedBox(height: gap),
          writing,
        ];
        return Center(
          child: side
              ? Row(mainAxisSize: MainAxisSize.min, children: children)
              : Column(mainAxisSize: MainAxisSize.min, children: children),
        );
      },
    );
  }

  Widget _panel(double w, double h, String label, Widget child) => SizedBox(
    width: w,
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
        SizedBox(width: w, height: h, child: child),
      ],
    ),
  );

  /// Each letter of the word with its stars once checked: shows which
  /// letter needs work.
  Widget _letters() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scores = _score?.letters;
    final letters = _word.split('');
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < letters.length; i++)
            Container(
              key: Key(
                scores == null
                    ? 'letter-$i-none'
                    : 'letter-$i-stars-${scores[i].stars}',
              ),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(letters[i], style: text.titleSmall),
                  if (scores != null) ...[
                    const SizedBox(width: 2),
                    Text('${scores[i].stars}', style: text.labelMedium),
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber.shade600,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buttons({required bool vertical}) {
    if (_score != null && vertical) {
      // Landscape: stacked, as wide as the button column.
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onNext == null)
            FilledButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: const Text('Write again'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: const Text('Write again'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.onNext,
              icon: const Icon(Icons.arrow_forward),
              label: Text(widget.nextLabel ?? 'Next'),
            ),
          ],
        ],
      );
    }
    if (_score != null) {
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
              label: const Text('Write again'),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _again,
              icon: const Icon(Icons.replay),
              label: const Text('Write again'),
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
    final c = _box;
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
