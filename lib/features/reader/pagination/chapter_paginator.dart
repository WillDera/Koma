import 'package:flutter/material.dart';

import '../../../theme/theme_state.dart';

/// One page of a chapter, as a half-open character range into the chapter's
/// extracted plain text: `[start, end)`.
///
/// Character offsets — not pixels — are the coordinate space highlights, TTS
/// and selection already use, so pages expressed this way survive font and
/// layout changes.
@immutable
class PageBreak {
  final int start;
  final int end;

  const PageBreak(this.start, this.end);

  int get length => end - start;

  bool get isEmpty => end <= start;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  bool operator ==(Object other) =>
      other is PageBreak && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PageBreak($start..$end)';
}

/// Everything about the layout that can change where pages break.
///
/// Value equality is the point: a chapter's pagination is only reusable while
/// its key still matches, so any font, spacing or viewport change invalidates
/// it and triggers a re-measure.
@immutable
class PaginationKey {
  final Size viewport;
  final double fontSize;
  final double lineHeight;
  final TextAlign textAlign;
  final String? fontFamily;
  final bool bionicReading;

  const PaginationKey({
    required this.viewport,
    required this.fontSize,
    required this.lineHeight,
    required this.textAlign,
    required this.fontFamily,
    required this.bionicReading,
  });

