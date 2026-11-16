import '../utils/time.dart';
import 'stroke.dart';

enum PracticeKind { trace, copy }

/// One finished, scored letter: a completed trace or one checked copy box.
/// Keeps the raw drawing so it can be re-scored later with better rules.
class Attempt {
  Attempt({
    required this.letter,
    required this.kind,
    required this.stars,
    required this.overall,
    required this.score,
    required this.drawing,
    this.retries = 0,
    DateTime? at,
  }) : at = utcMillis(at ?? DateTime.now());

  final String letter;
  final PracticeKind kind;
  final DateTime at;
  final int stars;

  /// 0..1, see docs/scoring.md.
  final double overall;

  /// The full score breakdown (LetterScore.toJson()).
  final Map<String, dynamic> score;

  /// Strokes rejected while tracing (0 for copies).
  final int retries;
  final Drawing drawing;

  Map<String, dynamic> toJson() => {
    'letter': letter,
    'kind': kind.name,
    'at': at.toIso8601String(),
    'stars': stars,
    'overall': overall,
    'retries': retries,
    'score': score,
    'drawing': drawing.toJson(),
  };

  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
    letter: j['letter'] as String,
    kind: PracticeKind.values.byName(j['kind'] as String),
    at: DateTime.parse(j['at'] as String),
    stars: (j['stars'] as num).toInt(),
    overall: (j['overall'] as num).toDouble(),
    retries: (j['retries'] as num?)?.toInt() ?? 0,
    score: Map<String, dynamic>.from(j['score'] as Map),
    drawing: Drawing.fromJson(j['drawing'] as Map<String, dynamic>),
  );
}

/// A completed handwriting check. The full recording is in its own export
/// file; history keeps a summary.
class CheckRecord {
  CheckRecord({
    required this.tasks,
    required this.skipped,
    this.file,
    DateTime? at,
  }) : at = utcMillis(at ?? DateTime.now());

  final DateTime at;
  final int tasks;
  final int skipped;

  /// Path of the exported assessment file, if saving it worked.
  final String? file;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'tasks': tasks,
    'skipped': skipped,
    'file': file,
  };

  factory CheckRecord.fromJson(Map<String, dynamic> j) => CheckRecord(
    at: DateTime.parse(j['at'] as String),
    tasks: (j['tasks'] as num).toInt(),
    skipped: (j['skipped'] as num).toInt(),
    file: j['file'] as String?,
  );
}

/// Everything one profile has done, oldest first.
class History {
  History({List<Attempt>? attempts, List<CheckRecord>? checks})
    : attempts = List.unmodifiable(attempts ?? const []),
      checks = List.unmodifiable(checks ?? const []);

  static final empty = History();

  final List<Attempt> attempts;
  final List<CheckRecord> checks;

  History withAttempt(Attempt a) =>
      History(attempts: [...attempts, a], checks: checks);

  History withCheck(CheckRecord c) =>
      History(attempts: attempts, checks: [...checks, c]);

  Map<String, dynamic> toJson() => {
    'attempts': [for (final a in attempts) a.toJson()],
    'checks': [for (final c in checks) c.toJson()],
  };

  factory History.fromJson(Map<String, dynamic> j) => History(
    attempts: [
      for (final a in (j['attempts'] as List? ?? const []))
        Attempt.fromJson(a as Map<String, dynamic>),
    ],
    checks: [
      for (final c in (j['checks'] as List? ?? const []))
        CheckRecord.fromJson(c as Map<String, dynamic>),
    ],
  );
}
