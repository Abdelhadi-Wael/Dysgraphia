/// UTC with millisecond precision, so timestamps always serialise like
/// `2026-11-17T10:22:31.123Z` (see docs/stroke-format.md).
DateTime utcMillis(DateTime t) =>
    DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);
