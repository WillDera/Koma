import 'package:isar_community/isar.dart';

part 'snippet.g.dart';

@collection
@Name('Snippet')
class Snippet {
  Id? id;

  /// The selected passage. Existing column is named `content` in Drift but
  /// the model field is `text` — we keep `text` here for UI parity and
  /// serialize as `text` in toJson (matches existing backup JSON format).
  String text;

  String? note;
  String? sourceTitle;
  String? sourceUrl;

  /// Hex color string for the snippet card accent (e.g. '#FFD700').
  String? color;

  /// FK → [Book.id]. Nullable — web-only snippets have no book.
  @Index()
  int? bookId;

  /// FK → [Chapter.id]. Nullable — snippets can exist without a chapter.
  @Index()
  int? chapterId;

  /// FK → [SnippetCollection.id]. Nullable — snippets can be uncollected.
  @Index()
  int? collectionId;

  /// Character offsets within the chapter — used by the reader to
  /// re-select the snippet's source passage on tap.
  int? startOffset;
  int? endOffset;
  double? scrollPosition;

  /// Denormalized tag list. The catalog of all tags lives in the [Tag]
  /// collection; this is the per-snippet convenience copy.
  List<String>? tags;

  DateTime? createdAt;
  DateTime? updatedAt;

  Snippet({
    this.id = Isar.autoIncrement,
    required this.text,
    this.note,
    this.sourceTitle,
    this.sourceUrl,
    this.color,
    this.bookId,
    this.chapterId,
    this.collectionId,
    this.startOffset,
    this.endOffset,
    this.scrollPosition,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

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
        'start_offset': startOffset,
        'end_offset': endOffset,
        'scroll_position': scrollPosition,
        'tags': tags ?? const [],
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as int?,
        text: json['text'] as String,
        note: json['note'] as String?,
        sourceTitle: json['source_title'] as String?,
        sourceUrl: json['source_url'] as String?,
        color: json['color'] as String?,
        bookId: json['book_id'] as int?,
        chapterId: json['chapter_id'] as int?,
        collectionId: json['collection_id'] as int?,
        startOffset: json['start_offset'] as int?,
        endOffset: json['end_offset'] as int?,
        scrollPosition: (json['scroll_position'] as num?)?.toDouble(),
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}
