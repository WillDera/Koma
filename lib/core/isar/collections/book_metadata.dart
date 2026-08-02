import 'package:isar_community/isar.dart';

part 'book_metadata.g.dart';

/// Provenance for a [Book]'s enriched metadata (Open Library / Google Books).
@collection
@Name('BookMetadata')
class BookMetadata {
  Id? id;

  /// FK → [Book.id].
  @Index()
  int bookId;

  /// `"open_library"` or `"google_books"`.
  String source;

  /// OL work key or Google Books volume id.
  String? remoteId;

  /// Remote cover URL (local path lives on [Book.coverPath]).
  String? coverUrl;

  List<String> genres;

  DateTime? releaseDate;
  DateTime? fetchedAt;

  /// Title returned by the remote source.
  String? rawTitle;

  BookMetadata({
    this.id = Isar.autoIncrement,
    required this.bookId,
    required this.source,
    this.remoteId,
    this.coverUrl,
    this.genres = const [],
    this.releaseDate,
    this.fetchedAt,
    this.rawTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'source': source,
        'remote_id': remoteId,
        'cover_url': coverUrl,
        'genres': genres,
        'release_date': releaseDate?.toIso8601String(),
        'fetched_at': fetchedAt?.toIso8601String(),
        'raw_title': rawTitle,
      };

  factory BookMetadata.fromJson(Map<String, dynamic> json) => BookMetadata(
        id: json['id'] as int?,
        bookId: json['book_id'] as int,
        source: json['source'] as String? ?? '',
        remoteId: json['remote_id'] as String?,
        coverUrl: json['cover_url'] as String?,
        genres: (json['genres'] as List?)?.cast<String>() ?? const [],
        releaseDate: json['release_date'] != null
            ? DateTime.tryParse(json['release_date'] as String)
            : null,
        fetchedAt: json['fetched_at'] != null
            ? DateTime.tryParse(json['fetched_at'] as String)
            : null,
        rawTitle: json['raw_title'] as String?,
      );
}
