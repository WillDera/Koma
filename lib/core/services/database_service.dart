import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import '../database/database.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/snippet.dart';
import '../models/reading_stat.dart';

class DatabaseService {
  final AppDatabase _db;
  static DatabaseService? _instance;

  DatabaseService(this._db);

  static Future<DatabaseService> getInstance() async {
    if (_instance == null) {
      final db = await AppDatabase.create();
      _instance = DatabaseService(db);
    }
    return _instance!;
  }

  AppDatabase get db => _db;

  // -- Books --

  Future<List<Book>> getBooks() async {
    final rows = await _db.customSelect('SELECT * FROM books ORDER BY updated_at DESC').get();
    return rows.map((r) => _bookFromRow(r.data)).toList();
  }

  Future<Book?> getBook(int id) async {
    final rows = await _db
        .customSelect('SELECT * FROM books WHERE id = ?',
            variables: [Variable.withInt(id)])
        .get();
    if (rows.isEmpty) return null;
    return _bookFromRow(rows.first.data);
  }

  Future<Book?> findLocalBook(String title, String? author) async {
    final rows = await _db
        .customSelect('SELECT * FROM books WHERE title = ? AND author = ? AND source = ?',
            variables: [
          Variable.withString(title),
          Variable.withString(author ?? ''),
          Variable.withString('local'),
        ]).get();
    if (rows.isEmpty) return null;
    return _bookFromRow(rows.first.data);
  }

