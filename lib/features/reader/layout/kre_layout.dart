import 'dart:ui' show Offset, Rect;

/// Level 3 layout boxes from KRE-shaped KIR.
///
/// [charStart]/[charEnd] are Dart `String` indices (UTF-16 code units) into
/// [LayoutResult.plainText], matching [KirToDocument] (no chapter title,
/// images 0 chars). The reader paginates and paints from these boxes;
/// [hitTestLayoutPage] maps a tap back to the same offsets highlights and
/// TTS already use.
class LayoutGlyph {
  const LayoutGlyph({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.charStart,
    required this.charEnd,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int charStart;
  final int charEnd;
}

class LayoutLine {
  const LayoutLine({
    required this.y,
    required this.height,
    required this.charStart,
    required this.charEnd,
    this.glyphs = const [],
  });

  final double y;
  final double height;
  final int charStart;
  final int charEnd;
  final List<LayoutGlyph> glyphs;

  /// Image placeholder: reserved height, no characters.
  bool get isImage => glyphs.isEmpty;
}

class LayoutPage {
  const LayoutPage({
    required this.charStart,
    required this.charEnd,
    this.lines = const [],
  });

  final int charStart;
  final int charEnd;
  final List<LayoutLine> lines;
}

class LayoutResult {
  const LayoutResult({required this.plainText, this.pages = const []});

  final String plainText;
  final List<LayoutPage> pages;
}

/// Pixel → character offset. `null` if [local] misses every line.
///
/// On a hit line, a tap left of the first glyph returns the line start; a tap
/// to the right of the last glyph returns that glyph's exclusive [charEnd]
/// (caret-after), so a drag-to-select can cover the whole line.
int? hitTestLayoutPage(LayoutPage page, Offset local) {
  final x = local.dx;
  final y = local.dy;
  for (final line in page.lines) {
    if (y < line.y || y >= line.y + line.height) continue;
    if (line.glyphs.isEmpty) return line.charStart;
    if (x < line.glyphs.first.x) return line.charStart;
    for (final g in line.glyphs) {
      if (x >= g.x && x < g.x + g.width) return g.charStart;
    }
    return line.glyphs.last.charEnd;
  }
  return null;
}

/// Line-box rects for glyphs whose `[charStart, charEnd)` overlaps `[start, end)`.
List<Rect> glyphRectsOverlapping(LayoutPage page, int start, int end) {
  if (end <= start) return const [];
  final out = <Rect>[];
  for (final line in page.lines) {
    for (final g in line.glyphs) {
      if (g.charEnd <= start || g.charStart >= end) continue;
      out.add(Rect.fromLTWH(g.x, line.y, g.width, line.height));
    }
  }
  return out;
}

/// Half-open page ranges from laid-out pages.
List<(int, int)> pageCharRanges(LayoutResult layout) {
  return [
    for (final p in layout.pages)
      if (p.charEnd >= p.charStart) (p.charStart, p.charEnd),
  ];
}

/// Slice of [plain] for a layout range. Offsets are Dart UTF-16 indices.
String layoutSlice(String plain, int start, int end) {
  final s = start.clamp(0, plain.length);
  final e = end.clamp(s, plain.length);
  return plain.substring(s, e);
}

/// How many image placeholder lines sit on pages before [pageIndex].
int imageSlotBase(LayoutResult layout, int pageIndex) {
  var n = 0;
  for (var i = 0; i < pageIndex && i < layout.pages.length; i++) {
    for (final line in layout.pages[i].lines) {
      if (line.isImage) n++;
    }
  }
  return n;
}
