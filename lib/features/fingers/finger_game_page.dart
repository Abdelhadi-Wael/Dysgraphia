import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_litert/flutter_litert.dart' show CoverFitTransform;
import 'package:material_ui/material_ui.dart';

import '../../core/audio/app_audio.dart';
import '../../core/models/history.dart';
import '../../core/widgets/fit_or_scroll.dart';
import 'finger_game.dart';
import 'hand_frame.dart';
import 'hand_source.dart';
import 'pinch_detector.dart';

Color fingerColor(Finger f) => Color(f.argb);

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

enum _Phase { setup, starting, playing, done, problem }

/// The finger warm-up: touch the thumb to the finger shown, as fast and as
/// accurately as you can, while the camera follows the hand.
class FingerGamePage extends StatefulWidget {
  const FingerGamePage({
    super.key,
    this.source,
    this.onFinished,
    this.bestScore,
  });

  /// Makes the hand source when a round starts; the camera by default.
  final HandSource Function()? source;

  /// Receives every finished round, e.g. to save it.
  final void Function(FingerGameRecord record)? onFinished;

  /// Best earlier score with the given settings, to show at the end.
  final int? Function(GameSettings settings)? bestScore;

  @override
  State<FingerGamePage> createState() => _FingerGamePageState();
}

class _FingerGamePageState extends State<FingerGamePage>
    with SingleTickerProviderStateMixin {
  var _phase = _Phase.setup;
  var _settings = const GameSettings();
  HandSourceProblem? _problem;

  HandSource? _source;
  StreamSubscription<HandFrame>? _sub;
  FingerGame? _game;
  final _detector = PinchDetector();
  HandFrame? _lastFrame;
  int? _bestBefore;

  /// Shakes the target after a wrong finger.
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// Briefly true after a hit, to flash the target.
  var _flash = false;

  @override
  void dispose() {
    _shake.dispose();
    _end();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _phase = _Phase.starting);
    _bestBefore = widget.bestScore?.call(_settings);
    final source = (widget.source ?? CameraHandSource.new)();
    try {
      await source.start();
    } on HandSourceException catch (e) {
      await source.stop();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.problem;
        _problem = e.problem;
      });
      return;
    }
    if (!mounted) {
      await source.stop();
      return;
    }
    _source = source;
    _detector.reset();
    _game = FingerGame(_settings);
    _sub = source.frames.listen(_onFrame);
    setState(() => _phase = _Phase.playing);
    _sayTarget();
  }

  void _sayTarget() {
    final g = _game;
    if (g != null && mounted) AppAudioScope.of(context).say(g.target.spoken);
  }

  void _onFrame(HandFrame frame) {
    final game = _game;
    if (game == null || _phase != _Phase.playing) return;
    final audio = AppAudioScope.of(context);
    for (final e in _detector.add(frame)) {
      if (e is PinchStart) {
        switch (game.pinch(e.finger)) {
          case GameEvent.hit:
            audio.play(Sfx.star);
            _flash = true;
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted) setState(() => _flash = false);
            });
            _sayTarget();
          case GameEvent.wrong:
            _shake.forward(from: 0);
          default:
        }
      }
    }
    final event = game.tick(frame.time, handSeen: frame.hasHand);
    if (event == GameEvent.missed) _sayTarget();
    if (event == GameEvent.finished) {
      _finish();
      return;
    }
    setState(() => _lastFrame = frame);
  }

  void _finish() {
    final g = _game!;
    final record = FingerGameRecord(
      pattern: _settings.pattern.name,
      speed: _settings.speed.name,
      seconds: _settings.length.inSeconds,
      hits: g.hits,
      wrong: g.wrongs,
      missed: g.misses,
      reactionMs: g.averageReaction?.inMilliseconds,
    );
    widget.onFinished?.call(record);
    _end();
    setState(() => _phase = _Phase.done);
    final audio = AppAudioScope.of(context);
    audio.play(Sfx.success);
    final best = _bestBefore;
    audio.say(
      best != null && g.hits > best
          ? 'New best! You caught ${g.hits}.'
          : 'Well done! You caught ${g.hits}.',
    );
  }

  /// Stops the camera; frames are never kept.
  void _end() {
    _sub?.cancel();
    _sub = null;
    _source?.stop();
    _source = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finger taps')),
      body: Padding(
        padding: EdgeInsets.all(pagePadding(context)),
        child: switch (_phase) {
          _Phase.setup => _setup(),
          _Phase.starting => const Center(child: CircularProgressIndicator()),
          _Phase.playing => _playing(),
          _Phase.done => _done(),
          _Phase.problem => _problemView(),
        },
      ),
    );
  }

  // ---------------------------------------------------------------- setup

  Widget _setup() {
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(s, style: text.titleSmall),
    );
    return ListView(
      children: [
        Text(
          'Touch your thumb to the finger with the same colour.',
          style: text.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Hold your hand up in front of the screen, palm towards it. '
          'The camera watches your hand; nothing is recorded.',
        ),
        const SizedBox(height: 12),
        const Center(
          child: SizedBox(width: 180, height: 180, child: HandPicture()),
        ),
        label('Pattern'),
        SegmentedButton<PinchPattern>(
          key: const Key('pattern'),
          showSelectedIcon: false,
          segments: [
            for (final p in PinchPattern.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_settings.pattern},
          onSelectionChanged: (s) =>
              setState(() => _settings = _settings.copyWith(pattern: s.single)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_settings.pattern.description, style: text.bodySmall),
        ),
        label('Speed'),
        SegmentedButton<GameSpeed>(
          showSelectedIcon: false,
          segments: [
            for (final s in GameSpeed.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {_settings.speed},
          onSelectionChanged: (s) =>
              setState(() => _settings = _settings.copyWith(speed: s.single)),
        ),
        label('Length'),
        SegmentedButton<Duration>(
          showSelectedIcon: false,
          segments: [
            for (final d in GameSettings.lengths)
              ButtonSegment(value: d, label: Text('${d.inSeconds} s')),
          ],
          selected: {_settings.length},
          onSelectionChanged: (s) =>
              setState(() => _settings = _settings.copyWith(length: s.single)),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Start'),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- playing

  Widget _playing() {
    final game = _game!;
    final source = _source!;
    final hasHand = _lastFrame?.hasHand ?? false;
    final camera = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<Size?>(
          valueListenable: source.imageSize,
          builder: (context, size, _) => Stack(
            fit: StackFit.expand,
            children: [
              if (source.preview() case final preview? when size != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: preview,
                  ),
                ),
              if (size != null)
                CustomPaint(
                  painter: _HandOverlay(
                    frame: _lastFrame,
                    imageSize: size,
                    mirror: source.mirrored,
                    target: game.target,
                    pinched: _detector.pinched,
                  ),
                ),
              if (!hasHand)
                Center(
                  child: Container(
                    key: const Key('show-hand'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Show your hand',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final panel = _targetPanel(game);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBar(game),
            const SizedBox(height: 8),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: camera),
                        const SizedBox(width: 12),
                        SizedBox(width: box.maxWidth * 0.35, child: panel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: camera),
                        const SizedBox(height: 12),
                        SizedBox(height: box.maxHeight * 0.3, child: panel),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusBar(FingerGame game) {
    final text = Theme.of(context).textTheme;
    final left = game.settings.length - game.played;
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          '${(left.inMilliseconds / 1000).ceil()} s',
          style: text.titleMedium,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LinearProgressIndicator(
            value:
                game.played.inMilliseconds /
                game.settings.length.inMilliseconds,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.star_rounded, color: Colors.amber.shade600),
        Text('${game.hits}', key: const Key('score'), style: text.titleLarge),
      ],
    );
  }

  /// The finger to pinch now: a big circle in its colour, with a ring that
  /// runs down as its time passes.
  Widget _targetPanel(FingerGame game) {
    final color = fingerColor(game.target);
    final text = Theme.of(context).textTheme;
    return Card(
      child: LayoutBuilder(
        builder: (context, box) {
          final d = math.max(
            40.0,
            math.min(box.maxWidth * 0.6, box.maxHeight - 56),
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    math.sin(_shake.value * math.pi * 6) *
                        12 *
                        (1 - _shake.value),
                    0,
                  ),
                  child: child,
                ),
                child: SizedBox(
                  key: Key('target-${game.target.name}'),
                  width: d,
                  height: d,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: game.targetTimeLeft.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _flash ? Colors.white : color,
                            border: Border.all(color: color, width: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cap(game.target.spoken),
                style: text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------- done

  Widget _done() {
    final g = _game!;
    final text = Theme.of(context).textTheme;
    final best = _bestBefore;
    final reaction = g.averageReaction;
    return FitOrScroll(
      minHeight: 360,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              best != null && g.hits > best ? 'New best!' : 'Well done!',
              style: text.headlineMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber.shade600,
                  size: 48,
                ),
                Text(
                  '${g.hits}',
                  key: const Key('final-score'),
                  style: text.displaySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Wrong finger: ${g.wrongs}'),
                Text('Missed: ${g.misses}'),
                Text('Accuracy: ${(g.accuracy * 100).round()}%'),
                if (reaction != null)
                  Text(
                    'Average time: '
                    '${(reaction.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  ),
                if (best != null) Text('Best before: $best'),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _phase = _Phase.setup),
                  icon: const Icon(Icons.tune),
                  label: const Text('Settings'),
                ),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.replay),
                  label: const Text('Play again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _problemView() {
    final text = Theme.of(context).textTheme;
    final (title, detail) = switch (_problem!) {
      HandSourceProblem.unsupported => (
        'This game needs a phone or tablet',
        'It uses the front camera to follow your hand. Try it on an '
            'Android or iOS device.',
      ),
      HandSourceProblem.noCamera => (
        'No camera found',
        'This game uses the front camera to follow your hand.',
      ),
      HandSourceProblem.denied => (
        'The camera is not allowed',
        'Allow the camera for this app in the device settings, then try '
            'again. Nothing is recorded or saved.',
      ),
      HandSourceProblem.failed => (
        'The camera did not start',
        'Close other apps that use the camera and try again.',
      ),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              key: const Key('camera-problem'),
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() => _phase = _Phase.setup),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tracked hand drawn over the camera picture: thin bones, the thumb
/// tip, and each fingertip in its colour (the target bigger).
class _HandOverlay extends CustomPainter {
  _HandOverlay({
    required this.frame,
    required this.imageSize,
    required this.mirror,
    required this.target,
    required this.pinched,
  });

  final HandFrame? frame;
  final Size imageSize;
  final bool mirror;
  final Finger target;
  final Finger? pinched;

  static const _bones = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 7, 8],
    [5, 9, 10, 11, 12],
    [9, 13, 14, 15, 16],
    [13, 17, 18, 19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = frame?.points;
    if (points == null) return;
    final t = CoverFitTransform.cover(
      sourceWidth: imageSize.width,
      sourceHeight: imageSize.height,
      viewWidth: size.width,
      viewHeight: size.height,
      mirror: mirror,
    );
    Offset at(int i) => t.map(points[i].x, points[i].y);
    final bone = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final chain in _bones) {
      for (var i = 1; i < chain.length; i++) {
        canvas.drawLine(at(chain[i - 1]), at(chain[i]), bone);
      }
    }
    canvas.drawCircle(
      at(HandLandmarks.thumbTip),
      9,
      Paint()..color = Colors.white,
    );
    for (final f in Finger.values) {
      final r = f == target ? 16.0 : 9.0;
      final c = at(HandLandmarks.tipOf(f));
      canvas.drawCircle(c, r, Paint()..color = fingerColor(f));
      if (f == pinched) {
        canvas.drawCircle(
          c,
          r + 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HandOverlay old) =>
      old.frame != frame || old.target != target || old.pinched != pinched;
}

/// A simple drawn hand with each fingertip in its game colour, to explain
/// the colours before playing.
class HandPicture extends StatelessWidget {
  const HandPicture({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HandPicturePainter(
      skin: Theme.of(context).colorScheme.surfaceContainerHighest,
      line: Theme.of(context).colorScheme.outline,
    ),
  );
}

class _HandPicturePainter extends CustomPainter {
  _HandPicturePainter({required this.skin, required this.line});

  final Color skin, line;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 10;
    final fill = Paint()..color = skin;
    final edge = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void finger(double x, double top, double angle, Color? tip) {
      canvas.save();
      canvas.translate(x, 6.2 * u);
      canvas.rotate(angle);
      final r = RRect.fromLTRBR(
        -0.65 * u,
        top - 6.2 * u,
        0.65 * u,
        0,
        Radius.circular(0.65 * u),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, edge);
      if (tip != null) {
        canvas.drawCircle(
          Offset(0, top - 6.2 * u + 0.75 * u),
          0.55 * u,
          Paint()..color = tip,
        );
      }
      canvas.restore();
    }

    final cx = size.width / 2;
    // Fingers behind the palm, from pointer to little finger.
    final f = Finger.values;
    finger(cx - 1.9 * u, 1.4 * u, -0.08, fingerColor(f[0]));
    finger(cx - 0.6 * u, 0.6 * u, -0.02, fingerColor(f[1]));
    finger(cx + 0.7 * u, 1.0 * u, 0.04, fingerColor(f[2]));
    finger(cx + 1.95 * u, 2.4 * u, 0.12, fingerColor(f[3]));
    // Thumb, then the palm on top.
    finger(cx - 2.6 * u, 4.6 * u, -0.9, Colors.white);
    final palm = RRect.fromLTRBR(
      cx - 2.6 * u,
      5.0 * u,
      cx + 2.6 * u,
      9.6 * u,
      Radius.circular(1.6 * u),
    );
    canvas.drawRRect(palm, fill);
    canvas.drawRRect(palm, edge);
  }

  @override
  bool shouldRepaint(_HandPicturePainter old) =>
      old.skin != skin || old.line != line;
}
