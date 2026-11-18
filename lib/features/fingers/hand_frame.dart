/// One camera frame's view of the hand, independent of the tracking
/// library, so the game logic can be tested without a camera.
library;

import 'dart:math' as math;

/// A point in image coordinates (any unit; only ratios are used).
typedef HandPoint = ({double x, double y});

double handDistance(HandPoint a, HandPoint b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// The four fingers that pinch against the thumb, with their colours in the
/// game (as ARGB values, so this file needs no Flutter).
enum Finger {
  pointer('pointer finger', 0xFFE53935),
  middle('middle finger', 0xFFFDD835),
  ring('ring finger', 0xFF43A047),
  pinky('little finger', 0xFF1E88E5);

  const Finger(this.spoken, this.argb);

  /// How the finger is called out loud to a child.
  final String spoken;
  final int argb;
}

/// The hand points the game uses, in MediaPipe's 21-landmark numbering:
/// 0 wrist, 4 thumb tip, 8 / 12 / 16 / 20 the other fingertips, 9 the base
/// of the middle finger.
abstract final class HandLandmarks {
  static const wrist = 0;
  static const thumbTip = 4;
  static const middleBase = 9;
  static const count = 21;

  static int tipOf(Finger f) => switch (f) {
    Finger.pointer => 8,
    Finger.middle => 12,
    Finger.ring => 16,
    Finger.pinky => 20,
  };
}

class HandFrame {
  const HandFrame(this.time, this.points)
    : assert(points == null || points.length == HandLandmarks.count);

  /// No hand seen in this frame.
  const HandFrame.empty(this.time) : points = null;

  /// When the frame was taken (from the start of the game).
  final Duration time;

  /// The 21 landmarks, or null when no hand is seen.
  final List<HandPoint>? points;

  bool get hasHand => points != null;
}
