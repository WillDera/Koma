class Highlight {
  final int id;
  final int? snippetId;
  final int bookId;
  final int chapterId;
  final int startOffset;
  final int endOffset;
  final String color;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Highlight({
    required this.id,
    this.snippetId,
    required this.bookId,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    this.color = 'yellow',
    required this.text,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'snippet_id': snippetId,
        'book_id': bookId,
        'chapter_id': chapterId,
        'start_offset': startOffset,
        'end_offset': endOffset,
        'color': color,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'] as int,
        snippetId: json['snippet_id'] as int?,
        bookId: json['book_id'] as int,
        chapterId: json['chapter_id'] as int,
        startOffset: json['start_offset'] as int,
        endOffset: json['end_offset'] as int,
        color: json['color'] as String? ?? 'yellow',
        text: json['text'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
}
