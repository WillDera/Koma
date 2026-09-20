/// Pure helpers for tracker start/finish dates (epoch millis ↔ API shapes).
class TrackDateUtils {
  TrackDateUtils._();

  /// Pass to [BaseTracker.updateListEntry] to clear a date field.
  static const int clearSentinel = 0;

  /// Local calendar midnight today as epoch millis.
  static int todayEpochMs([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  /// Normalize a stored value: `null` / `<= 0` → unset.
  static int? normalize(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return null;
    return epochMs;
  }

  /// AniList `FuzzyDateInput` from epoch millis, or `null` if unset.
  static Map<String, int>? toFuzzyDate(int? epochMs) {
    final ms = normalize(epochMs);
    if (ms == null) return null;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return {'year': d.year, 'month': d.month, 'day': d.day};
  }

  /// AniList clear payload (`year`/`month`/`day` all null).
  static Map<String, dynamic> clearFuzzyDate() => {
        'year': null,
        'month': null,
        'day': null,
      };

  /// Epoch millis from AniList `FuzzyDate` / `FuzzyDateInput` map.
  static int? fromFuzzyDate(Map<String, dynamic>? fuzzy) {
    if (fuzzy == null) return null;
    final y = (fuzzy['year'] as num?)?.toInt();
    if (y == null || y <= 0) return null;
    final m = (fuzzy['month'] as num?)?.toInt() ?? 1;
    final d = (fuzzy['day'] as num?)?.toInt() ?? 1;
    return DateTime(y, m, d).millisecondsSinceEpoch;
  }

  /// MAL `YYYY-MM-DD`, empty string when [epochMs] is the clear sentinel,
  /// or `null` when the field should be omitted.
  static String? toMalDate(int? epochMs, {bool forClear = false}) {
    if (epochMs == null) return forClear ? '' : null;
    if (epochMs <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Epoch millis from MAL `YYYY-MM-DD` (or empty → null).
  static int? fromMalDate(String? ymd) {
    if (ymd == null || ymd.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(ymd.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day)
        .millisecondsSinceEpoch;
  }

  /// Short display string for UI tiles.
  static String formatDisplay(int? epochMs) {
    final ms = normalize(epochMs);
    if (ms == null) return 'Not set';
    return toMalDate(ms)!;
  }
}
