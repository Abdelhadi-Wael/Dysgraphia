import 'hand_frame.dart';

/// Something that happened between the thumb and a finger.
sealed class PinchEvent {
  const PinchEvent(this.time);
  final Duration time;
}

/// The thumb now touches [finger].
class PinchStart extends PinchEvent {
  const PinchStart(super.time, this.finger);
  final Finger finger;

  @override
  String toString() => 'PinchStart(${finger.name})';
}

/// The thumb let go.
class PinchEnd extends PinchEvent {
  const PinchEnd(super.time);

  @override
  String toString() => 'PinchEnd';
}

/// Turns hand frames into pinch events.
///
/// Distances are divided by the hand's size (wrist to the base of the
/// middle finger), so a hand near or far from the camera behaves the same.
/// A pinch starts when the closest fingertip comes within [closeAt] of the
/// thumb tip for [holdFrames] frames in a row, and ends when it moves past
/// [openAt]: the gap between the two stops the result from flickering when
/// the fingers hover at the edge.
class PinchDetector {
  PinchDetector({this.closeAt = 0.25, this.openAt = 0.35, this.holdFrames = 2})
    : assert(closeAt < openAt);

  final double closeAt, openAt;
  final int holdFrames;

  Finger? _pinched;
  Finger? _candidate;
  var _candidateFrames = 0;

  /// The finger touching the thumb now, if any.
  Finger? get pinched => _pinched;

  /// Distance from the thumb tip to each fingertip, in hand sizes.
  static Map<Finger, double> gaps(List<HandPoint> p) {
    final size = handDistance(
      p[HandLandmarks.wrist],
      p[HandLandmarks.middleBase],
    );
    final thumb = p[HandLandmarks.thumbTip];
    return {
      for (final f in Finger.values)
        f:
            handDistance(thumb, p[HandLandmarks.tipOf(f)]) /
            (size < 1e-9 ? 1e-9 : size),
    };
  }

  /// Feeds one frame; returns what changed (usually nothing).
  List<PinchEvent> add(HandFrame frame) {
    final points = frame.points;
    if (points == null) {
      // Hand lost: whatever was pinched is let go.
      _candidate = null;
      _candidateFrames = 0;
      return _release(frame.time);
    }
    final g = gaps(points);
    final closest = Finger.values.reduce((a, b) => g[a]! <= g[b]! ? a : b);

    final current = _pinched;
    if (current != null) {
      // Still pinching while this finger stays close and no other finger
      // has clearly taken over.
      if (g[current]! <= openAt &&
          (closest == current || g[closest]! > closeAt)) {
        return const [];
      }
      final events = _release(frame.time);
      return [...events, ..._consider(closest, g[closest]!, frame.time)];
    }
    return _consider(closest, g[closest]!, frame.time);
  }

  List<PinchEvent> _consider(Finger closest, double gap, Duration time) {
    if (gap > closeAt) {
      _candidate = null;
      _candidateFrames = 0;
      return const [];
    }
    if (_candidate == closest) {
      _candidateFrames++;
    } else {
      _candidate = closest;
      _candidateFrames = 1;
    }
    if (_candidateFrames < holdFrames) return const [];
    _pinched = closest;
    _candidate = null;
    _candidateFrames = 0;
    return [PinchStart(time, closest)];
  }

  List<PinchEvent> _release(Duration time) {
    if (_pinched == null) return const [];
    _pinched = null;
    return [PinchEnd(time)];
  }

  void reset() {
    _pinched = null;
    _candidate = null;
    _candidateFrames = 0;
  }
}
