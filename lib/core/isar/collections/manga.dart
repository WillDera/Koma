import 'package:isar_community/isar.dart';

part 'manga.g.dart';

/// Status enum kept as int (mirrors existing Drift schema + mangayomi's
/// Status.values indices):
///   0 = ongoing, 1 = completed, 2 = hiatus, 3 = cancelled,
///   4 = publishing finished.
/// Will be promoted to a typed enum at the JS-bridge boundary in PHASE 9.
@collection
@Name('Manga')
class Manga {
  Id? id;

  String name;

  @Index(unique: false, replace: false) // hot lookup: getMangaUpdate by url
  String url;

  String? imageUrl;
  String? author;
  String? artist;
  String? description;

  /// See class doc for the int→status mapping.
  int status;

  /// Stored denormalized — Isar supports List<String> natively and the
  /// existing Drift schema stores genre as a comma-joined string.
  List<String>? genres;

  /// Foreign key to [ExtensionSource.id] (a String). Indexed for the
  /// "list manga from this source" query.
  @Index()
  String sourceId;

  bool inLibrary;

  /// 0 = unread, 1 = reading, 2 = read. Mirrors existing column.
  int readingStatus;

  DateTime? createdAt;
  DateTime? updatedAt;

  Manga({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.url,
    this.imageUrl,
    this.author,
    this.artist,
    this.description,
    this.status = 0,
    this.genres,
    required this.sourceId,
    this.inLibrary = false,
    this.readingStatus = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'image_url': imageUrl,
    'author': author,
    'artist': artist,
    'description': description,
    'status': status,
    'genre': genres?.join(', ') ?? '',
    'source_id': sourceId,
    'in_library': inLibrary ? 1 : 0,
    'reading_status': readingStatus,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Manga.fromJson(Map<String, dynamic> json) => Manga(
    id: json['id'] as int?,
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    author: json['author'] as String?,
    artist: json['artist'] as String?,
    description: json['description'] as String?,
    status: json['status'] as int? ?? 0,
    genres: _splitGenres(json['genre'] as String? ?? ''),
    sourceId: json['source_id'] as String? ?? '',
    inLibrary: (json['in_library'] as int? ?? 0) == 1,
    readingStatus: json['reading_status'] as int? ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );
}

List<String> _splitGenres(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((genre) => genre.trim())
      .where((genre) => genre.isNotEmpty)
      .toList(growable: false);
}
