import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/providers.dart';

/// Reactive detail data backed only by the persisted Isar rows.
final bookDetailStreamProvider = StreamProvider.family<Book?, int>((
  ref,
  bookId,
) {
  return ref.watch(repositoriesProvider).books.watchBook(bookId);
});

/// Persisted chapters for a book, ordered by their stored index.
final bookChaptersStreamProvider = StreamProvider.family<List<Chapter>, int>((
  ref,
  bookId,
) {
  return ref.watch(repositoriesProvider).books.watchChapters(bookId);
});
