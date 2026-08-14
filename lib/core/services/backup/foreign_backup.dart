import '../../models/manga.dart';
import '../../models/manga_chapter.dart';
import '../../models/library_category.dart';
import '../../models/extension_repo.dart';
import '../../models/extension_source.dart';

/// Normalized library extracted from Mihon or Mangayomi backups.
class ForeignLibraryBackup {
  final List<LibraryCategory> categories;
  final List<ForeignManga> manga;
  final List<ExtensionRepo> repos;
  final List<ForeignCookie> cookies;
  final List<ExtensionSource> jsExtensions;
  final List<String> sourceLabels;
  final int skippedAnime;
  final int skippedNovels;
  final bool showNsfw;
  final double? novelFontSize;

  const ForeignLibraryBackup({
    this.categories = const [],
    this.manga = const [],
    this.repos = const [],
    this.cookies = const [],
    this.jsExtensions = const [],
    this.sourceLabels = const [],
    this.skippedAnime = 0,
    this.skippedNovels = 0,
    this.showNsfw = false,
    this.novelFontSize,
  });
}

class ForeignCookie {
  final String host;
  final String cookie;
  const ForeignCookie({required this.host, required this.cookie});
}

class ForeignManga {
  final Manga manga;
  final List<MangaChapter> chapters;
  final String backupSourceId;
  final String? sourceName;

  const ForeignManga({
    required this.manga,
    required this.chapters,
    required this.backupSourceId,
    this.sourceName,
  });
}
