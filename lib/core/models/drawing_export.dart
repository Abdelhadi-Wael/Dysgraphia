import '../utils/time.dart';
import 'stroke.dart';

/// The envelope a drawing travels in when it leaves the app: exported
/// files today, API requests to a scoring service later.
/// Specified in docs/stroke-format.md; bump [version] on breaking changes.
class DrawingExport {
  /// [createdAt] is stored in UTC with millisecond precision, so it always
  /// serialises like `2026-11-17T10:22:31.123Z`.
  DrawingExport({required this.drawing, this.target, DateTime? createdAt})
    : createdAt = utcMillis(createdAt ?? DateTime.now());

  static const format = 'dysgraphia-drawing';
  static const version = 1;

  final Drawing drawing;

  /// What the user was asked to write (e.g. "o", "cat"), or null for free
  /// writing.
  final String? target;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'target': target,
    'drawing': drawing.toJson(),
  };

  factory DrawingExport.fromJson(Map<String, dynamic> j) {
    if (j['format'] != format) {
      throw FormatException('Not a $format file (format: ${j['format']})');
    }
    if (j['version'] != version) {
      throw FormatException(
        'Unsupported $format version ${j['version']}, expected $version',
      );
    }
    return DrawingExport(
      drawing: Drawing.fromJson(j['drawing'] as Map<String, dynamic>),
      target: j['target'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}
