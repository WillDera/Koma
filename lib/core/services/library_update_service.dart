import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/services/library_update_prefs.dart';

/// One manga that gained newly merged chapters during a poll.
class LibraryUpdateAddition {
  final Manga manga;
  final List<MangaChapter> chapters;

  const LibraryUpdateAddition({
    required this.manga,
    required this.chapters,
  });
}

/// Result of one library chapter-poll pass.
class LibraryUpdateReport {
  /// mangaId → number of new chapters discovered.
  final Map<int, int> newByManga;

  /// Display names of manga that received new chapters, in scan order.
  final List<String> updatedNames;

  /// Newly merged chapters (with parent manga) for auto-download enqueue.
  final List<LibraryUpdateAddition> additions;

  const LibraryUpdateReport({
    this.newByManga = const {},
    this.updatedNames = const [],
    this.additions = const [],
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
///
/// Manga skip filters follow Mihon's [LibraryUpdateJob.addMangaToQueue]
/// restrictions (completed / unread / not-started). Categories deferred.
class LibraryUpdateService {
  final Repositories _repos;
  final KeiyoushiService _keiyoushi;
  final ExtensionManager? _extensionManager;

  LibraryUpdateService(
    this._repos,
    this._keiyoushi, {
    ExtensionManager? extensionManager,
  }) : _extensionManager = extensionManager;

  Future<String> _resolveSourceId(String sourceId) async {
    final mgr = _extensionManager;
    if (mgr == null) return sourceId;
    final resolved = await mgr.resolveSourceId(sourceId);
    return resolved.isNotEmpty ? resolved : sourceId;
  }

  /// Returns true when [manga] should be skipped for this poll (Mihon smart
  /// update). Local chapter rows are loaded only when unread/started checks
  /// are enabled — completed-status alone needs no DB hit.
  Future<bool> _shouldSkip(
    Manga manga,
    LibraryUpdateMangaRestrictions r,
  ) async {
    // Mihon: status == COMPLETED (SManga.COMPLETED = 1).
    if (r.skipCompleted && manga.status == 1) return true;

    if (!r.skipWithUnread && !r.skipNotStarted) return false;

    final chapters = await _repos.manga.getMangaChapters(manga.id);
    if (r.skipWithUnread) {
      final hasUnread = chapters.any((c) => !c.isRead);
      if (hasUnread) return true;
    }
    if (r.skipNotStarted) {
      final started = chapters.any((c) => c.isRead || c.readAt != null);
      if (chapters.isNotEmpty && !started) return true;
    }
    return false;
  }

  Future<LibraryUpdateReport> checkForNewChapters({
    LibraryUpdateMangaRestrictions? restrictions,
  }) async {
    final mangas = await _repos.manga.getMangasInLibrary();
    final r = restrictions ?? await LibraryUpdatePrefs.loadMangaRestrictions();
    final newByManga = <int, int>{};
    final updatedNames = <String>[];
    final additions = <LibraryUpdateAddition>[];

    for (final manga in mangas) {
      try {
        if (await _shouldSkip(manga, r)) continue;

        final sourceId = await _resolveSourceId(manga.sourceId);
        final raw = await _keiyoushi.getChapterList(
          sourceId: sourceId,
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
          // Prefer the resolved source id so auto-download hits the live
          // extension the same way the chapter list did.
          final resolved = manga.copyWith(sourceId: sourceId);
          additions.add(
            LibraryUpdateAddition(manga: resolved, chapters: added),
          );
        }
      } catch (_) {
        // One manga (or one unavailable source) failing shouldn't block the
        // rest of the library (mangayomi pattern).
      }
    }

    return LibraryUpdateReport(
      newByManga: newByManga,
      updatedNames: updatedNames,
      additions: additions,
    );
  }
}
