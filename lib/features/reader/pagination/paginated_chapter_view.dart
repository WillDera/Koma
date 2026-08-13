import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_type.dart';
import '../html/reading_document.dart';
import 'chapter_paginator.dart';
import 'empty_selection_menu.dart';
import 'reading_spans.dart';

/// Renders exactly one page of a chapter, with no scroll view.
///
/// The page is a character range ([PageBreak]) into the chapter's extracted
/// plain text, so this widget shares [ReadingSpans] with the scrolling reader
/// and highlight/TTS/bionic decoration behaves identically.
///
/// Selection offsets reported by [onSelectionChanged] are rebased into
/// chapter coordinates, since [SelectableText] reports them relative to the
/// substring it was given.
class PaginatedChapterView extends StatelessWidget {
  /// Full extracted plain text of the chapter.
  final String text;

  /// Structured document for rich styles / images. When null, falls back to
  /// plain [text] painting.
  final ReadingDocument? document;

  /// The slice of [text] this page shows.
  final PageBreak page;

  /// Chapter title, drawn only when [showTitle] is set (the chapter's
  /// first page).
  final String chapterTitle;
  final bool showTitle;

  /// Vertical space between the title and the body. Must match the paginator's
  /// `firstPageInset` accounting, or measured breaks won't match what renders.
  final double titleGap;

  final ThemeState themeProv;
  final List<Highlight> highlights;

  final bool ttsActive;
  final int ttsStart;
  final int ttsEnd;
  final int focusStart;
  final int focusEnd;
  final double focusAlpha;

  /// Rebuild discriminator so edits to highlights re-run selection state.
  final int highlightVersion;

  /// Content width used to size image WidgetSpans (must match paginator).
  final double? contentWidth;

  /// Fires with chapter-relative offsets, or null when the selection clears.
  final void Function(int start, int end)? onSelected;
  final VoidCallback? onSelectionCleared;
  final VoidCallback? onSelectionCollapsed;

  const PaginatedChapterView({
    super.key,
    required this.text,
    this.document,
    required this.page,
    required this.chapterTitle,
    required this.themeProv,
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
    this.contentWidth,
    this.onSelected,
    this.onSelectionCleared,
    this.onSelectionCollapsed,
  });

  /// Vertical space the title consumes on a first page, so callers can pass the
  /// same value to [ChapterPaginator.firstPageInset] and keep measurement and
  /// rendering in agreement.
  static double titleInsetFor(
    BuildContext context,
    ThemeState prov,
    String title,
    double maxWidth, {
    double gap = 28,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (title.isEmpty) return gap;
    final painter = TextPainter(
      text: TextSpan(text: title, style: _titleStyle(context, prov)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final h = painter.height;
    painter.dispose();
    return h + gap;
  }

  static TextStyle _titleStyle(BuildContext context, ThemeState prov) {
    return AppType.reading(
      fontSize: prov.fontSize,
      lineHeight: prov.lineHeight,
      color: context.colors.textTertiary,
    ).copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = ReadingSpans.style(themeProv, context.colors.textPrimary);
    final c = context.colors;
    final width = contentWidth ?? MediaQuery.sizeOf(context).width;
    final doc = document;
    final children = doc != null
        ? ReadingSpans.buildFromDocument(
            doc: doc,
            prov: themeProv,
            baseStyle: baseStyle,
            brightness: Theme.of(context).brightness,
            highlights: highlights,
            ttsActive: ttsActive,
            ttsStart: ttsStart,
            ttsEnd: ttsEnd,
            focusStart: focusStart,
            focusEnd: focusEnd,
            focusAlpha: focusAlpha,
            rangeStart: page.start,
            rangeEnd: page.end,
            contentWidth: width,
            includeImages: true,
            linkColor: c.accent,
            onLinkTap: ReadingSpans.openLink,
          )
        : ReadingSpans.build(
            text: text,
            prov: themeProv,
            baseStyle: baseStyle,
            brightness: Theme.of(context).brightness,
            highlights: highlights,
            ttsActive: ttsActive,
            ttsStart: ttsStart,
            ttsEnd: ttsEnd,
            focusStart: focusStart,
            focusEnd: focusEnd,
            focusAlpha: focusAlpha,
            rangeStart: page.start,
            rangeEnd: page.end,
          );

    final body = SelectableText.rich(
      key: ValueKey('page-${page.start}-${page.end}-$highlightVersion'),
      TextSpan(
        style: baseStyle,
        children: children,
      ),
      textAlign: themeProv.textAlign,
      contextMenuBuilder: emptyTextSelectionContextMenu,
      onSelectionChanged: (selection, cause) {
        if (selection.isValid && !selection.isCollapsed) {
          // SelectableText reports offsets into the spans it rendered, which
          // start at page.start in chapter coordinates.
          final start = (page.start + selection.start).clamp(0, text.length);
          final end = (page.start + selection.end).clamp(0, text.length);
          if (end > start) onSelected?.call(start, end);
        } else if (selection.isValid && selection.isCollapsed) {
          onSelectionCollapsed?.call();
        } else {
          onSelectionCleared?.call();
        }
      },
    );

    return ColoredBox(
      // Opaque page background. The curl stacks this page under its neighbour
      // and snapshots both to textures mid-turn, so a transparent page would
      // let the one underneath show through — idle *and* while turning — and
      // would capture a blank texture for the mesh to curl.
      color: themeProv.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(chapterTitle, style: _titleStyle(context, themeProv)),
            SizedBox(height: titleGap),
          ],
          // The page is measured to fit, so the body takes the space it needs
          // and any rounding slack falls to the bottom rather than clipping
          // text.
          Flexible(
            child: Align(alignment: Alignment.topLeft, child: body),
          ),
        ],
      ),
    );
  }
}
