import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';
import 'download/download_manager.dart';
import 'group_download_rules.dart';
import 'library_update_prefs.dart';
import 'library_update_service.dart';

/// Maps newly discovered chapters from a library poll into the download
/// queue (Mihon [FilterChaptersForDownload] + [LibraryUpdateJob] parity).
///
/// Per-group rules ([GroupDownloadRules]) can skip, download all, or
/// download unread-only — overriding the global download-new toggle.
Future<void> enqueueNewChaptersFromUpdate({
  required DownloadManager manager,
  required LibraryUpdateReport report,
  required Repositories repositories,
  bool? downloadNewOverride,
  bool autoStart = true,
}) async {
  if (report.additions.isEmpty) return;

  final rules = await GroupDownloadRules.load();
  final globalEnabled =
      downloadNewOverride ?? await LibraryUpdatePrefs.isDownloadNewEnabled();

  for (final item in report.additions) {
    if (item.chapters.isEmpty) continue;

    final groupIds =
        await repositories.groups.groupIdsForManga(item.manga.id);
    final behavior = GroupDownloadRules.resolveRule(
      groupIds: groupIds,
      globalDownloadNew: globalEnabled,
      rules: rules,
    );
    if (behavior == GroupDownloadBehavior.skip) continue;

    final chapters = behavior == GroupDownloadBehavior.downloadUnreadOnly
        ? [for (final c in item.chapters) if (!c.isRead) c]
        : item.chapters;
    if (chapters.isEmpty) continue;

    await manager.downloadChapters(
      sourceId: item.manga.sourceId,
      mangaUrl: item.manga.url,
      mangaTitle: item.manga.name,
      mangaId: item.manga.id,
      mangaMemo: item.manga.memo,
      chapters: [
        for (final c in chapters) _chapterMap(c),
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
