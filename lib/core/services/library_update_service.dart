import '../../core/models/manga_chapter.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/keiyoushi_service.dart';

/// Result of one library chapter-poll pass.
class LibraryUpdateReport {
  /// mangaId → number of new chapters discovered.
  final Map<int, int> newByManga;

  /// Display names of manga that received new chapters, in scan order.
  final List<String> updatedNames;

  const LibraryUpdateReport({
    this.newByManga = const {},
    this.updatedNames = const [],
  });

  int get totalNew => newByManga.values.fold(0, (a, b) => a + b);
}

/// Polls the chapter list of every manga in the library and merges any
/// chapters not yet persisted. New chapters are inserted with
/// `isOpened = false`, which drives the "new" badge on library cards
/// (mangayomi parity — `SChapter`'s first-open marker).
///
/// One failing source never blocks the others, matching mangayomi's
/// `LibUpdatesAlarm` catch-per-manga pattern.
class LibraryUpdateService {
  final Repositories _repos;
  final KeiyoushiService _keiyoushi;

  LibraryUpdateService(this._repos, this._keiyoushi);

  Future<LibraryUpdateReport> checkForNewChapters() async {
    final mangas = await _repos.manga.getMangasInLibrary();
    final newByManga = <int, int>{};
    final updatedNames = <String>[];

    for (final manga in mangas) {
      try {
        final raw = await _keiyoushi.getChapterList(
          sourceId: manga.sourceId,
          url: manga.url,
          memo: manga.memo,
          title: manga.name,
        );
        if (raw.isEmpty) continue;

        final incoming = <MangaChapter>[];
        for (var i = 0; i < raw.length; i++) {
          final ch = raw[i];
          final url = (ch['url'] as String? ?? '').trim();
          if (url.isEmpty) continue;
          incoming.add(
            MangaChapter(
              id: 0,
              mangaId: manga.id,
              name: ch['name'] as String? ?? '',
              url: url,
              scanlator: ch['scanlator'] as String?,
              dateUpload: ch['date_upload'] as int? ?? 0,
              index: i,
              memo: ch['memo'] as String?,
            ),
          );
        }
        if (incoming.isEmpty) continue;

        final added = await _repos.manga.mergeNewChapters(manga.id, incoming);
        if (added.isNotEmpty) {
          newByManga[manga.id] = added.length;
          updatedNames.add(manga.name);
        }
      } catch (_) {
        // One manga (or one unavailable source) failing shouldn't block the
        // rest of the library (mangayomi pattern).
      }
    }

    return LibraryUpdateReport(
      newByManga: newByManga,
      updatedNames: updatedNames,
    );
  }
}
