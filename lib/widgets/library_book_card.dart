import 'package:flutter/material.dart';
import '../core/models/book.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'book_cover.dart';
import 'progress_ring.dart';

enum LibraryCardVariant { grid, list, compact }

class LibraryBookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;
  final LibraryCardVariant variant;

  const LibraryBookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.variant = LibraryCardVariant.grid,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == LibraryCardVariant.list) return _list(context);
    if (variant == LibraryCardVariant.compact) return _compact(context);
    return _grid(context);
  }

  Widget _grid(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              BookCover(book: book, variant: BookCoverVariant.grid),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: AppSpacing.brPill,
                  ),
                  child: Text(
                    _sourceLabel(book.source),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (book.progress > 0 && book.progress < 1)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: ThinProgressBar(
                      progress: book.progress,
                      height: 3,
                      color: Colors.white,
                      trackColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              if (selectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check,
                            size: 14, color: c.onAccent)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
          if (book.author != null && book.author!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scaleDown: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : Colors.transparent,
          borderRadius: AppSpacing.brLg,
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? c.accent : c.textTertiary,
              ),
              const SizedBox(width: 12),
            ],
            Stack(
              children: [
                BookCover(book: book, variant: BookCoverVariant.list),
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: AppSpacing.brPill,
                    ),
                    child: Text(
                      _sourceLabel(book.source),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (book.author != null && book.author!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (book.progress > 0)
                    Row(
                      children: [
                        Expanded(
                          child: ThinProgressBar(
                            progress: book.progress,
                            height: 3,
                            color: c.accent,
                            trackColor: c.border,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(book.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _sourceLabel(book.source),
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.97,
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookCover(book: book, variant: BookCoverVariant.grid),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'web':
        return 'WEB ARTICLE';
      case 'manual':
        return 'NOTE';
      default:
        return 'EPUB';
    }
  }
}