  /// Derives a key from the current theme state and the measured content box.
  factory PaginationKey.from(ThemeState prov, Size viewport) {
    return PaginationKey(
      viewport: viewport,
      fontSize: prov.fontSize,
      lineHeight: prov.lineHeight,
      textAlign: prov.textAlign,
      fontFamily: prov.effectiveReadingFontFamily,
      bionicReading: prov.bionicReading,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaginationKey &&
      other.viewport == viewport &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.textAlign == textAlign &&
      other.fontFamily == fontFamily &&
      other.bionicReading == bionicReading;

  @override
  int get hashCode => Object.hash(
    viewport,
    fontSize,
    lineHeight,
    textAlign,
    fontFamily,
    bionicReading,
  );
}

/// A chapter split into pages, plus the layout it was measured against.
@immutable
class PaginatedChapter {
  final int chapterId;
  final List<PageBreak> pages;
  final PaginationKey key;

  /// Total length of the text that was paginated, for bounds checks.
  final int textLength;

  const PaginatedChapter({
    required this.chapterId,
    required this.pages,
    required this.key,
    required this.textLength,
  });

  int get pageCount => pages.length;

  /// The page holding [charOffset]. Clamped, so an out-of-range offset lands on
  /// the first or last page rather than throwing.
  int pageIndexForOffset(int charOffset) {
    if (pages.isEmpty) return 0;
    if (charOffset <= pages.first.start) return 0;
    if (charOffset >= pages.last.end) return pages.length - 1;

    // Pages are contiguous and ascending, so binary search is exact.
    var lo = 0;
    var hi = pages.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (charOffset < pages[mid].end) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Character offset a page starts at, for persisting reading position.
  int offsetForPageIndex(int pageIndex) {
    if (pages.isEmpty) return 0;
    return pages[pageIndex.clamp(0, pages.length - 1)].start;
  }

  PageBreak pageAt(int pageIndex) {
    if (pages.isEmpty) return const PageBreak(0, 0);
    return pages[pageIndex.clamp(0, pages.length - 1)];
  }
}

/// Splits chapter text into pages by measuring it against a viewport.
///
/// Measurement is a single [TextPainter] layout per chapter: lay the whole
/// chapter out at the page width, then walk [TextPainter.computeLineMetrics]
/// accumulating line heights, starting a new page whenever the next line would
/// overflow. Breaks therefore always land on line boundaries — never mid-line.
///
/// One layout pass beats a binary search per page, which matters because bionic
/// mode multiplies the span count.
class ChapterPaginator {
  /// Builds the spans for a character range. The paginator measures exactly
  /// what the renderer will draw, which matters for bionic mode: bold segments
  /// are wider and would otherwise shift the metrics.
  final List<InlineSpan> Function(int start, int end) spanBuilder;

  /// Vertical space to reserve on the first page, for the chapter title.
  final double firstPageInset;

  const ChapterPaginator({required this.spanBuilder, this.firstPageInset = 0});

  /// Measures [text] and returns its page breaks.
  ///
  /// [textScaler] should be the ambient scaler so accessibility text sizing is
  /// accounted for in the measurement.
  PaginatedChapter paginate({
    required int chapterId,
    required String text,
    required PaginationKey key,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final empty = PaginatedChapter(
      chapterId: chapterId,
      pages: const [PageBreak(0, 0)],
      key: key,
      textLength: text.length,
    );

    if (text.isEmpty) return empty;

    final width = key.viewport.width;
    final height = key.viewport.height;
    // A viewport with no room can't be measured; treat the chapter as one page
    // so the reader still shows something rather than dividing by zero.
    if (width <= 0 || height <= 0) {
      return PaginatedChapter(
        chapterId: chapterId,
        pages: [PageBreak(0, text.length)],
        key: key,
        textLength: text.length,
      );
    }

    final span = TextSpan(children: spanBuilder(0, text.length));
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: key.textAlign,
      textScaler: textScaler,
    );
    // WidgetSpan.build asserts dimensions != null. TextPainter only fills
    // those when we pass placeholder sizes; without this, any chapter that
    // contains an image throws during paginate (warm-neighbour and chapter
    // turns are the usual triggers).
    final placeholders = _placeholderDimensionsOf(span);
    if (placeholders.isNotEmpty) {
      painter.setPlaceholderDimensions(placeholders);
    }
    painter.layout(maxWidth: width);

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) {
      painter.dispose();
      return empty;
    }

    final pages = <PageBreak>[];
    var pageStart = 0;
    var consumed = 0.0;
    // The title only displaces content on the first page.
    var budget = (height - firstPageInset).clamp(0.0, height);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // This line overflows the page — close the page before it, unless it is
      // the first line on the page (a single line taller than the viewport
      // must still be placed somewhere, or we would loop forever).
      if (consumed > 0 && consumed + line.height > budget) {
        final breakAt = _offsetAtLineTop(painter, line, width);
        // Guard against a non-advancing break: if the offset resolution lands
        // at or behind the page start, keep the line on this page instead of
        // emitting an empty one.
        if (breakAt > pageStart) {
          pages.add(PageBreak(pageStart, breakAt));
          pageStart = breakAt;
          consumed = line.height;
          budget = height;
          continue;
        }
      }
      consumed += line.height;
    }

    // Whatever is left after the last break is the final page.
    if (pageStart < text.length) {
      pages.add(PageBreak(pageStart, text.length));
    }
    painter.dispose();

    if (pages.isEmpty) pages.add(PageBreak(0, text.length));

    return PaginatedChapter(
      chapterId: chapterId,
      pages: pages,
      key: key,
      textLength: text.length,
    );
  }

  /// Character offset of the first character on [line].
  ///
  /// Probes just below the line's top edge at the leading horizontal edge, then
  /// asks the painter which text position sits there.
  int _offsetAtLineTop(TextPainter painter, LineMetrics line, double width) {
    final y = line.baseline - line.ascent + 1.0;
    // Probe from the line's own left edge so centred and right-aligned text
    // resolve to the first glyph rather than to empty margin.
    final x = line.left + 0.5;
    final pos = painter.getPositionForOffset(Offset(x.clamp(0.0, width), y));
    return pos.offset;
  }
}

/// Placeholder sizes for [WidgetSpan]s in [root], in document order.
///
/// Image spans in [ReadingSpans] wrap a [SizedBox] with an explicit width and
/// height; those become the paragraph placeholders. Anything else is empty so
/// layout still succeeds.
List<PlaceholderDimensions> _placeholderDimensionsOf(InlineSpan root) {
  final out = <PlaceholderDimensions>[];
  root.visitChildren((span) {
    if (span is WidgetSpan) {
      out.add(
        PlaceholderDimensions(
          size: _placeholderSize(span.child),
          alignment: span.alignment,
          baseline: span.baseline ?? TextBaseline.alphabetic,
        ),
      );
    }
    return true;
  });
  return out;
}

Size _placeholderSize(Widget child) {
  if (child is SizedBox) {
    return Size(child.width ?? 0, child.height ?? 0);
  }
  return Size.zero;
}
