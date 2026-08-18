import 'dart:ui' show Offset, Rect;

/// Text lines allowed above, between, or below figures before the image
/// stays an in-flow band instead of expanding into leftover page space.
const int kImageCaptionLineLimit = 5;

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

  /// True when the sheet has figures and no text (cover / plate / splash).
  bool get isImageOnly =>
      lines.isNotEmpty && lines.every((l) => l.isImage);

  /// Figure sheet: at least one image, and at most [kImageCaptionLineLimit]
  /// text lines above, between, and below the figure(s).
  bool get expandsImage => imageExpandLayout(this, 0).expand;
}

/// Where the figure band sits when [LayoutPage.expandsImage] is true.
class ImageExpandLayout {
  const ImageExpandLayout({
    required this.expand,
    this.top = 0,
    this.bottom = 0,
  });

  final bool expand;

  /// Distance from the page top to the image band.
  final double top;

  /// Distance from the page bottom to the image band.
  final double bottom;

  static const none = ImageExpandLayout(expand: false);
}

/// [height] is only used to place the band; pass 0 when checking [expand].
ImageExpandLayout imageExpandLayout(
  LayoutPage page,
  double height, {
  double gap = 8,
  int captionLines = kImageCaptionLineLimit,
}) {
  if (!page.lines.any((l) => l.isImage)) return ImageExpandLayout.none;
  final first = page.lines.indexWhere((l) => l.isImage);
  final last = page.lines.lastIndexWhere((l) => l.isImage);
  var before = 0;
  var after = 0;
  var between = 0;
  for (var i = 0; i < page.lines.length; i++) {
    if (page.lines[i].isImage) continue;
    if (i < first) {
      before++;
    } else if (i > last) {
      after++;
    } else {
      between++;
    }
  }
  if (before > captionLines ||
      after > captionLines ||
      between > captionLines) {
    return ImageExpandLayout.none;
  }
  if (page.isImageOnly || height <= 0) {
    return const ImageExpandLayout(expand: true);
  }

  var leadingBottom = 0.0;
  for (var i = 0; i < first; i++) {
    final line = page.lines[i];
    if (line.isImage) continue;
    final bottom = line.y + line.height;
    if (bottom > leadingBottom) leadingBottom = bottom;
  }

  var hasTrail = false;
  var trailMin = 0.0;
  var trailMax = 0.0;
  for (var i = last + 1; i < page.lines.length; i++) {
    final line = page.lines[i];
    if (line.isImage) continue;
    if (!hasTrail) {
      trailMin = line.y;
      trailMax = line.y + line.height;
      hasTrail = true;
    } else {
      if (line.y < trailMin) trailMin = line.y;
      final bottom = line.y + line.height;
      if (bottom > trailMax) trailMax = bottom;
    }
  }
  final trailH = hasTrail ? trailMax - trailMin : 0.0;
  final top = leadingBottom > 0 ? leadingBottom + gap : 0.0;
  final bottom = trailH > 0 ? trailH + gap : 0.0;
  if (height - top - bottom < 48) {
    return ImageExpandLayout.none;
  }
  return ImageExpandLayout(expand: true, top: top, bottom: bottom);
}

/// Moves caption lines under an expanded figure to the bottom of the sheet
/// so highlights and hit-testing match what is painted.
LayoutPage rebaseExpandedImagePage(
  LayoutPage page,
  ImageExpandLayout layout,
  double height,
) {
  if (!layout.expand || page.isImageOnly || layout.bottom <= 0) return page;
  final last = page.lines.lastIndexWhere((l) => l.isImage);
  var trailMin = double.infinity;
  for (var i = last + 1; i < page.lines.length; i++) {
    if (page.lines[i].isImage) continue;
    if (page.lines[i].y < trailMin) trailMin = page.lines[i].y;
  }
  if (trailMin.isInfinite) return page;
  final trailH = layout.bottom > 8 ? layout.bottom - 8 : layout.bottom;
  final dy = (height - trailH) - trailMin;
  if (dy.abs() < 0.5) return page;
  return LayoutPage(
    charStart: page.charStart,
    charEnd: page.charEnd,
    lines: [
      for (var i = 0; i < page.lines.length; i++)
        if (i > last && !page.lines[i].isImage)
          _shiftLine(page.lines[i], dy)
        else
          page.lines[i],
    ],
  );
}

LayoutLine _shiftLine(LayoutLine line, double dy) {
  return LayoutLine(
    y: line.y + dy,
    height: line.height,
    charStart: line.charStart,
    charEnd: line.charEnd,
    glyphs: [
      for (final g in line.glyphs)
        LayoutGlyph(
          x: g.x,
          y: g.y + dy,
          width: g.width,
          height: g.height,
          charStart: g.charStart,
          charEnd: g.charEnd,
        ),
    ],
  );
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
