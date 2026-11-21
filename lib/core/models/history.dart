import '../utils/time.dart';
import 'stroke.dart';

enum PracticeKind { trace, copy, word }

/// One finished, scored letter (a completed trace or one checked copy box)
/// or one checked word (then [letter] is the word's id, e.g. "word-cat").
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

/// One finished round of the finger game (thumb to finger pinches).
class FingerGameRecord {
  FingerGameRecord({
    required this.pattern,
    required this.speed,
    required this.seconds,
    required this.hits,
    required this.wrong,
    required this.missed,
    this.reactionMs,
    DateTime? at,
  }) : at = utcMillis(at ?? DateTime.now());

  final DateTime at;

  /// Settings, by name (PinchPattern / GameSpeed), and length.
  final String pattern;
  final String speed;
  final int seconds;

  final int hits, wrong, missed;

  /// Average time from a target appearing to the right pinch.
  final int? reactionMs;

  /// The score shown to the child.
  int get score => hits;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'pattern': pattern,
    'speed': speed,
    'seconds': seconds,
    'hits': hits,
    'wrong': wrong,
    'missed': missed,
    'reactionMs': reactionMs,
  };

  factory FingerGameRecord.fromJson(Map<String, dynamic> j) => FingerGameRecord(
    at: DateTime.parse(j['at'] as String),
    pattern: j['pattern'] as String,
    speed: j['speed'] as String,
    seconds: (j['seconds'] as num).toInt(),
    hits: (j['hits'] as num).toInt(),
    wrong: (j['wrong'] as num).toInt(),
    missed: (j['missed'] as num).toInt(),
    reactionMs: (j['reactionMs'] as num?)?.toInt(),
  );
}

/// A finished challenge on the writing journey.
class ChallengeRecord {
  ChallengeRecord({required this.number, required this.stars, DateTime? at})
    : at = utcMillis(at ?? DateTime.now());

  final int number;

  /// Best copy stars for the challenge's new letter in that session.
  final int stars;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'number': number,
    'stars': stars,
    'at': at.toIso8601String(),
  };

  factory ChallengeRecord.fromJson(Map<String, dynamic> j) => ChallengeRecord(
    number: (j['number'] as num).toInt(),
    stars: (j['stars'] as num).toInt(),
    at: DateTime.parse(j['at'] as String),
  );
}

/// Everything one profile has done, oldest first.
class History {
  History({
    List<Attempt>? attempts,
    List<CheckRecord>? checks,
    List<ChallengeRecord>? challenges,
    List<FingerGameRecord>? games,
  }) : attempts = List.unmodifiable(attempts ?? const []),
       checks = List.unmodifiable(checks ?? const []),
       challenges = List.unmodifiable(challenges ?? const []),
       games = List.unmodifiable(games ?? const []);

  static final empty = History();

  final List<Attempt> attempts;
  final List<CheckRecord> checks;
  final List<ChallengeRecord> challenges;
  final List<FingerGameRecord> games;

  History _copy({
    List<Attempt>? attempts,
    List<CheckRecord>? checks,
    List<ChallengeRecord>? challenges,
    List<FingerGameRecord>? games,
  }) => History(
    attempts: attempts ?? this.attempts,
    checks: checks ?? this.checks,
    challenges: challenges ?? this.challenges,
    games: games ?? this.games,
  );

  History withAttempt(Attempt a) => _copy(attempts: [...attempts, a]);

  History withCheck(CheckRecord c) => _copy(checks: [...checks, c]);

  History withChallenge(ChallengeRecord c) =>
      _copy(challenges: [...challenges, c]);

  History withGame(FingerGameRecord g) => _copy(games: [...games, g]);

  Map<String, dynamic> toJson() => {
    'attempts': [for (final a in attempts) a.toJson()],
    'checks': [for (final c in checks) c.toJson()],
    'challenges': [for (final c in challenges) c.toJson()],
    'games': [for (final g in games) g.toJson()],
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
    challenges: [
      for (final c in (j['challenges'] as List? ?? const []))
        ChallengeRecord.fromJson(c as Map<String, dynamic>),
    ],
    games: [
      for (final g in (j['games'] as List? ?? const []))
        FingerGameRecord.fromJson(g as Map<String, dynamic>),
    ],
  );
}
