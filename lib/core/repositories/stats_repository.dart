import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/reading_stat.dart' as i;
import '../isar/collections/source.dart' as i;
import '../isar/collections/web_cache.dart' as i;
import '../models/reading_stat.dart';
import '../models/source.dart';

/// Misc data: reading stats (per-day counter), ebook web sources, and
/// the offline web-cache for the URL-fetch reader.
class StatsRepository {
  final Isar _isar;
  StatsRepository(this._isar);

  // ── ReadingStats ───────────────────────────────────────────────────

  /// Get or create the [ReadingStat] row for [date] (date-only, no time).
  /// Returns a non-null row, creating one if missing (matches Drift's
  /// upsertStatsForDate behaviour).
  Future<ReadingStat?> getStatsForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final row = await _isar.readingStats
        .where()
        .dateEqualTo(day)
        .findFirst();
    return row == null ? null : _statToModel(row);
  }

  Future<void> upsertStatsForDate(
    DateTime date, {
    int readingTimeSeconds = 0,
    int snippetsCreated = 0,
    int booksCompleted = 0,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    await _isar.writeTxn(() async {
      final existing = await _isar.readingStats
          .where()
          .dateEqualTo(day)
          .findFirst();
      if (existing == null) {
        await _isar.readingStats.put(i.ReadingStat(
          date: day,
          readingTimeSeconds: readingTimeSeconds,
          snippetsCreated: snippetsCreated,
          booksCompleted: booksCompleted,
        ));
      } else {
        existing.readingTimeSeconds += readingTimeSeconds;
        existing.snippetsCreated += snippetsCreated;
        existing.booksCompleted += booksCompleted;
        await _isar.readingStats.put(existing);
      }
    });
  }

  Future<List<ReadingStat>> getStatsRange(
      DateTime start, DateTime end) async {
    final rows = await _isar.readingStats
        .where()
        .dateBetween(start, end)
        .sortByDate()
        .findAll();
    return rows.map(_statToModel).toList(growable: false);
  }

  Stream<List<ReadingStat>> watchStatsRange(
      DateTime start, DateTime end, {bool fireImmediately = true}) {
    return _isar.readingStats
        .where()
        .dateBetween(start, end)
        .sortByDate()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_statToModel).toList());
  }

  // ── Ebook Sources (Anna's Archive / Gutenberg / etc.) ──────────────

  Future<List<Source>> getSources() async {
    final rows = await _isar.sources.where().sortByCreatedAtDesc().findAll();
    return rows.map(_sourceToModel).toList(growable: false);
  }

  Future<int> insertSource(Source source) async {
    return _isar.writeTxn(() => _isar.sources.put(_sourceFromModel(source)));
  }

  Future<void> updateSource(Source source) async {
    await _isar.writeTxn(() => _isar.sources.put(_sourceFromModel(source)));
  }

  Future<void> deleteSource(int id) async {
    await _isar.writeTxn(() => _isar.sources.delete(id));
  }

  Stream<List<Source>> watchSources({bool fireImmediately = true}) {
    return _isar.sources
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_sourceToModel).toList());
  }

  // ── WebCache ───────────────────────────────────────────────────────

  /// Returns true if a cached copy of [urlHash] exists.
  Future<bool> isCached(String urlHash) async {
    final row = await _isar.webCaches.where().urlHashEqualTo(urlHash).findFirst();
    return row != null;
  }

  /// Returns a triple (title, content) or null if not cached.
  Future<({String title, String content})?> getCached(String urlHash) async {
    final row = await _isar.webCaches.where().urlHashEqualTo(urlHash).findFirst();
    if (row == null) return null;
    return (title: row.title, content: row.content);
  }

  Future<void> cacheContent(
      String url, String urlHash, String title, String htmlContent) async {
    await _isar.writeTxn(() => _isar.webCaches.put(i.WebCache(
          urlHash: urlHash,
          url: url,
          title: title,
          content: htmlContent,
          cachedAt: DateTime.now(),
        )));
  }

  Future<void> clearCache() async {
    await _isar.writeTxn(() => _isar.webCaches.where().deleteAll());
  }

  // ── Conversions ────────────────────────────────────────────────────

  static ReadingStat _statToModel(i.ReadingStat s) => ReadingStat(
        id: s.id ?? 0,
        date: s.date,
        readingTimeSeconds: s.readingTimeSeconds,
        snippetsCreated: s.snippetsCreated,
        booksCompleted: s.booksCompleted,
      );

  static Source _sourceToModel(i.Source s) => Source(
        id: s.id ?? 0,
        name: s.name,
        tag: s.tag,
        baseUrl: s.baseUrl,
        enabled: s.enabled,
        language: s.language,
      );

  static i.Source _sourceFromModel(Source s) => i.Source(
        id: s.id == 0 ? Isar.autoIncrement : s.id,
        name: s.name,
        tag: s.tag,
        baseUrl: s.baseUrl,
        enabled: s.enabled,
        language: s.language,
      );
}
