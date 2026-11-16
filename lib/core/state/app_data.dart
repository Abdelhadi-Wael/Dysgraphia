import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history.dart';
import '../models/profile.dart';
import '../storage/progress_store.dart';

/// Where data is saved. Tests override this with a temporary folder.
final progressStoreProvider = Provider<ProgressStore>((ref) => ProgressStore());

/// The profiles on this device, who is practising now, and their history.
class AppData {
  const AppData({required this.profiles, this.current, required this.history});

  final List<Profile> profiles;

  /// Null while nobody is chosen (the profile picker is shown).
  final Profile? current;

  /// History of [current]; empty when nobody is chosen.
  final History history;
}

/// Loads and changes [AppData]. Every change is saved before the state
/// updates, so what the screen shows is what is on disk.
class AppDataNotifier extends AsyncNotifier<AppData> {
  ProgressStore get _store => ref.read(progressStoreProvider);
  AppData get _data => state.requireValue;

  @override
  Future<AppData> build() async {
    final profiles = await _store.loadProfiles();
    // One profile: go straight in. Several: let them pick.
    final current = profiles.length == 1 ? profiles.single : null;
    return AppData(
      profiles: profiles,
      current: current,
      history: current == null
          ? History.empty
          : await _store.loadHistory(current.id),
    );
  }

  /// Switches to the profile with [id], or back to the picker with null.
  Future<void> select(String? id) async {
    final profile = id == null
        ? null
        : _data.profiles.firstWhere((p) => p.id == id);
    final history = profile == null
        ? History.empty
        : await _store.loadHistory(profile.id);
    state = AsyncData(
      AppData(profiles: _data.profiles, current: profile, history: history),
    );
  }

  /// Adds a profile and switches to it.
  Future<void> addProfile(Profile p) async {
    final profiles = [..._data.profiles, p];
    await _store.saveProfiles(profiles);
    state = AsyncData(
      AppData(profiles: profiles, current: p, history: History.empty),
    );
  }

  Future<void> updateProfile(Profile p) async {
    final profiles = [
      for (final old in _data.profiles) old.id == p.id ? p : old,
    ];
    await _store.saveProfiles(profiles);
    state = AsyncData(
      AppData(
        profiles: profiles,
        current: _data.current?.id == p.id ? p : _data.current,
        history: _data.history,
      ),
    );
  }

  /// Deletes a profile and everything it did on this device.
  Future<void> deleteProfile(String id) async {
    final profiles = [..._data.profiles.where((p) => p.id != id)];
    await _store.saveProfiles(profiles);
    await _store.deleteHistory(id);
    final wasCurrent = _data.current?.id == id;
    state = AsyncData(
      AppData(
        profiles: profiles,
        current: wasCurrent ? null : _data.current,
        history: wasCurrent ? History.empty : _data.history,
      ),
    );
  }

  Future<void> addAttempt(Attempt a) =>
      _saveHistory(_data.history.withAttempt(a));

  Future<void> addCheck(CheckRecord c) =>
      _saveHistory(_data.history.withCheck(c));

  Future<void> _saveHistory(History h) async {
    final current = _data.current;
    if (current == null) return; // nobody to save for
    await _store.saveHistory(current.id, h);
    state = AsyncData(
      AppData(profiles: _data.profiles, current: current, history: h),
    );
  }
}

final appDataProvider = AsyncNotifierProvider<AppDataNotifier, AppData>(
  AppDataNotifier.new,
);
