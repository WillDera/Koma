import 'package:isar_community/isar.dart';

part 'track.g.dart';

enum TrackStatus {
  reading,
  completed,
  onHold,
  dropped,
  planToRead,
  reReading,
}

@collection
@Name('Track')
class Track {
  Id? id;

  int? libraryId;
  int? mediaId;

  @Index()
  int? mangaId;

  @Index()
  int? syncId;

  String? title;
  int? lastChapterRead;
  int? totalChapter;
  int? score;

  @enumerated
  TrackStatus status;

  int? startedReadingDate;
  int? finishedReadingDate;
  String? trackingUrl;
  int? updatedAt;

  /// When true, the list entry is private on the tracker (AniList) or
  /// stored locally only (MAL / others that lack a private flag).
  bool private = false;

  /// Cached [TrackerMediaDetails] JSON from the tracker catalog.
  String? mediaDetailsJson;

  Track({
    this.id = Isar.autoIncrement,
    this.libraryId,
    this.mediaId,
    this.mangaId,
    this.syncId,
    this.title,
    this.lastChapterRead,
    this.totalChapter,
    this.score,
    this.status = TrackStatus.reading,
    this.startedReadingDate,
    this.finishedReadingDate,
    this.trackingUrl,
    this.updatedAt = 0,
    this.private = false,
    this.mediaDetailsJson,
  });
}
