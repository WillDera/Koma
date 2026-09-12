import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import '../../utils/chapter_recognition.dart';
import 'anilist.dart';
import 'base_tracker.dart';
import 'manga_updates.dart';
import 'myanimelist.dart';
import 'track_sync_feedback.dart';

/// After marking a chapter read, push progress to linked trackers.
class TrackChapterUseCase {
  TrackChapterUseCase(this._repos);

  final Repositories _repos;

  static const updateAfterReadingKey = 'tracker_update_after_reading';

  static Future<bool> isUpdateAfterReadingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(updateAfterReadingKey) ?? true;
  }

  BaseTracker? trackerFor(int syncId) {
    return switch (syncId) {
      TrackIds.mal => MyAnimeListTracker(_repos),
      TrackIds.anilist => AnilistTracker(_repos),
      TrackIds.mangaUpdates => MangaUpdatesTracker(_repos),
      _ => null,
    };
  }

  /// Push [chapterNumber] (and/or the highest recognized read chapter) to
  /// every linked tracker for [mangaId].
  Future<TrackSyncOutcome?> invoke({
    required int mangaId,
    double? chapterNumber,
    String? chapterName,
  }) async {
    if (!await isUpdateAfterReadingEnabled()) return null;

    var last = 0;
    if (chapterNumber != null &&
        chapterNumber.isFinite &&
        chapterNumber > 0) {
      last = chapterNumber.floor();
    }
    if (last <= 0 && chapterName != null && chapterName.trim().isNotEmpty) {
      final parsed = ChapterRecognition.parseChapterNumber(
        '',
        chapterName,
      );
      if (parsed.isFinite && parsed > 0) last = parsed.floor();
    }

    // Prefer the highest recognized *read* chapter in the library so manual
    // mark-read and unrecognized single chapters still sync correctly.
    final fromLibrary = await _highestReadChapter(mangaId);
    if (fromLibrary > last) last = fromLibrary;
    if (last <= 0) return null;

    return _push(mangaId, last);
  }

  Future<int> _highestReadChapter(int mangaId) async {
    final chapters = await _repos.manga.getMangaChapters(mangaId);
    var max = 0;
    for (final c in chapters) {
      if (!c.isRead) continue;
      var n = c.chapterNumber;
      if (!n.isFinite || n <= 0) {
        n = ChapterRecognition.parseChapterNumber('', c.name);
      }
      if (n.isFinite && n > 0) {
        final floor = n.floor();
        if (floor > max) max = floor;
      }
    }
    return max;
  }

  Future<TrackSyncOutcome?> _push(int mangaId, int last) async {
    final linked = await _repos.tracks.getTracksForManga(mangaId);
    if (linked.isEmpty) return null;

    final synced = <String>[];
    final failed = <String>[];

    for (final track in linked) {
      final syncId = track.syncId;
      if (syncId == null) continue;
      final prev = track.lastChapterRead ?? 0;
      if (last <= prev) continue;
      final tracker = trackerFor(syncId);
      if (tracker == null) continue;
      if (!await tracker.isLoggedIn()) continue;
      try {
        await tracker.updateProgress(track, last);
        synced.add(_shortName(tracker.name));
      } catch (e, st) {
        debugPrint('TrackChapterUseCase ${tracker.name} failed: $e\n$st');
        failed.add(_shortName(tracker.name));
      }
    }

    if (synced.isEmpty && failed.isEmpty) return null;
    return TrackSyncOutcome(
      mangaId: mangaId,
      chapter: last,
      syncedNames: synced,
      failedNames: failed,
    );
  }

  static String _shortName(String name) => switch (name) {
        'MyAnimeList' => 'MAL',
        'MangaUpdates' => 'MU',
        _ => name,
      };
}
