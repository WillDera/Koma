import 'package:flutter/widgets.dart';

import '../../../core/models/chapter.dart';
import '../../../core/utils/text_extractor.dart';
import 'chapter_paginator.dart';

/// A position in the book: which chapter, and which page within it.
@immutable
class BookPosition {
  final int chapterIndex;
  final int pageIndex;

  const BookPosition(this.chapterIndex, this.pageIndex);

  @override
  bool operator ==(Object other) =>
      other is BookPosition &&
      other.chapterIndex == chapterIndex &&
      other.pageIndex == pageIndex;

  @override
  int get hashCode => Object.hash(chapterIndex, pageIndex);

  @override
  String toString() => 'BookPosition(ch $chapterIndex, page $pageIndex)';
}

/// Maps between book positions and the flat page indices [PageCurlView] wants,
/// paginating chapters on demand.
///
/// Chapters are measured lazily — opening a book only measures the chapter being
/// read, and neighbours are measured when the reader approaches them. Results
/// are cached per chapter and invalidated wholesale when the layout changes,
/// since a [PaginationKey] change moves every break.
class BookPageCursor {
  BookPageCursor({required this.chapters, required this.paginatorFor});

  final List<Chapter> chapters;

  /// Supplies a paginator configured for a chapter. Takes the chapter index
  /// because the title inset differs per chapter (titles wrap differently).
  final ChapterPaginator Function(int chapterIndex) paginatorFor;

  final Map<int, PaginatedChapter> _cache = {};
  PaginationKey? _key;

  /// Discards cached pagination when the layout changes. Returns true if
  /// anything was invalidated, so callers can decide whether to re-resolve the
  /// reading position.
  bool updateKey(PaginationKey key) {
    if (_key == key) return false;
    _key = key;
    _cache.clear();
    return true;
  }

  PaginationKey? get key => _key;

  /// Pagination for [chapterIndex], measuring it if not already cached.
  PaginatedChapter? pagesFor(int chapterIndex) {
    final key = _key;
    if (key == null) return null;
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return null;

    final cached = _cache[chapterIndex];
    if (cached != null) return cached;

    final chapter = chapters[chapterIndex];
    final text = TextExtractor.extractCached(chapter.id, chapter.content);
    final result = paginatorFor(
      chapterIndex,
    ).paginate(chapterId: chapter.id, text: text, key: key);
    _cache[chapterIndex] = result;
    return result;
  }

  /// Whether [chapterIndex] has already been measured, so callers can avoid
  /// forcing a synchronous measure on the render path.
  bool isPaginated(int chapterIndex) => _cache.containsKey(chapterIndex);

  int pageCountOf(int chapterIndex) => pagesFor(chapterIndex)?.pageCount ?? 0;

  /// The position one page after [pos], crossing into the next chapter's first
  /// page at a chapter end. Null at the end of the book.
  BookPosition? next(BookPosition pos) {
    final pages = pagesFor(pos.chapterIndex);
    if (pages == null) return null;
    if (pos.pageIndex + 1 < pages.pageCount) {
      return BookPosition(pos.chapterIndex, pos.pageIndex + 1);
    }
    final nextChapter = pos.chapterIndex + 1;
    if (nextChapter >= chapters.length) return null;
    return BookPosition(nextChapter, 0);
  }

  /// The position one page before [pos], crossing into the previous chapter's
  /// last page at a chapter start. Null at the start of the book.
  BookPosition? previous(BookPosition pos) {
    if (pos.pageIndex > 0) {
      return BookPosition(pos.chapterIndex, pos.pageIndex - 1);
    }
    final prevChapter = pos.chapterIndex - 1;
    if (prevChapter < 0) return null;
    final pages = pagesFor(prevChapter);
    if (pages == null) return null;
    return BookPosition(prevChapter, pages.pageCount - 1);
  }

  /// Clamps [pos] to a page that actually exists.
  BookPosition clamp(BookPosition pos) {
    if (chapters.isEmpty) return const BookPosition(0, 0);
    final ci = pos.chapterIndex.clamp(0, chapters.length - 1);
    final pages = pagesFor(ci);
    if (pages == null) return BookPosition(ci, 0);
    return BookPosition(ci, pos.pageIndex.clamp(0, pages.pageCount - 1));
  }

  /// The page in [chapterIndex] containing [charOffset].
  BookPosition positionForOffset(int chapterIndex, int charOffset) {
    final pages = pagesFor(chapterIndex);
    if (pages == null) return BookPosition(chapterIndex, 0);
    return BookPosition(chapterIndex, pages.pageIndexForOffset(charOffset));
  }

  /// Character offset a position starts at, for persisting reading progress.
  int offsetAt(BookPosition pos) {
    final pages = pagesFor(pos.chapterIndex);
    if (pages == null) return 0;
    return pages.offsetForPageIndex(pos.pageIndex);
  }

  /// The character range a position covers.
  PageBreak pageAt(BookPosition pos) {
    final pages = pagesFor(pos.chapterIndex);
    if (pages == null) return const PageBreak(0, 0);
    return pages.pageAt(pos.pageIndex);
  }

  /// Maps a legacy pixel scroll offset onto a page, by treating it as a
  /// fraction of the old content height.
  ///
  /// Pixel offsets can't be converted exactly without the layout that produced
  /// them, which is gone. This lands the reader close, and callers should
  /// persist a character offset afterwards so the approximation happens once.
  BookPosition approximateFromScrollFraction(
    int chapterIndex,
    double fraction,
  ) {
    final pages = pagesFor(chapterIndex);
    if (pages == null) return BookPosition(chapterIndex, 0);
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    final offset = (f * pages.textLength).round();
    return BookPosition(chapterIndex, pages.pageIndexForOffset(offset));
  }

  void invalidate() => _cache.clear();
}
