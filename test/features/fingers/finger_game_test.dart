import 'dart:math' as math;

import 'package:dysgraphia_app/features/fingers/finger_game.dart';
import 'package:dysgraphia_app/features/fingers/hand_frame.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

/// The first [n] targets when every target is caught at once.
List<Finger> sequence(PinchPattern p, int n, {int seed = 1}) {
  final g = FingerGame(GameSettings(pattern: p), random: math.Random(seed));
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = g.target;
        g.pinch(t);
        return t;
      }(),
  ];
}

void main() {
  const p = Finger.pointer,
      m = Finger.middle,
      r = Finger.ring,
      l = Finger.pinky;

  test('in order goes round the fingers', () {
    expect(sequence(PinchPattern.inOrder, 9), [p, m, r, l, p, m, r, l, p]);
  });

  test('there and back turns at the little finger and the pointer', () {
    expect(sequence(PinchPattern.thereAndBack, 10), [
      p,
      m,
      r,
      l,
      r,
      m,
      p,
      m,
      r,
      l,
    ]);
  });

  test('mixed never repeats a finger and uses them all', () {
    final s = sequence(PinchPattern.mixed, 60, seed: 7);
    for (var i = 1; i < s.length; i++) {
      expect(s[i], isNot(s[i - 1]));
    }
    expect(s.toSet(), Finger.values.toSet());
  });

  test('hits, wrong fingers and reaction time', () {
    final g = FingerGame(const GameSettings());
    g.tick(ms(0), handSeen: true);
    g.tick(ms(800), handSeen: true);
    expect(g.pinch(Finger.ring), GameEvent.wrong);
    expect(g.target, Finger.pointer, reason: 'a wrong finger keeps the target');
    expect(g.pinch(Finger.pointer), GameEvent.hit);
    expect(g.target, Finger.middle);
    expect((g.hits, g.wrongs, g.misses), (1, 1, 0));
    expect(g.averageReaction, ms(800));
    expect(g.accuracy, 0.5);
  });

  test('a target not caught in time is missed', () {
    final g = FingerGame(const GameSettings(speed: GameSpeed.fast));
    g.tick(ms(0), handSeen: true);
    expect(g.tick(ms(1400), handSeen: true), isNull);
    expect(g.targetTimeLeft, closeTo(1 / 15, 1e-9));
    expect(g.tick(ms(1500), handSeen: true), GameEvent.missed);
    expect(g.misses, 1);
    expect(g.target, Finger.middle);
    expect(g.targetTimeLeft, 1);
  });

  test('time stops while no hand is seen', () {
    final g = FingerGame(const GameSettings(length: Duration(seconds: 30)));
    g.tick(ms(0), handSeen: true);
    g.tick(ms(1000), handSeen: true);
    g.tick(ms(20000), handSeen: false); // hand away for 19 s
    expect(g.played, ms(1000));
    expect(g.misses, 0);
    g.tick(ms(20500), handSeen: true);
    expect(g.played, ms(1500));
  });

  test('the game ends after its length; later pinches do nothing', () {
    final g = FingerGame(const GameSettings(length: Duration(seconds: 30)));
    var t = 0;
    g.tick(ms(t), handSeen: true);
    GameEvent? last;
    while (!g.finished) {
      t += 100;
      last = g.tick(ms(t), handSeen: true) ?? last;
    }
    expect(last, GameEvent.finished);
    expect(g.played, ms(30000));
    expect(g.pinch(g.target), isNull);
    expect(g.tick(ms(t + 100), handSeen: true), isNull);
  });
}
