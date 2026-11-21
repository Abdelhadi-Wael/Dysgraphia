import 'package:dysgraphia_app/features/fingers/hand_frame.dart';

/// Fingertip positions of a made-up open hand. The wrist is at (0, 0) and
/// the base of the middle finger at (0, -1), so the hand size is 1 and
/// distances read directly in hand sizes. [scale] and [dx] place the hand
/// bigger or elsewhere in the image.
const _tips = {
  Finger.pointer: (x: -0.4, y: -1.8),
  Finger.middle: (x: 0.0, y: -2.0),
  Finger.ring: (x: 0.4, y: -1.8),
  Finger.pinky: (x: 0.8, y: -1.5),
};

/// A hand frame: open, or with the thumb tip [gap] hand sizes away from
/// the tip of [pinch].
HandFrame hand(
  int ms, {
  Finger? pinch,
  double gap = 0.05,
  double scale = 1,
  double dx = 0,
}) {
  HandPoint at(double x, double y) => (x: x * scale + dx, y: y * scale);
  final points = List<HandPoint>.filled(HandLandmarks.count, at(0, -0.5));
  points[HandLandmarks.wrist] = at(0, 0);
  points[HandLandmarks.middleBase] = at(0, -1);
  for (final MapEntry(key: f, value: t) in _tips.entries) {
    points[HandLandmarks.tipOf(f)] = at(t.x, t.y);
  }
  final thumb = pinch == null
      ? (x: -0.9, y: -0.7)
      : (x: _tips[pinch]!.x, y: _tips[pinch]!.y + gap);
  points[HandLandmarks.thumbTip] = at(thumb.x, thumb.y);
  return HandFrame(Duration(milliseconds: ms), points);
}

HandFrame noHand(int ms) => HandFrame.empty(Duration(milliseconds: ms));
