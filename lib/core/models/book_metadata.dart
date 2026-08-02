class BookMetadata {
  final int id;
  final int bookId;
  final String source;
  final String? remoteId;
  final String? coverUrl;
  final List<String> genres;
  final DateTime? releaseDate;
  final DateTime? fetchedAt;
  final String? rawTitle;

  BookMetadata({
    required this.id,
    required this.bookId,
    required this.source,
    this.remoteId,
    this.coverUrl,
    List<String>? genres,
    this.releaseDate,
    this.fetchedAt,
    this.rawTitle,
  }) : genres = List.unmodifiable(genres ?? const []);
}
