import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_litert/flutter_litert.dart' show FrameThrottle;
import 'package:hand_detection/hand_detection.dart' hide HandLandmarks;
import 'package:material_ui/material_ui.dart';

import 'hand_frame.dart';

/// Why the camera cannot be used.
enum HandSourceProblem { unsupported, noCamera, denied, failed }

class HandSourceException implements Exception {
  const HandSourceException(this.problem, [this.detail]);
  final HandSourceProblem problem;
  final Object? detail;

  @override
  String toString() => 'HandSourceException($problem, $detail)';
}

/// Where hand frames come from: the camera, or a fake in tests.
abstract class HandSource {
  /// Frames with or without a hand, as fast as they are processed.
  Stream<HandFrame> get frames;

  /// Size of the image the landmarks are measured in (for drawing them),
  /// once known.
  ValueListenable<Size?> get imageSize;

  /// A live camera picture to show behind the game, if any.
  Widget? preview();

  /// Whether the picture is mirrored (front camera): landmarks are then
  /// drawn mirrored too.
  bool get mirrored;

  /// Starts the camera and tracking. Throws [HandSourceException].
  Future<void> start();

  Future<void> stop();
}

/// The front camera, with Google's MediaPipe hand models running on the
/// device (via `hand_detection`). Frames are only processed in memory:
/// nothing is recorded or saved.
class CameraHandSource implements HandSource {
  final _frames = StreamController<HandFrame>.broadcast();
  final _size = ValueNotifier<Size?>(null);
  final _throttle = FrameThrottle();
  final _clock = Stopwatch();
  CameraController? _camera;
  HandDetector? _detector;
  var _stopped = false;

  /// Phones and tablets only: the camera plugin has no live frames on
  /// desktop without extra packages.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<HandFrame> get frames => _frames.stream;

  @override
  ValueListenable<Size?> get imageSize => _size;

  @override
  bool get mirrored =>
      _camera?.description.lensDirection == CameraLensDirection.front;

  @override
  Widget? preview() {
    final c = _camera;
    return c == null || !c.value.isInitialized ? null : CameraPreview(c);
  }

  @override
  Future<void> start() async {
    if (!supported) {
      throw const HandSourceException(HandSourceProblem.unsupported);
    }
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw HandSourceException(HandSourceProblem.failed, e);
    }
    if (cameras.isEmpty) {
      throw const HandSourceException(HandSourceProblem.noCamera);
    }
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final camera = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      // Avoids a JPEG fallback on Android.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await camera.initialize();
    } on CameraException catch (e) {
      await camera.dispose();
      final denied = e.code.contains('Denied') || e.code.contains('denied');
      throw HandSourceException(
        denied ? HandSourceProblem.denied : HandSourceProblem.failed,
        e,
      );
    }
    _camera = camera;
    // Tracking follows the hand between frames instead of searching the
    // whole picture every time: steadier and faster.
    _detector = await HandDetector.create(
      enableTracking: true,
      maxDetections: 1,
    );
    _clock.start();
    await camera.startImageStream(_onImage);
  }

  void _onImage(CameraImage image) {
    _throttle.run(() async {
      final camera = _camera, detector = _detector;
      if (_stopped || camera == null || detector == null) return;
      try {
        final rotation = rotationForFrame(
          width: image.width,
          height: image.height,
          sensorOrientation: camera.description.sensorOrientation,
          isFrontCamera: mirrored,
          deviceOrientation: camera.value.deviceOrientation,
        );
        const maxDim = 640;
        _size.value = detectionSize(
          width: image.width,
          height: image.height,
          rotation: rotation,
          maxDim: maxDim,
        );
        final hands = await detector.detectFromCameraImage(
          image,
          rotation: rotation,
          maxDim: maxDim,
        );
        if (_stopped) return;
        _frames.add(_toFrame(hands));
      } catch (e) {
        // A bad frame should not end the game; the next one may work.
        debugPrint('Hand tracking frame failed: $e');
      }
    });
  }

  HandFrame _toFrame(List<Hand> hands) {
    final time = _clock.elapsed;
    final hand = hands.where((h) => h.hasLandmarks).firstOrNull;
    if (hand == null || hand.landmarks.length != HandLandmarks.count) {
      return HandFrame.empty(time);
    }
    // MediaPipe's order matches HandLandmarks' numbering.
    return HandFrame(time, [
      for (final l in hand.landmarks) (x: l.x.toDouble(), y: l.y.toDouble()),
    ]);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      await camera.dispose();
    }
    await _detector?.dispose();
    _detector = null;
    await _frames.close();
  }
}
