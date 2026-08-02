import 'package:flutter/material.dart';
import '../core/models/book.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_motion.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'book_cover.dart';
import 'progress_ring.dart';

/// Horizontal carousel of "Continue reading" cards. Each card is a large
/// cover with a thin progress bar and the book title. Used at the top of
/// the Library screen.
class ContinueReadingShelf extends StatefulWidget {
  final List<Book> books;
  final ValueChanged<Book> onTap;

  const ContinueReadingShelf({
    super.key,
    required this.books,
    required this.onTap,
  });

  @override
  State<ContinueReadingShelf> createState() => _ContinueReadingShelfState();
}

class _ContinueReadingShelfState extends State<ContinueReadingShelf> {
  final ScrollController _ctrl = ScrollController();
  double _maxScroll = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _maxScroll = _ctrl.position.maxScrollExtent;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Continue reading',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${widget.books.length} in progress',
                style: TextStyle(
                  color: c.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) {
              final book = widget.books[i];
              return _ContinueCard(book: book, onTap: () => widget.onTap(book));
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_maxScroll > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.standard,
              height: 2,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(1),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.2,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _ContinueCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.97,
      child: SizedBox(
        width: 280,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brXl,
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: AppSpacing.shadow1(
              isDark: c.bg.computeLuminance() < 0.5,
            ),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'book-cover-${book.id}',
                child: SizedBox(
                  width: 80,
                  child: BookCover(book: book, variant: BookCoverVariant.list),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (book.author != null && book.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 10),
                        ProgressRing(
                          progress: book.progress,
                          size: 28,
                          strokeWidth: 2,
                          color: c.accent,
                          trackColor: c.border,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(book.progress * 100).toInt()}% · Resume',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
