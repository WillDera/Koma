import 'dart:convert';

import '../models/book.dart';
import '../models/bookmark.dart';
import '../models/chapter.dart';
import '../models/extension_repo.dart';
import '../models/highlight.dart';
import '../models/library_category.dart';
import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../models/reading_stat.dart';
import '../models/snippet.dart';
import '../models/snippet_collection.dart';
import '../repositories/repositories.dart';
import 'backup/backup_format.dart';
import 'backup/backup_importer.dart';
import 'backup/import_result.dart';
import 'backup/mangayomi_backup_decoder.dart';
import 'backup/mihon_backup_decoder.dart';

export 'backup/import_result.dart';

class ExportService {
  final Repositories _repos;

  ExportService(this._repos);

  Future<String> exportToJson() async {
    final books = await _repos.books.getBooks();
    final chapters = <Chapter>[];
    for (final book in books) {
      final bookChapters = await _repos.books.getChapters(book.id);
      chapters.addAll(bookChapters);
    }
    chapters.sort((a, b) {
      final cmp = a.bookId.compareTo(b.bookId);
      if (cmp != 0) return cmp;
      return a.index.compareTo(b.index);
    });

    final snippets = await _repos.snippets.getSnippets();
    final tags = await _repos.snippets.getAllTags();
    final stats = await _repos.stats.getStatsRange(
      DateTime(2000, 1, 1),
      DateTime.now(),
    );
    final mangas = await _repos.manga.getAllMangas();
    final mangaChapters = <MangaChapter>[];
    for (final manga in mangas) {
      mangaChapters.addAll(await _repos.manga.getMangaChapters(manga.id));
    }
    final categories = await _repos.categories.getCategories();
    final repos = await _repos.extensions.getExtensionRepos();
    final cookies = await _repos.cookies.getAll();
    final bookmarks = await _repos.bookmarks.getAllBookmarks();
    final highlights = await _repos.books.getAllHighlights();
    final collections = await _repos.snippets.getCollections();

    final export = {
      'version': 4,
      'exported_at': DateTime.now().toIso8601String(),
      'books': books.map((b) => b.toJson()).toList(),
      'chapters': chapters.map((ch) => ch.toJson()).toList(),
      'snippets': snippets.map((s) => s.toJson()).toList(),
      'tags': tags,
      'reading_stats': stats.map((s) => s.toJson()).toList(),
      'manga': mangas.map((m) => m.toJson()).toList(),
      'manga_chapters': mangaChapters.map((c) => c.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'extension_repos': repos.map((r) => r.toJson()).toList(),
      'cookies': cookies.map((c) => c.toJson()).toList(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'highlights': highlights.map((h) => h.toJson()).toList(),
      'snippet_collections': collections.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  Future<ImportResult> importBytes(
    List<int> bytes, {
    String? filename,
  }) async {
    final sniff = sniffBackup(bytes, filename: filename);
    switch (sniff.kind) {
      case BackupKind.mihon:
        final foreign = decodeMihonBackup(bytes);
        return BackupImporter(_repos).importForeign(foreign);
      case BackupKind.mangayomi:
        final foreign = decodeMangayomiBackup(bytes);
        return BackupImporter(_repos).importForeign(foreign);
      case BackupKind.komaJson:
        return importFromJson(utf8.decode(bytes));
      case BackupKind.unknown:
        // Last resort: try JSON then Mihon protobuf.
        try {
          return importFromJson(utf8.decode(bytes));
        } catch (_) {
          try {
            final foreign = decodeMihonBackup(bytes);
            return BackupImporter(_repos).importForeign(foreign);
          } catch (e) {
            throw FormatException(
              'Unrecognized backup. Use a Koma .json, Mihon .tachibk, '
              'or Mangayomi .backup file. ($e)',
            );
          }
        }
    }
  }

  Future<ImportResult> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = (data['version'] as int?) ?? 1;
    final booksJson = (data['books'] as List<dynamic>?) ?? [];
    final chaptersJson = (data['chapters'] as List<dynamic>?) ?? [];
    final snippetsJson = (data['snippets'] as List<dynamic>?) ?? [];
    final tagsJson = (data['tags'] as List<dynamic>?) ?? [];
    final statsJson = (data['reading_stats'] as List<dynamic>?) ?? [];
    final mangaJson = (data['manga'] as List<dynamic>?) ?? [];
    final mangaChaptersJson = (data['manga_chapters'] as List<dynamic>?) ?? [];
    final categoriesJson = (data['categories'] as List<dynamic>?) ?? [];
    final reposJson = (data['extension_repos'] as List<dynamic>?) ?? [];
    final cookiesJson = (data['cookies'] as List<dynamic>?) ?? [];
    final bookmarksJson = (data['bookmarks'] as List<dynamic>?) ?? [];
    final highlightsJson = (data['highlights'] as List<dynamic>?) ?? [];
    final collectionsJson =
        (data['snippet_collections'] as List<dynamic>?) ?? [];

    int booksImported = 0;
    int booksSkipped = 0;
    int chaptersImported = 0;
    int chaptersSkipped = 0;
    int snippetsImported = 0;
    int snippetsSkipped = 0;
    int mangaImported = 0;
    int mangaSkipped = 0;
    int mangaChaptersImported = 0;
    int categoriesImported = 0;
    int reposImported = 0;
    int cookiesImported = 0;

    final existingBooks = await _repos.books.getBooks();
    final bookKey = <String, Book>{
      for (final b in existingBooks) '${b.title}\u0000${b.author ?? ''}': b,
    };

    final oldToNewBookId = <int, int>{};
    final newlyImportedOldBookIds = <int>{};

    for (final b in booksJson) {
      final book = Book.fromJson(b as Map<String, dynamic>);
      final key = '${book.title}\u0000${book.author ?? ''}';
      final existing = bookKey[key];
      if (existing == null) {
        final newId = await _repos.books.insertBook(book.copyWith(id: 0));
        oldToNewBookId[book.id] = newId;
        newlyImportedOldBookIds.add(book.id);
        bookKey[key] = book.copyWith(id: newId);
        booksImported++;
      } else {
        oldToNewBookId[book.id] = existing.id;
        booksSkipped++;
      }
    }

    final oldToNewChapterId = <int, int>{};
    if (version >= 2) {
      for (final c in chaptersJson) {
        final map = c as Map<String, dynamic>;
        final oldBookId = map['book_id'] as int?;
        final newBookId = oldBookId == null ? null : oldToNewBookId[oldBookId];
        if (newBookId == null) {
          chaptersSkipped++;
          continue;
        }
        final index = map['index'] as int? ?? 0;
        final local = await _repos.books.findChapterByIndex(newBookId, index);

        if (local != null) {
          final scroll = (map['scroll_position'] as num?)?.toDouble() ?? 0.0;
          if (scroll > 0) {
            await _repos.books.updateChapterScroll(local.id, scroll);
          }
          final readAtRaw = map['read_at'];
          if (readAtRaw is String) {
            final readAt = DateTime.tryParse(readAtRaw);
            if (readAt != null) {
              await _repos.books.updateChapterReadAt(local.id, readAt);
            }
          }
          final offset = map['reading_char_offset'];
          if (offset is num) {
            await _repos.books.updateChapterReadingOffset(
              local.id,
              offset.toInt(),
            );
          }
          oldToNewChapterId[map['id'] as int] = local.id;
          chaptersImported++;
        } else if (newlyImportedOldBookIds.contains(oldBookId)) {
          final chapter = Chapter.fromJson(
            map,
          ).copyWith(bookId: newBookId, id: 0);
          final newChapterId = await _repos.books.insertChapter(chapter);
          oldToNewChapterId[map['id'] as int] = newChapterId;
          chaptersImported++;
        } else {
          chaptersSkipped++;
        }
      }
    }

    final oldToNewCollectionId = <int, int>{};
    if (version >= 4) {
      final existingCollections = await _repos.snippets.getCollections();
      final byName = {for (final c in existingCollections) c.name: c};
      for (final raw in collectionsJson) {
        final col = SnippetCollection.fromJson(raw as Map<String, dynamic>);
        final existing = byName[col.name];
        if (existing != null) {
          oldToNewCollectionId[col.id] = existing.id;
        } else {
          final newId = await _repos.snippets.insertCollection(col);
          oldToNewCollectionId[col.id] = newId;
        }
      }
    }

    for (final tagName in tagsJson) {
      final name = tagName as String;
      final exists = await _repos.snippets.getTagExists(name);
      if (!exists) {
        await _repos.snippets.createTag(name);
      }
    }

    for (final s in snippetsJson) {
      final snippet = Snippet.fromJson(s as Map<String, dynamic>);
      int? remappedBookId;
      if (snippet.bookId != null) {
        remappedBookId = oldToNewBookId[snippet.bookId];
      }
      int? remappedChapterId;
      if (snippet.chapterId != null) {
        remappedChapterId = oldToNewChapterId[snippet.chapterId];
      }
      int? remappedCollectionId;
      if (snippet.collectionId != null) {
        remappedCollectionId = oldToNewCollectionId[snippet.collectionId];
      }

      try {
        await _repos.snippets.createSnippet(
          text: snippet.text,
          note: snippet.note,
          sourceTitle: snippet.sourceTitle,
          sourceUrl: snippet.sourceUrl,
          color: snippet.color,
          bookId: remappedBookId,
          chapterId: remappedChapterId,
          collectionId: remappedCollectionId,
          tags: snippet.tags,
        );
        snippetsImported++;
      } catch (_) {
        snippetsSkipped++;
      }
    }

    if (version >= 3) {
      for (final s in statsJson) {
        final stat = ReadingStat.fromJson(s as Map<String, dynamic>);
        await _repos.stats.setStatsForDate(
          stat.date,
          readingTimeSeconds: stat.readingTimeSeconds,
          snippetsCreated: stat.snippetsCreated,
          booksCompleted: stat.booksCompleted,
        );
      }
    }

    final oldToNewMangaId = <int, int>{};
    final oldCatToNew = <int, int>{};
    if (version >= 4) {
      for (final raw in categoriesJson) {
        final cat = LibraryCategory.fromJson(raw as Map<String, dynamic>);
        if (cat.name.trim().isEmpty) continue;
        final newId = await _repos.categories.upsertByName(
          LibraryCategory(
            id: 0,
            name: cat.name,
            order: cat.order,
            flags: cat.flags,
          ),
        );
        oldCatToNew[cat.id] = newId;
        categoriesImported++;
      }

      for (final raw in mangaJson) {
        final manga = Manga.fromJson(raw as Map<String, dynamic>);
        final catIds = [
          for (final id in manga.categoryIds)
            if (oldCatToNew[id] != null) oldCatToNew[id]!,
        ];
        final existing = await _repos.manga.getMangaByKey(
          manga.sourceId,
          manga.url,
        );
        if (existing == null) {
          final newId = await _repos.manga.insertManga(
            manga.copyWith(id: 0, categoryIds: catIds),
          );
          oldToNewMangaId[manga.id] = newId;
          mangaImported++;
        } else {
          oldToNewMangaId[manga.id] = existing.id;
          await _repos.manga.updateManga(
            existing.copyWith(
              inLibrary: existing.inLibrary || manga.inLibrary,
              categoryIds: {...existing.categoryIds, ...catIds}.toList(),
              notes: (existing.notes == null || existing.notes!.isEmpty)
                  ? manga.notes
                  : existing.notes,
            ),
          );
          mangaSkipped++;
        }
      }

      for (final raw in mangaChaptersJson) {
        final ch = MangaChapter.fromJson(raw as Map<String, dynamic>);
        final newMangaId = oldToNewMangaId[ch.mangaId];
        if (newMangaId == null) continue;
        final local = await _repos.manga.getMangaChapterByUrl(
          newMangaId,
          ch.url,
        );
        if (local == null) {
          await _repos.manga.putMangaChapter(
            ch.copyWith(id: 0, mangaId: newMangaId),
          );
        } else {
          await _repos.manga.putMangaChapter(
            local.copyWith(
              isRead: local.isRead || ch.isRead,
              isBookmarked: local.isBookmarked || ch.isBookmarked,
              lastPageRead: ch.lastPageRead > local.lastPageRead
                  ? ch.lastPageRead
                  : local.lastPageRead,
              readAt: _maxDate(local.readAt, ch.readAt),
              scrollPosition: ch.scrollPosition > local.scrollPosition
                  ? ch.scrollPosition
                  : local.scrollPosition,
            ),
          );
        }
        mangaChaptersImported++;
      }

      for (final raw in reposJson) {
        await _repos.extensions.insertExtensionRepo(
          ExtensionRepo.fromJson(raw as Map<String, dynamic>),
        );
        reposImported++;
      }

      for (final raw in cookiesJson) {
        final map = raw as Map<String, dynamic>;
        final host = map['host'] as String? ?? '';
        if (host.isEmpty) continue;
        await _repos.cookies.setCookie(host, map['cookie'] as String? ?? '');
        cookiesImported++;
      }

      for (final raw in bookmarksJson) {
        final bm = Bookmark.fromJson(raw as Map<String, dynamic>);
        final bookId = oldToNewBookId[bm.bookId];
        final chapterId = oldToNewChapterId[bm.chapterId];
        if (bookId == null || chapterId == null) continue;
        await _repos.bookmarks.createBookmark(
          bookId: bookId,
          chapterId: chapterId,
          pageNumber: bm.pageNumber,
          scrollPosition: bm.scrollPosition,
        );
      }

      for (final raw in highlightsJson) {
        final hl = Highlight.fromJson(raw as Map<String, dynamic>);
        final bookId = oldToNewBookId[hl.bookId];
        final chapterId = oldToNewChapterId[hl.chapterId];
        if (bookId == null || chapterId == null) continue;
        await _repos.books.insertHighlight(
          Highlight(
            id: 0,
            snippetId: hl.snippetId,
            bookId: bookId,
            chapterId: chapterId,
            startOffset: hl.startOffset,
            endOffset: hl.endOffset,
            color: hl.color,
            text: hl.text,
            createdAt: hl.createdAt,
            updatedAt: hl.updatedAt,
          ),
        );
      }
    }

    return ImportResult(
      booksImported: booksImported,
      booksSkipped: booksSkipped,
      chaptersImported: chaptersImported,
      chaptersSkipped: chaptersSkipped,
      snippetsImported: snippetsImported,
      snippetsSkipped: snippetsSkipped,
      mangaImported: mangaImported,
      mangaSkipped: mangaSkipped,
      mangaChaptersImported: mangaChaptersImported,
      categoriesImported: categoriesImported,
      reposImported: reposImported,
      cookiesImported: cookiesImported,
      version: version,
    );
  }

  static DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
