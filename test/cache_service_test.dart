import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/repositories/repositories.dart';
import 'package:koma/core/services/cache_service.dart';

import 'helpers/test_database.dart';

void main() {
  late Repositories repos;
  late CacheService service;

  setUp(() async {
    repos = await createTestRepositories();
    service = CacheService(repos);
  });

  tearDown(() {
    repos.isar.close();
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
      expect(cached!.bookId, 0);
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
      await service.cacheContent('https://example.com/1', 'P1', '<p>1</p>');
      await service.cacheContent('https://example.com/2', 'P2', '<p>2</p>');

      expect(await service.isCached('https://example.com/1'), isTrue);
      expect(await service.isCached('https://example.com/2'), isTrue);

      await service.clearCache();

      expect(await service.isCached('https://example.com/1'), isFalse);
      expect(await service.isCached('https://example.com/2'), isFalse);
    });
  });
}
