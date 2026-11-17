import 'dart:io';

import '../../core/audio/app_audio.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/widgets/fit_or_scroll.dart';

import '../../core/models/guide_geometry.dart';
import '../canvas/drawing_preview.dart';
import '../canvas/writing_canvas.dart';
import '../canvas/writing_controller.dart';
import '../canvas/writing_shortcuts.dart';
import '../export/drawing_exporter.dart';
import 'assessment_result.dart';
import 'assessment_task.dart';

/// Runs the handwriting check task by task, then saves everything as one
/// JSON file. Recording only: scoring comes later.
class AssessmentPage extends StatefulWidget {
  AssessmentPage({
    super.key,
    this.participant,
    List<AssessmentTask>? tasks,
    this.exporter,
    this.onSaved,
  }) : tasks = tasks ?? defaultAssessmentTasks;

  final String? participant;
  final List<AssessmentTask> tasks;
  final DrawingExporter? exporter;

  /// Called once at the end with the result and the exported file (null if
  /// writing the file failed).
  final void Function(AssessmentResult result, File? file)? onSaved;

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final _exporter = widget.exporter ?? DrawingExporter();
  final _results = <TaskResult>[];
  var _controller = WritingController();
  var _index = 0;
  var _startedAt = DateTime.now();
  File? _savedFile;
  Object? _saveError;

  bool get _finished => _index >= widget.tasks.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayTask());
  }

  /// Reads the current task aloud, with the text to copy if there is one.
  void _sayTask() {
    if (!mounted) return;
    final audio = AppAudioScope.of(context);
    if (_finished) {
      audio.play(Sfx.success);
      audio.say('Handwriting check complete. Well done!');
      return;
    }
    final t = widget.tasks[_index];
    audio.say(
      t.modelText == null ? t.instruction : '${t.instruction}: ${t.modelText}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    _results.add(
      TaskResult(
        task: widget.tasks[_index],
        startedAt: _startedAt,
        duration: DateTime.now().difference(_startedAt),
        drawing: _controller.drawing,
      ),
    );
    // A fresh controller per task, so undo can't reach the previous task.
    final old = _controller;
    setState(() {
      _controller = WritingController();
      _index++;
      _startedAt = DateTime.now();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());

    _sayTask();
    if (_finished) await _save();
  }

  Future<void> _save() async {
    final result = AssessmentResult(
      tasks: _results,
      participant: widget.participant,
    );
    File? file;
    try {
      file = await _exporter.saveJson(
        DrawingExporter.fileStem(
          'assessment_${widget.participant ?? 'anon'}',
          result.createdAt,
        ),
        result.toJson(),
      );
      if (mounted) setState(() => _savedFile = file);
    } catch (e) {
      if (mounted) setState(() => _saveError = e);
    }
    widget.onSaved?.call(result, file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handwriting check'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _index / widget.tasks.length),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(pagePadding(context)),
        child: _finished
            ? _buildSummary(context)
            // Scrolls on short screens (phone in landscape).
            : FitOrScroll(
                minHeight: ExerciseHeights.check,
                child: _buildTask(context),
              ),
      ),
    );
  }

  Widget _buildTask(BuildContext context) {
    final task = widget.tasks[_index];
    final text = Theme.of(context).textTheme;
    final isLast = _index == widget.tasks.length - 1;

    return WritingShortcuts(
      controller: _controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Task ${_index + 1} of ${widget.tasks.length}',
            style: text.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(task.instruction, style: text.headlineSmall),
          const SizedBox(height: 12),
          if (task.modelText != null)
            Text(
              task.modelText!,
              key: const Key('model-text'),
              style: text.displaySmall,
            ),
          if (task.modelDrawing != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                key: const Key('model-drawing'),
                width: 360,
                height: 72,
                child: DrawingPreview(drawing: task.modelDrawing!),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // Make the line small enough that the task fits on it.
                final maxUnit = box.maxWidth / task.requiredWidthUnits;
                final height = math.min(
                  box.maxHeight,
                  GuideGeometry.heightForUnit(maxUnit),
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: height,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: WritingCanvas(
                        key: const Key('writing-canvas'),
                        controller: _controller,
                        showGuides: task.showGuides,
                      ),
                    ),
                  ),
                );
              },
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
                  tooltip: 'Redo (Ctrl+Shift+Z)',
                  icon: const Icon(Icons.redo),
                  onPressed: _controller.canRedo ? _controller.redo : null,
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _controller.isEmpty ? null : _controller.clear,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  child: Text(
                    _controller.drawing.isEmpty
                        ? 'Skip'
                        : (isLast ? 'Finish' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Handwriting check complete',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final r in _results)
              ListTile(
                title: Text(r.task.instruction),
                trailing: Text(
                  r.skipped
                      ? 'skipped'
                      : '${(r.duration.inMilliseconds / 1000).toStringAsFixed(1)} s',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _saveError != null
                  ? 'Could not save: $_saveError'
                  : _savedFile != null
                  ? 'Saved to ${_savedFile!.path}'
                  : 'Saving…',
              key: const Key('save-status'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
