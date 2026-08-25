import 'package:koma/core/services/keiyoushi_service.dart'
    show coerceMemoJson;

class Manga {
  final int id;
  final String name;
  final String url;
  final String? imageUrl;
  final String? author;
  final String? artist;
  final String? description;
  final int status;
  final List<String> genres;
  final String sourceId;
  final bool inLibrary;
  final int readingStatus;

  /// Source-side `SManga.memo` JSON (e.g. allanime `{"slug":...}`).
  /// Round-tripped on detail fetch / library reopen (Mihon parity).
  final String? memo;

  /// [LibraryCategory] ids. Stored in the MangaExtras sidecar.
  final List<int> categoryIds;

  /// Mihon user notes. Stored in the MangaExtras sidecar.
  final String? notes;

  /// Local custom cover path. Stored in the MangaExtras sidecar.
  final String? customCoverPath;

  /// Mihon reader viewer flags. Stored in MangaExtras (opaque to Koma UI).
  final int viewerFlags;

  /// Mihon chapter-list flags. Stored in MangaExtras (opaque to Koma UI).
  final int chapterFlags;

  final DateTime createdAt;
  final DateTime updatedAt;

  Manga({
    required this.id,
    required this.name,
    required this.url,
    this.imageUrl,
    this.author,
    this.artist,
    this.description,
    this.status = 0,
    List<String>? genres,
    required this.sourceId,
    this.inLibrary = false,
    this.readingStatus = 0,
    this.memo,
    List<int>? categoryIds,
    this.notes,
    this.customCoverPath,
    this.viewerFlags = 0,
    this.chapterFlags = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : genres = List.unmodifiable(genres ?? const []),
       categoryIds = List.unmodifiable(categoryIds ?? const []),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Manga copyWith({
    int? id,
    String? name,
    String? url,
    String? imageUrl,
    String? author,
    String? artist,
    String? description,
    int? status,
    List<String>? genres,
    String? sourceId,
    bool? inLibrary,
    int? readingStatus,
    String? memo,
    List<int>? categoryIds,
    String? notes,
    String? customCoverPath,
    int? viewerFlags,
    int? chapterFlags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Manga(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      status: status ?? this.status,
      genres: genres ?? this.genres,
      sourceId: sourceId ?? this.sourceId,
      inLibrary: inLibrary ?? this.inLibrary,
      readingStatus: readingStatus ?? this.readingStatus,
      memo: memo ?? this.memo,
      categoryIds: categoryIds ?? this.categoryIds,
      notes: notes ?? this.notes,
      customCoverPath: customCoverPath ?? this.customCoverPath,
      viewerFlags: viewerFlags ?? this.viewerFlags,
      chapterFlags: chapterFlags ?? this.chapterFlags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'image_url': imageUrl,
    'author': author,
    'artist': artist,
    'description': description,
    'status': status,
    'genre': genres.join(', '),
    'source_id': sourceId,
    'in_library': inLibrary ? 1 : 0,
    'reading_status': readingStatus,
    'memo': memo,
    'category_ids': categoryIds,
    'notes': notes,
    'custom_cover_path': customCoverPath,
    'viewer_flags': viewerFlags,
    'chapter_flags': chapterFlags,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Manga.fromJson(Map<String, dynamic> json) => Manga(
    id: json['id'] as int? ?? 0,
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
    memo: coerceMemoJson(json['memo']),
    categoryIds: (json['category_ids'] as List<dynamic>?)
        ?.map((e) => (e as num).toInt())
        .toList(),
    notes: json['notes'] as String?,
    customCoverPath: json['custom_cover_path'] as String?,
    viewerFlags: (json['viewer_flags'] as num?)?.toInt() ?? 0,
    chapterFlags: (json['chapter_flags'] as num?)?.toInt() ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.now(),
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
