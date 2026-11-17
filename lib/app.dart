import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/audio/app_audio.dart';
import 'core/state/app_data.dart';
import 'features/home/start_gate.dart';

/// The device's speech and sound effects, shared by the whole app.
final appAudioProvider = Provider<DeviceAudio>((ref) {
  final audio = DeviceAudio();
  ref.onDispose(audio.stop);
  return audio;
});

class DysgraphiaApp extends StatelessWidget {
  const DysgraphiaApp({super.key});

  /// Friendly and easy to read on a tablet: light by default, a soft teal
  /// palette, round cards and big buttons.
  static ThemeData theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF14A38B),
      brightness: b,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handwriting Helper',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      // Light even when the device is in dark mode: easier to read, and
      // closer to paper. The dark theme stays available for later.
      themeMode: ThemeMode.light,
      builder: (context, child) => _AudioBinder(child: child!),
      home: const StartGate(),
    );
  }
}

/// Applies the current profile's audio settings and offers the audio to
/// every screen through [AppAudioScope].
class _AudioBinder extends ConsumerWidget {
  const _AudioBinder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(appAudioProvider);
    final profile = ref.watch(appDataProvider).value?.current;
    audio
      ..speech = profile?.readAloud ?? false
      ..sounds = profile?.sounds ?? false;
    return AppAudioScope(audio: audio, child: child);
  }
}
