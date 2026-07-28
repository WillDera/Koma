import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:koma/core/isar/isar.dart'
    show openIsarInMemory;
import 'package:koma/core/repositories/book_repository.dart';
import 'package:koma/core/repositories/manga_repository.dart';
import 'package:koma/core/repositories/snippet_repository.dart';
import 'package:koma/core/models/book.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/models/manga.dart';
import 'package:koma/core/models/manga_chapter.dart';

/// Point Isar at the macOS dylib shipped in isar_community_flutter_libs.
Future<void> _initIsarCore() async {
  final home = Platform.environment['HOME']!;
  final dylib = File('$home/.pub-cache/hosted/pub.dev/'
      'isar_community_flutter_libs-3.3.2/macos/libisar.dylib');
  await Isar.initializeIsarCore(libraries: {Abi.current(): dylib.path});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;

  setUp(() async {
    await _initIsarCore();
    isar = await openIsarInMemory();
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('BookRepository', () {
    test('insert + get round-trip preserves fields', () async {
      final repo = BookRepository(isar);
      final id = await repo.insertBook(Book(
        id: 0,
        title: 'The Odyssey',
        author: 'Homer',
        source: 'local',
        progress: 0.3,
      ));
      final fetched = await repo.getBook(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'The Odyssey');
      expect(fetched.author, 'Homer');
      expect(fetched.progress, 0.3);
    });

    test('updateProgress mutates only progress fields', () async {
      final repo = BookRepository(isar);
      final id = await repo.insertBook(
          Book(id: 0, title: 'B', source: 'local'));
      await repo.updateProgress(id, 0.75, currentChapterIndex: 4);
      final b = await repo.getBook(id);
      expect(b!.progress, 0.75);
      expect(b.currentChapterIndex, 4);
    });

    test('deleteBook cascades chapters', () async {
      final repo = BookRepository(isar);
      final bookId = await repo.insertBook(
          Book(id: 0, title: 'B', source: 'local'));
      await repo.insertChapters([
        Chapter(id: 0, bookId: bookId, title: 'C1', content: 'x', index: 0),
        Chapter(id: 0, bookId: bookId, title: 'C2', content: 'y', index: 1),
      ]);
      expect((await repo.getChapters(bookId)).length, 2);
      await repo.deleteBook(bookId);
      expect(await repo.getBook(bookId), isNull);
      expect((await repo.getChapters(bookId)).length, 0);
    });

    test('watchBooks emits immediately then on insert', () async {
      final repo = BookRepository(isar);
      final emissions = <int>[];
      final sub = repo.watchBooks().listen((books) {
        emissions.add(books.length);
      });
      // fireImmediately → first emission is the empty list.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.insertBook(Book(id: 0, title: 'A', source: 'local'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.insertBook(Book(id: 0, title: 'B', source: 'local'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // Should have seen 0 (immediate), then 1, then 2.
      expect(emissions.first, 0);
      expect(emissions.last, 2);
    });

    test('watchBook emits null after delete', () async {
      final repo = BookRepository(isar);
      final id = await repo.insertBook(
          Book(id: 0, title: 'B', source: 'local'));
      final emissions = <Book?>[];
      final sub = repo.watchBook(id).listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.deleteBook(id);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first?.title, 'B');
      expect(emissions.last, isNull);
    });
  });

  group('SnippetRepository', () {
    test('createSnippet also populates tag catalog', () async {
      final repo = SnippetRepository(isar);
      await repo.createSnippet(
        text: 'a passage',
        tags: ['philosophy', 'stoicism'],
      );
      final snippets = await repo.getSnippets();
      expect(snippets.length, 1);
      expect(snippets.first.tags, containsAll(['philosophy', 'stoicism']));
      final catalog = await repo.getAllTags();
      expect(catalog, containsAll(['philosophy', 'stoicism']));
    });

    test('deleteCollection nulls out snippet.collectionId', () async {
      final repo = SnippetRepository(isar);
      final cid = await repo.createCollection('Faves');
      await repo.createSnippet(text: 'x', collectionId: cid);
      await repo.deleteCollection(cid);
      final snippets = await repo.getSnippets();
      expect(snippets.first.collectionId, isNull);
      expect((await repo.getCollections()).length, 0);
    });

    test('watchSnippets reacts to creation', () async {
      final repo = SnippetRepository(isar);
      final counts = <int>[];
      final sub = repo.watchSnippets().listen((s) => counts.add(s.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.createSnippet(text: 'one');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(counts.first, 0);
      expect(counts.last, 1);
    });
  });

  group('MangaRepository', () {
    test('getInProgressManga computes read counts', () async {
      final repo = MangaRepository(isar);
      final mid = await repo.insertManga(Manga(
        id: 0,
        name: 'M',
        url: '/m',
        sourceId: 'src1',
      ));
      await repo.insertMangaChapters(mid, [
        MangaChapter(id: 0, mangaId: mid, name: 'c1', url: '/c1', index: 0,
            isRead: true, readAt: DateTime.now()),
        MangaChapter(id: 0, mangaId: mid, name: 'c2', url: '/c2', index: 1),
      ]);
      final inProgress = await repo.getInProgressManga();
      expect(inProgress.length, 1);
      expect(inProgress.first.readCount, 1);
      expect(inProgress.first.totalChapters, 2);
      expect(inProgress.first.progress, 0.5);
    });

    test('setMangaInLibrary toggles library membership', () async {
      final repo = MangaRepository(isar);
      final mid = await repo.insertManga(
          Manga(id: 0, name: 'M', url: '/m', sourceId: 's'));
      expect((await repo.getMangasInLibrary()).length, 0);
      await repo.setMangaInLibrary(mid, true);
      expect((await repo.getMangasInLibrary()).length, 1);
    });

    test('getMangaByKey finds by sourceId + url', () async {
      final repo = MangaRepository(isar);
      await repo.insertManga(
          Manga(id: 0, name: 'M', url: '/unique', sourceId: 'srcX'));
      final found = await repo.getMangaByKey('srcX', '/unique');
      expect(found, isNotNull);
      expect(found!.name, 'M');
      expect(await repo.getMangaByKey('srcX', '/missing'), isNull);
    });
  });
}
