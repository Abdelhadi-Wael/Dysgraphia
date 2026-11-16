import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/drawing_export.dart';
import '../../core/models/stroke.dart';
import '../export/drawing_exporter.dart';
import 'writing_canvas.dart';
import 'writing_controller.dart';
import 'writing_shortcuts.dart';

/// Temporary developer screen for trying the canvas (week 1).
/// Replaced by the real exercise screens later.
class CanvasPlaygroundPage extends StatefulWidget {
  const CanvasPlaygroundPage({super.key, this.exporter});

  /// Where "Export JSON" saves; tests pass one that writes to a temp folder.
  final DrawingExporter? exporter;

  @override
  State<CanvasPlaygroundPage> createState() => _CanvasPlaygroundPageState();
}

class _CanvasPlaygroundPageState extends State<CanvasPlaygroundPage> {
  final _controller = WritingController();
  bool _showGhost = true;
  double _inkWidth = 0.06;

  /// A sample "o": one counter-clockwise loop starting at the top right
  /// (about 1-2 o'clock), the way it is taught in school. y grows downwards,
  /// so increasing the angle moves up and over to the left.
  /// Real templates arrive in the next step.
  static final _sampleO = Drawing([
    Stroke([
      for (var i = 0; i <= 48; i++)
        () {
          final a = math.pi / 4 + i / 48 * 2 * math.pi;
          return StrokePoint(
            0.3 + 0.25 * math.cos(a),
            -0.25 - 0.25 * math.sin(a),
          );
        }(),
    ]),
  ]);

  late final _exporter = widget.exporter ?? DrawingExporter();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Saves the current drawing as JSON (see docs/stroke-format.md). With the
  /// trace guide on, the target is recorded as "o".
  Future<void> _export() async {
    final export = DrawingExport(
      drawing: _controller.drawing,
      target: _showGhost ? 'o' : null,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _exporter.save(export);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Copy JSON',
            onPressed: () => Clipboard.setData(
              ClipboardData(text: jsonEncode(export.toJson())),
            ),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WritingShortcuts(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Writing canvas'),
          actions: [
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
                    tooltip: 'Redo (Ctrl+Shift+Z)',
                    icon: const Icon(Icons.redo),
                    onPressed: _controller.canRedo ? _controller.redo : null,
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _controller.isEmpty ? null : _controller.clear,
                  ),
                  IconButton(
                    tooltip: 'Export JSON',
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: _controller.drawing.isEmpty ? null : _export,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: WritingCanvas(
                    key: const Key('writing-canvas'),
                    controller: _controller,
                    ghost: _showGhost ? _sampleO : null,
                    inkWidth: _inkWidth,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Trace guide'),
                    selected: _showGhost,
                    onSelected: (v) => setState(() => _showGhost = v),
                  ),
                  SizedBox(
                    width: 260,
                    child: Row(
                      children: [
                        const Text('Pen size'),
                        Expanded(
                          child: Slider(
                            value: _inkWidth,
                            min: 0.02,
                            max: 0.12,
                            onChanged: (v) => setState(() => _inkWidth = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      final d = _controller.drawing;
                      final points = d.allPoints.length;
                      final ms = d.isEmpty ? 0 : d.strokes.last.end.t;
                      return Text(
                        'Strokes: ${d.strokeCount}   Points: $points   Time: ${(ms / 1000).toStringAsFixed(1)} s',
                        key: const Key('stats'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
