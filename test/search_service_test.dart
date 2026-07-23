import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:koma/core/database/database.dart';
import 'package:koma/core/services/search_service.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SearchService service;

  setUp(() async {
    db = await createTestDb();
    service = SearchService(db);

    // Seed test data
    await db.customInsert(
      'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
      variables: [
        Variable.withString('The Great Gatsby'),
        Variable.withString('F. Scott Fitzgerald'),
        Variable.withString('local'),
      ],
    );
    await db.customInsert(
      'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
      variables: [
        Variable.withString('Dart in Action'),
        Variable.withString('John Doe'),
        Variable.withString('local'),
      ],
    );

    final bookId = (await db
            .customSelect('SELECT id FROM books WHERE title = ?',
                variables: [Variable.withString('The Great Gatsby')])
            .get())
        .first
        .data['id'] as int;

    await db.customInsert(
      'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withInt(bookId),
        Variable.withString('Chapter 1'),
        Variable.withString('In my younger and more vulnerable years my father gave me some advice.'),
        Variable.withInt(0),
      ],
    );
    await db.customInsert(
      'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withInt(bookId),
        Variable.withString('Chapter 2'),
        Variable.withString('The wind blew and the green light twinkled across the bay.'),
        Variable.withInt(1),
      ],
    );

    await db.customInsert(
      'INSERT INTO snippets (content, note, source_title, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('So we beat on, boats against the current.'),
        Variable.withString('Closing line'),
        Variable.withString('The Great Gatsby'),
        Variable.withDateTime(DateTime.now()),
        Variable.withDateTime(DateTime.now()),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('searchAll', () {
    test('returns mixed results from books, chapters, and snippets', () async {
      final results = await service.searchAll('gatsby');
      // Should match: 1 book (title), 0 chapters, 1 snippet (source_title)
      expect(results.length, greaterThanOrEqualTo(2));
      final types = results.map((r) => r.type).toSet();
      expect(types, contains('book'));
      expect(types, contains('snippet'));
    });

    test('returns chapter matches', () async {
      final results = await service.searchAll('vulnerable');
      expect(results.length, 1);
      expect(results.first.type, 'chapter');
    });

    test('returns empty list for no matches', () async {
      final results = await service.searchAll('nonexistent query xyz');
      expect(results, isEmpty);
    });

    test('returns empty for blank query', () async {
      expect(await service.searchAll(''), isEmpty);
      expect(await service.searchAll('   '), isEmpty);
    });
  });

  group('searchBooks', () {
    test('finds book by title', () async {
      final books = await service.searchBooks('gatsby');
      expect(books.length, 1);
      expect(books.first.title, 'The Great Gatsby');
    });

    test('finds book by author', () async {
      final books = await service.searchBooks('Fitzgerald');
      expect(books.length, 1);
      expect(books.first.title, 'The Great Gatsby');
    });

    test('returns empty for blank query', () async {
      expect(await service.searchBooks(''), isEmpty);
    });
  });

  group('searchChapters', () {
    test('finds chapter by content', () async {
      final chapters = await service.searchChapters('vulnerable');
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Chapter 1');
    });

    test('finds chapter by title', () async {
      final chapters = await service.searchChapters('Chapter 2');
      expect(chapters.length, 1);
      expect(chapters.first.content, contains('wind blew'));
    });

    test('returns empty for blank query', () async {
      expect(await service.searchChapters(''), isEmpty);
    });
  });

  group('searchSnippets', () {
    test('finds snippet by content', () async {
      final snippets = await service.searchSnippets('beat on');
      expect(snippets.length, 1);
      expect(snippets.first.text, contains('boats against the current'));
    });

    test('finds snippet by source_title', () async {
      final snippets = await service.searchSnippets('Great Gatsby');
      expect(snippets.length, 1);
    });

    test('finds snippet by note', () async {
      final snippets = await service.searchSnippets('Closing line');
      expect(snippets.length, 1);
    });

    test('returns empty for blank query', () async {
      expect(await service.searchSnippets(''), isEmpty);
    });
  });

  group('SearchResult', () {
    test('matchPreview is populated', () async {
      final results = await service.searchAll('gatsby');
      final bookResult = results.firstWhere((r) => r.type == 'book');
      expect(bookResult.matchPreview, isNotEmpty);
    });
  });
}
