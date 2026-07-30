import 'package:isar_community/isar.dart';

part 'bookmark.g.dart';

@collection
@Name('Bookmark')
class Bookmark {
  Id? id;

  /// FK → [Book.id].
  @Index()
  int bookId;

  /// FK → [Chapter.id].
  @Index()
  int chapterId;

  /// 0-based page index within the chapter. Nullable — null means this
  /// bookmark is identified by [scrollPosition] instead (webtoon mode).
  int? pageNumber;

  /// Scroll offset for webtoon mode (null for paged).
  double? scrollPosition;

  DateTime? createdAt;

  Bookmark({
    this.id = Isar.autoIncrement,
    required this.bookId,
    required this.chapterId,
    required this.pageNumber,
    this.scrollPosition,
    this.createdAt,
  });
}
