import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/history.dart';
import '../../core/models/profile.dart';
import '../../core/state/app_data.dart';
import '../assessment/assessment_page.dart';
import '../dev/dev_tools_page.dart';
import '../profiles/profile_avatar.dart';
import '../profiles/profile_form_page.dart';
import '../progress/progress_page.dart';

/// The "Me" tab: who is practising, the writing check, and settings.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).requireValue;
    final p = data.current;
    if (p == null) return const SizedBox.shrink(); // switching away
    final h = data.history;
    void push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        children: [
          ListTile(
            leading: ProfileAvatar(avatar: p.avatar),
            title: Text(p.name),
            subtitle: Text(
              '${p.mode == ProfileMode.kid ? 'Child' : 'Adult'} · '
              '${p.hand == Hand.left ? 'Left' : 'Right'}-handed'
              '${p.researchCode != null ? ' · Code ${p.researchCode}' : ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit profile'),
            onTap: () => push(ProfileFormPage(profile: p)),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Writing check'),
            subtitle: Text(
              h.checks.isEmpty
                  ? 'About 5 minutes, not done yet'
                  : 'Last done ${formatWhen(h.checks.last.at)}',
            ),
            onTap: () => push(
              AssessmentPage(
                participant: p.researchCode,
                onSaved: (result, file) => ref
                    .read(appDataProvider.notifier)
                    .addCheck(
                      CheckRecord(
                        tasks: result.tasks.length,
                        skipped: result.tasks.where((t) => t.skipped).length,
                        file: file?.path,
                      ),
                    ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Switch person'),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              ref.read(appDataProvider.notifier).select(null);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Add someone'),
            onTap: () => push(const ProfileFormPage()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: const Text('Developer tools'),
            subtitle: const Text('Canvas test, letter gallery, exports'),
            onTap: () => push(const DevToolsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Handwriting Helper',
              applicationVersion: '0.1.0',
              children: const [
                Text(
                  'Handwriting practice for children and adults, including '
                  'those with dysgraphia. A graduation project.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
