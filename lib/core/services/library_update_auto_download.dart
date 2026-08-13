import '../models/manga_chapter.dart';
import 'download/download_manager.dart';
import 'library_update_prefs.dart';
import 'library_update_service.dart';

/// Maps newly discovered chapters from a library poll into the download
/// queue (Mihon [FilterChaptersForDownload] + [LibraryUpdateJob] parity).
///
/// Category gates are deferred until Isar categories exist.
Future<void> enqueueNewChaptersFromUpdate({
  required DownloadManager manager,
  required LibraryUpdateReport report,
  bool? downloadNewOverride,
  bool autoStart = true,
}) async {
  if (report.additions.isEmpty) return;
  final enabled =
      downloadNewOverride ?? await LibraryUpdatePrefs.isDownloadNewEnabled();
  if (!enabled) return;

  for (final item in report.additions) {
    if (item.chapters.isEmpty) continue;
    await manager.downloadChapters(
      sourceId: item.manga.sourceId,
      mangaUrl: item.manga.url,
      mangaTitle: item.manga.name,
      mangaId: item.manga.id,
      mangaMemo: item.manga.memo,
      chapters: [
        for (final c in item.chapters) _chapterMap(c),
      ],
      autoStart: autoStart,
    );
  }
}

Map<String, dynamic> _chapterMap(MangaChapter c) => {
      'url': c.url,
      'name': c.name,
      'id': c.id,
      if (c.memo != null) 'memo': c.memo,
    };
