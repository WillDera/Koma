import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/book.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/models/snippet.dart';
import 'package:koma/core/repositories/repositories.dart';
import 'package:koma/core/services/search_service.dart';

import 'helpers/test_database.dart';

void main() {
  late Repositories repos;
  late SearchService service;

  setUp(() async {
    repos = await createTestRepositories();
    service = SearchService(repos);

    // Seed test data
    final book1Id = await repos.books.insertBook(
      Book(
        id: 0,
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        source: 'local',
      ),
    );
    await repos.books.insertBook(
      Book(id: 0, title: 'Dart in Action', author: 'John Doe', source: 'local'),
    );

    await repos.books.insertChapter(
      Chapter(
        id: 0,
        bookId: book1Id,
        title: 'Chapter 1',
        content:
            'In my younger and more vulnerable years my father gave me some advice.',
        index: 0,
      ),
    );
    await repos.books.insertChapter(
      Chapter(
        id: 0,
        bookId: book1Id,
        title: 'Chapter 2',
        content: 'The wind blew and the green light twinkled across the bay.',
        index: 1,
      ),
    );

    await repos.snippets.createSnippet(
      text: 'So we beat on, boats against the current.',
      note: 'Closing line',
      sourceTitle: 'The Great Gatsby',
    );
  });

  group('searchAll', () {
    test('returns mixed results from books, chapters, and snippets', () async {
      final results = await service.searchAll('gatsby');
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
      expect((books.first.item as Book).title, 'The Great Gatsby');
    });

    test('finds book by author', () async {
      final books = await service.searchBooks('Fitzgerald');
      expect(books.length, 1);
      expect((books.first.item as Book).title, 'The Great Gatsby');
    });

    test('returns empty for blank query', () async {
      expect(await service.searchBooks(''), isEmpty);
    });
  });

  group('searchChapters', () {
    test('finds chapter by content', () async {
      final chapters = await service.searchChapters('vulnerable');
      expect(chapters.length, 1);
      expect((chapters.first.item as Chapter).title, 'Chapter 1');
    });

    test('finds chapter by title', () async {
      final chapters = await service.searchChapters('Chapter 2');
      expect(chapters.length, 1);
      expect((chapters.first.item as Chapter).content, contains('wind blew'));
    });

    test('returns empty for blank query', () async {
      expect(await service.searchChapters(''), isEmpty);
    });
  });

  group('searchSnippets', () {
    test('finds snippet by content', () async {
      final snippets = await service.searchSnippets('beat on');
      expect(snippets.length, 1);
      expect(
        (snippets.first.item as Snippet).text,
        contains('boats against the current'),
      );
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
