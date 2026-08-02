import 'book_page_cursor.dart';

/// Where a paginated reader should open, and whether that position was exact.
class ResumeTarget {
  final BookPosition position;

  /// True when the position came from a stored character offset, false when it
  /// was approximated from a legacy pixel scroll offset.
  ///
  /// An approximated position should be persisted as a character offset right
  /// away, so the approximation happens exactly once per chapter.
  final bool exact;

  const ResumeTarget(this.position, {required this.exact});

  @override
  String toString() => 'ResumeTarget($position, exact: $exact)';
}

/// Resolves a paginated reading position from whatever was persisted.
///
/// Three sources, in order of trust:
///  1. a stored character offset — exact, and survives layout changes;
///  2. a legacy pixel scroll offset — approximated as a fraction of content;
///  3. nothing — start of the chapter.
///
/// Pixel offsets cannot be converted exactly, because doing so would need the
/// layout that produced them and that layout is gone. Approximating once and
/// then storing a character offset means the imprecision does not compound.
class ResumeResolver {
  const ResumeResolver({
    required this.cursor,
    required this.charOffsetFor,
    required this.pixelOffsetFor,
    required this.contentHeightFor,
  });

  final BookPageCursor cursor;

  /// Stored character offset for a chapter index, or null if never recorded.
  final int? Function(int chapterIndex) charOffsetFor;

  /// Legacy stored pixel scroll offset for a chapter index.
  final double Function(int chapterIndex) pixelOffsetFor;

  /// Best estimate of the scrollable content height the pixel offset was
  /// recorded against. Null when unknown, in which case the pixel offset can't
  /// be turned into a fraction and the chapter opens at its start.
  final double? Function(int chapterIndex) contentHeightFor;

  ResumeTarget resolve(int chapterIndex) {
    final stored = charOffsetFor(chapterIndex);
    if (stored != null) {
      return ResumeTarget(
        cursor.positionForOffset(chapterIndex, stored),
        exact: true,
      );
    }

    final pixels = pixelOffsetFor(chapterIndex);
    final height = contentHeightFor(chapterIndex);
    if (pixels > 0 && height != null && height > 0) {
      final fraction = pixels / height;
      return ResumeTarget(
        cursor.approximateFromScrollFraction(chapterIndex, fraction),
        // Approximate: the caller should persist a character offset now.
        exact: false,
      );
    }

    return ResumeTarget(BookPosition(chapterIndex, 0), exact: true);
  }
}
