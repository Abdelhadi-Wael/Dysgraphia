import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/history.dart';
import '../models/profile.dart';

/// Saves profiles and their history as JSON files on the device, in the
/// app support folder: `dysgraphia/profiles.json`,
/// `dysgraphia/history_PROFILEID.json` and `dysgraphia/dev.json` (developer
/// options, for the whole device).
/// Plain files keep it simple, offline and easy to inspect; a backend can
/// sync the same JSON later.
class ProgressStore {
  ProgressStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? _defaultBase;

  final Future<Directory> Function() _baseDirectory;

  static const formatVersion = 1;

  static Future<Directory> _defaultBase() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/dysgraphia');

  Future<File> _file(String name) async {
    final dir = await _baseDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  Future<List<Profile>> loadProfiles() async {
    final j = await _read('profiles.json');
    return [
      for (final p in (j?['profiles'] as List? ?? const []))
        Profile.fromJson(p as Map<String, dynamic>),
    ];
  }

  Future<void> saveProfiles(List<Profile> profiles) => _write('profiles.json', {
    'version': formatVersion,
    'profiles': [for (final p in profiles) p.toJson()],
  });

  Future<DevOptions> loadDevOptions() async =>
      DevOptions.fromJson(await _read('dev.json') ?? const {});

  Future<void> saveDevOptions(DevOptions o) => _write('dev.json', o.toJson());

  Future<History> loadHistory(String profileId) async {
    final j = await _read('history_$profileId.json');
    return j == null ? History.empty : History.fromJson(j);
  }

  Future<void> saveHistory(String profileId, History h) => _write(
    'history_$profileId.json',
    {'version': formatVersion, ...h.toJson()},
  );

  Future<void> deleteHistory(String profileId) async {
    final f = await _file('history_$profileId.json');
    if (await f.exists()) await f.delete();
  }

  Future<Map<String, dynamic>?> _read(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return null;
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  }

  /// Writes to a temporary file first, then renames it over the old one, so
  /// a crash mid-write never leaves a half-written file.
  Future<void> _write(String name, Map<String, dynamic> json) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }
}

/// Developer options: shortcuts for testing and demos, for every profile on
/// the device.
class DevOptions {
  const DevOptions({this.unlockAll = false});

  /// Every journey challenge can be opened, finished or not.
  final bool unlockAll;

  Map<String, dynamic> toJson() => {'unlockAll': unlockAll};

  factory DevOptions.fromJson(Map<String, dynamic> j) =>
      DevOptions(unlockAll: j['unlockAll'] as bool? ?? false);
}
