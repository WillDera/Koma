import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import '../services/app_storage.dart';
import '../services/storage_path_rewrite.dart';

import 'collections/book.dart';
import 'collections/book_metadata.dart';
import 'collections/bookmark.dart';
import 'collections/chapter.dart';
import 'collections/extension_repo.dart';
import 'collections/extension_source.dart';
import 'collections/highlight.dart';
import 'collections/library_category.dart';
import 'collections/library_group.dart';
import 'collections/library_group_member.dart';
import 'collections/manga.dart';
import 'collections/manga_chapter.dart';
import 'collections/manga_cookie.dart';
import 'collections/manga_extras.dart';
import 'collections/reading_stat.dart';
import 'collections/snippet.dart';
import 'collections/snippet_collection.dart';
import 'collections/source.dart';
import 'collections/source_pref_value.dart';
import 'collections/tag.dart';
import 'collections/web_cache.dart';

export 'collections/book.dart';
export 'collections/book_metadata.dart';
export 'collections/bookmark.dart';
export 'collections/chapter.dart';
export 'collections/extension_repo.dart';
export 'collections/extension_source.dart';
export 'collections/highlight.dart';
export 'collections/library_category.dart';
export 'collections/library_group.dart';
export 'collections/library_group_member.dart';
export 'collections/manga.dart';
export 'collections/manga_chapter.dart';
export 'collections/manga_cookie.dart';
export 'collections/manga_extras.dart';
export 'collections/reading_stat.dart';
export 'collections/snippet.dart';
export 'collections/snippet_collection.dart';
export 'collections/source.dart';
export 'collections/source_pref_value.dart';
export 'collections/tag.dart';
export 'collections/web_cache.dart';

/// Schema list passed to [Isar.open]. Order is significant for Isar's
/// internal layout — don't reorder without a migration. Mirrors
/// mangayomi's [StorageProvider.initDB] schema list.
/// New collections are appended only.
const List<CollectionSchema<dynamic>> komaIsarSchemas = [
  BookSchema,
  BookmarkSchema,
  ChapterSchema,
  MangaSchema,
  MangaChapterSchema,
  MangaCookieSchema,
  SnippetSchema,
  SnippetCollectionSchema,
  TagSchema,
  ExtensionSourceSchema,
  ExtensionRepoSchema,
  HighlightSchema,
  ReadingStatSchema,
  WebCacheSchema,
  SourceSchema,
  BookMetadataSchema,
  LibraryCategorySchema,
  MangaExtrasSchema,
  LibraryGroupSchema,
  LibraryGroupMemberSchema,
  SourcePrefValueSchema,
];

/// Open (or create) the Koma Isar instance in the app documents dir.
///
/// Also remaps absolute cover/media paths that no longer resolve after a
/// data-folder move (best-effort repair for libraries migrated before path
/// rewrite shipped).
Future<Isar> openIsar({String? directory, String? file}) async {
  final dir = directory ?? (await AppStorage.documents()).path;
  final isar = await Isar.open(
    komaIsarSchemas,
    directory: dir,
    name: file ?? 'koma',
    inspector: true,
  );
  try {
    await StoragePathRewrite.repairBrokenAbsolutePaths(isar);
  } catch (_) {}
  return isar;
}

/// Convenience for tests that need an in-memory Isar. Isar.open is
/// async on the host but sync in tests — we await it here for a
/// consistent API surface.
Future<Isar> openIsarInMemory() async {
  return Isar.open(
    komaIsarSchemas,
    directory: p.join(p.separator, 'tmp'),
    name: 'koma-test-${DateTime.now().microsecondsSinceEpoch}',
    inspector: false,
  );
}
