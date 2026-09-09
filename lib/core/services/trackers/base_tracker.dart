import '../../isar/collections/track.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';

class TrackSearchResult {
  final int mediaId;
  final String title;
  final String? coverUrl;
  final String? summary;
  final int? totalChapters;
  final String? trackingUrl;

  const TrackSearchResult({
    required this.mediaId,
    required this.title,
    this.coverUrl,
    this.summary,
    this.totalChapters,
    this.trackingUrl,
  });
}

/// One page of tracker catalog recommendations / suggestions.
class TrackerRecPage {
  const TrackerRecPage({
    required this.items,
    required this.reachedEnd,
  });

  final List<TrackSearchResult> items;

  /// True when the upstream API has no further pages (not merely “no manga
  /// on this mixed anime/manga page”).
  final bool reachedEnd;
}

abstract class BaseTracker {
  int get syncId;
  String get name;

  Repositories get repos;
  TrackRepository get tracks => repos.tracks;

  Future<bool> isLoggedIn() => tracks.isLoggedIn(syncId);

  Future<void> logout() => tracks.clearPreference(syncId);

  Future<List<TrackSearchResult>> search(String query);

  Future<Track> bind({
    required int mangaId,
    required TrackSearchResult hit,
    int lastChapterRead = 0,
  });

  Future<void> updateProgress(Track track, int lastChapterRead);
}
