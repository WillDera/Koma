import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/highlight.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../html/reading_document.dart';
import 'empty_selection_menu.dart';
import 'reading_spans.dart';

/// Hybrid scroll-mode chapter body: block widgets for headings / quotes /
/// images / lists, [SelectableText.rich] for each text block.
class RichChapterBody extends StatelessWidget {
  final ReadingDocument document;
  final ThemeState themeProv;
  final TextStyle baseStyle;
  final Brightness brightness;
  final List<Highlight> highlights;
  final bool ttsActive;
  final int ttsStart;
  final int ttsEnd;
  final String contentKey;
  final TextAlign textAlign;
  final void Function(TextSelection selection)? onSelectionChanged;
  final VoidCallback? onSelectionCleared;

  const RichChapterBody({
    super.key,
    required this.document,
    required this.themeProv,
    required this.baseStyle,
    required this.brightness,
    this.highlights = const [],
    this.ttsActive = false,
    this.ttsStart = 0,
    this.ttsEnd = 0,
    required this.contentKey,
    required this.textAlign,
    this.onSelectionChanged,
    this.onSelectionCleared,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final blocks = document.blocks;
    if (blocks.isEmpty) {
      return SelectableText.rich(
        key: ValueKey(contentKey),
        TextSpan(
          style: baseStyle,
          children: ReadingSpans.buildFromDocument(
            doc: document,
            prov: themeProv,
            baseStyle: baseStyle,
            brightness: brightness,
            highlights: highlights,
            ttsActive: ttsActive,
            ttsStart: ttsStart,
            ttsEnd: ttsEnd,
            linkColor: c.accent,
            onLinkTap: ReadingSpans.openLink,
          ),
        ),
        textAlign: textAlign,
        contextMenuBuilder: emptyTextSelectionContextMenu,
        onSelectionChanged: (sel, _) {
          if (sel.isValid && !sel.isCollapsed) {
            onSelectionChanged?.call(sel);
          } else {
            onSelectionCleared?.call();
          }
        },
      );
    }

    return Column(
      key: ValueKey(contentKey),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: _gapBefore(blocks[i])),
          _buildBlock(context, blocks[i], c),
        ],
      ],
    );
  }

  double _gapBefore(ReadingBlock block) {
    if (block.isHeading) return 22;
    if (block.kind == ReadingBlockKind.blockquote) return 16;
    if (block.kind == ReadingBlockKind.image) return 8;
    if (block.kind == ReadingBlockKind.thematicBreak) return 20;
    return 10;
  }

  Widget _buildBlock(BuildContext context, ReadingBlock block, KomaColors c) {
    switch (block.kind) {
      case ReadingBlockKind.image:
        return _BlockImage(path: block.imagePath ?? '');
      case ReadingBlockKind.thematicBreak:
        return Divider(
          height: 28,
          thickness: 0.8,
          color: c.border.withValues(alpha: 0.7),
        );
      case ReadingBlockKind.blockquote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: c.accent.withValues(alpha: 0.85), width: 3),
            ),
            color: c.accent.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
          ),
          child: _textBlock(
            block,
            baseStyle.copyWith(
              color: baseStyle.color?.withValues(alpha: 0.88) ?? c.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            c,
          ),
        );
      case ReadingBlockKind.listItem:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28.0 * block.listDepth,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  block.listMarker ?? '•',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _textBlock(block, baseStyle, c)),
          ],
        );
      default:
        final scale = block.isHeading
            ? ReadingSpans.headingScale(block.kind)
            : 1.0;
        final headingStyle = block.isHeading
            ? baseStyle.copyWith(
                fontSize: (baseStyle.fontSize ?? 16) * scale,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: 0.15,
              )
            : baseStyle;
        return _textBlock(block, headingStyle, c);
    }
  }

  Widget _textBlock(ReadingBlock block, TextStyle style, KomaColors c) {
    if (!block.hasText) return const SizedBox.shrink();
    final children = ReadingSpans.buildFromDocument(
      doc: document,
      prov: themeProv,
      baseStyle: style,
      brightness: brightness,
      highlights: highlights,
      ttsActive: ttsActive,
      ttsStart: ttsStart,
      ttsEnd: ttsEnd,
      rangeStart: block.start,
      rangeEnd: block.end,
      includeImages: false,
      linkColor: c.accent,
      onLinkTap: ReadingSpans.openLink,
    );
    return SelectableText.rich(
      TextSpan(style: style, children: children),
      textAlign: textAlign,
      contextMenuBuilder: emptyTextSelectionContextMenu,
      onSelectionChanged: (sel, _) {
        if (sel.isValid && !sel.isCollapsed) {
          // Rebase page-local selection into chapter plain-text coordinates.
          final rebased = TextSelection(
            baseOffset: block.start + sel.baseOffset,
            extentOffset: block.start + sel.extentOffset,
          );
          onSelectionChanged?.call(rebased);
        } else {
          onSelectionCleared?.call();
        }
      },
    );
  }
}

class _BlockImage extends StatelessWidget {
  final String path;
  const _BlockImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (path.isEmpty) return const SizedBox.shrink();
    final filePath = path.startsWith('file:')
        ? Uri.parse(path).toFilePath()
        : path;
    final file = File(filePath);
    if (!file.existsSync()) {
      return Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: AppSpacing.brSm,
        ),
        child: Icon(Icons.broken_image_outlined, color: c.textTertiary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => Container(
          height: 72,
          alignment: Alignment.center,
          color: c.surfaceMuted,
          child: Icon(Icons.broken_image_outlined, color: c.textTertiary),
        ),
      ),
    );
  }
}
