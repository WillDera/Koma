import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_colors.dart';
import '../html/reading_document.dart';
import '../pagination/paginated_chapter_view.dart';
import '../pagination/reading_spans.dart';
import 'kre_layout.dart';

/// One KRE-laid-out sheet: line boxes from cosmic-text, painted with the
/// same face KRE wrapped with. Selection goes through [hitTestLayoutPage].
class KrePageView extends StatefulWidget {
  const KrePageView({
    super.key,
    required this.page,
    required this.plainText,
    required this.themeProv,
    required this.chapterTitle,
    this.document,
    this.showTitle = false,
    this.titleGap = 28,
    this.highlights = const [],
    this.ttsActive = false,
    this.ttsStart = 0,
    this.ttsEnd = 0,
    this.focusStart = 0,
    this.focusEnd = 0,
    this.focusAlpha = 0,
    this.highlightVersion = 0,
    this.embeds = const [],
    this.imageSlotBase = 0,
    this.onSelected,
    this.onSelectionCleared,
    this.onSelectionCollapsed,
  });

  final LayoutPage page;
  final String plainText;
  final ReadingDocument? document;
  final ThemeState themeProv;
  final String chapterTitle;
  final bool showTitle;
  final double titleGap;
  final List<Highlight> highlights;
  final bool ttsActive;
  final int ttsStart;
  final int ttsEnd;
  final int focusStart;
  final int focusEnd;
  final double focusAlpha;
  final int highlightVersion;
  final List<ReadingEmbed> embeds;
  final int imageSlotBase;
  final void Function(int start, int end)? onSelected;
  final VoidCallback? onSelectionCleared;
  final VoidCallback? onSelectionCollapsed;

  @override
  State<KrePageView> createState() => _KrePageViewState();
}

class _KrePageViewState extends State<KrePageView> {
  int? _selStart;
  int? _selEnd;

  void _clearSelection({required bool collapsed}) {
    if (_selStart == null) return;
    setState(() {
      _selStart = null;
      _selEnd = null;
    });
    if (collapsed) {
      widget.onSelectionCollapsed?.call();
    } else {
      widget.onSelectionCleared?.call();
    }
  }

