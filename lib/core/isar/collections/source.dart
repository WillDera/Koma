import 'package:isar_community/isar.dart';

part 'source.g.dart';

/// Ebook web source (Anna's Archive, Project Gutenberg, Standard Ebooks,
/// etc.). Distinct from [ExtensionSource], which represents an installed
/// Keiyoushi/JS manga extension. The existing Drift `sources` table is
/// the source of truth for the Discover screen's ebook tab.
@collection
@Name('Source')
class Source {
  Id? id;

  String name;

  /// Short slug used in URLs (e.g. `annas-archive`, `gutenberg`).
  @Index(unique: true, replace: true)
  String tag;

  String baseUrl;
  bool enabled;
  String? language;

  /// File extensions of interest for search results (e.g. epub, pdf). Empty = all.
  List<String>? fileExtensions;

  DateTime? createdAt;

  Source({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.tag,
    required this.baseUrl,
    this.enabled = true,
    this.language,
    this.fileExtensions,
    this.createdAt,
  });

  String get label => '$name ($tag)';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tag': tag,
    'base_url': baseUrl,
    'enabled': enabled ? 1 : 0,
    if (language != null) 'language': language,
    if (fileExtensions != null && fileExtensions!.isNotEmpty)
      'file_extensions': fileExtensions,
  };

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    id: json['id'] as int?,
    name: json['name'] as String,
    tag: json['tag'] as String? ?? '',
    baseUrl: json['base_url'] as String? ?? json['search_url'] as String? ?? '',
    enabled: (json['enabled'] as int? ?? 1) == 1,
    language: json['language'] as String?,
    fileExtensions: (json['file_extensions'] as List<dynamic>?)
        ?.map((e) => e.toString().toLowerCase())
        .toList(),
  );
}
