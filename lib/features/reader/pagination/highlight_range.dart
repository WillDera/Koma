import '../../../core/models/highlight.dart';

/// Highlights whose `[startOffset, endOffset)` overlaps `[start, end)`.
List<Highlight> highlightsOverlapping(
  List<Highlight> highlights, {
  required int start,
  required int end,
}) {
  if (end <= start) return const [];
  return [
    for (final h in highlights)
      if (h.startOffset < end && h.endOffset > start) h,
  ];
}