  void _extendSelection(Offset local) {
    final hit = hitTestLayoutPage(widget.page, local);
    if (hit == null) return;
    final anchor = _selStart ?? hit;
    final a = math.min(anchor, hit);
    final b = math.max(anchor, hit);
    setState(() {
      _selStart = anchor;
      _selEnd = hit;
    });
    if (b > a) {
      widget.onSelected?.call(a, b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = ReadingSpans.style(
      widget.themeProv,
      context.colors.textPrimary,
    );
    final brightness = Theme.of(context).brightness;
    var imageSlot = widget.imageSlotBase;

    return ColoredBox(
      color: widget.themeProv.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(
              widget.chapterTitle,
              style: PaginatedChapterView.titleStyleFor(
                context,
                widget.themeProv,
              ),
            ),
            SizedBox(height: widget.titleGap),
          ],
          Expanded(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    key: ValueKey(widget.highlightVersion),
                    painter: _KrePagePainter(
                      page: widget.page,
                      plainText: widget.plainText,
                      document: widget.document,
                      baseStyle: baseStyle,
                      textScaler: MediaQuery.textScalerOf(context),
                      highlights: widget.highlights,
                      ttsActive: widget.ttsActive,
                      ttsStart: widget.ttsStart,
                      ttsEnd: widget.ttsEnd,
                      focusStart: widget.focusStart,
                      focusEnd: widget.focusEnd,
                      focusAlpha: widget.focusAlpha,
                      brightness: brightness,
                      isSepia: widget.themeProv.sepiaMode,
                      accent: widget.themeProv.accentColor,
                      selStart: _selStart,
                      selEnd: _selEnd,
                    ),
                  ),
                  for (final line in widget.page.lines)
                    if (line.isImage)
                      _imageAt(line, imageSlot++),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_selStart != null) {
                        _clearSelection(collapsed: true);
                      }
                    },
                    onLongPressStart: (d) {
                      _selStart = hitTestLayoutPage(
                        widget.page,
                        d.localPosition,
                      );
                      _selEnd = _selStart;
                    },
                    onLongPressMoveUpdate: (d) =>
                        _extendSelection(d.localPosition),
                    onLongPressEnd: (_) {
                      final a = _selStart;
                      final b = _selEnd;
                      if (a == null || b == null || a == b) {
                        _clearSelection(collapsed: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageAt(LayoutLine line, int slot) {
    if (slot < 0 || slot >= widget.embeds.length) {
      return const SizedBox.shrink();
    }
    final embed = widget.embeds[slot];
    return Positioned(
      top: line.y,
      left: 0,
      right: 0,
      height: line.height,
      child: _KreEmbedImage(path: embed.path),
    );
  }
}

class _KrePagePainter extends CustomPainter {
  _KrePagePainter({
    required this.page,
    required this.plainText,
    required this.document,
    required this.baseStyle,
    required this.textScaler,
    required this.highlights,
    required this.ttsActive,
    required this.ttsStart,
    required this.ttsEnd,
    required this.focusStart,
    required this.focusEnd,
    required this.focusAlpha,
    required this.brightness,
    required this.isSepia,
    required this.accent,
    required this.selStart,
    required this.selEnd,
  });

  final LayoutPage page;
  final String plainText;
  final ReadingDocument? document;
  final TextStyle baseStyle;
  final TextScaler textScaler;
  final List<Highlight> highlights;
  final bool ttsActive;
  final int ttsStart;
  final int ttsEnd;
  final int focusStart;
  final int focusEnd;
  final double focusAlpha;
  final Brightness brightness;
  final bool isSepia;
  final Color accent;
  final int? selStart;
  final int? selEnd;

  @override
  void paint(Canvas canvas, Size size) {
    void fill(List<Rect> rects, Color color) {
      final paint = Paint()..color = color;
      for (final r in rects) {
        canvas.drawRect(r, paint);
      }
    }

    for (final h in highlights) {
      fill(
        glyphRectsOverlapping(page, h.startOffset, h.endOffset),
        AppColors.highlightWash(h.color, brightness, isSepia: isSepia),
      );
    }
    if (ttsActive && ttsEnd > ttsStart) {
      fill(
        glyphRectsOverlapping(page, ttsStart, ttsEnd),
        accent.withValues(alpha: 0.15),
      );
    }
    if (focusAlpha > 0 && focusEnd > focusStart) {
      fill(
        glyphRectsOverlapping(page, focusStart, focusEnd),
        AppColors.highlight(
          'yellow',
          brightness,
          isSepia: isSepia,
        ).withValues(alpha: focusAlpha),
      );
    }
    final a = selStart;
    final b = selEnd;
    if (a != null && b != null && a != b) {
      fill(
        glyphRectsOverlapping(page, math.min(a, b), math.max(a, b)),
        accent.withValues(alpha: 0.22),
      );
    }

    for (final line in page.lines) {
      if (line.isImage) continue;
      _paintLine(canvas, line);
    }
  }

  void _paintLine(Canvas canvas, LayoutLine line) {
    final cuts = <int>{line.charEnd};
    for (final h in highlights) {
      if (h.endOffset <= line.charStart || h.startOffset >= line.charEnd) {
        continue;
      }
      cuts.add(h.startOffset.clamp(line.charStart, line.charEnd));
      cuts.add(h.endOffset.clamp(line.charStart, line.charEnd));
    }
    final sorted = cuts.toList()..sort();
    var x = 0.0;
    var cursor = line.charStart;
    final lineStyle = _styleFor(line);
    for (final cut in sorted) {
      if (cut <= cursor) continue;
      final slice = layoutSlice(plainText, cursor, cut);
      if (slice.isNotEmpty) {
        var style = lineStyle;
        final marked = highlights.any(
          (h) => cursor >= h.startOffset && cursor < h.endOffset,
        );
        if (marked) {
          style = style.copyWith(
            fontWeight: ReadingSpans.highlightWeight(style.fontWeight),
          );
        }
        final painter = TextPainter(
          text: TextSpan(text: slice, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        painter.paint(canvas, Offset(x, line.y));
        x += painter.width;
        painter.dispose();
      }
      cursor = cut;
    }
  }

  TextStyle _styleFor(LayoutLine line) {
    var s = baseStyle;
    final doc = document;
    if (doc == null) return s;
    for (final b in doc.blocks) {
      if (!b.isHeading) continue;
      if (line.charStart >= b.start && line.charStart < b.end) {
        s = s.copyWith(
          fontSize: (s.fontSize ?? 17) * b.headingScale(),
          fontWeight: FontWeight.w600,
        );
        break;
      }
    }
    for (final r in doc.styleRuns) {
      if (r.end <= line.charStart || r.start >= line.charEnd) continue;
      if (r.flags.bold) s = s.copyWith(fontWeight: FontWeight.w700);
      if (r.flags.italic) s = s.copyWith(fontStyle: FontStyle.italic);
      if (r.flags.underline) {
        s = s.copyWith(decoration: TextDecoration.underline);
      }
      break;
    }
    return s;
  }

  @override
  bool shouldRepaint(covariant _KrePagePainter old) {
    return old.page != page ||
        old.plainText != plainText ||
        old.baseStyle != baseStyle ||
        old.highlights != highlights ||
        old.ttsActive != ttsActive ||
        old.ttsStart != ttsStart ||
        old.ttsEnd != ttsEnd ||
        old.focusStart != focusStart ||
        old.focusEnd != focusEnd ||
        old.focusAlpha != focusAlpha ||
        old.selStart != selStart ||
        old.selEnd != selEnd ||
        old.brightness != brightness ||
        old.isSepia != isSepia;
  }
}

class _KreEmbedImage extends StatelessWidget {
  const _KreEmbedImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return Icon(Icons.broken_image_outlined, color: context.colors.textTertiary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}
