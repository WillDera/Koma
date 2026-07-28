import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/reading_stat.dart';
import 'package:koma/core/repositories/repositories.dart';

import 'helpers/test_database.dart';

void main() {
  late Repositories repos;

  setUp(() async {
    repos = await createTestRepositories();
  });

  tearDown(() {
    repos.isar.close();
  });

  group('upsertStatsForDate (reading time)', () {
    test('creates new stats entry for a day', () async {
      final today = DateTime(2025, 7, 1);
      await repos.stats.upsertStatsForDate(today, readingTimeSeconds: 300);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat, isNotNull);
      expect(stat!.readingTimeSeconds, 300);
    });

    test('increments reading time on existing day', () async {
      final today = DateTime(2025, 7, 1);
      await repos.stats.upsertStatsForDate(today, readingTimeSeconds: 120);
      await repos.stats.upsertStatsForDate(today, readingTimeSeconds: 80);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 200);
    });
  });

  group('upsertStatsForDate (snippet count)', () {
    test('creates new entry with snippet count', () async {
      final today = DateTime(2025, 7, 2);
      await repos.stats.upsertStatsForDate(today, snippetsCreated: 1);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.snippetsCreated, 1);
    });

    test('increments snippet count', () async {
      final today = DateTime(2025, 7, 2);
      await repos.stats.upsertStatsForDate(today, snippetsCreated: 2);
      await repos.stats.upsertStatsForDate(today, snippetsCreated: 1);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.snippetsCreated, 3);
    });
  });

  group('upsertStatsForDate (book completion)', () {
    test('creates new entry with completion', () async {
      final today = DateTime(2025, 7, 3);
      await repos.stats.upsertStatsForDate(today, booksCompleted: 1);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.booksCompleted, 1);
    });

    test('increments completion count', () async {
      final today = DateTime(2025, 7, 3);
      await repos.stats.upsertStatsForDate(today, booksCompleted: 1);
      await repos.stats.upsertStatsForDate(today, booksCompleted: 1);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.booksCompleted, 2);
    });
  });

  group('setStatsForDate (import replacement)', () {
    test('replaces values for existing day', () async {
      final today = DateTime(2025, 7, 4);
      await repos.stats.upsertStatsForDate(today, readingTimeSeconds: 60);
      await repos.stats.setStatsForDate(today, readingTimeSeconds: 120);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 120);
    });

    test('creates entry if none exists', () async {
      final today = DateTime(2025, 7, 4);
      await repos.stats.setStatsForDate(today, readingTimeSeconds: 60);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 60);
    });
  });

  group('getStatsRange', () {
    test('returns stats within date range', () async {
      await repos.stats.upsertStatsForDate(DateTime(2025, 6, 10), readingTimeSeconds: 60);
      await repos.stats.upsertStatsForDate(DateTime(2025, 6, 12), readingTimeSeconds: 120);
      await repos.stats.upsertStatsForDate(DateTime(2025, 6, 15), readingTimeSeconds: 90);

      final stats = await repos.stats.getStatsRange(
        DateTime(2025, 6, 10),
        DateTime(2025, 6, 12),
      );
      expect(stats.length, 2);
      expect(stats[0].readingTimeSeconds, 60);
      expect(stats[1].readingTimeSeconds, 120);
    });

    test('returns empty for range with no data', () async {
      final stats = await repos.stats.getStatsRange(
        DateTime(2020, 1, 1),
        DateTime(2020, 1, 31),
      );
      expect(stats, isEmpty);
    });

    test('returns single day when start equals end', () async {
      await repos.stats.upsertStatsForDate(DateTime(2025, 7, 1), readingTimeSeconds: 45);

      final stats = await repos.stats.getStatsRange(
        DateTime(2025, 7, 1),
        DateTime(2025, 7, 1),
      );
      expect(stats.length, 1);
      expect(stats.first.readingTimeSeconds, 45);
    });
  });

  group('daily stats aggregation', () {
    test('multiple metrics accumulate on same day', () async {
      final today = DateTime(2025, 7, 4);
      await repos.stats.upsertStatsForDate(today, readingTimeSeconds: 60);
      await repos.stats.upsertStatsForDate(today, snippetsCreated: 2);
      await repos.stats.upsertStatsForDate(today, booksCompleted: 1);

      final stat = await repos.stats.getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 60);
      expect(stat.snippetsCreated, 2);
      expect(stat.booksCompleted, 1);
    });

    test('different days are independent', () async {
      final day1 = DateTime(2025, 7, 1);
      final day2 = DateTime(2025, 7, 2);

      await repos.stats.upsertStatsForDate(day1, readingTimeSeconds: 100);
      await repos.stats.upsertStatsForDate(day2, readingTimeSeconds: 200);

      final stat1 = await repos.stats.getStatsForDate(day1);
      final stat2 = await repos.stats.getStatsForDate(day2);
      expect(stat1!.readingTimeSeconds, 100);
      expect(stat2!.readingTimeSeconds, 200);
    });

    test('weekly range aggregates correctly', () async {
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2025, 7, 1 + i);
        await repos.stats.upsertStatsForDate(day, readingTimeSeconds: (i + 1) * 60);
      }

      final stats = await repos.stats.getStatsRange(
        DateTime(2025, 7, 1),
        DateTime(2025, 7, 7),
      );
      expect(stats.length, 7);

      final totalSeconds = stats.fold<int>(0, (sum, s) => sum + s.readingTimeSeconds);
      expect(totalSeconds, 1680);
    });
  });
}
