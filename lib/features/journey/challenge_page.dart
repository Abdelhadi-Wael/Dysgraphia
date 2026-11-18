import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/widgets/fit_or_scroll.dart';

import '../../core/audio/app_audio.dart';
import '../../core/models/history.dart';
import '../exercises/copy/copy_view.dart';
import '../exercises/trace/trace_view.dart';
import '../templates/letter_page.dart';
import '../templates/letter_templates.dart';
import '../templates/warmup_shapes.dart';
import '../templates/watch_view.dart';
import '../words/word_templates.dart';
import '../words/word_view.dart';
import 'journey.dart';

enum _Kind { warmUp, watch, trace, copy, watchWord, writeWord, review, done }

class _Step {
  const _Step(this.kind, this.template, this.title, {this.word});

  final _Kind kind;
  final LetterTemplate template;
  final String title;

  /// For word steps.
  final WordTemplate? word;
}

/// One challenge of the writing journey, as a guided session:
/// warm-up shape (trace) → new letter (watch, trace, copy ×3) → review of
/// an earlier letter (copy once) → celebration. A word challenge instead
/// watches and writes each of its words, then reviews a letter.
///
/// Saves nothing itself: results go to [onAttempt], and [onComplete] gets
/// the challenge's stars at the end: the best copy of the new letter, or
/// for words the average of each word's best.
class ChallengePage extends StatefulWidget {
  const ChallengePage({
    super.key,
    required this.challenge,
    this.review,
    this.onAttempt,
    this.onComplete,
    this.hasNext = true,
  });

  final Challenge challenge;

  /// Earlier letter to review, if any.
  final String? review;
  final void Function(Attempt attempt)? onAttempt;
  final void Function(int stars)? onComplete;

  /// Whether another challenge follows (for the "unlocked" message).
  final bool hasNext;

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> {
  Challenge get _c => widget.challenge;

  late final List<_Step> _steps = [
    if (_c.isWords)
      for (final id in _c.words) ...[
        _Step(
          _Kind.watchWord,
          practiceWords[id]!.model,
          'Watch: ${practiceWordText(id)}',
          word: practiceWords[id],
        ),
        _Step(
          _Kind.writeWord,
          practiceWords[id]!.model,
          'Write: ${practiceWordText(id)}',
          word: practiceWords[id],
        ),
      ]
    else ...[
      _Step(
        _Kind.warmUp,
        templateFor(_c.warmUp!),
        'Warm-up: ${templateFor(_c.warmUp!).label}',
      ),
      _Step(_Kind.watch, templateFor(_c.letter!), 'Watch'),
      _Step(_Kind.trace, templateFor(_c.letter!), 'Trace'),
      _Step(_Kind.copy, templateFor(_c.letter!), 'Copy'),
    ],
    if (widget.review != null)
      _Step(_Kind.review, templateFor(widget.review!), 'Review'),
    _Step(_Kind.done, _steps0Template, 'Done'),
  ];

  LetterTemplate get _steps0Template => _c.isWords
      ? practiceWords[_c.words.first]!.model
      : templateFor(_c.letter!);

  var _index = 0;
  var _bestStars = 0;

  /// Best stars per word, for word challenges.
  final _wordStars = <String, int>{};

  _Step get _step => _steps[_index];

  int get _stars {
    if (!_c.isWords) return math.max(1, _bestStars);
    if (_wordStars.isEmpty) return 1;
    final sum = _c.words.map((w) => _wordStars[w] ?? 1).reduce((a, b) => a + b);
    return math.max(1, (sum / _c.words.length).round());
  }

  void _next() {
    setState(() => _index++);
    if (_step.kind == _Kind.done) {
      final stars = _stars;
      widget.onComplete?.call(stars);
      final audio = AppAudioScope.of(context);
      audio.play(Sfx.success);
      audio.say(
        'Challenge ${widget.challenge.number} complete! You got $stars '
        '${stars == 1 ? 'star' : 'stars'}.',
      );
    }
  }

  String _nextLabel() {
    final following = _steps[_index + 1];
    return switch (following.kind) {
      _Kind.watch => 'Next: ${following.template.label.toLowerCase()}',
      _Kind.trace => 'Trace it',
      _Kind.copy => 'Copy it',
      _Kind.watchWord => 'Next word: ${following.word!.word}',
      _Kind.writeWord => 'Write it',
      _Kind.review => 'Next: review',
      _Kind.done => 'Finish',
      _Kind.warmUp => 'Next',
    };
  }

  void _report(Attempt a) => widget.onAttempt?.call(a);

  @override
  Widget build(BuildContext context) {
    final step = _step;
    // Steps that do something (not the final celebration), for progress.
    final total = _steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _c.isWords
              ? 'Challenge ${_c.number} · ${_c.name}'
              : 'Challenge ${_c.number} · letter ${_c.letter}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            // On narrow screens the text shortens with "…" and the bar
            // keeps at least 2/5 of the width.
            child: Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    step.kind == _Kind.done
                        ? 'Finished'
                        : 'Step ${_index + 1} of $total · ${step.title}',
                    key: const Key('challenge-step'),
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: LinearProgressIndicator(
                    value: _index / total,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(pagePadding(context)),
        // Keyed by step, so two steps of the same kind never share state.
        // Scrolls on short screens (phone in landscape).
        child: FitOrScroll(
          minHeight: switch (step.kind) {
            _Kind.watch ||
            _Kind.watchWord ||
            _Kind.done => ExerciseHeights.watch,
            _Kind.warmUp || _Kind.trace => ExerciseHeights.trace,
            _Kind.copy ||
            _Kind.writeWord ||
            _Kind.review => ExerciseHeights.copy,
          },
          child: KeyedSubtree(key: ValueKey(_index), child: _body(step)),
        ),
      ),
    );
  }

