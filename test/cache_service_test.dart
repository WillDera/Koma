import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:koma/core/database/database.dart';
import 'package:koma/core/services/cache_service.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CacheService service;

  setUp(() async {
    db = await createTestDb();
    service = CacheService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('cacheContent', () {
    test('stores content and isCached returns true', () async {
      await service.cacheContent(
        'https://example.com/article',
        'Article Title',
        '<p>Article body</p>',
      );

      expect(await service.isCached('https://example.com/article'), isTrue);
    });

    test('storing same URL replaces old content', () async {
      await service.cacheContent(
        'https://example.com/page',
        'V1',
        '<p>Version 1</p>',
      );
      await service.cacheContent(
        'https://example.com/page',
        'V2',
        '<p>Version 2</p>',
      );

      final cached = await service.getCached('https://example.com/page');
      expect(cached, isNotNull);
      expect(cached!.content, '<p>Version 2</p>');
    });
  });

  group('isCached / getCached', () {
    test('isCached returns false for unknown URL', () async {
      expect(await service.isCached('https://unknown.com'), isFalse);
    });

    test('getCached returns null for unknown URL', () async {
      final result = await service.getCached('https://unknown.com');
      expect(result, isNull);
    });

    test('getCached returns chapter with correct data', () async {
      await service.cacheContent(
        'https://example.com/test',
        'Test Page',
        '<h1>Hello</h1>',
      );

      final cached = await service.getCached('https://example.com/test');
      expect(cached, isNotNull);
      expect(cached!.bookId, 0); // book_id=0 marks cached web content
      expect(cached.content, '<h1>Hello</h1>');
      expect(cached.index, 0);
    });

    test('cached entries are isolated by URL', () async {
      await service.cacheContent(
        'https://example.com/a',
        'Page A',
        '<p>Content A</p>',
      );
      await service.cacheContent(
        'https://example.com/b',
        'Page B',
        '<p>Content B</p>',
      );

      expect(await service.isCached('https://example.com/a'), isTrue);
      expect(await service.isCached('https://example.com/b'), isTrue);

      final a = await service.getCached('https://example.com/a');
      final b = await service.getCached('https://example.com/b');
      expect(a!.content, '<p>Content A</p>');
      expect(b!.content, '<p>Content B</p>');
    });
  });

  group('clearCache', () {
    test('removes all cached entries', () async {
      await service.cacheContent(
        'https://example.com/1',
        'P1',
        '<p>1</p>',
      );
      await service.cacheContent(
        'https://example.com/2',
        'P2',
        '<p>2</p>',
      );

      expect(await service.isCached('https://example.com/1'), isTrue);
      expect(await service.isCached('https://example.com/2'), isTrue);

      await service.clearCache();

      expect(await service.isCached('https://example.com/1'), isFalse);
      expect(await service.isCached('https://example.com/2'), isFalse);
    });

    test('clearCache does not remove real book chapters', () async {
      // Insert a real book
      final bookId = await db.customInsert(
        'INSERT INTO books (title, author, source) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('Real Book'),
          Variable.withString('Author'),
          Variable.withString('local'),
        ],
      );
      // Insert a real chapter (book_id > 0)
      await db.customInsert(
        'INSERT INTO chapters (book_id, title, content, "index") VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withInt(bookId),
          Variable.withString('Ch 1'),
          Variable.withString('Real content'),
          Variable.withInt(0),
        ],
      );

      await service.clearCache();

      // Real chapter should still exist
      final chapters = await db.customSelect(
        'SELECT * FROM chapters WHERE book_id = ?',
        variables: [Variable.withInt(bookId)],
      ).get();
      expect(chapters.length, 1);
      expect(chapters.first.data['content'], 'Real content');
    });
  });

  group('cache entries do not interfere with real data', () {
    test('cached entries use web_cache table', () async {
      await service.cacheContent(
        'https://example.com/cached',
        'Cached',
        '<p>Cached content</p>',
      );

      final rows = await db
          .customSelect('SELECT * FROM web_cache').get();
      expect(rows.length, 1);
      expect(rows.first.data['title'], 'Cached');
    });

    test('multiple caches stored in web_cache', () async {
      await service.cacheContent('https://a.com', 'A', '<p>A</p>');
      await service.cacheContent('https://b.com', 'B', '<p>B</p>');

      final rows = await db
          .customSelect('SELECT * FROM web_cache').get();
      expect(rows.length, 2);
    });
  });
}
