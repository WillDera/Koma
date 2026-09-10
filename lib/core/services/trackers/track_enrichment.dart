import '../../isar/collections/track.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'anilist.dart';
import 'base_tracker.dart';
import 'manga_updates.dart';
import 'myanimelist.dart';

/// After bind / on detail open: refresh catalog metadata + alternate titles.
abstract final class TrackEnrichment {
  static BaseTracker trackerFor(Repositories repos, int syncId) {
    return switch (syncId) {
      TrackIds.mal => MyAnimeListTracker(repos),
      TrackIds.anilist => AnilistTracker(repos),
      _ => MangaUpdatesTracker(repos),
    };
  }

  static Future<Track?> refreshTrackMedia(
    Repositories repos,
    Track track,
  ) async {
    final mediaId = track.mediaId;
    final syncId = track.syncId;
    if (mediaId == null || syncId == null) return track;
    final tracker = trackerFor(repos, syncId);
    if (!await tracker.isLoggedIn()) return track;
    try {
      final details = await tracker.fetchMediaDetails(mediaId);
      if (details == null) return track;
      track.mediaDetailsJson = details.encode();
      if (details.trackingUrl != null && details.trackingUrl!.isNotEmpty) {
        track.trackingUrl = details.trackingUrl;
      }
      if (details.totalChapters != null && details.totalChapters! > 0) {
        track.totalChapter = details.totalChapters;
      }
      await repos.tracks.upsertTrack(track);
      final mangaId = track.mangaId;
      if (mangaId != null) {
        await mergeAlternateTitles(repos, mangaId, details);
      }
      return track;
    } catch (_) {
      return track;
    }
  }

  static Future<void> mergeAlternateTitles(
    Repositories repos,
    int mangaId,
    TrackerMediaDetails details,
  ) async {
    final manga = await repos.manga.getMangaById(mangaId);
    if (manga == null) return;
    final primary = manga.name.trim().toLowerCase();
    final existing = {...manga.alternateTitles.map((e) => e.toLowerCase())};
    final merged = [...manga.alternateTitles];
    for (final alt in details.alternateTitles) {
      final key = alt.toLowerCase();
      if (key == primary || !existing.add(key)) continue;
      merged.add(alt);
    }
    if (merged.length == manga.alternateTitles.length) return;
    await repos.manga.updateMangaExtras(mangaId, alternateTitles: merged);
  }

  /// Preferred linked track among a manga's tracks (AniList > MAL > MU).
  static Track? preferredTrack(List<Track> tracks) {
    if (tracks.isEmpty) return null;
    final preferred = TrackerPublicationStatus.preferredSyncId(
      tracks.map((t) => t.syncId).whereType<int>(),
    );
    return tracks.cast<Track?>().firstWhere(
          (t) => t?.syncId == preferred,
          orElse: () => tracks.first,
        );
  }
}
