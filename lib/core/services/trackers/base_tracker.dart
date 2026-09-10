import '../../isar/collections/track.dart';
import '../../repositories/repositories.dart';
import '../../repositories/track_repository.dart';
import 'tracker_media_details.dart';

export 'tracker_media_details.dart';

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

class TrackerReview {
  const TrackerReview({
    required this.id,
    required this.body,
    this.title,
    this.score,
    this.userName,
    this.isMine = false,
  });

  final int id;
  final String body;
  final String? title;
  final int? score;
  final String? userName;
  final bool isMine;
}

class TrackerComment {
  const TrackerComment({
    required this.id,
    required this.body,
    this.userName,
    this.createdAt,
  });

  final int id;
  final String body;
  final String? userName;
  final DateTime? createdAt;
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

  Future<TrackerMediaDetails?> fetchMediaDetails(int mediaId) async => null;

  Future<void> updateScore(Track track, int score) async {
    track.score = score;
    await tracks.upsertTrack(track);
  }

  Future<List<TrackerReview>> listReviews(int mediaId) async => const [];

  Future<TrackerReview?> upsertReview({
    required int mediaId,
    required String body,
    String? title,
    int? score,
    int? existingReviewId,
  }) async =>
      null;

  Future<List<TrackerComment>> listComments(int reviewId) async => const [];

  Future<void> postComment({
    required int reviewId,
    required String body,
  }) async {}
}
