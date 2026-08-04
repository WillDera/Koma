import '../../core/services/keiyoushi_service.dart';

class MManga {
  final String url;
  final String title;
  final String? thumbnailUrl;
  final String? author;
  final String? artist;
  final String? description;
  final int status;
  final List<String> genres;

  /// Raw JSON of the source-side `SManga.memo` (e.g. allanime `{"slug":...}`).
  /// Opaque to the UI — round-tripped back to the Dalvik server so sources
  /// that derive URLs from memo can work.
  final String? memo;

  const MManga({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.author,
    this.artist,
    this.description,
    this.status = 0,
    this.memo,
    List<String>? genres,
  }) : genres = genres ?? const [];

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'thumbnail_url': thumbnailUrl,
    'author': author,
    'artist': artist,
    'description': description,
    'status': status,
    'genre': genres.join(', '),
    'memo': memo,
  };

  factory MManga.fromJson(Map<String, dynamic> json) => MManga(
    url: json['url'] as String? ?? '',
    title: json['title'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String?,
    author: json['author'] as String?,
    artist: json['artist'] as String?,
    description: json['description'] as String?,
    status: json['status'] as int? ?? 0,
    memo: coerceMemoJson(json['memo']),
    genres: json['genre'] != null
        ? (json['genre'] as String).split(',').map((g) => g.trim()).toList()
        : null,
  );

  factory MManga.fromMap(Map<String, dynamic> map) => MManga.fromJson(map);

  factory MManga.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return MManga.fromJson(d);
    if (d is Map) {
      return MManga.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}