  Future<int> insertBook(Book book) async {
    final id = await _db.customInsert(
      'INSERT INTO books (title, author, cover_path, source, source_url, file_path, progress, current_chapter_index, total_chapters, scroll_position) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(book.title),
        Variable.withString(book.author ?? ''),
        Variable.withString(book.coverPath ?? ''),
        Variable.withString(book.source),
        Variable.withString(book.sourceUrl ?? ''),
        Variable.withString(book.filePath ?? ''),
        Variable.withReal(book.progress),
        Variable.withInt(book.currentChapterIndex),
        Variable.withInt(book.totalChapters),
        Variable.withReal(book.scrollPosition),
      ],
    );
    return id;
  }

  Future<void> updateBook(Book book) async {
    await _db.customUpdate(
      'UPDATE books SET title=?, author=?, cover_path=?, source=?, source_url=?, '
      'file_path=?, progress=?, current_chapter_index=?, total_chapters=?, updated_at=? '
      'WHERE id=?',
      variables: [
        Variable.withString(book.title),
        Variable.withString(book.author ?? ''),
        Variable.withString(book.coverPath ?? ''),
        Variable.withString(book.source),
        Variable.withString(book.sourceUrl ?? ''),
        Variable.withString(book.filePath ?? ''),
        Variable.withReal(book.progress),
        Variable.withInt(book.currentChapterIndex),
        Variable.withInt(book.totalChapters),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(book.id),
      ],
    );
  }

  Future<void> updateProgress(int bookId, double progress, {int? currentChapterIndex, double scrollPosition = 0.0}) async {
    await _db.customUpdate(
      'UPDATE books SET progress=?, current_chapter_index=?, scroll_position=?, updated_at=? WHERE id=?',
      variables: [
        Variable.withReal(progress),
        Variable.withInt(currentChapterIndex ?? 0),
        Variable.withReal(scrollPosition),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(bookId),
      ],
    );
  }

  Future<void> deleteBook(int id) async {
    await _db.customUpdate(
      'DELETE FROM books WHERE id=?',
      variables: [Variable.withInt(id)],
    );
  }

  // -- Chapters --

  Future<List<Chapter>> getChapters(int bookId) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM chapters WHERE book_id = ? ORDER BY "index" ASC',
            variables: [Variable.withInt(bookId)])
        .get();
    return rows.map((r) => _chapterFromRow(r.data)).toList();
  }

  Future<Chapter?> getChapter(int id) async {
    final rows = await _db
        .customSelect('SELECT * FROM chapters WHERE id = ?',
            variables: [Variable.withInt(id)])
        .get();
    if (rows.isEmpty) return null;
    return _chapterFromRow(rows.first.data);
  }

  Future<int> insertChapter(Chapter chapter) async {
    return await _db.customInsert(
      'INSERT INTO chapters (book_id, title, content, "index", read_at, scroll_position) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withInt(chapter.bookId),
        Variable.withString(chapter.title),
        Variable.withString(chapter.content),
        Variable.withInt(chapter.index),
        chapter.readAt != null
            ? Variable.withDateTime(chapter.readAt!)
            : Variable<DateTime>(null),
        Variable.withReal(chapter.scrollPosition),
      ],
    );
  }

  Future<void> insertChapters(List<Chapter> chapters) async {
    await _db.transaction(() async {
      for (final ch in chapters) {
        await _db.customInsert(
          'INSERT INTO chapters (book_id, title, content, "index", read_at, scroll_position) VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(ch.bookId),
            Variable.withString(ch.title),
            Variable.withString(ch.content),
            Variable.withInt(ch.index),
            ch.readAt != null
                ? Variable.withDateTime(ch.readAt!)
                : Variable<DateTime>(null),
            Variable.withReal(ch.scrollPosition),
          ],
        );
      }
    });
  }

  Future<void> markChapterRead(int chapterId) async {
    await _db.customUpdate(
      'UPDATE chapters SET read_at=? WHERE id=?',
      variables: [
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(chapterId),
      ],
    );
  }

  /// Persist the per-chapter scroll position.  Cheap; safe to call on
  /// every scroll tick (the surrounding reader debounces).
  Future<void> updateChapterScroll(int chapterId, double position) async {
    await _db.customUpdate(
      'UPDATE chapters SET scroll_position=? WHERE id=?',
      variables: [
        Variable.withReal(position),
        Variable.withInt(chapterId),
      ],
    );
  }

  /// Find a chapter by its (book_id, index) — used by import to
  /// remap a backup's chapter reference onto the user's local copy
  /// of the same chapter.
  Future<Chapter?> findChapterByIndex(int bookId, int index) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM chapters WHERE book_id = ? AND "index" = ? LIMIT 1',
            variables: [Variable.withInt(bookId), Variable.withInt(index)])
        .get();
    if (rows.isEmpty) return null;
    return _chapterFromRow(rows.first.data);
  }

  // -- Snippets --

  Future<List<Snippet>> getSnippets() async {
    final rows = await _db
        .customSelect('SELECT * FROM snippets ORDER BY created_at DESC')
        .get();
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r.data['id'] as int).toList();
    final tagMap = await _batchGetTags(ids);
    return rows.map((r) => _snippetFromRow(r.data, tagMap[r.data['id'] as int] ?? [])).toList();
  }

  Future<List<Snippet>> getSnippetsForBook(int bookId) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM snippets WHERE book_id = ? ORDER BY created_at DESC',
            variables: [Variable.withInt(bookId)])
        .get();
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r.data['id'] as int).toList();
    final tagMap = await _batchGetTags(ids);
    return rows.map((r) => _snippetFromRow(r.data, tagMap[r.data['id'] as int] ?? [])).toList();
  }

  Future<Snippet?> getSnippet(int id) async {
    final rows = await _db
        .customSelect('SELECT * FROM snippets WHERE id = ?',
            variables: [Variable.withInt(id)])
        .get();
    if (rows.isEmpty) return null;
    return await _snippetFromRow(rows.first.data, await _getTagsForSnippet(id));
  }

  Future<int> createSnippet({
    required String text,
    String? note,
    String? sourceTitle,
    String? sourceUrl,
    String? color,
    int? bookId,
    int? chapterId,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final id = await _db.customInsert(
      'INSERT INTO snippets (content, note, source_title, source_url, color, book_id, chapter_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(text),
        Variable.withString(note ?? ''),
        Variable.withString(sourceTitle ?? ''),
        Variable.withString(sourceUrl ?? ''),
        Variable.withString(color ?? ''),
        bookId != null ? Variable.withInt(bookId) : Variable<int>(null),
        chapterId != null ? Variable.withInt(chapterId) : Variable<int>(null),
        Variable.withDateTime(now),
        Variable.withDateTime(now),
      ],
    );
    await _setSnippetTags(id, tags);
    return id;
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await _db.customUpdate(
      'UPDATE snippets SET content=?, note=?, source_title=?, source_url=?, '
      'color=?, book_id=?, chapter_id=?, updated_at=? WHERE id=?',
      variables: [
        Variable.withString(snippet.text),
        Variable.withString(snippet.note ?? ''),
        Variable.withString(snippet.sourceTitle ?? ''),
        Variable.withString(snippet.sourceUrl ?? ''),
        Variable.withString(snippet.color ?? ''),
        snippet.bookId != null
            ? Variable.withInt(snippet.bookId!)
            : Variable<int>(null),
        snippet.chapterId != null
            ? Variable.withInt(snippet.chapterId!)
            : Variable<int>(null),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(snippet.id),
      ],
    );
    await _setSnippetTags(snippet.id, snippet.tags);
  }

  Future<void> deleteSnippet(int id) async {
    await _db.customUpdate(
      'DELETE FROM snippets WHERE id=?',
      variables: [Variable.withInt(id)],
    );
  }

  // -- Tags --

  Future<List<String>> getAllTags() async {
    final rows =
        await _db.customSelect('SELECT name FROM tags ORDER BY name').get();
    return rows.map((r) => r.data['name'] as String).toList();
  }

  Future<void> _ensureTag(String name) async {
    final existing = await _db
        .customSelect('SELECT id FROM tags WHERE name = ?',
            variables: [Variable.withString(name)])
        .get();
    if (existing.isEmpty) {
      await _db.customInsert('INSERT INTO tags (name) VALUES (?)',
          variables: [Variable.withString(name)]);
    }
  }

  Future<int?> _getTagId(String name) async {
    final rows = await _db
        .customSelect('SELECT id FROM tags WHERE name = ?',
            variables: [Variable.withString(name)])
        .get();
    if (rows.isEmpty) return null;
    return rows.first.data['id'] as int;
  }

  Future<void> _setSnippetTags(int snippetId, List<String> tagNames) async {
    await _db.customUpdate(
      'DELETE FROM snippet_tags WHERE snippet_id=?',
      variables: [Variable.withInt(snippetId)],
    );
    for (final name in tagNames) {
      await _ensureTag(name);
      final tagId = await _getTagId(name);
      if (tagId == null) continue;
      await _db.customInsert(
        'INSERT OR IGNORE INTO snippet_tags (snippet_id, tag_id) VALUES (?, ?)',
        variables: [Variable.withInt(snippetId), Variable.withInt(tagId)],
      );
    }
  }

  Future<List<String>> _getTagsForSnippet(int snippetId) async {
    final rows = await _db.customSelect(
      'SELECT t.name FROM tags t '
      'INNER JOIN snippet_tags st ON st.tag_id = t.id '
      'WHERE st.snippet_id = ? ORDER BY t.name',
      variables: [Variable.withInt(snippetId)],
    ).get();
    return rows.map((r) => r.data['name'] as String).toList();
  }

  Future<Map<int, List<String>>> _batchGetTags(List<int> snippetIds) async {
    if (snippetIds.isEmpty) return {};
    final placeholders = snippetIds.map((_) => '?').join(',');
    final rows = await _db.customSelect(
      'SELECT st.snippet_id, t.name FROM tags t '
      'INNER JOIN snippet_tags st ON st.tag_id = t.id '
      'WHERE st.snippet_id IN ($placeholders) ORDER BY t.name',
      variables: snippetIds.map((id) => Variable.withInt(id)).toList(),
    ).get();
    final map = <int, List<String>>{};
    for (final r in rows) {
      final sid = r.data['snippet_id'] as int;
      map.putIfAbsent(sid, () => []).add(r.data['name'] as String);
    }
    return map;
  }

  // -- Reading Stats --

  Future<ReadingStat?> getStatsForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final rows = await _db
        .customSelect('SELECT * FROM reading_stats WHERE date = ?',
            variables: [Variable.withDateTime(day)])
        .get();
    if (rows.isEmpty) return null;
    return _statFromRow(rows.first.data);
  }

  Future<void> upsertStatsForDate(
    DateTime date, {
    int readingTimeSeconds = 0,
    int snippetsCreated = 0,
    int booksCompleted = 0,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    await _db.customInsert(
      'INSERT INTO reading_stats (date, reading_time_seconds, snippets_created, books_completed) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(date) DO UPDATE SET '
      'reading_time_seconds = reading_time_seconds + excluded.reading_time_seconds, '
      'snippets_created = snippets_created + excluded.snippets_created, '
      'books_completed = books_completed + excluded.books_completed',
      variables: [
        Variable.withDateTime(day),
        Variable.withInt(readingTimeSeconds),
        Variable.withInt(snippetsCreated),
        Variable.withInt(booksCompleted),
      ],
    );
  }

  Future<List<ReadingStat>> getStatsRange(DateTime start, DateTime end) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM reading_stats WHERE date >= ? AND date <= ? ORDER BY date',
            variables: [
          Variable.withDateTime(start),
          Variable.withDateTime(end),
        ]).get();
    return rows.map((r) => _statFromRow(r.data)).toList();
  }

  // -- Export / Import --

  Future<String> exportToJson() async {
    final books = await getBooks();
    final snippets = await getSnippets();
    final chapterRows = await _db
        .customSelect(
            'SELECT id, book_id, title, content, "index", read_at, scroll_position FROM chapters ORDER BY book_id, "index" ASC')
        .get();
    final chapters = chapterRows
        .map((r) => _chapterFromRow(r.data))
        .map((ch) => ch.toJson())
        .toList();

    final tagRows = await _db
        .customSelect('SELECT name FROM tags ORDER BY name').get();
    final tags = tagRows.map((r) => r.data['name'] as String).toList();

    final statRows = await _db
        .customSelect('SELECT * FROM reading_stats ORDER BY date').get();
    final stats = statRows
        .map((r) => _statFromRow(r.data).toJson())
        .toList();

    final export = {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'books': books.map((b) => b.toJson()).toList(),
      'chapters': chapters,
      'snippets': snippets.map((s) => s.toJson()).toList(),
      'tags': tags,
      'reading_stats': stats,
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


    await _db.transaction(() async {
      // 1. Books.  Build old → new book id map so we can remap
      // chapter and snippet references.
      final oldToNewBookId = <int, int>{};
      final newlyImportedOldBookIds = <int>{};
      for (final b in booksJson) {
        final book = Book.fromJson(b as Map<String, dynamic>);
        final existing = await _db
            .customSelect(
                'SELECT id FROM books WHERE title = ? AND author = ?',
                variables: [
                  Variable.withString(book.title),
                  Variable.withString(book.author ?? ''),
                ]).get();
        if (existing.isEmpty) {
          final newId = await insertBook(book);
          oldToNewBookId[book.id] = newId;
          newlyImportedOldBookIds.add(book.id);
          booksImported++;
        } else {
          oldToNewBookId[book.id] = existing.first.data['id'] as int;
          booksSkipped++;
        }
      }

      // 2. Chapters.  v3+ exports include full chapter content; v2
      // exports have metadata only.  For newly imported books we
      // insert chapters with content.  For existing books we restore
      // scroll_position and read_at via index matching.
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
          final local = await findChapterByIndex(newBookId, index);

          if (local != null) {
            final scroll =
                (map['scroll_position'] as num?)?.toDouble() ?? 0.0;
            if (scroll > 0) {
              await updateChapterScroll(local.id, scroll);
            }
            final readAtRaw = map['read_at'];
            if (readAtRaw is String) {
              final readAt = DateTime.tryParse(readAtRaw);
              if (readAt != null) {
                await _db.customUpdate(
                  'UPDATE chapters SET read_at=? WHERE id=?',
                  variables: [
                    Variable.withDateTime(readAt),
                    Variable.withInt(local.id),
                  ],
                );
              }
            }
            oldToNewChapterId[map['id'] as int] = local.id;
            chaptersImported++;
          } else if (newlyImportedOldBookIds.contains(oldBookId)) {
            final chapter = Chapter.fromJson(map)
                .copyWith(bookId: newBookId, id: 0);
            final newChapterId = await insertChapter(chapter);
            oldToNewChapterId[map['id'] as int] = newChapterId;
            chaptersImported++;
          } else {
            chaptersSkipped++;
          }
        }
      }

      // 3. Tags.  Ensure all exported tags exist (v3+).
      for (final tagName in tagsJson) {
        await _ensureTag(tagName as String);
      }

      // 4. Snippets.  Remap bookId and chapterId.
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
          await createSnippet(
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

      // 5. Reading stats (v3+).
      if (version >= 3) {
        for (final s in statsJson) {
          final stat = ReadingStat.fromJson(s as Map<String, dynamic>);
          await _db.customInsert(
            'INSERT OR REPLACE INTO reading_stats (date, reading_time_seconds, snippets_created, books_completed) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString(
                  stat.date.toIso8601String().substring(0, 10)),
              Variable.withInt(stat.readingTimeSeconds),
              Variable.withInt(stat.snippetsCreated),
              Variable.withInt(stat.booksCompleted),
            ],
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

  // -- Row parsers --

  Book _bookFromRow(Map<String, dynamic> row) {
    return Book(
      id: row['id'] as int,
      title: row['title'] as String,
      author: row['author'] as String?,
      coverPath: row['cover_path'] as String?,
      source: row['source'] as String? ?? 'local',
      sourceUrl: row['source_url'] as String?,
      filePath: row['file_path'] as String?,
      progress: (row['progress'] as num?)?.toDouble() ?? 0.0,
      currentChapterIndex: row['current_chapter_index'] as int? ?? 0,
      totalChapters: row['total_chapters'] as int? ?? 0,
      scrollPosition: (row['scroll_position'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Chapter _chapterFromRow(Map<String, dynamic> row) {
    final readAtRaw = row['read_at'];
    DateTime? readAt;
    if (readAtRaw is int) {
      readAt = DateTime.fromMillisecondsSinceEpoch(readAtRaw);
    } else if (readAtRaw is double) {
      readAt = DateTime.fromMillisecondsSinceEpoch(readAtRaw.toInt());
    } else if (readAtRaw is String) {
      readAt = DateTime.tryParse(readAtRaw);
      if (readAt == null) {
        final ms = int.tryParse(readAtRaw);
        if (ms != null) {
          readAt = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    } else if (readAtRaw != null) {
      final n = readAtRaw as num;
      readAt = DateTime.fromMillisecondsSinceEpoch(n.toInt());
    }
    return Chapter(
      id: row['id'] as int,
      bookId: row['book_id'] as int,
      title: row['title'] as String,
      content: row['content'] as String,
      index: row['index'] as int,
      readAt: readAt,
      scrollPosition: (row['scroll_position'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Snippet _snippetFromRow(Map<String, dynamic> row, [List<String>? preloadedTags]) {
    final sid = row['id'] as int;
    return Snippet(
      id: sid,
      text: row['content'] as String,
      note: row['note'] as String?,
      sourceTitle: row['source_title'] as String?,
      sourceUrl: row['source_url'] as String?,
      color: row['color'] as String?,
      bookId: row['book_id'] as int?,
      chapterId: row['chapter_id'] as int?,
      tags: preloadedTags ?? [],
    );
  }

  ReadingStat _statFromRow(Map<String, dynamic> row) {
    final dateRaw = row['date'];
    final date = dateRaw is String ? DateTime.parse(dateRaw) : dateRaw as DateTime;
    return ReadingStat(
      id: row['id'] as int,
      date: date,
      readingTimeSeconds: row['reading_time_seconds'] as int? ?? 0,
      snippetsCreated: row['snippets_created'] as int? ?? 0,
      booksCompleted: row['books_completed'] as int? ?? 0,
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
