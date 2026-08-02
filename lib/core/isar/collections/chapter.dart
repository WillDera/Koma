import 'package:isar_community/isar.dart';

part 'chapter.g.dart';

@collection
@Name('Chapter')
class Chapter {
  Id? id;

  @Index() // hot lookup: chapters of a book
  int bookId;

  String title;
  String content;

  /// 0-based position of this chapter within its parent book.
  int index;

  DateTime? readAt;

  /// Per-chapter scroll restoration (parallel to book.scrollPosition).
  double scrollPosition;

  /// Reading position as a character offset into the chapter's extracted plain
  /// text. Unlike [scrollPosition] this survives a font-size or viewport
  /// change, so it is what paginated mode restores from.
  ///
  /// Null means "never recorded" — a book last read before pagination existed.
  /// Those fall back to approximating from [scrollPosition] once, after which
  /// this field takes over.
  int? readingCharOffset;

  Chapter({
    this.id = Isar.autoIncrement,
    required this.bookId,
    required this.title,
    required this.content,
    required this.index,
    this.readAt,
    this.scrollPosition = 0.0,
    this.readingCharOffset,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'title': title,
        'content': content,
        'index': index,
        'read_at': readAt?.toIso8601String(),
        'scroll_position': scrollPosition,
    'reading_char_offset': readingCharOffset,
  };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as int?,
        bookId: json['book_id'] as int,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        index: json['index'] as int,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
        scrollPosition:
            (json['scroll_position'] as num?)?.toDouble() ?? 0.0,
    readingCharOffset: (json['reading_char_offset'] as num?)?.toInt(),
  );
}
