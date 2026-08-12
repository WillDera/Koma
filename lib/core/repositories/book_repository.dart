import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/book.dart' as i;
import '../isar/collections/book_metadata.dart' as i;
import '../isar/collections/chapter.dart' as i;
import '../isar/collections/highlight.dart' as i;
import '../models/book.dart';
import '../models/book_metadata.dart';
import '../models/chapter.dart';
import '../models/highlight.dart';
import '../services/ebook_media_store.dart';

/// Bookshelf repository: books + ebook chapters + highlights.
///
/// Exposes both legacy `Future<T>` methods (for drop-in replacement of
/// DatabaseService during PHASE 2 Riverpod migration) AND reactive
/// `Stream<List<T>>` variants (for the new Riverpod StreamProviders
/// that close mangayomi's reactivity gap — see PHASE 2).
///
/// Conversion between Isar collection instances (mutable, nullable
/// timestamps) and the immutable model DTOs happens here, so callers
/// keep working with the typed `Book`/`Chapter`/`Highlight` they know.
class BookRepository {
  final Isar _isar;
  BookRepository(this._isar);

  // ── Books: Future API (drop-in DatabaseService replacement) ────────

  Future<List<Book>> getBooks() async {
    final rows = await _isar.books.where().sortByUpdatedAtDesc().findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Book>> getInProgressBooks() async {
    final rows = await _isar.books
        .filter()
        .progressGreaterThan(0.0)
        .progressLessThan(1.0)
        .sortByUpdatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<Book?> getBook(int id) async {
    final row = await _isar.books.get(id);
    return row == null ? null : _toModel(row);
  }

  Future<Book?> findLocalBook(String title, String? author) async {
    final q = _isar.books.filter().titleEqualTo(title);
    final row = author == null
        ? await q.authorIsNull().findFirst()
        : await q.authorEqualTo(author).findFirst();
    return row == null ? null : _toModel(row);
  }

  Future<int> insertBook(Book book) async {
    return _isar.writeTxn(() => _isar.books.put(_fromModel(book)));
  }

  Future<void> insertBooks(List<Book> books) async {
    await _isar.writeTxn(
      () => _isar.books.putAll(books.map(_fromModel).toList()),
    );
  }

  Future<void> updateBook(Book book) async {
    await _isar.writeTxn(() => _isar.books.put(_fromModel(book)));
  }

  Future<void> updateProgress(
    int bookId,
    double progress, {
    int? currentChapterIndex,
    double scrollPosition = 0.0,
  }) async {
    await _isar.writeTxn(() async {
      final row = await _isar.books.get(bookId);
      if (row == null) return;
      row.progress = progress;
      if (currentChapterIndex != null) {
        row.currentChapterIndex = currentChapterIndex;
      }
      row.scrollPosition = scrollPosition;
      row.updatedAt = DateTime.now();
      await _isar.books.put(row);
    });
  }

  Future<void> clearProgress(int bookId) async {
    await updateProgress(
      bookId,
      0.0,
      currentChapterIndex: 0,
      scrollPosition: 0.0,
    );
  }

  Future<void> deleteBook(int id) async {
    await EbookMediaStore.deleteBookMedia(id);
    await _isar.writeTxn(() async {
      // Cascade: delete the book's chapters + highlights first.
      // (Isar has no FK cascade; we do it manually, mirroring the
      // Drift schema's ON DELETE CASCADE.)
      await _isar.chapters.where().bookIdEqualTo(id).deleteAll();
      await _isar.highlights.where().bookIdEqualTo(id).deleteAll();
      await _isar.bookMetadatas.where().bookIdEqualTo(id).deleteAll();
      await _isar.books.delete(id);
    });
  }

  Future<BookMetadata?> getMetadataForBook(int bookId) async {
    final row =
        await _isar.bookMetadatas.filter().bookIdEqualTo(bookId).findFirst();
    return row == null ? null : _metadataToModel(row);
  }

  /// Apply engine enrichment to [Book] display fields and upsert provenance.
  Future<void> applyEnrichment({
    required int bookId,
    required String? author,
    required String? localCoverPath,
    required List<String> genres,
    required DateTime? releaseDate,
    required String source,
    required String? remoteId,
    required String? coverUrl,
    required String? rawTitle,
  }) async {
    await _isar.writeTxn(() async {
      final book = await _isar.books.get(bookId);
      if (book == null) return;

      if (author != null && author.trim().isNotEmpty) {
        book.author = author.trim();
      }
      if (localCoverPath != null && localCoverPath.isNotEmpty) {
        book.coverPath = localCoverPath;
      }
      if (genres.isNotEmpty) {
        book.genre = genres.join(', ');
      }
      if (releaseDate != null) {
        book.releaseDate = releaseDate;
      }
      book.updatedAt = DateTime.now();
      await _isar.books.put(book);

      final existing = await _isar.bookMetadatas
          .filter()
          .bookIdEqualTo(bookId)
          .findFirst();
      final meta = existing ??
          i.BookMetadata(
            bookId: bookId,
            source: source,
          );
      meta.source = source;
      meta.remoteId = remoteId;
      meta.coverUrl = coverUrl;
      meta.genres = List<String>.from(genres);
      meta.releaseDate = releaseDate;
      meta.fetchedAt = DateTime.now();
      meta.rawTitle = rawTitle;
      await _isar.bookMetadatas.put(meta);
    });
  }

  Future<int> getCompletedBooksCount() async {
    return _isar.books.filter().progressEqualTo(1.0).count();
  }

  Future<Map<String, int>> getGenreCounts() async {
    final books = await _isar.books.where().findAll();
    final counts = <String, int>{};
    for (final b in books) {
      final raw = b.genre.trim();
      if (raw.isEmpty) continue;
      for (final part in raw.split(',')) {
        final g = part.trim();
        if (g.isEmpty) continue;
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<Map<String, int>> getExtensionCounts() async {
    final books = await _isar.books.where().findAll();
    final counts = <String, int>{};
    for (final b in books) {
      final label = _formatLabelForBook(b);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  /// Human-readable format bucket for stats. [fileExtension] is often empty
  /// because importers don't populate it — fall back to the path suffix.
  static String _formatLabelForBook(i.Book b) {
    final stored = b.fileExtension.trim();
    if (stored.isNotEmpty) return stored.toUpperCase();

    final path = b.filePath?.trim() ?? '';
    if (path.isNotEmpty) {
      final dot = path.lastIndexOf('.');
      if (dot >= 0 && dot < path.length - 1) {
        final ext = path.substring(dot + 1).toLowerCase();
        if (ext.isNotEmpty &&
            ext.length <= 8 &&
            RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
          return ext.toUpperCase();
        }
      }
    }

    if (b.source == 'web') return 'Web';
    return 'Other';
  }

  // ── Books: Stream API (reactive, for Riverpod StreamProvider) ──────

  /// Emits the full book list on any change. Sorts by updatedAt desc
  /// (matches the library screen's default ordering).
  Stream<List<Book>> watchBooks({bool fireImmediately = true}) {
    return _isar.books
        .where()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_toModel).toList());
  }

  /// Emits a single book on any change to that book (or null if deleted).
  Stream<Book?> watchBook(int id, {bool fireImmediately = true}) {
    return _isar.books
        .watchObject(id, fireImmediately: fireImmediately)
        .map((row) => row == null ? null : _toModel(row));
  }

  // ── Chapters: Future API ───────────────────────────────────────────

  Future<List<Chapter>> getChapters(int bookId) async {
    final rows = await _isar.chapters
        .where()
        .bookIdEqualTo(bookId)
        .sortByIndex()
        .findAll();
    return rows.map(_chapterToModel).toList(growable: false);
  }

  Future<List<Book>> searchBooks(String term) async {
    final lower = term.toLowerCase();
    final rows = await _isar.books
        .filter()
        .titleContains(lower, caseSensitive: false)
        .or()
        .authorContains(lower, caseSensitive: false)
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Chapter>> searchChapters(String term) async {
    final lower = term.toLowerCase();
    final rows = await _isar.chapters
        .filter()
        .titleContains(lower, caseSensitive: false)
        .or()
        .contentContains(lower, caseSensitive: false)
        .sortByIndex()
        .findAll();
    return rows.map(_chapterToModel).toList(growable: false);
  }

  Future<Chapter?> getChapter(int id) async {
    final row = await _isar.chapters.get(id);
    return row == null ? null : _chapterToModel(row);
  }

  Future<Chapter?> findChapterByIndex(int bookId, int index) async {
    final row = await _isar.chapters
        .where()
        .bookIdEqualTo(bookId)
        .filter()
        .indexEqualTo(index)
        .findFirst();
    return row == null ? null : _chapterToModel(row);
  }

  Future<int> insertChapter(Chapter chapter) async {
    return _isar.writeTxn(() => _isar.chapters.put(_chapterFromModel(chapter)));
  }

  Future<void> insertChapters(List<Chapter> chapters) async {
    await _isar.writeTxn(
      () => _isar.chapters.putAll(chapters.map(_chapterFromModel).toList()),
    );
  }

  Future<void> markChapterRead(int chapterId) async {
    await _isar.writeTxn(() async {
      final row = await _isar.chapters.get(chapterId);
      if (row == null) return;
      row.readAt = DateTime.now();
      await _isar.chapters.put(row);
    });
  }

  Future<void> updateChapterScroll(int chapterId, double position) async {
    await _isar.writeTxn(() async {
      final row = await _isar.chapters.get(chapterId);
      if (row == null) return;
      row.scrollPosition = position;
      await _isar.chapters.put(row);
    });
  }

  /// Records the paginated reading position for a chapter.
  ///
  /// Kept separate from [updateChapterScroll] so the two layout modes never
  /// clobber each other's position: scroll mode writes pixels, paginated mode
  /// writes character offsets, and switching modes reads whichever it needs.
  Future<void> updateChapterReadingOffset(int chapterId, int charOffset) async {
    await _isar.writeTxn(() async {
      final row = await _isar.chapters.get(chapterId);
      if (row == null) return;
      row.readingCharOffset = charOffset;
      await _isar.chapters.put(row);
    });
  }

  Future<void> updateChapterReadAt(int chapterId, DateTime readAt) async {
    await _isar.writeTxn(() async {
      final row = await _isar.chapters.get(chapterId);
      if (row == null) return;
      row.readAt = readAt;
      await _isar.chapters.put(row);
    });
  }

  // ── Chapters: Stream API ───────────────────────────────────────────

  Stream<List<Chapter>> watchChapters(
    int bookId, {
    bool fireImmediately = true,
  }) {
    return _isar.chapters
        .where()
        .bookIdEqualTo(bookId)
        .sortByIndex()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_chapterToModel).toList());
  }

  // ── Highlights ─────────────────────────────────────────────────────

  Future<List<Highlight>> getHighlightsForChapter(int chapterId) async {
    final rows = await _isar.highlights
        .where()
        .chapterIdEqualTo(chapterId)
        .findAll();
    return rows.map(_highlightToModel).toList(growable: false);
  }

  /// Persists [hl] and returns the assigned row id, so callers holding an
  /// in-memory copy can keep it in step with the stored row rather than
  /// carrying a placeholder id.
  Future<int> insertHighlight(Highlight hl) async {
    return _isar.writeTxn(() => _isar.highlights.put(_highlightFromModel(hl)));
  }

  Future<void> deleteHighlight(int id) async {
    await _isar.writeTxn(() => _isar.highlights.delete(id));
  }

  // ── Conversions: Isar collection ↔ immutable model DTO ─────────────

  static Book _toModel(i.Book b) => Book(
        id: b.id ?? 0,
        title: b.title,
        author: b.author,
        coverPath: b.coverPath,
        source: b.source,
        sourceUrl: b.sourceUrl,
        filePath: b.filePath,
        progress: b.progress,
        currentChapterIndex: b.currentChapterIndex,
        totalChapters: b.totalChapters,
        scrollPosition: b.scrollPosition,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
        genre: b.genre,
        fileExtension: b.fileExtension,
        releaseDate: b.releaseDate,
      );

  static i.Book _fromModel(Book b) => i.Book(
        id: b.id == 0 ? Isar.autoIncrement : b.id,
        title: b.title,
        author: b.author,
        coverPath: b.coverPath,
        source: b.source,
        sourceUrl: b.sourceUrl,
        filePath: b.filePath,
        progress: b.progress,
        currentChapterIndex: b.currentChapterIndex,
        totalChapters: b.totalChapters,
        scrollPosition: b.scrollPosition,
        genre: b.genre,
        fileExtension: b.fileExtension,
        releaseDate: b.releaseDate,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
      );

  static BookMetadata _metadataToModel(i.BookMetadata m) => BookMetadata(
        id: m.id ?? 0,
        bookId: m.bookId,
        source: m.source,
        remoteId: m.remoteId,
        coverUrl: m.coverUrl,
        genres: m.genres,
        releaseDate: m.releaseDate,
        fetchedAt: m.fetchedAt,
        rawTitle: m.rawTitle,
      );

  static Chapter _chapterToModel(i.Chapter c) => Chapter(
    id: c.id ?? 0,
    bookId: c.bookId,
    title: c.title,
    content: c.content,
    index: c.index,
    readAt: c.readAt,
    scrollPosition: c.scrollPosition,
    readingCharOffset: c.readingCharOffset,
  );

  static i.Chapter _chapterFromModel(Chapter c) => i.Chapter(
    id: c.id == 0 ? Isar.autoIncrement : c.id,
    bookId: c.bookId,
    title: c.title,
    content: c.content,
    index: c.index,
    readAt: c.readAt,
    scrollPosition: c.scrollPosition,
    readingCharOffset: c.readingCharOffset,
  );

  static Highlight _highlightToModel(i.Highlight h) => Highlight(
    id: h.id ?? 0,
    snippetId: h.snippetId,
    bookId: h.bookId,
    chapterId: h.chapterId,
    startOffset: h.startOffset,
    endOffset: h.endOffset,
    color: h.color,
    text: h.text,
    createdAt: h.createdAt,
    updatedAt: h.updatedAt,
  );

  static i.Highlight _highlightFromModel(Highlight h) => i.Highlight(
    id: h.id == 0 ? Isar.autoIncrement : h.id,
    snippetId: h.snippetId,
    bookId: h.bookId,
    chapterId: h.chapterId,
    startOffset: h.startOffset,
    endOffset: h.endOffset,
    color: h.color,
    text: h.text,
    createdAt: h.createdAt,
    updatedAt: h.updatedAt,
  );
}
