import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/models/drawing_export.dart';

/// Saves drawings as JSON files in a `dysgraphia_exports` folder:
/// * Linux / desktop: ~/Documents/dysgraphia_exports
/// * Android: Android/data/com.dysgraphia.dysgraphia_app/files/dysgraphia_exports
///   (reachable over USB or `adb pull`, no storage permission needed)
/// * iOS: the app's Documents folder
class DrawingExporter {
  DrawingExporter({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? _defaultBaseDirectory;

  final Future<Directory> Function() _baseDirectory;

  static const folderName = 'dysgraphia_exports';

  /// Writes [export] and returns the new file. File names look like
  /// `o_2026-11-17T10-22-31.123Z.json` (target, then UTC time).
  Future<File> save(DrawingExport export) async {
    final dir = Directory('${(await _baseDirectory()).path}/$folderName');
    await dir.create(recursive: true);
    final stamp = export.createdAt.toIso8601String().replaceAll(':', '-');
    final file = File(
      '${dir.path}/${_safe(export.target ?? 'free')}_$stamp.json',
    );
    await file.writeAsString(jsonEncode(export.toJson()));
    return file;
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static Future<Directory> _defaultBaseDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    }
    return getApplicationDocumentsDirectory();
  }
}
