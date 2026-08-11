import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models/snippet.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_colors.dart';
import '../theme/tokens/app_spacing.dart';
import '../theme/tokens/app_type.dart';
import 'animated_press.dart';
import 'tag_pill.dart';

class SnippetCard extends StatelessWidget {
  final Snippet snippet;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpenSource;
  final bool dense;
  final bool selected;
  final bool selectionMode;

  const SnippetCard({
    super.key,
    required this.snippet,
    this.onTap,
    this.onLongPress,
    this.onOpenSource,
    this.dense = false,
    this.selected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final isSepia = c.bg == AppColors.sepiaBg;
    final colorKey = snippet.color ?? 'yellow';
    final color = AppColors.highlight(colorKey, brightness, isSepia: isSepia);

    return AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.99,
      child: Container(
        decoration: BoxDecoration(
          color: selectionMode && selected ? c.accentMuted : c.surface,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-width highlight color bar (Figma).
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source row + selection checkbox
                  Row(
                    children: [
                      if (snippet.sourceTitle != null)
                        Expanded(
                          child: GestureDetector(
                            onTap: onOpenSource,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.book_outlined,
                                  size: 14,
                                  color: onOpenSource != null
                                      ? c.accent
                                      : c.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    snippet.sourceTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: onOpenSource != null
                                          ? c.accent
                                          : c.textSecondary,
                                      fontSize: 12,
                                      fontWeight: onOpenSource != null
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (selectionMode)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? c.accent
                                : Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? c.accent : c.textTertiary,
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? Icon(Icons.check, size: 13, color: c.onAccent)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quote block with left accent strip
                  ClipRRect(
                    borderRadius: AppSpacing.brMd,
                    child: Container(
                      width: double.infinity,
                      color: c.surfaceMuted,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 3, color: color),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                child: Text(
                                  '"${snippet.text}"',
                                  maxLines: dense ? 3 : 8,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.readingItalic(
                                    fontSize: 13,
                                    lineHeight: 1.65,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Note
                  if (snippet.note != null && snippet.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      snippet.note!,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Footer
                  Row(
                    children: [
                      Text(
                        _relativeDate(snippet.createdAt),
                        style: TextStyle(color: c.textTertiary, fontSize: 10),
                      ),
                      const Spacer(),
                      if (snippet.tags.isNotEmpty)
                        Text(
                          '${snippet.tags.length} tag${snippet.tags.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  if (snippet.tags.isNotEmpty && !dense) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: snippet.tags
                          .take(4)
                          .map((t) => TagPill(label: t))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) return DateFormat('MMM d').format(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
