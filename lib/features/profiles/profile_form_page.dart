import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/profile.dart';
import '../../core/state/app_data.dart';
import 'profile_avatar.dart';

/// Create or edit a profile. On first launch it is the welcome screen.
class ProfileFormPage extends ConsumerStatefulWidget {
  const ProfileFormPage({super.key, this.profile, this.firstRun = false});

  /// The profile to edit; null creates a new one.
  final Profile? profile;
  final bool firstRun;

  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _code = TextEditingController(text: widget.profile?.researchCode);
  late var _avatar = widget.profile?.avatar ?? 0;
  late var _mode = widget.profile?.mode ?? ProfileMode.kid;
  late var _hand = widget.profile?.hand ?? Hand.right;
  late var _readAloud = widget.profile?.readAloud ?? true;
  late var _sounds = widget.profile?.sounds ?? true;
  String? _nameError;
  var _saving = false;

  bool get _editing => widget.profile != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    final code = _code.text.trim();
    setState(() => _saving = true);
    final data = ref.read(appDataProvider.notifier);
    final navigator = Navigator.of(context);
    if (_editing) {
      await data.updateProfile(
        widget.profile!.copyWith(
          name: name,
          avatar: _avatar,
          mode: _mode,
          hand: _hand,
          researchCode: () => code.isEmpty ? null : code,
          readAloud: _readAloud,
          sounds: _sounds,
        ),
      );
    } else {
      await data.addProfile(
        Profile.create(
          name: name,
          avatar: _avatar,
          mode: _mode,
          hand: _hand,
          researchCode: code.isEmpty ? null : code,
          readAloud: _readAloud,
          sounds: _sounds,
        ),
      );
    }
    // On first run this page is the start screen itself and the app moves
    // on by itself; otherwise go back to where we came from.
    if (!widget.firstRun && navigator.canPop()) navigator.pop();
  }

  Future<void> _delete() async {
    final p = widget.profile!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text(
          'This removes the profile and all of its practice history from '
          'this device. Exported files are kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(appDataProvider.notifier).deleteProfile(p.id);
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.firstRun
          ? null
          : AppBar(title: Text(_editing ? 'Edit profile' : 'Add someone')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.firstRun) ...[
                Text(
                  'Welcome to Handwriting Helper',
                  style: text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Let's set up who is going to practise.",
                  style: text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],
              TextField(
                key: const Key('profile-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name or nickname',
                  border: const OutlineInputBorder(),
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 24),
              Text('Picture', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < profileAvatars.length; i++)
                    InkWell(
                      key: Key('avatar-$i'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _avatar = i),
                      child: ProfileAvatar(
                        avatar: i,
                        size: 46,
                        selected: i == _avatar,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Who is it for?', style: text.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ProfileMode>(
                segments: const [
                  ButtonSegment(
                    value: ProfileMode.kid,
                    icon: Icon(Icons.child_care),
                    label: Text('Child'),
                  ),
                  ButtonSegment(
                    value: ProfileMode.adult,
                    icon: Icon(Icons.person),
                    label: Text('Adult'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.single;
                  // New profiles: children usually need instructions read
                  // aloud, adults usually don't. Editing keeps the choice.
                  if (!_editing) _readAloud = _mode == ProfileMode.kid;
                }),
              ),
              const SizedBox(height: 24),
              Text('Writing hand', style: text.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<Hand>(
                segments: const [
                  ButtonSegment(value: Hand.left, label: Text('Left')),
                  ButtonSegment(value: Hand.right, label: Text('Right')),
                ],
                selected: {_hand},
                onSelectionChanged: (s) => setState(() => _hand = s.single),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const Key('profile-read-aloud'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Read instructions aloud'),
                value: _readAloud,
                onChanged: (v) => setState(() => _readAloud = v),
              ),
              SwitchListTile(
                key: const Key('profile-sounds'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('Sounds'),
                value: _sounds,
                onChanged: (v) => setState(() => _sounds = v),
              ),
              const SizedBox(height: 8),
              // Most people never need this, so it starts folded away
              // (open when editing a profile that already has a code).
              ExpansionTile(
                key: const Key('research-section'),
                tilePadding: EdgeInsets.zero,
                title: const Text('For research (optional)'),
                initiallyExpanded: _code.text.isNotEmpty,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    key: const Key('profile-code'),
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'Research code',
                      helperText:
                          'A code like P01, used instead of the name in '
                          'exported files',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _editing
                      ? 'Save changes'
                      : (widget.firstRun ? "Let's start" : 'Add'),
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete profile'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
