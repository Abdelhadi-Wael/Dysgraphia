import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

/// Short sound effects (assets/sounds, made by tool/make_sounds.py).
enum Sfx {
  /// Stars earned.
  star,

  /// A letter or challenge finished.
  success,

  /// A stroke rejected: gentle, never harsh.
  oops,
}

/// What screens use to talk and play sounds. Screens never deal with
/// devices or settings; they just ask, and the app decides.
abstract class AppAudio {
  /// Reads [text] aloud, replacing anything still being said.
  Future<void> say(String text);
  Future<void> play(Sfx sfx);
  Future<void> stop();
}

/// Does nothing: in tests, and where speech or sound is switched off.
class SilentAudio implements AppAudio {
  const SilentAudio();

  @override
  Future<void> say(String text) async {}
  @override
  Future<void> play(Sfx sfx) async {}
  @override
  Future<void> stop() async {}
}

/// Real speech (text-to-speech) and sound effects on the device, honouring
/// the current profile's settings. Speech exists on Android, iOS, macOS,
/// Windows and web; sound effects on Android, iOS, macOS and web. Elsewhere
/// (e.g. the Linux test build) calls quietly do nothing.
class DeviceAudio implements AppAudio {
  DeviceAudio();

  /// Read instructions and tips aloud.
  bool speech = false;

  /// Play sound effects.
  bool sounds = false;

  static bool get _hasSpeech =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows);

  static bool get _hasSounds =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  FlutterTts? _tts;
  final _players = <Sfx, AudioPlayer>{};

  Future<FlutterTts> _speaker() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    await tts.setLanguage('en-US');
    // A little slower than normal: clearer for children.
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.05);
    return _tts = tts;
  }

  @override
  Future<void> say(String text) async {
    if (!speech || !_hasSpeech) return;
    try {
      final tts = await _speaker();
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('Speech unavailable: $e');
    }
  }

  @override
  Future<void> play(Sfx sfx) async {
    if (!sounds || !_hasSounds) return;
    try {
      final player = _players[sfx] ??= AudioPlayer();
      await player.setAsset('assets/sounds/${sfx.name}.wav');
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('Sound unavailable: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
      for (final p in _players.values) {
        await p.stop();
      }
    } catch (_) {}
  }
}

/// Makes an [AppAudio] available to every screen below it.
class AppAudioScope extends InheritedWidget {
  const AppAudioScope({super.key, required this.audio, required super.child});

  final AppAudio audio;

  /// The audio for [context]; silent if no scope is above it (tests).
  static AppAudio of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppAudioScope>()?.audio ??
      const SilentAudio();

  @override
  bool updateShouldNotify(AppAudioScope old) => old.audio != audio;
}
