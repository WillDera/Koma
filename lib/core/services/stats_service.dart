import '../models/reading_stat.dart';
import '../repositories/repositories.dart';

class StatsService {
  final Repositories _repos;

  StatsService(this._repos);

  Future<void> trackReading(int bookId, int seconds) async {
    await _repos.stats.upsertStatsForDate(
      DateTime.now(),
      readingTimeSeconds: seconds,
    );
  }

  Future<void> trackSnippet() async {
    await _repos.stats.upsertStatsForDate(
      DateTime.now(),
      snippetsCreated: 1,
    );
  }

  Future<void> trackCompletion(int bookId) async {
    await _repos.stats.upsertStatsForDate(
      DateTime.now(),
      booksCompleted: 1,
    );
  }

  Future<List<ReadingStat>> getStats(DateTime start, DateTime end) async {
    return await _repos.stats.getStatsRange(start, end);
  }

  Future<int> getTotalReadingTimeToday() async {
    final today = DateTime.now();
    final stat = await _repos.stats.getStatsForDate(today);
    return stat?.readingTimeSeconds ?? 0;
  }

  Future<int> getTotalReadingTimeThisWeek() async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final List<ReadingStat> stats = await _repos.stats.getStatsRange(
      DateTime(start.year, start.month, start.day),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    int total = 0;
    for (final s in stats) {
      total += s.readingTimeSeconds;
    }
    return total;
  }

  Future<({List<int> minutesPerDay, int currentStreak})> getWeeklyStreak() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    final start = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day);
    final stats = await _repos.stats.getStatsRange(
      start,
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final byDate = {for (final s in stats) s.date: s.readingTimeSeconds};
    final minutesPerDay = <int>[];
    int streak = 0;
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final seconds = byDate[dayStart] ?? 0;
      minutesPerDay.add(seconds ~/ 60);
      if (seconds > 0) { streak++; } else { streak = 0; }
    }
    return (minutesPerDay: minutesPerDay, currentStreak: streak);
  }
}
