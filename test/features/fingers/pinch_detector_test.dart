import 'package:dysgraphia_app/features/fingers/hand_frame.dart';
import 'package:dysgraphia_app/features/fingers/pinch_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_hands.dart';

/// Feeds [frames] and lists the events as text.
List<String> run(PinchDetector d, List<HandFrame> frames) => [
  for (final f in frames)
    for (final e in d.add(f)) e.toString(),
];

void main() {
  test('an open hand pinches nothing', () {
    final d = PinchDetector();
    expect(run(d, [for (var i = 0; i < 5; i++) hand(i * 33)]), isEmpty);
    expect(d.pinched, isNull);
  });

  test('each finger is recognised, after two frames', () {
    for (final f in Finger.values) {
      final d = PinchDetector();
      expect(
        d.add(hand(0, pinch: f)),
        isEmpty,
        reason: 'one frame is not enough',
      );
      final e = d.add(hand(33, pinch: f));
      expect(e.single, isA<PinchStart>().having((s) => s.finger, 'finger', f));
      expect(d.pinched, f);
      expect(run(d, [hand(66, pinch: f)]), isEmpty, reason: 'held, no repeat');
      expect(run(d, [hand(99)]), ['PinchEnd']);
    }
  });

  test('size and place in the image do not matter', () {
    final d = PinchDetector();
    final frames = [
      hand(0, pinch: Finger.ring, scale: 120, dx: 300),
      hand(33, pinch: Finger.ring, scale: 120, dx: 300),
    ];
    expect(run(d, frames), ['PinchStart(ring)']);
  });

  test('hovering at the edge does not flicker', () {
    final d = PinchDetector();
    // In at 0.2, then wobbling between 0.27 and 0.33: still one pinch.
    final frames = [
      hand(0, pinch: Finger.middle, gap: 0.2),
      hand(33, pinch: Finger.middle, gap: 0.2),
      for (var i = 0; i < 6; i++)
        hand(66 + i * 33, pinch: Finger.middle, gap: i.isEven ? 0.27 : 0.33),
      hand(300, pinch: Finger.middle, gap: 0.5),
    ];
    expect(run(d, frames), ['PinchStart(middle)', 'PinchEnd']);
  });

  test('almost touching is not a pinch', () {
    final d = PinchDetector();
    final frames = [
      for (var i = 0; i < 4; i++) hand(i * 33, pinch: Finger.pointer, gap: 0.3),
    ];
    expect(run(d, frames), isEmpty);
  });

  test('a single stray frame is ignored', () {
    final d = PinchDetector();
    final frames = [hand(0), hand(33, pinch: Finger.pinky), hand(66), hand(99)];
    expect(run(d, frames), isEmpty);
  });

  test('sliding from one finger to the next', () {
    final d = PinchDetector();
    final frames = [
      hand(0, pinch: Finger.pointer),
      hand(33, pinch: Finger.pointer),
      hand(66, pinch: Finger.middle),
      hand(99, pinch: Finger.middle),
    ];
    expect(run(d, frames), [
      'PinchStart(pointer)',
      'PinchEnd',
      'PinchStart(middle)',
    ]);
  });

  test('losing the hand lets go', () {
    final d = PinchDetector();
    final frames = [
      hand(0, pinch: Finger.ring),
      hand(33, pinch: Finger.ring),
      noHand(66),
    ];
    expect(run(d, frames), ['PinchStart(ring)', 'PinchEnd']);
    expect(d.pinched, isNull);
  });

  test('gaps are measured in hand sizes', () {
    final g = PinchDetector.gaps(
      hand(0, pinch: Finger.pointer, gap: 0.1, scale: 50).points!,
    );
    expect(g[Finger.pointer], closeTo(0.1, 1e-9));
    expect(g[Finger.pinky]!, greaterThan(1));
  });
}
