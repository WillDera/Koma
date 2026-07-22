class Snippet {
  final int id;
  final String text;
  final String? note;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? color;
  final int? bookId;
  final int? chapterId;
  final int? collectionId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Snippet({
    required this.id,
    required this.text,
    this.note,
    this.sourceTitle,
    this.sourceUrl,
    this.color,
    this.bookId,
    this.chapterId,
    this.collectionId,
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Snippet copyWith({
    int? id,
    String? text,
    String? note,
    String? sourceTitle,
    String? sourceUrl,
    String? color,
    int? bookId,
    int? chapterId,
    int? collectionId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Snippet(
      id: id ?? this.id,
      text: text ?? this.text,
      note: note ?? this.note,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      color: color ?? this.color,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      collectionId: collectionId ?? this.collectionId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'note': note,
        'source_title': sourceTitle,
        'source_url': sourceUrl,
        'color': color,
        'book_id': bookId,
        'chapter_id': chapterId,
        'collection_id': collectionId,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as int,
        text: json['text'] as String,
        note: json['note'] as String?,
        sourceTitle: json['source_title'] as String?,
        sourceUrl: json['source_url'] as String?,
        color: json['color'] as String?,
        bookId: json['book_id'] as int?,
        chapterId: json['chapter_id'] as int?,
        collectionId: json['collection_id'] as int?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
}
