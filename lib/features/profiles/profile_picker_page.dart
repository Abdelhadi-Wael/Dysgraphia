import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/profile.dart';
import '../../core/state/app_data.dart';
import 'profile_avatar.dart';
import 'profile_form_page.dart';

/// "Who's practising?" Shown when there is more than one profile.
class ProfilePickerPage extends ConsumerWidget {
  const ProfilePickerPage({super.key, required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text("Who's practising?", style: text.headlineMedium),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in profiles)
                    _Tile(
                      key: Key('pick-${p.id}'),
                      onTap: () =>
                          ref.read(appDataProvider.notifier).select(p.id),
                      child: Column(
                        children: [
                          ProfileAvatar(avatar: p.avatar, size: 72),
                          const SizedBox(height: 12),
                          Text(p.name, style: text.titleMedium),
                          Text(
                            p.mode == ProfileMode.kid ? 'Child' : 'Adult',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  _Tile(
                    key: const Key('add-profile'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileFormPage(),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(Icons.add, size: 36),
                        ),
                        const SizedBox(height: 12),
                        Text('Add someone', style: text.titleMedium),
                        Text('', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    ),
  );
}
