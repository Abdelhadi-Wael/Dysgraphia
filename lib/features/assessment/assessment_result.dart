import '../../core/models/stroke.dart';
import '../../core/utils/time.dart';
import 'assessment_task.dart';

/// What happened in one task: the raw drawing plus timing. Not scored yet.
class TaskResult {
  TaskResult({
    required this.task,
    required DateTime startedAt,
    required this.duration,
    required this.drawing,
  }) : startedAt = utcMillis(startedAt);

  final AssessmentTask task;
  final DateTime startedAt;

  /// From the task appearing to the user pressing Next/Skip/Finish.
  final Duration duration;
  final Drawing drawing;

  bool get skipped => drawing.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': task.id,
    'instruction': task.instruction,
    'target': task.target,
    'startedAt': startedAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'skipped': skipped,
    'drawing': drawing.toJson(),
  };
}

/// One complete handwriting check. Specified in docs/stroke-format.md.
class AssessmentResult {
  AssessmentResult({required this.tasks, this.participant, DateTime? createdAt})
    : createdAt = utcMillis(createdAt ?? DateTime.now());

  static const format = 'dysgraphia-assessment';
  static const version = 1;

  /// A code like "P01" (not a real name), or null.
  final String? participant;
  final DateTime createdAt;
  final List<TaskResult> tasks;

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'participant': participant,
    'tasks': [for (final t in tasks) t.toJson()],
  };
}
