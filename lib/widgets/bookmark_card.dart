import 'package:flutter/material.dart';

import '../../core/models/bookmark.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../widgets/animated_press.dart';

class BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final String? chapterName;
  final String? sourceTitle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const BookmarkCard({
    super.key,
    required this.bookmark,
    this.chapterName,
    this.sourceTitle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.bookmark_rounded, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapterName ?? 'Chapter ${bookmark.chapterId}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (sourceTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sourceTitle!,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    bookmark.pageNumber != null
                        ? 'Page ${bookmark.pageNumber! + 1}'
                        : 'Scroll position',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              _formatDate(bookmark.createdAt),
              style: TextStyle(color: c.textTertiary, fontSize: 11),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: c.textTertiary),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) return '${date.month}/${date.day}';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
