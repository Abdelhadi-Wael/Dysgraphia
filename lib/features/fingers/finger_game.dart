import 'dart:math' as math;

import 'hand_frame.dart';

/// Which finger comes next.
enum PinchPattern {
  inOrder('In order', 'pointer → little finger, again and again'),
  thereAndBack('There and back', 'pointer → little finger → pointer'),
  mixed('Mixed', 'any finger, never the same twice');

  const PinchPattern(this.label, this.description);

  final String label, description;
}

/// Time allowed for each target.
enum GameSpeed {
  slow('Slow', Duration(milliseconds: 4000)),
  medium('Medium', Duration(milliseconds: 2500)),
  fast('Fast', Duration(milliseconds: 1500));

  const GameSpeed(this.label, this.perTarget);

  final String label;
  final Duration perTarget;
}

class GameSettings {
  const GameSettings({
    this.pattern = PinchPattern.inOrder,
    this.speed = GameSpeed.slow,
    this.length = const Duration(seconds: 60),
  });

  final PinchPattern pattern;
  final GameSpeed speed;

  /// Playing time; it only runs while a hand is seen.
  final Duration length;

  static const lengths = [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 90),
  ];

  GameSettings copyWith({
    PinchPattern? pattern,
    GameSpeed? speed,
    Duration? length,
  }) => GameSettings(
    pattern: pattern ?? this.pattern,
    speed: speed ?? this.speed,
    length: length ?? this.length,
  );
}

/// What a pinch or the passing time did.
enum GameEvent { hit, wrong, missed, finished }

/// The rules of the finger game, without camera or screen: one target
/// finger at a time; pinching it scores, pinching another finger counts as
/// wrong (the target stays), and a target not caught in time is missed.
/// Time only runs while the hand is seen, so a child who drops their hand
/// does not lose targets.
class FingerGame {
  FingerGame(this.settings, {math.Random? random})
    : _random = random ?? math.Random() {
    _target = _first();
  }

  final GameSettings settings;
  final math.Random _random;

  late Finger _target;
  var _step = 0; // position in the in-order / there-and-back cycle
  Duration? _lastTick;
  var _played = Duration.zero;
  var _onTarget = Duration.zero;

  var hits = 0, wrongs = 0, misses = 0;
  final reactions = <Duration>[];

  Finger get target => _target;
  Duration get played => _played;
  bool get finished => _played >= settings.length;

  /// Time left for the current target, 0..1.
  double get targetTimeLeft =>
      1 - _onTarget.inMicroseconds / settings.speed.perTarget.inMicroseconds;

  /// Hits per target shown (wrong pinches count against it too), 0..1.
  double get accuracy {
    final tries = hits + wrongs + misses;
    return tries == 0 ? 0 : hits / tries;
  }

  Duration? get averageReaction => reactions.isEmpty
      ? null
      : reactions.reduce((a, b) => a + b) ~/ reactions.length;

  /// Advances the clock to [now]. Returns [GameEvent.missed] when the
  /// target ran out of time, [GameEvent.finished] when the game ends.
  GameEvent? tick(Duration now, {required bool handSeen}) {
    final last = _lastTick;
    _lastTick = now;
    if (finished || last == null || !handSeen) return null;
    final delta = now - last;
    _played += delta;
    _onTarget += delta;
    if (finished) return GameEvent.finished;
    if (_onTarget >= settings.speed.perTarget) {
      misses++;
      _next();
      return GameEvent.missed;
    }
    return null;
  }

  /// A pinch with [finger] was detected.
  GameEvent? pinch(Finger finger) {
    if (finished) return null;
    if (finger != _target) {
      wrongs++;
      return GameEvent.wrong;
    }
    hits++;
    reactions.add(_onTarget);
    _next();
    return GameEvent.hit;
  }

  Finger _first() => settings.pattern == PinchPattern.mixed
      ? Finger.values[_random.nextInt(Finger.values.length)]
      : Finger.pointer;

  void _next() {
    _onTarget = Duration.zero;
    _step++;
    const f = Finger.values;
    _target = switch (settings.pattern) {
      PinchPattern.inOrder => f[_step % f.length],
      // 0 1 2 3 2 1 | 0 1 2 3 2 1 ...
      PinchPattern.thereAndBack => () {
        final cycle = 2 * (f.length - 1);
        final i = _step % cycle;
        return f[i < f.length ? i : cycle - i];
      }(),
      PinchPattern.mixed => () {
        final others = [...f]..remove(_target);
        return others[_random.nextInt(others.length)];
      }(),
    };
  }
}
