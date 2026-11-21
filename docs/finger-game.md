# Finger taps (finger warm-up game)

A fine-motor warm-up before writing. The child touches the thumb to the finger
the game shows, while the front camera follows the hand. The exercise is
thumb-to-finger opposition, a standard occupational-therapy drill for finger
isolation and sequencing, skills that handwriting relies on.

Code: `lib/features/fingers/`. Opened from Practise → Warm-up → Finger taps.

## Privacy

- Camera frames are processed **in memory, on the device**, and dropped
  straight away. No picture or video is recorded, saved or sent anywhere.
- Only the round's numbers are saved in the profile's history (see below).
- The camera is on only while a round is played and is switched off at the
  end, or when the screen is left.
- The permission texts say so: `AndroidManifest.xml` and `ios/Runner/Info.plist`.

## How the hand is followed

`hand_detection` (Apache-2.0) runs Google's MediaPipe hand models with LiteRT
(TensorFlow Lite) on the device:

1. A palm detector finds the hand.
2. A landmark model places 21 points on it (wrist, finger joints and tips).
3. Tracking follows the hand from frame to frame, so the palm search does not
   run every time.

Frames are scaled down to 640 px. A frame that arrives while one is still being
processed is dropped (`FrameThrottle`), so the game stays current instead of
falling behind.

## When is it a pinch? (`pinch_detector.dart`)

1. **Hand size** is the distance from the wrist to the base of the middle
   finger (landmarks 0 and 9). Dividing by it makes a hand near the camera and
   one far away behave the same.
2. **Gap per finger** is the distance from the thumb tip (4) to each fingertip
   (8, 12, 16, 20), in hand sizes.
3. **A pinch starts** when the closest fingertip is within **0.25** for **2
   frames in a row**. A single stray frame is ignored.
4. **A pinch ends** when that gap grows past **0.35**. The gap between 0.25 and
   0.35 stops a finger hovering at the edge from flickering on and off.
5. Losing the hand ends any pinch.

These values were chosen on synthetic hands (`test/features/fingers/`). Tune
them with real hands on the device.

## The game (`finger_game.dart`)

**Settings** (chosen by a therapist or parent):

| Setting | Choices |
|---|---|
| Pattern | in order (pointer → little finger, repeated); there and back (pointer → little → pointer); mixed (random, never the same finger twice) |
| Speed (time per target) | slow 4 s, medium 2.5 s, fast 1.5 s |
| Length | 30, 60 or 90 s |

**Rules:**
- One target finger at a time, shown in its colour: pointer red, middle
  yellow, ring green, little finger blue. Its name is read out in Kid mode.
- **Hit:** the right finger. One star, and the next target comes up.
- **Wrong finger:** no star. The target shakes and stays.
- **Missed:** time ran out on the target. The next one comes up.
- **No hand seen:** "Show your hand" appears and the clock stops, so the child
  loses nothing.

## What is saved (`FingerGameRecord` in `history.dart`)

For each round: the time, pattern, speed and length; hits, wrong fingers and
missed targets; and the average reaction time (from a target appearing to the
right pinch).

Where it is used:
- **"New best"** compares only rounds with the same settings.
- The Progress tab shows the best score.
- Rounds count towards the days-in-a-row streak.

The **accuracy** shown at the end is hits divided by (hits + wrong + missed).

## Platforms

| Platform | Status |
|---|---|
| Android | Built and tested here |
| iOS | Supported by the plugins. Needs a Mac to build. Deployment target 15.0, also set for OpenCV in `pubspec.yaml` under `hooks` |
| Linux / desktop | The game says it needs a phone or tablet. The rest of the app works |

## Building on this machine

The plugin pulls in OpenCV (`dartcv4`), whose build step looks for `cmake`.
On a computer where `cmake` is the snap package, that lookup fails: "`snapd
--version` returned unexpected exit code". The fix is to make sure a normal
`cmake` (for example `/usr/bin/cmake` from apt) comes first in `PATH` when
running `flutter`.
