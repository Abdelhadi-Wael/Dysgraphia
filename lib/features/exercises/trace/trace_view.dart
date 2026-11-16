import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/models/guide_geometry.dart';
import '../../../core/models/stroke.dart';
import '../../canvas/writing_canvas.dart';
import '../../canvas/writing_controller.dart';
import '../../canvas/writing_shortcuts.dart';
import '../../scoring/letter_scorer.dart';
import '../../scoring/score_card.dart';
import '../../templates/letter_templates.dart';
import 'trace_checker.dart';

/// Trace a letter over its dotted template with live feedback:
/// * a numbered dot and arrow show where the next stroke starts;
/// * the line turns orange as soon as it goes wrong;
/// * a wrong stroke fades away, so the child just tries it again.
class TraceView extends StatefulWidget {
  const TraceView({super.key, required this.template, this.onCopy});

  final LetterTemplate template;

  /// When set, a finished trace offers "Copy it" to move on.
  final VoidCallback? onCopy;

  /// Width / height of the writing box.
  static const aspect = 1.2;

  /// The template centred in the writing box, in canvas line units.
  static Drawing shapeFor(LetterTemplate t) {
    // Box width in line units for this aspect (see GuideGeometry).
    final unitsPerHeight = 0.8 / 1.5;
    final widthUnits = aspect / unitsPerHeight - 0.25;
    return t.drawing.shifted((widthUnits - t.width) / 2, 0);
  }

