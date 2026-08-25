/// Single entry point for all five Isar-backed repositories.
///
/// Construction:
/// ```dart
/// final isar = await openIsar();
/// final repos = Repositories(isar);
/// ```
///
/// Or via the async factory that opens Isar for you:
/// ```dart
/// final repos = await Repositories.open();
/// ```
///
/// Held by `repositoriesProvider` in `lib/core/providers.dart`, which
/// constructs a single instance from the shared `isarProvider`. Screens
/// reach individual repositories via `ref.watch(repositoriesProvider).books`
/// etc. — the reactive `watch*` streams are wired into the UI as each
/// feature is migrated.
library;

import 'package:isar_community/isar.dart';

import '../isar/isar.dart';
import 'book_repository.dart';
import 'bookmark_repository.dart';
import 'category_repository.dart';
import 'cookie_repository.dart';
import 'extension_repository.dart';
import 'library_group_repository.dart';
import 'manga_repository.dart';
import 'snippet_repository.dart';
import 'stats_repository.dart';

class Repositories {
  final Isar isar;
  final BookRepository books;
  final MangaRepository manga;
  final SnippetRepository snippets;
  final ExtensionRepository extensions;
  final StatsRepository stats;
  final BookmarkRepository bookmarks;
  final CookieRepository cookies;
  final CategoryRepository categories;
  final LibraryGroupRepository groups;

  Repositories(this.isar)
    : books = BookRepository(isar),
      manga = MangaRepository(isar),
      snippets = SnippetRepository(isar),
      extensions = ExtensionRepository(isar),
      stats = StatsRepository(isar),
      bookmarks = BookmarkRepository(isar),
      cookies = CookieRepository(isar),
      categories = CategoryRepository(isar),
      groups = LibraryGroupRepository(isar);

  /// Convenience: open Isar with the Koma schema list and wrap all
  /// repositories in one call. Mirrors [DatabaseService.getInstance].
  static Future<Repositories> open() async {
    final isar = await openIsar();
    return Repositories(isar);
  }
}
