import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/manga.dart' as i;
import '../isar/collections/manga_chapter.dart' as i;
import '../models/manga.dart';
import '../models/manga_chapter.dart';

/// Manga repository: library manga + their chapters (image-based reading).
///
/// Same dual-API pattern as [BookRepository] — legacy Futures + reactive
/// Streams. The Isar collection's `inLibrary` flag drives the "Library"
/// tab list; `sourceId` links back to an [ExtensionSource].
class MangaRepository {
  final Isar _isar;
  MangaRepository(this._isar);

  // ── Manga: Future API ──────────────────────────────────────────────

  Future<List<Manga>> getMangasInLibrary() async {
    final rows = await _isar.mangas
        .filter()
        .inLibraryEqualTo(true)
        .sortByUpdatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Manga>> getAllMangas() async {
    final rows = await _isar.mangas.where().sortByUpdatedAtDesc().findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<Manga?> getMangaByKey(String sourceId, String url) async {
    final row = await _isar.mangas
        .filter()
        .sourceIdEqualTo(sourceId)
        .urlEqualTo(url)
        .findFirst();
    return row == null ? null : _toModel(row);
  }

  Future<Manga?> getMangaById(int id) async {
    final row = await _isar.mangas.get(id);
    return row == null ? null : _toModel(row);
  }

  Future<int> insertManga(Manga manga) async {
    return _isar.writeTxn(() => _isar.mangas.put(_fromModel(manga)));
  }

  Future<void> updateManga(Manga manga) async {
    await _isar.writeTxn(() => _isar.mangas.put(_fromModel(manga)));
  }

  Future<void> setMangaInLibrary(int mangaId, bool inLibrary) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangas.get(mangaId);
      if (row == null) return;
      row.inLibrary = inLibrary;
      row.updatedAt = DateTime.now();
      await _isar.mangas.put(row);
    });
  }

  Future<void> deleteManga(int id) async {
    await _isar.writeTxn(() async {
      // Cascade chapters (mirrors Drift FK ON DELETE CASCADE).
      await _isar.mangaChapters.where().mangaIdEqualTo(id).deleteAll();
      await _isar.mangas.delete(id);
    });
  }

  /// "Continue reading" shelf query — manga with at least one read
  /// chapter, ordered by most-recent read_at. Returns manga + the
  /// read/total counts the UI shows as a progress ring.
  Future<List<InProgressManga>> getInProgressManga() async {
    final mangas = await _isar.mangas.where().findAll();
    final result = <InProgressManga>[];
    for (final m in mangas) {
      final chapters =
          await _isar.mangaChapters.where().mangaIdEqualTo(m.id ?? 0).findAll();
      final readCount = chapters.where((c) => c.isRead || c.readAt != null).length;
      if (readCount == 0) continue;
      final lastReadAt = chapters
          .where((c) => c.readAt != null)
          .map((c) => c.readAt!)
          .fold<DateTime?>(null, (a, b) => (a == null || b.isAfter(a)) ? b : a);
      result.add(InProgressManga(
        manga: _toModel(m),
        readCount: readCount,
        totalChapters: chapters.length,
        lastReadAt: lastReadAt,
      ));
    }
    result.sort((a, b) {
      final at = a.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return result;
  }

  // ── Manga: Stream API ──────────────────────────────────────────────

  Stream<List<Manga>> watchLibrary({bool fireImmediately = true}) {
    return _isar.mangas
        .filter()
        .inLibraryEqualTo(true)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_toModel).toList());
  }

  Stream<Manga?> watchManga(int id, {bool fireImmediately = true}) {
    return _isar.mangas
        .watchObject(id, fireImmediately: fireImmediately)
        .map((row) => row == null ? null : _toModel(row));
  }

  // ── MangaChapters: Future API ──────────────────────────────────────

  Future<List<MangaChapter>> getMangaChapters(int mangaId) async {
    final rows = await _isar.mangaChapters
        .where()
        .mangaIdEqualTo(mangaId)
        .sortByIndex()
        .findAll();
    return rows.map(_chapterToModel).toList(growable: false);
  }

  Future<MangaChapter?> getMangaChapterByUrl(int mangaId, String url) async {
    final row = await _isar.mangaChapters
        .where()
        .mangaIdEqualTo(mangaId)
        .filter()
        .urlEqualTo(url)
        .findFirst();
    return row == null ? null : _chapterToModel(row);
  }

  Future<MangaChapter?> getMangaChapter(int id) async {
    final row = await _isar.mangaChapters.get(id);
    return row == null ? null : _chapterToModel(row);
  }

  Future<void> insertMangaChapters(
      int mangaId, List<MangaChapter> chapters) async {
    await _isar.writeTxn(() => _isar.mangaChapters
        .putAll(chapters.map(_chapterFromModel).toList()));
  }

  Future<void> deleteMangaChapters(int mangaId) async {
    await _isar.writeTxn(
        () => _isar.mangaChapters.where().mangaIdEqualTo(mangaId).deleteAll());
  }

  Future<void> markMangaChapterRead(int chapterId) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangaChapters.get(chapterId);
      if (row == null) return;
      row.isRead = true;
      row.readAt = DateTime.now();
      await _isar.mangaChapters.put(row);
    });
  }

  Future<void> markMangaChapterOpened(int chapterId) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangaChapters.get(chapterId);
      if (row == null) return;
      row.isOpened = true;
      await _isar.mangaChapters.put(row);
    });
  }

  Future<void> updateMangaChapterProgress(int chapterId, int page) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangaChapters.get(chapterId);
      if (row == null) return;
      row.lastPageRead = page;
      row.readAt = DateTime.now();
      await _isar.mangaChapters.put(row);
    });
  }

  Future<void> updateMangaChapterScrollPosition(
      int chapterId, double position) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangaChapters.get(chapterId);
      if (row == null) return;
      row.scrollPosition = position;
      row.readAt = DateTime.now();
      await _isar.mangaChapters.put(row);
    });
  }

  Future<void> markMangaChapterDownloaded(
      int chapterId, bool downloaded) async {
    await _isar.writeTxn(() async {
      final row = await _isar.mangaChapters.get(chapterId);
      if (row == null) return;
      row.isDownloaded = downloaded;
      await _isar.mangaChapters.put(row);
    });
  }

  Future<void> clearMangaChapterHistory(int mangaId) async {
    await _isar.writeTxn(() async {
      final chapters = await _isar.mangaChapters
          .where()
          .mangaIdEqualTo(mangaId)
          .findAll();
      for (final c in chapters) {
        c.isRead = false;
        c.isOpened = false;
        c.lastPageRead = 0;
        c.scrollPosition = 0.0;
        c.readAt = null;
      }
      await _isar.mangaChapters.putAll(chapters);
    });
  }

  // ── MangaChapters: Stream API ──────────────────────────────────────

  Stream<List<MangaChapter>> watchMangaChapters(int mangaId,
      {bool fireImmediately = true}) {
    return _isar.mangaChapters
        .where()
        .mangaIdEqualTo(mangaId)
        .sortByIndex()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_chapterToModel).toList());
  }

  // ── Conversions ────────────────────────────────────────────────────

  static Manga _toModel(i.Manga m) => Manga(
        id: m.id ?? 0,
        name: m.name,
        url: m.url,
        imageUrl: m.imageUrl,
        author: m.author,
        artist: m.artist,
        description: m.description,
        status: m.status,
        genres: m.genres ?? const [],
        sourceId: m.sourceId,
        inLibrary: m.inLibrary,
        readingStatus: m.readingStatus,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static i.Manga _fromModel(Manga m) => i.Manga(
        id: m.id == 0 ? Isar.autoIncrement : m.id,
        name: m.name,
        url: m.url,
        imageUrl: m.imageUrl,
        author: m.author,
        artist: m.artist,
        description: m.description,
        status: m.status,
        genres: m.genres,
        sourceId: m.sourceId,
        inLibrary: m.inLibrary,
        readingStatus: m.readingStatus,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  static MangaChapter _chapterToModel(i.MangaChapter c) => MangaChapter(
        id: c.id ?? 0,
        mangaId: c.mangaId,
        name: c.name,
        url: c.url,
        scanlator: c.scanlator,
        dateUpload: c.dateUpload,
        index: c.index,
        isRead: c.isRead,
        lastPageRead: c.lastPageRead,
        scrollPosition: c.scrollPosition,
        isDownloaded: c.isDownloaded,
        isOpened: c.isOpened,
        readAt: c.readAt,
    memo: c.memo,
      );

  static i.MangaChapter _chapterFromModel(MangaChapter c) => i.MangaChapter(
        id: c.id == 0 ? Isar.autoIncrement : c.id,
        mangaId: c.mangaId,
        name: c.name,
        url: c.url,
        scanlator: c.scanlator,
        dateUpload: c.dateUpload,
        index: c.index,
        isRead: c.isRead,
        lastPageRead: c.lastPageRead,
        scrollPosition: c.scrollPosition,
        isDownloaded: c.isDownloaded,
        isOpened: c.isOpened,
        readAt: c.readAt,
    memo: c.memo,
      );
}

/// A manga row + its read progress, for the "Continue Reading" shelf.
/// Replaces the raw `Map<String, dynamic>` the Drift version returned.
class InProgressManga {
  final Manga manga;
  final int readCount;
  final int totalChapters;
  final DateTime? lastReadAt;

  const InProgressManga({
    required this.manga,
    required this.readCount,
    required this.totalChapters,
    required this.lastReadAt,
  });

  double get progress =>
      totalChapters == 0 ? 0.0 : readCount / totalChapters;
}