  @override
  State<TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<TraceView>
    with SingleTickerProviderStateMixin {
  late final _shape = TraceView.shapeFor(widget.template);
  late final _checker = TraceChecker(_shape);
  late final _controller = WritingController(acceptStroke: _onStrokeEnd);
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// Problem with the stroke being written right now.
  var _live = TraceIssue.none;

  /// Why the last stroke was rejected (shown until the next good stroke).
  TraceIssue? _rejectedIssue;
  Stroke? _rejected;
  var _mistakes = 0;

  int get _accepted => _controller.drawing.strokeCount;
  bool get _complete => _checker.isComplete(_accepted);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _onChange() {
    var live = TraceIssue.none;
    if (_controller.isWriting) {
      live = _checker.checkLive(_controller.strokes.last, _accepted).issue;
    }
    // Rebuild for the message; the canvas repaints by itself.
    setState(() => _live = live);
  }

  bool _onStrokeEnd(Stroke s) {
    final r = _checker.checkFinished(s, _accepted);
    if (r.ok) {
      _rejectedIssue = null;
      return true;
    }
    _mistakes++;
    _rejected = s;
    _rejectedIssue = r.issue;
    _fade.forward(from: 0);
    return false;
  }

  void _restart() {
    _mistakes = 0;
    _rejectedIssue = null;
    _controller.clear(); // notifies → _onChange rebuilds
  }

  String get _message {
    if (_complete) {
      return switch (_mistakes) {
        0 => 'Well done!',
        1 => 'Well done! (1 retry)',
        _ => 'Well done! ($_mistakes retries)',
      };
    }
    final next = _accepted + 1;
    final issue = _live != TraceIssue.none ? _live : _rejectedIssue;
    return switch (issue) {
      TraceIssue.wrongStart => 'Start at dot $next',
      TraceIssue.wrongOrder => 'Not yet: start with stroke $next',
      TraceIssue.wrongDirection => 'Go the other way: follow the arrow',
      TraceIssue.offPath => 'Stay on the dotted line',
      TraceIssue.tooShort => 'Keep going to the end of the line',
      _ =>
        _accepted == 0
            ? 'Start at dot 1 and follow the arrow'
            : 'Good! Now stroke $next',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = Colors.orange.shade700;
    final hasIssue =
        !_complete && (_live != TraceIssue.none || _rejectedIssue != null);
    final messageColor = _complete
        ? scheme.primary
        : (hasIssue ? warning : scheme.onSurface);

    return WritingShortcuts(
      controller: _controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _complete
                    ? Icons.celebration_outlined
                    : (hasIssue ? Icons.info_outline : Icons.edit_outlined),
                color: messageColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _message,
                  key: const Key('trace-message'),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: messageColor),
                ),
              ),
            ],
          ),
          if (_complete) ...[
            const SizedBox(height: 8),
            ScoreCard(
              score: const LetterScorer().score(_controller.drawing, _shape),
              hasDescender: _shape.bounds!.$4 > 0.2,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: TraceView.aspect,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: IgnorePointer(
                    ignoring: _complete,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        WritingCanvas(
                          key: const Key('trace-canvas'),
                          controller: _controller,
                          ghost: _shape,
                          inkColorOf: (i, _) =>
                              _controller.isWriting &&
                                  i == _controller.strokes.length - 1 &&
                                  _live != TraceIssue.none
                              ? warning
                              : null,
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _HintPainter(
                              shape: _shape,
                              controller: _controller,
                              fade: _fade,
                              rejected: _rejected,
                              hint: scheme.primary,
                              onHint: scheme.onPrimary,
                              warning: warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(
              children: [
                IconButton(
                  tooltip: 'Undo (Ctrl+Z)',
                  icon: const Icon(Icons.undo),
                  onPressed: _controller.canUndo ? _controller.undo : null,
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _controller.isEmpty ? null : _restart,
                ),
                const Spacer(),
                if (_complete) ...[
                  OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Trace again'),
                  ),
                  if (widget.onCopy != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: widget.onCopy,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Copy it'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws on top of the canvas: the next stroke's numbered start dot with a
/// short arrow (only while the pen is up), and the fading rejected stroke.
class _HintPainter extends CustomPainter {
  _HintPainter({
    required this.shape,
    required this.controller,
    required this.fade,
    required this.rejected,
    required this.hint,
    required this.onHint,
    required this.warning,
  }) : super(repaint: Listenable.merge([controller, fade]));

  final Drawing shape;
  final WritingController controller;
  final Animation<double> fade;
  final Stroke? rejected;
  final Color hint, onHint, warning;

  @override
  void paint(Canvas canvas, Size size) {
    final g = GuideGeometry(size);

    final r = rejected;
    if (r != null && fade.isAnimating && r.points.length > 1) {
      final path = Path()
        ..moveTo(g.toPixels(r.start).dx, g.toPixels(r.start).dy);
      for (final p in r.points.skip(1)) {
        path.lineTo(g.toPixels(p).dx, g.toPixels(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = warning.withValues(alpha: 1 - fade.value)
          ..strokeWidth = g.unit * 0.06
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final index = controller.drawing.strokeCount;
    if (controller.isWriting || index >= shape.strokeCount) return;
    final next = shape.strokes[index];
    final start = g.toPixels(next.start);
    final radius = math.max(10.0, g.unit * 0.08);

    // Short arrow along the beginning of the stroke.
    if (next.points.length > 1) {
      final pts = <Offset>[start];
      var travelled = 0.0;
      for (var i = 1; i < next.points.length && travelled < 0.3; i++) {
        travelled += next.points[i - 1].distanceTo(next.points[i]);
        pts.add(g.toPixels(next.points[i]));
      }
      final arrow = Path()..moveTo(start.dx, start.dy);
      for (final p in pts.skip(1)) {
        arrow.lineTo(p.dx, p.dy);
      }
      final paint = Paint()
        ..color = hint
        ..strokeWidth = math.max(3, g.unit * 0.025)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(arrow, paint);
      final d = pts.last - pts[pts.length - 2];
      if (d.distance > 0) {
        final dir = d / d.distance;
        final normal = Offset(-dir.dy, dir.dx);
        final s = radius * 0.8;
        final tip = pts.last + dir * s * 0.5;
        final a = tip - dir * s + normal * s * 0.6;
        final b = tip - dir * s - normal * s * 0.6;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..close(),
          Paint()..color = hint,
        );
      }
    }

    canvas.drawCircle(start, radius, Paint()..color = hint);
    final label = TextPainter(
      text: TextSpan(
        text: '${index + 1}',
        style: TextStyle(
          color: onHint,
          fontSize: radius * 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, start - Offset(label.width / 2, label.height / 2));
  }

  @override
  bool shouldRepaint(_HintPainter old) =>
      old.rejected != rejected || old.shape != shape;
}
