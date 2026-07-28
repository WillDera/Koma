import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_stat.dart';
import '../models/snippet.dart';
import '../repositories/repositories.dart';

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

    final export = {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'books': books.map((b) => b.toJson()).toList(),
      'chapters': chapters.map((ch) => ch.toJson()).toList(),
      'snippets': snippets.map((s) => s.toJson()).toList(),
      'tags': tags,
      'reading_stats': stats.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  Future<ImportResult> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = (data['version'] as int?) ?? 1;
    final booksJson = (data['books'] as List<dynamic>?) ?? [];
    final chaptersJson = (data['chapters'] as List<dynamic>?) ?? [];
    final snippetsJson = (data['snippets'] as List<dynamic>?) ?? [];
    final tagsJson = (data['tags'] as List<dynamic>?) ?? [];
    final statsJson = (data['reading_stats'] as List<dynamic>?) ?? [];

    int booksImported = 0;
    int booksSkipped = 0;
    int chaptersImported = 0;
    int chaptersSkipped = 0;
    int snippetsImported = 0;
    int snippetsSkipped = 0;

    await _repos.isar.writeTxn(() async {
      final oldToNewBookId = <int, int>{};
      final newlyImportedOldBookIds = <int>{};

      for (final b in booksJson) {
        final book = Book.fromJson(b as Map<String, dynamic>);
        Book? existing;
        for (final x in await _repos.books.getBooks()) {
          if (x.title == book.title && (x.author ?? '') == (book.author ?? '')) {
            existing = x;
            break;
          }
        }
        if (existing == null) {
          final newId = await _repos.books.insertBook(book);
          oldToNewBookId[book.id] = newId;
          newlyImportedOldBookIds.add(book.id);
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
            final scroll =
                (map['scroll_position'] as num?)?.toDouble() ?? 0.0;
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
            oldToNewChapterId[map['id'] as int] = local.id;
            chaptersImported++;
          } else if (newlyImportedOldBookIds.contains(oldBookId)) {
            final chapter = Chapter.fromJson(map)
                .copyWith(bookId: newBookId, id: 0);
            final newChapterId = await _repos.books.insertChapter(chapter);
            oldToNewChapterId[map['id'] as int] = newChapterId;
            chaptersImported++;
          } else {
            chaptersSkipped++;
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

        try {
          await _repos.snippets.createSnippet(
            text: snippet.text,
            note: snippet.note,
            sourceTitle: snippet.sourceTitle,
            sourceUrl: snippet.sourceUrl,
            color: snippet.color,
            bookId: remappedBookId,
            chapterId: remappedChapterId,
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
    });

    return ImportResult(
      booksImported: booksImported,
      booksSkipped: booksSkipped,
      chaptersImported: chaptersImported,
      chaptersSkipped: chaptersSkipped,
      snippetsImported: snippetsImported,
      snippetsSkipped: snippetsSkipped,
      version: version,
    );
  }
}

class ImportResult {
  final int booksImported;
  final int booksSkipped;
  final int chaptersImported;
  final int chaptersSkipped;
  final int snippetsImported;
  final int snippetsSkipped;
  final int version;

  const ImportResult({
    required this.booksImported,
    required this.booksSkipped,
    required this.chaptersImported,
    required this.chaptersSkipped,
    required this.snippetsImported,
    required this.snippetsSkipped,
    required this.version,
  });

  @override
  String toString() {
    final parts = <String>[];
    final totalBooks = booksImported + booksSkipped;
    if (totalBooks > 0) {
      final newCount =
          booksSkipped > 0 ? '$booksImported new' : '$booksImported';
      parts.add(
          '$newCount book${booksImported == 1 ? '' : 's'}'
          '${booksSkipped > 0 ? ' ($booksSkipped duplicate${booksSkipped == 1 ? '' : 's'} skipped)' : ''}');
    }
    if (chaptersImported > 0) {
      parts.add(
          '$chaptersImported chapter${chaptersImported == 1 ? '' : 's'} restored');
    }
    if (chaptersSkipped > 0) {
      parts.add(
          '$chaptersSkipped chapter${chaptersSkipped == 1 ? '' : 's'} skipped');
    }
    parts.add(
        '$snippetsImported snippet${snippetsImported == 1 ? '' : 's'}');
    if (snippetsSkipped > 0) {
      parts.add('$snippetsSkipped skipped');
    }
    return 'Imported: ${parts.join(', ')}';
  }
}
