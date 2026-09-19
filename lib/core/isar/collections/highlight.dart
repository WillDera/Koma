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

  /// FK → [Book.id]. Null when this highlight is novel-backed ([mangaId]).
  @Index()
  int? bookId;

  /// FK → [Chapter.id]. Null when novel-backed.
  @Index()
  int? chapterId;

  /// FK → manga library row for novel highlights.
  @Index()
  int? mangaId;

  /// FK → [MangaChapter.id] for novel highlights.
  @Index()
  int? mangaChapterId;

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
    this.bookId,
    this.chapterId,
    this.mangaId,
    this.mangaChapterId,
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
    'manga_id': mangaId,
    'manga_chapter_id': mangaChapterId,
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
    bookId: json['book_id'] as int?,
    chapterId: json['chapter_id'] as int?,
    mangaId: json['manga_id'] as int?,
    mangaChapterId: json['manga_chapter_id'] as int?,
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