  Widget _body(_Step step) => switch (step.kind) {
    _Kind.warmUp || _Kind.trace => TraceView(
      template: step.template,
      onNext: _next,
      nextLabel: _nextLabel(),
      onFinished: (d, s, retries) => _report(
        makeAttempt(
          step.template.letter,
          PracticeKind.trace,
          d,
          s,
          retries: retries,
        ),
      ),
    ),
    _Kind.watch => WatchView(
      template: step.template,
      onNext: _next,
      nextLabel: _nextLabel(),
    ),
    _Kind.watchWord => WatchView(
      template: step.template,
      intro: 'Watch how to write the word ${step.word!.word}.',
      onNext: _next,
      nextLabel: _nextLabel(),
    ),
    _Kind.writeWord => WordView(
      word: step.word!,
      onChecked: (d, s) {
        final id = step.word!.id;
        _wordStars[id] = math.max(_wordStars[id] ?? 0, s.stars);
        _report(
          Attempt(
            letter: id,
            kind: PracticeKind.word,
            stars: s.stars,
            overall: s.overall,
            score: s.toJson(),
            drawing: d,
          ),
        );
      },
      onNext: _next,
      nextLabel: _nextLabel(),
    ),
    _Kind.copy || _Kind.review => CopyView(
      template: step.template,
      attempts: step.kind == _Kind.copy ? 3 : 1,
      onChecked: (d, s) {
        if (step.kind == _Kind.copy) {
          _bestStars = math.max(_bestStars, s.stars);
        }
        _report(makeAttempt(step.template.letter, PracticeKind.copy, d, s));
      },
      onNext: _next,
      nextLabel: _nextLabel(),
    ),
    _Kind.done => _Celebration(
      challenge: widget.challenge,
      stars: _stars,
      hasNext: widget.hasNext,
    ),
  };
}

class _Celebration extends StatelessWidget {
  const _Celebration({
    required this.challenge,
    required this.stars,
    required this.hasNext,
  });

  final Challenge challenge;
  final int stars;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Challenge ${challenge.number} complete!',
            style: text.headlineMedium,
          ),
          const SizedBox(height: 24),
          Row(
            key: Key('celebration-stars-$stars'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 3; i++)
                // Stars pop in one after another.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + i * 250),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Icon(
                    i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 96,
                    color: Colors.amber.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasNext
                ? 'Challenge ${challenge.number + 1} is now open.'
                : 'You finished the whole journey!',
            style: text.titleMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
            icon: const Icon(Icons.route),
            label: const Text('Back to journey'),
          ),
        ],
      ),
    );
  }
}
