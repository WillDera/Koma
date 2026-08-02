import 'package:flutter/material.dart';
import '../core/models/chapter.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/app_spacing.dart';
import 'animated_press.dart';
import 'dialog_sheet.dart';
import 'text_field.dart';

class ChapterSheet extends StatefulWidget {
  final String bookTitle;
  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const ChapterSheet({
    super.key,
    required this.bookTitle,
    required this.chapters,
    required this.currentIndex,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookTitle,
    required List<Chapter> chapters,
    required int currentIndex,
    required ValueChanged<int> onSelect,
  }) {
    return StashSheet.show<void>(
      context,
      title: bookTitle,
      subtitle: '${chapters.length} chapters',
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      child: ChapterSheet(
        bookTitle: bookTitle,
        chapters: chapters,
        currentIndex: currentIndex,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<ChapterSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _filter.trim().isEmpty
        ? widget.chapters
        : widget.chapters
              .where(
                (ch) => ch.title.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: StashTextField(
            hint: 'Search chapters',
            leadingIcon: Icons.search,
            showClearButton: true,
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (ctx, i) {
              final ch = filtered[i];
              final originalIndex = widget.chapters.indexOf(ch);
              final isCurrent = originalIndex == widget.currentIndex;
              return AnimatedPress(
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSelect(originalIndex);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: isCurrent ? c.accentMuted : Colors.transparent,
                    borderRadius: AppSpacing.brMd,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${originalIndex + 1}',
                          style: TextStyle(
                            color: isCurrent ? c.accent : c.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ch.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Icon(Icons.bookmark, size: 16, color: c.accent)
                      else if (ch.readAt != null)
                        Icon(Icons.check, size: 16, color: c.textTertiary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
