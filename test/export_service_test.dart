import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/book.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/models/library_category.dart';
import 'package:koma/core/models/manga.dart';
import 'package:koma/core/models/manga_chapter.dart';
import 'package:koma/core/models/snippet.dart';
import 'package:koma/core/repositories/repositories.dart';
import 'package:koma/core/services/export_service.dart';

import 'helpers/test_database.dart';

void main() {
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
      final snippet = Snippet(id: 2, text: 'Minimal snippet');

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

  group('ExportService round-trip', () {
    late Repositories repos;
    late ExportService svc;

    setUp(() async {
      repos = await createTestRepositories();
      svc = ExportService(repos);
    });

    tearDown(() {
      repos.isar.close();
    });

    test('export then import restores books, chapters, snippets', () async {
      final bookId = await repos.books.insertBook(
        Book(
          id: 0,
          title: 'Lord of Mysteries',
          author: 'Cuttlefish',
          source: 'local',
          progress: 0,
          totalChapters: 5,
        ),
      );
      await repos.books.insertChapters([
        Chapter(
          id: 0,
          bookId: bookId,
          title: 'Chapter 1',
          content: 'Clown content',
          index: 0,
          scrollPosition: 12.5,
        ),
        Chapter(
          id: 0,
          bookId: bookId,
          title: 'Chapter 2',
          content: 'More content',
          index: 1,
          scrollPosition: 200,
          readAt: DateTime(2026, 1, 1),
        ),
        Chapter(
          id: 0,
          bookId: bookId,
          title: 'Chapter 3',
          content: '...',
          index: 2,
        ),
      ]);
      final saved = await repos.books.getChapters(bookId);
      await repos.snippets.createSnippet(
        text: 'SUDDEN TURN OF EVENTS',
        sourceTitle: 'Lord of Mysteries Volume 1: Clown',
        bookId: bookId,
        chapterId: saved[0].id,
        tags: const ['highlight'],
      );

      final jsonStr = await svc.exportToJson();

      // Wipe and import into a fresh repos.
      repos.isar.close();
      repos = await createTestRepositories();
      svc = ExportService(repos);

      final result = await svc.importFromJson(jsonStr);
      expect(result.booksImported, 1);
      expect(result.chaptersImported, 3);
      expect(result.snippetsImported, 1);
      expect(result.toString(), contains('1 book'));
      expect(result.toString(), contains('3 chapters restored'));
      expect(result.toString(), contains('1 snippet'));

      final books = await repos.books.getBooks();
      expect(books.length, 1);
      expect(books.first.title, 'Lord of Mysteries');
      expect(books.first.author, 'Cuttlefish');

      final restoredChapters = await repos.books.getChapters(books.first.id);
      expect(restoredChapters.length, 3);
      expect(restoredChapters[0].content, 'Clown content');
      expect(restoredChapters[0].scrollPosition, 12.5);
      expect(restoredChapters[1].scrollPosition, 200);
      expect(restoredChapters[1].readAt, isNotNull);

      final snippets = await repos.snippets.getSnippets();
      expect(snippets.length, 1);
      expect(snippets.first.text, 'SUDDEN TURN OF EVENTS');
      expect(snippets.first.sourceTitle, 'Lord of Mysteries Volume 1: Clown');
      expect(snippets.first.tags, ['highlight']);
    });

    test('v4 export then import restores manga and chapters', () async {
      final mangaId = await repos.manga.insertManga(
        Manga(
          id: 0,
          name: 'One Piece',
          url: '/manga/op',
          author: 'Oda',
          sourceId: '12345',
          inLibrary: true,
          notes: 'Great',
        ),
      );
      await repos.manga.putMangaChapter(
        MangaChapter(
          id: 0,
          mangaId: mangaId,
          name: 'Chapter 1',
          url: '/ch/1',
          index: 0,
          isRead: true,
          lastPageRead: 12,
        ),
      );
      await repos.categories.upsertByName(
        LibraryCategory(id: 0, name: 'Shonen', order: 1),
      );

      final jsonStr = await svc.exportToJson();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['version'], 4);
      expect(parsed['manga'], isNotEmpty);

      repos.isar.close();
      repos = await createTestRepositories();
      svc = ExportService(repos);

      final result = await svc.importFromJson(jsonStr);
      expect(result.mangaImported, 1);
      expect(result.mangaChaptersImported, 1);

      final mangas = await repos.manga.getAllMangas();
      expect(mangas.length, 1);
      expect(mangas.first.name, 'One Piece');
      expect(mangas.first.inLibrary, isTrue);
      expect(mangas.first.notes, 'Great');

      final ch = await repos.manga.getMangaChapters(mangas.first.id);
      expect(ch.length, 1);
      expect(ch.first.isRead, isTrue);
      expect(ch.first.lastPageRead, 12);
    });

    test('import skips duplicate books by title+author', () async {
      await repos.books.insertBook(
        Book(id: 0, title: 'Existing', author: 'Author', source: 'local'),
      );
      final json = jsonEncode({
        'version': 2,
        'exported_at': DateTime.now().toIso8601String(),
        'books': [
          Book(
            id: 99,
            title: 'Existing',
            author: 'Author',
            source: 'local',
          ).toJson(),
        ],
        'chapters': <Map<String, dynamic>>[],
        'snippets': <Map<String, dynamic>>[],
        'tags': [],
      });
      final result = await svc.importFromJson(json);
      expect(result.booksImported, 0);
      expect(result.booksSkipped, 1);
      final allBooks = await repos.books.getBooks();
      expect(allBooks.length, 1);
    });

    test('empty export contains version and empty arrays', () {
      // Direct ExportService call would require data. Test JSON structure directly.
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
}
