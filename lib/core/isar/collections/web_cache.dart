import 'package:isar_community/isar.dart';

part 'web_cache.g.dart';

@collection
@Name('WebCache')
class WebCache {
  Id? id;

  @Index(unique: true, replace: true)
  String urlHash;

  String url;
  String title;
  String content;
  DateTime? cachedAt;

  WebCache({
    this.id = Isar.autoIncrement,
    required this.urlHash,
    required this.url,
    required this.title,
    required this.content,
    this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url_hash': urlHash,
        'url': url,
        'title': title,
        'content': content,
        'cached_at': cachedAt?.toIso8601String(),
      };

  factory WebCache.fromJson(Map<String, dynamic> json) => WebCache(
        id: json['id'] as int?,
        urlHash: json['url_hash'] as String,
        url: json['url'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        cachedAt: json['cached_at'] != null
            ? DateTime.parse(json['cached_at'] as String)
            : null,
      );
}
