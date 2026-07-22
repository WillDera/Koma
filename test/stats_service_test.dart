import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:koma/core/database/database.dart';
import 'package:koma/core/models/reading_stat.dart';

import 'helpers/test_database.dart';

/// Tests StatsService logic by exercising the same upsert/query SQL
/// that StatsService delegates to DatabaseService.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  /// Replicates DatabaseService.upsertStatsForDate SQL logic
  Future<void> upsertStats(
    DateTime date, {
    int readingTimeSeconds = 0,
    int snippetsCreated = 0,
    int booksCompleted = 0,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final existing = await db
        .customSelect('SELECT * FROM reading_stats WHERE date = ?',
            variables: [Variable.withDateTime(day)])
        .get();

    if (existing.isNotEmpty) {
      await db.customUpdate(
        'UPDATE reading_stats SET '
        'reading_time_seconds = reading_time_seconds + ?, '
        'snippets_created = snippets_created + ?, '
        'books_completed = books_completed + ? '
        'WHERE date = ?',
        variables: [
          Variable.withInt(readingTimeSeconds),
          Variable.withInt(snippetsCreated),
          Variable.withInt(booksCompleted),
          Variable.withDateTime(day),
        ],
      );
    } else {
      await db.customInsert(
        'INSERT INTO reading_stats (date, reading_time_seconds, snippets_created, books_completed) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withDateTime(day),
          Variable.withInt(readingTimeSeconds),
          Variable.withInt(snippetsCreated),
          Variable.withInt(booksCompleted),
        ],
      );
    }
  }

  /// SQLite stores dates as TEXT; parse them back to DateTime
  DateTime parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.parse(raw);
    throw StateError('Unexpected date type: ${raw.runtimeType}');
  }

  /// Replicates DatabaseService.getStatsForDate
  Future<ReadingStat?> getStatsForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final rows = await db
        .customSelect('SELECT * FROM reading_stats WHERE date = ?',
            variables: [Variable.withDateTime(day)])
        .get();
    if (rows.isEmpty) return null;
    return ReadingStat(
      id: rows.first.data['id'] as int,
      date: parseDate(rows.first.data['date']),
      readingTimeSeconds: rows.first.data['reading_time_seconds'] as int? ?? 0,
      snippetsCreated: rows.first.data['snippets_created'] as int? ?? 0,
      booksCompleted: rows.first.data['books_completed'] as int? ?? 0,
    );
  }

  /// Replicates DatabaseService.getStatsRange
  Future<List<ReadingStat>> getStatsRange(
      DateTime start, DateTime end) async {
    final rows = await db
        .customSelect(
            'SELECT * FROM reading_stats WHERE date >= ? AND date <= ? ORDER BY date',
            variables: [
          Variable.withDateTime(start),
          Variable.withDateTime(end),
        ])
        .get();
    return rows
        .map((r) => ReadingStat(
              id: r.data['id'] as int,
              date: parseDate(r.data['date']),
              readingTimeSeconds:
                  r.data['reading_time_seconds'] as int? ?? 0,
              snippetsCreated: r.data['snippets_created'] as int? ?? 0,
              booksCompleted: r.data['books_completed'] as int? ?? 0,
            ))
        .toList();
  }

  group('trackReading (upsert reading time)', () {
    test('creates new stats entry for a day', () async {
      final today = DateTime(2025, 7, 1);
      await upsertStats(today, readingTimeSeconds: 300);

      final stat = await getStatsForDate(today);
      expect(stat, isNotNull);
      expect(stat!.readingTimeSeconds, 300);
    });

    test('increments reading time on existing day', () async {
      final today = DateTime(2025, 7, 1);
      await upsertStats(today, readingTimeSeconds: 120);
      await upsertStats(today, readingTimeSeconds: 80);

      final stat = await getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 200);
    });
  });

  group('trackSnippet (upsert snippet count)', () {
    test('creates new entry with snippet count', () async {
      final today = DateTime(2025, 7, 2);
      await upsertStats(today, snippetsCreated: 1);

      final stat = await getStatsForDate(today);
      expect(stat!.snippetsCreated, 1);
    });

    test('increments snippet count', () async {
      final today = DateTime(2025, 7, 2);
      await upsertStats(today, snippetsCreated: 2);
      await upsertStats(today, snippetsCreated: 1);

      final stat = await getStatsForDate(today);
      expect(stat!.snippetsCreated, 3);
    });
  });

  group('trackCompletion (upsert book completion)', () {
    test('creates new entry with completion', () async {
      final today = DateTime(2025, 7, 3);
      await upsertStats(today, booksCompleted: 1);

      final stat = await getStatsForDate(today);
      expect(stat!.booksCompleted, 1);
    });

    test('increments completion count', () async {
      final today = DateTime(2025, 7, 3);
      await upsertStats(today, booksCompleted: 1);
      await upsertStats(today, booksCompleted: 1);

      final stat = await getStatsForDate(today);
      expect(stat!.booksCompleted, 2);
    });
  });

  group('getStatsRange', () {
    test('returns stats within date range', () async {
      await upsertStats(DateTime(2025, 6, 10), readingTimeSeconds: 60);
      await upsertStats(DateTime(2025, 6, 12), readingTimeSeconds: 120);
      await upsertStats(DateTime(2025, 6, 15), readingTimeSeconds: 90);

      final stats = await getStatsRange(
        DateTime(2025, 6, 10),
        DateTime(2025, 6, 12),
      );
      expect(stats.length, 2);
      expect(stats[0].readingTimeSeconds, 60);
      expect(stats[1].readingTimeSeconds, 120);
    });

    test('returns empty for range with no data', () async {
      final stats = await getStatsRange(
        DateTime(2020, 1, 1),
        DateTime(2020, 1, 31),
      );
      expect(stats, isEmpty);
    });

    test('returns single day when start equals end', () async {
      await upsertStats(DateTime(2025, 7, 1), readingTimeSeconds: 45);

      final stats = await getStatsRange(
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
      await upsertStats(today, readingTimeSeconds: 60);
      await upsertStats(today, snippetsCreated: 2);
      await upsertStats(today, booksCompleted: 1);

      final stat = await getStatsForDate(today);
      expect(stat!.readingTimeSeconds, 60);
      expect(stat.snippetsCreated, 2);
      expect(stat.booksCompleted, 1);
    });

    test('different days are independent', () async {
      final day1 = DateTime(2025, 7, 1);
      final day2 = DateTime(2025, 7, 2);

      await upsertStats(day1, readingTimeSeconds: 100);
      await upsertStats(day2, readingTimeSeconds: 200);

      final stat1 = await getStatsForDate(day1);
      final stat2 = await getStatsForDate(day2);
      expect(stat1!.readingTimeSeconds, 100);
      expect(stat2!.readingTimeSeconds, 200);
    });

    test('weekly range aggregates correctly', () async {
      // Simulate a week of reading
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2025, 7, 1 + i);
        await upsertStats(day, readingTimeSeconds: (i + 1) * 60);
      }

      final stats = await getStatsRange(
        DateTime(2025, 7, 1),
        DateTime(2025, 7, 7),
      );
      expect(stats.length, 7);

      final totalSeconds =
          stats.fold<int>(0, (sum, s) => sum + s.readingTimeSeconds);
      // Values inserted: 60, 120, 180, 240, 300, 360, 420 = 1680
      expect(totalSeconds, 1680);
    });
  });
}
