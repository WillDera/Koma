class Bookmark {
  final int id;
  final int bookId;
  final int chapterId;
  final int? pageNumber;
  final double? scrollPosition;
  final DateTime createdAt;

  Bookmark({
    this.id = 0,
    required this.bookId,
    required this.chapterId,
    this.pageNumber,
    this.scrollPosition,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? chapterId,
    int? pageNumber,
    double? scrollPosition,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      pageNumber: pageNumber ?? this.pageNumber,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'book_id': bookId,
    'chapter_id': chapterId,
    'page_number': pageNumber,
    'scroll_position': scrollPosition,
    'created_at': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'] as int? ?? 0,
    bookId: json['book_id'] as int,
    chapterId: json['chapter_id'] as int,
    pageNumber: json['page_number'] as int?,
    scrollPosition: (json['scroll_position'] as num?)?.toDouble(),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );
}
