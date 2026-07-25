import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'collections/book.dart';
import 'collections/chapter.dart';
import 'collections/extension_repo.dart';
import 'collections/extension_source.dart';
import 'collections/highlight.dart';
import 'collections/manga.dart';
import 'collections/manga_chapter.dart';
import 'collections/reading_stat.dart';
import 'collections/snippet.dart';
import 'collections/snippet_collection.dart';
import 'collections/source.dart';
import 'collections/tag.dart';
import 'collections/web_cache.dart';

export 'collections/book.dart';
export 'collections/chapter.dart';
export 'collections/extension_repo.dart';
export 'collections/extension_source.dart';
export 'collections/highlight.dart';
export 'collections/manga.dart';
export 'collections/manga_chapter.dart';
export 'collections/reading_stat.dart';
export 'collections/snippet.dart';
export 'collections/snippet_collection.dart';
export 'collections/source.dart';
export 'collections/tag.dart';
export 'collections/web_cache.dart';

/// Schema list passed to [Isar.open]. Order is significant for Isar's
/// internal layout — don't reorder without a migration. Mirrors
/// mangayomi's [StorageProvider.initDB] schema list.
const List<CollectionSchema<dynamic>> komaIsarSchemas = [
  BookSchema,
  ChapterSchema,
  MangaSchema,
  MangaChapterSchema,
  SnippetSchema,
  SnippetCollectionSchema,
  TagSchema,
  ExtensionSourceSchema,
  ExtensionRepoSchema,
  HighlightSchema,
  ReadingStatSchema,
  WebCacheSchema,
  SourceSchema,
];

/// Open (or create) the Koma Isar instance in the app documents dir.
///
/// The file is named `koma.isar` next to the existing `koma.db` Drift
/// file — both coexist during PHASE 1b's one-time migration, after which
/// Drift is retired (PHASE 11).
Future<Isar> openIsar({String? directory, String? file}) async {
  final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
  return Isar.open(
    komaIsarSchemas,
    directory: dir,
    name: file ?? 'koma',
    inspector: true,
  );
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
