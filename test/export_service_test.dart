import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:stashreader/core/database/database.dart';
import 'package:stashreader/core/models/book.dart';
import 'package:stashreader/core/models/chapter.dart';
import 'package:stashreader/core/models/snippet.dart';
import 'package:stashreader/core/services/database_service.dart';

import 'helpers/test_database.dart';

/// Tests JSON round-trip: export data → import data → verify integrity.
/// ExportService wraps DatabaseService.exportToJson/importFromJson + FilePicker.
/// We test the DB-level export/import logic directly.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('Model JSON round-trip', () {
    test('Book toJson/fromJson preserves fields', () {
      final book = Book(
        id: 1,
        title: 'Test Title',
        author: 'Test Author',
        coverPath: '/path/to/cover',
        source: 'local',
        sourceUrl: 'https://example.com',
        filePath: '/path/to/file.epub',
        progress: 0.42,
        currentChapterIndex: 3,
        totalChapters: 10,
      );

      final json = book.toJson();
      final restored = Book.fromJson(json);

      expect(restored.id, book.id);
      expect(restored.title, book.title);
      expect(restored.author, book.author);
      expect(restored.coverPath, book.coverPath);
      expect(restored.source, book.source);
      expect(restored.sourceUrl, book.sourceUrl);
      expect(restored.filePath, book.filePath);
      expect(restored.progress, book.progress);
      expect(restored.currentChapterIndex, book.currentChapterIndex);
      expect(restored.totalChapters, book.totalChapters);
    });

    test('Snippet toJson/fromJson preserves fields and tags', () {
      final snippet = Snippet(
        id: 1,
        text: 'Important quote',
        note: 'My thoughts',
        sourceTitle: 'Source Book',
        sourceUrl: 'https://example.com',
        color: '#FF5733',
        bookId: 5,
        chapterId: 10,
        tags: ['flutter', 'dart'],
      );

      final json = snippet.toJson();
      final restored = Snippet.fromJson(json);

      expect(restored.id, snippet.id);
      expect(restored.text, snippet.text);
      expect(restored.note, snippet.note);
      expect(restored.sourceTitle, snippet.sourceTitle);
      expect(restored.sourceUrl, snippet.sourceUrl);
      expect(restored.color, snippet.color);
      expect(restored.bookId, snippet.bookId);
      expect(restored.chapterId, snippet.chapterId);
      expect(restored.tags, ['flutter', 'dart']);
    });

    test('Snippet with null optional fields round-trips', () {
      final snippet = Snippet(
        id: 2,
        text: 'Minimal snippet',
      );

      final json = snippet.toJson();
      final restored = Snippet.fromJson(json);

      expect(restored.note, isNull);
      expect(restored.sourceTitle, isNull);
      expect(restored.sourceUrl, isNull);
      expect(restored.color, isNull);
      expect(restored.bookId, isNull);
      expect(restored.chapterId, isNull);
      expect(restored.tags, isEmpty);
    });
  });

  group('DB-level export/import', () {
    test('export format matches expected structure', () async {
      // Insert test data
      await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Exported Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );

      await db.customInsert(
        'INSERT INTO snippets (content, note, created_at, updated_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('Exported snippet'),
          Variable.withString('A note'),
          Variable.withDateTime(DateTime.now()),
          Variable.withDateTime(DateTime.now()),
        ],
      );

      // Simulate export (same logic as DatabaseService.exportToJson)
      final bookRows =
          await db.customSelect('SELECT * FROM books ORDER BY updated_at DESC').get();
      final snippetRows =
          await db.customSelect('SELECT * FROM snippets ORDER BY created_at DESC').get();

      final export = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'books': bookRows.map((r) {
          return Book(
            id: r.data['id'] as int,
            title: r.data['title'] as String,
            author: r.data['author'] as String?,
            source: r.data['source'] as String? ?? 'local',
          ).toJson();
        }).toList(),
        'snippets': snippetRows.map((r) {
          return Snippet(
            id: r.data['id'] as int,
            text: r.data['content'] as String,
            note: r.data['note'] as String?,
          ).toJson();
        }).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(export);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['version'], 1);
      expect(parsed['exported_at'], isNotNull);
      expect(parsed['books'], isA<List>());
      expect(parsed['books'].length, 1);
      expect(parsed['snippets'], isA<List>());
      expect(parsed['snippets'].length, 1);
      expect(parsed['books'][0]['title'], 'Exported Book');
      expect(parsed['snippets'][0]['text'], 'Exported snippet');
    });

    test('import data integrity round-trip', () async {
      // Create export JSON
      final exportData = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'books': [
          Book(
            id: 1,
            title: 'Imported Book',
            author: 'Import Author',
            source: 'local',
            progress: 0.25,
            totalChapters: 8,
          ).toJson(),
        ],
        'snippets': [
          Snippet(
            id: 1,
            text: 'Imported snippet text',
            note: 'Import note',
            tags: ['import', 'test'],
          ).toJson(),
        ],
      };

      final jsonStr = jsonEncode(exportData);

      // Simulate import (same logic as DatabaseService.importFromJson)
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final books = data['books'] as List? ?? [];
      final snippets = data['snippets'] as List? ?? [];

      for (final b in books) {
        final book = Book.fromJson(b as Map<String, dynamic>);
        await db.customInsert(
          'INSERT INTO books (title, author, source, progress, total_chapters) '
          'VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(book.title),
            Variable.withString(book.author ?? ''),
            Variable.withString(book.source),
            Variable.withReal(book.progress),
            Variable.withInt(book.totalChapters),
          ],
        );
      }

      for (final s in snippets) {
        final snippet = Snippet.fromJson(s as Map<String, dynamic>);
        await db.customInsert(
          'INSERT INTO snippets (content, note, created_at, updated_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(snippet.text),
            Variable.withString(snippet.note ?? ''),
            Variable.withDateTime(DateTime.now()),
            Variable.withDateTime(DateTime.now()),
          ],
        );
      }

      // Verify data was imported correctly
      final importedBooks =
          await db.customSelect('SELECT * FROM books').get();
      expect(importedBooks.length, 1);
      expect(importedBooks.first.data['title'], 'Imported Book');
      expect(importedBooks.first.data['author'], 'Import Author');
      expect((importedBooks.first.data['progress'] as num).toDouble(), 0.25);
      expect(importedBooks.first.data['total_chapters'], 8);

      final importedSnippets =
          await db.customSelect('SELECT * FROM snippets').get();
      expect(importedSnippets.length, 1);
      expect(importedSnippets.first.data['content'], 'Imported snippet text');
      expect(importedSnippets.first.data['note'], 'Import note');
    });

    test('import skips duplicate books by title+author', () async {
      // Insert a book
      await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Existing Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );

      // Try to import the same book
      final importData = {
        'books': [
          Book(
            id: 1,
            title: 'Existing Book',
            author: 'Author',
            source: 'local',
          ).toJson(),
        ],
        'snippets': [],
      };

      final data = importData;
      final List books = data['books'] ?? [];

      for (final b in books) {
        final book = Book.fromJson(b as Map<String, dynamic>);
        final existing = await db
            .customSelect(
                'SELECT id FROM books WHERE title = ? AND author = ?',
                variables: [
              Variable.withString(book.title),
              Variable.withString(book.author ?? ''),
            ])
            .get();
        if (existing.isEmpty) {
          await db.customInsert(
            'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
            variables: [
              Variable.withString(book.title),
              Variable.withString(book.author ?? ''),
              Variable.withString(book.source),
            ],
          );
        }
      }

      final allBooks = await db.customSelect('SELECT * FROM books').get();
      expect(allBooks.length, 1); // No duplicate created
    });

    test('empty export contains version and empty arrays', () {
      final export = {
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'books': <Map<String, dynamic>>[],
        'chapters': <Map<String, dynamic>>[],
        'snippets': <Map<String, dynamic>>[],
      };

      final jsonStr = jsonEncode(export);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['version'], 2);
      expect(parsed['books'], isEmpty);
      expect(parsed['chapters'], isEmpty);
      expect(parsed['snippets'], isEmpty);
    });
  });

  group('DatabaseService round-trip', () {
    late DatabaseService svc;
    setUp(() {
      svc = DatabaseService(db);
    });

    test('export then import restores books, chapter progress, snippets',
        () async {
      // 1. Populate the source DB.
      final bookId = await svc.insertBook(Book(
        id: 0,
        title: 'Lord of Mysteries',
        author: 'Cuttlefish',
        source: 'local',
        progress: 0,
        totalChapters: 5,
      ));
      await svc.insertChapters([
        Chapter(
            id: 0,
            bookId: bookId,
            title: 'Chapter 1',
            content: 'Clown content',
            index: 0,
            scrollPosition: 12.5),
        Chapter(
            id: 0,
            bookId: bookId,
            title: 'Chapter 2',
            content: 'More content',
            index: 1,
            scrollPosition: 200,
            readAt: DateTime(2026, 1, 1)),
        Chapter(
            id: 0, bookId: bookId, title: 'Chapter 3', content: '...', index: 2),
      ]);
      // Get real chapter IDs from DB (constructor id=0 is placeholder).
      final saved = await svc.getChapters(bookId);
      await svc.createSnippet(
        text: 'SUDDEN TURN OF EVENTS',
        sourceTitle: 'Lord of Mysteries Volume 1: Clown',
        bookId: bookId,
        chapterId: saved[0].id,
        tags: const ['highlight'],
      );

      // 2. Export.
      final jsonStr = await svc.exportToJson();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['version'], 3);
      expect((parsed['books'] as List).length, 1);
      expect((parsed['chapters'] as List).length, 3);
      expect((parsed['snippets'] as List).length, 1);
      expect((parsed['tags'] as List).length, 1);
      // Content IS exported in v3.
      expect((parsed['chapters'] as List)[0]['content'], 'Clown content');

      // 3. Clear the DB and import.
      await db.customUpdate('DELETE FROM snippets');
      await db.customUpdate('DELETE FROM chapters');
      await db.customUpdate('DELETE FROM books');

      final result = await svc.importFromJson(jsonStr);
      expect(result.booksImported, 1);
      expect(result.chaptersImported, 3);
      expect(result.snippetsImported, 1);
      expect(result.toString(), contains('1 book'));
      expect(result.toString(), contains('3 chapters restored'));
      expect(result.toString(), contains('1 snippet'));

      // 4. Verify state.
      final books = await svc.getBooks();
      expect(books.length, 1);
      expect(books.first.title, 'Lord of Mysteries');
      expect(books.first.author, 'Cuttlefish');

      final restoredChapters = await svc.getChapters(books.first.id);
      expect(restoredChapters.length, 3);
      expect(restoredChapters[0].content, 'Clown content');
      expect(restoredChapters[1].content, 'More content');
      expect(restoredChapters[0].scrollPosition, 12.5);
      expect(restoredChapters[1].scrollPosition, 200);
      expect(restoredChapters[1].readAt, isNotNull);
      expect(restoredChapters[2].scrollPosition, 0);

      final snippets = await svc.getSnippets();
      expect(snippets.length, 1);
      expect(snippets.first.text, 'SUDDEN TURN OF EVENTS');
      expect(snippets.first.sourceTitle, 'Lord of Mysteries Volume 1: Clown');
      expect(snippets.first.bookId, books.first.id);
      expect(snippets.first.chapterId, isNotNull);
      expect(snippets.first.chapterId, restoredChapters[0].id);
      expect(snippets.first.tags, ['highlight']);
    });

    test('v1 backup (no chapters block) still imports', () async {
      // 1. Populate source DB.
      final bookId = await svc.insertBook(Book(
        id: 0,
        title: 'Pre-v2 Book',
        author: 'Author',
        source: 'local',
      ));
      await svc.createSnippet(
        text: 'Pre-v2 snippet',
        sourceTitle: 'Pre-v2 Book',
        bookId: bookId,
        tags: const ['old'],
      );

      // 2. Manually craft a v1 backup (no chapters block).
      final v1Json = jsonEncode({
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'books': [
          Book(
                  id: 7,
                  title: 'Pre-v2 Book',
                  author: 'Author',
                  source: 'local')
              .toJson()
        ],
        'snippets': [
          Snippet(
                  id: 7,
                  text: 'Pre-v2 snippet',
                  sourceTitle: 'Pre-v2 Book',
                  bookId: 7,
                  tags: const ['old'])
              .toJson()
        ],
      });

      // 3. Wipe and import.
      await db.customUpdate('DELETE FROM snippets');
      await db.customUpdate('DELETE FROM chapters');
      await db.customUpdate('DELETE FROM books');

      final result = await svc.importFromJson(v1Json);
      expect(result.version, 1);
      expect(result.booksImported, 1);
      expect(result.chaptersImported, 0);
      expect(result.snippetsImported, 1);
    });

    test('import skips duplicate books by title+author', () async {
      await svc.insertBook(Book(
        id: 0,
        title: 'Existing',
        author: 'Author',
        source: 'local',
      ));
      final json = jsonEncode({
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'books': [
          Book(
                  id: 99,
                  title: 'Existing',
                  author: 'Author',
                  source: 'local')
              .toJson()
        ],
        'chapters': <Map<String, dynamic>>[],
        'snippets': <Map<String, dynamic>>[],
      });
      final result = await svc.importFromJson(json);
      expect(result.booksImported, 0);
      expect(result.booksSkipped, 1);
      final allBooks = await svc.getBooks();
      expect(allBooks.length, 1);
    });
  });
}
