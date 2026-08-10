import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/book.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/providers.dart';
import 'package:koma/features/reader/reader_provider.dart';

import 'helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({ProviderContainer container, int chapterId})> createReader() async {
    final repositories = await createTestRepositories();
    final bookId = await repositories.books.insertBook(
      Book(id: 0, title: 'Performance test', source: 'local'),
    );
    final chapterId = await repositories.books.insertChapter(
      Chapter(
        id: 0,
        bookId: bookId,
        title: 'Chapter 1',
        content: '<p>Reader content.</p>',
        index: 0,
      ),
    );
    final container = ProviderContainer(
      overrides: [repositoriesProvider.overrideWithValue(repositories)],
    );
    addTearDown(() async {
      container.dispose();
      await repositories.isar.close(deleteFromDisk: true);
    });
    await container.read(readerProvider.notifier).loadBook(bookId);
    return (container: container, chapterId: chapterId);
  }

  test('scroll ticks do not emit watched ReaderState changes', () async {
    final reader = await createReader();
    final notifier = reader.container.read(readerProvider.notifier);
    var emissions = 0;
    final subscription = reader.container.listen<ReaderState>(
      readerProvider,
      (_, _) => emissions++,
    );

    notifier
      ..updateScrollPosition(10)
      ..updateScrollPosition(20)
      ..updateScrollPosition(30);

    expect(emissions, 0);
    expect(notifier.scrollPosition, 30);
    expect(reader.container.read(readerProvider).scrollPosition, 0);

    subscription.close();
    await notifier.stopReadingTimer();
  });

  test('latest scroll position is still persisted after debounce', () async {
    final reader = await createReader();
    final notifier = reader.container.read(readerProvider.notifier);

    notifier
      ..updateScrollPosition(120)
      ..updateScrollPosition(432.5);
    await Future<void>.delayed(const Duration(milliseconds: 1700));

    final stored = await reader.container
        .read(repositoriesProvider)
        .books
        .getChapter(reader.chapterId);
    expect(stored?.scrollPosition, 432.5);
    await notifier.stopReadingTimer();
  });
}
