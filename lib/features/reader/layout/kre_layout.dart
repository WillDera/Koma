import 'dart:ui' show Offset;

/// Level 3 layout boxes from KRE-shaped KIR (Flutter still paints).
///
/// [charStart]/[charEnd] are into [LayoutResult.plainText], which matches
/// [KirToDocument] (no chapter title, images 0 chars).
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
int? hitTestLayoutPage(LayoutPage page, Offset local) {
  final x = local.dx;
  final y = local.dy;
  for (final line in page.lines) {
    if (y < line.y || y >= line.y + line.height) continue;
    for (final g in line.glyphs) {
      if (x >= g.x && x < g.x + g.width) return g.charStart;
    }
    if (line.glyphs.isNotEmpty) return line.charStart;
  }
  return null;
}

/// Half-open [PageBreak] ranges from laid-out pages.
List<(int, int)> pageCharRanges(LayoutResult layout) {
  return [
    for (final p in layout.pages)
      if (p.charEnd >= p.charStart) (p.charStart, p.charEnd),
  ];
}
