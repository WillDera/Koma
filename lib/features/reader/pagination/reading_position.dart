/// Maps a scroll pixel offset onto a character offset (and back) using the
/// same length-ratio snippet jump already uses.
///
/// Not exact — title inset and images distort the mapping — but it is stable
/// across Scroll ↔ Page so both modes share one resume coordinate.
int charOffsetFromScroll({
  required int textLength,
  required double pixels,
  required double maxExtent,
}) {
  if (textLength <= 0 || maxExtent <= 0) return 0;
  final ratio = (pixels / maxExtent).clamp(0.0, 1.0);
  return (ratio * textLength).round().clamp(0, textLength);
}

double scrollPixelsFromChar({
  required int charOffset,
  required int textLength,
  required double maxExtent,
}) {
  if (textLength <= 0 || maxExtent <= 0) return 0;
  final clamped = charOffset.clamp(0, textLength);
  return ((clamped / textLength) * maxExtent).clamp(0.0, maxExtent);
}
