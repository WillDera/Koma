import 'package:isar_community/isar.dart';

part 'highlight.g.dart';

@collection
@Name('Highlight')
class Highlight {
  Id? id;

  /// FK → [Snippet.id]. Nullable — a highlight can exist before being
  /// promoted to a snippet.
  @Index()
  int? snippetId;

  /// FK → [Book.id]. Required — highlights are always anchored to a book.
  @Index()
  int bookId;

  /// FK → [Chapter.id]. Required — highlights are anchored to a chapter.
  @Index()
  int chapterId;

  int startOffset;
  int endOffset;

  /// Named color (yellow, green, blue, pink, underline) — matches the
  /// existing schema default.
  String color;

  String text;

  DateTime? createdAt;
  DateTime? updatedAt;

  Highlight({
    this.id = Isar.autoIncrement,
    this.snippetId,
    required this.bookId,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    this.color = 'yellow',
    required this.text,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'snippet_id': snippetId,
    'book_id': bookId,
    'chapter_id': chapterId,
    'start_offset': startOffset,
    'end_offset': endOffset,
    'color': color,
    'text': text,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    id: json['id'] as int?,
    snippetId: json['snippet_id'] as int?,
    bookId: json['book_id'] as int,
    chapterId: json['chapter_id'] as int,
    startOffset: json['start_offset'] as int,
    endOffset: json['end_offset'] as int,
    color: json['color'] as String? ?? 'yellow',
    text: json['text'] as String,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );
}
