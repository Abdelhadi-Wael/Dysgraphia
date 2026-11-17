import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/state/app_data.dart';
import '../profiles/profile_form_page.dart';
import '../profiles/profile_picker_page.dart';
import 'main_shell.dart';

/// Decides the first screen: welcome (no profiles yet), "Who's practising?"
/// (several profiles, none chosen) or the home screen.
class StartGate extends ConsumerWidget {
  const StartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(appDataProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Couldn't load your saved data."),
                  const SizedBox(height: 8),
                  Text('$e', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(appDataProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (d) => d.profiles.isEmpty
              ? const ProfileFormPage(firstRun: true)
              : d.current == null
              ? ProfilePickerPage(profiles: d.profiles)
              : const MainShell(),
        );
  }
}
