import 'dart:math';

import '../models/manga_chapter.dart';

/// Estimates release cadence from chapter upload / fetch dates
/// (Mangayomi [FetchInterval] port).
class FetchInterval {
  FetchInterval._();

  static const int maxInterval = 28;
  static const int _gracePeriod = 1;

  /// Median day-gap between recent distinct chapter dates, clamped to
  /// `[1, maxInterval]`. Defaults to 7 when there is not enough signal.
  static int calculateInterval(List<MangaChapter> chapters) {
    final chapterWindow = chapters.length <= 8 ? 3 : 10;

    final uploadDates =
        chapters
            .where((c) => c.dateUpload > 0)
            .map((c) => c.dateUpload)
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final distinctUploadDays = _distinctDays(
      uploadDates,
    ).take(chapterWindow).toList();
    if (distinctUploadDays.length >= 3) {
      return _medianInterval(distinctUploadDays);
    }

    final fetchDates =
        chapters
            .where((c) => c.dateFetch > 0)
            .map((c) => c.dateFetch)
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final distinctFetchDays = _distinctDays(
      fetchDates,
    ).take(chapterWindow).toList();
    if (distinctFetchDays.length >= 3) {
      return _medianInterval(distinctFetchDays);
    }

    return 7;
  }

  /// Next expected update day from last chapter signal + [interval].
  static DateTime? computeExpectedDate({
    required int? lastChapterDateMs,
    required int? lastUpdateMs,
    required int? interval,
    DateTime? now,
  }) {
    if (interval == null || interval <= 0) return null;

    final dateTime = now ?? DateTime.now();
    final referenceMs = [
      if (lastChapterDateMs != null && lastChapterDateMs > 0) lastChapterDateMs,
      if (lastUpdateMs != null && lastUpdateMs > 0) lastUpdateMs,
    ];
    if (referenceMs.isEmpty) return null;

    final latestMs = referenceMs.reduce(max);
    final latestDate = DateTime.fromMillisecondsSinceEpoch(latestMs);
    final latestDay = DateTime(
      latestDate.year,
      latestDate.month,
      latestDate.day,
    );

    final nowDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeSinceLatest = nowDay.difference(latestDay).inDays;

    if (timeSinceLatest < 0) {
      return latestDay.add(Duration(days: interval));
    }

    final effectiveInterval = _increaseInterval(
      interval,
      timeSinceLatest,
      increaseWhenOver: 10,
    );
    final cycle = effectiveInterval > 0
        ? timeSinceLatest ~/ effectiveInterval
        : 0;
    return latestDay.add(Duration(days: (cycle + 1) * interval));
  }

  static (int, int) getWindow(DateTime dateTime) {
    final today = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final lower = today.subtract(const Duration(days: _gracePeriod));
    final upper = today.add(const Duration(days: _gracePeriod));
    return (lower.millisecondsSinceEpoch, upper.millisecondsSinceEpoch - 1);
  }

  static int _increaseInterval(
    int delta,
    int timeSinceLatest, {
    required int increaseWhenOver,
  }) {
    if (delta >= maxInterval) return maxInterval;

    final cycle = (timeSinceLatest ~/ delta) + 1;
    if (cycle > increaseWhenOver) {
      return _increaseInterval(
        min(delta * 2, maxInterval),
        timeSinceLatest,
        increaseWhenOver: increaseWhenOver,
      );
    }
    return delta;
  }

  static Iterable<int> _distinctDays(List<int> epochMillis) sync* {
    final seen = <int>{};
    for (final ms in epochMillis) {
      final day = DateTime.fromMillisecondsSinceEpoch(ms);
      final dayKey = DateTime(
        day.year,
        day.month,
        day.day,
      ).millisecondsSinceEpoch;
      if (seen.add(dayKey)) yield dayKey;
    }
  }

  static int _medianInterval(List<int> distinctDays) {
    final ranges = <int>[];
    for (var i = 0; i + 1 < distinctDays.length; i++) {
      final daysDiff =
          DateTime.fromMillisecondsSinceEpoch(distinctDays[i])
              .difference(
                DateTime.fromMillisecondsSinceEpoch(distinctDays[i + 1]),
              )
              .inDays
              .abs();
      ranges.add(daysDiff);
    }
    ranges.sort();
    final median = ranges[(ranges.length - 1) ~/ 2];
    return median.clamp(1, maxInterval);
  }
}
