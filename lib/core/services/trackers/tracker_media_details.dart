import 'dart:convert';

/// Catalog metadata for a tracker media entry (AniList / MAL / MU).
class TrackerMediaDetails {
  const TrackerMediaDetails({
    this.format,
    this.publicationStatus,
    this.startDate,
    this.averageScore,
    this.meanScore,
    this.popularity,
    this.favourites,
    this.source,
    this.genres = const [],
    this.tags = const [],
    this.romajiTitle,
    this.englishTitle,
    this.nativeTitle,
    this.synonyms = const [],
    this.coverUrl,
    this.trackingUrl,
    this.totalChapters,
  });

  final String? format;
  final String? publicationStatus;
  final DateTime? startDate;

  /// Community score 0–100 (AniList averageScore) or normalized equivalent.
  final int? averageScore;
  final int? meanScore;
  final int? popularity;
  final int? favourites;
  final String? source;
  final List<String> genres;
  final List<String> tags;
  final String? romajiTitle;
  final String? englishTitle;
  final String? nativeTitle;
  final List<String> synonyms;
  final String? coverUrl;
  final String? trackingUrl;
  final int? totalChapters;

  /// Alternate titles for search (excludes blanks / dups).
  List<String> get alternateTitles {
    final out = <String>[];
    final seen = <String>{};
    void add(String? s) {
      final t = s?.trim() ?? '';
      if (t.isEmpty) return;
      final key = t.toLowerCase();
      if (!seen.add(key)) return;
      out.add(t);
    }

    add(romajiTitle);
    add(englishTitle);
    add(nativeTitle);
    for (final s in synonyms) {
      add(s);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        if (format != null) 'format': format,
        if (publicationStatus != null) 'publicationStatus': publicationStatus,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (averageScore != null) 'averageScore': averageScore,
        if (meanScore != null) 'meanScore': meanScore,
        if (popularity != null) 'popularity': popularity,
        if (favourites != null) 'favourites': favourites,
        if (source != null) 'source': source,
        'genres': genres,
        'tags': tags,
        if (romajiTitle != null) 'romajiTitle': romajiTitle,
        if (englishTitle != null) 'englishTitle': englishTitle,
        if (nativeTitle != null) 'nativeTitle': nativeTitle,
        'synonyms': synonyms,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (trackingUrl != null) 'trackingUrl': trackingUrl,
        if (totalChapters != null) 'totalChapters': totalChapters,
      };

  factory TrackerMediaDetails.fromJson(Map<String, dynamic> json) {
    DateTime? start;
    final rawStart = json['startDate'];
    if (rawStart is String && rawStart.isNotEmpty) {
      start = DateTime.tryParse(rawStart);
    }
    return TrackerMediaDetails(
      format: json['format'] as String?,
      publicationStatus: json['publicationStatus'] as String?,
      startDate: start,
      averageScore: (json['averageScore'] as num?)?.toInt(),
      meanScore: (json['meanScore'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      favourites: (json['favourites'] as num?)?.toInt(),
      source: json['source'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => '$e')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => '$e')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      romajiTitle: json['romajiTitle'] as String?,
      englishTitle: json['englishTitle'] as String?,
      nativeTitle: json['nativeTitle'] as String?,
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => '$e')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      coverUrl: json['coverUrl'] as String?,
      trackingUrl: json['trackingUrl'] as String?,
      totalChapters: (json['totalChapters'] as num?)?.toInt(),
    );
  }

  String encode() => jsonEncode(toJson());

  static TrackerMediaDetails? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return TrackerMediaDetails.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

/// Maps tracker publication status strings → manga detail status ints
/// used by [_MangaDetailScreenState._statusLabels]
/// (0 Unknown, 1 Ongoing, 2 Completed, 5 Cancelled, 6 Hiatus).
abstract final class TrackerPublicationStatus {
  static int toMangaStatusInt(String? raw) {
    final s = (raw ?? '').trim().toUpperCase().replaceAll(' ', '_');
    return switch (s) {
      'RELEASING' ||
      'CURRENTLY_PUBLISHING' ||
      'PUBLISHING' ||
      'ONGOING' =>
        1,
      'FINISHED' || 'COMPLETED' || 'COMPLETE' => 2,
      'CANCELLED' || 'CANCELED' || 'DISCONTINUED' => 5,
      'HIATUS' || 'ON_HOLD' || 'ON-HOLD' => 6,
      'NOT_YET_RELEASED' || 'NOT_YET_PUBLISHED' || 'UPCOMING' => 0,
      _ => 0,
    };
  }

  static String labelForMangaStatusInt(int status) => switch (status) {
        1 => 'Ongoing',
        2 => 'Completed',
        5 => 'Cancelled',
        6 => 'Hiatus',
        _ => 'Unknown',
      };

  /// Prefer AniList, then MAL, then MangaUpdates among linked sync ids.
  static int preferredSyncId(Iterable<int> syncIds) {
    final set = syncIds.toSet();
    if (set.contains(2)) return 2; // anilist
    if (set.contains(1)) return 1; // mal
    if (set.contains(7)) return 7; // mu
    return set.isEmpty ? 0 : set.first;
  }
}
