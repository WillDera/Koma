import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kenji-style opaque manga reader top bar.
class ReaderAppBar extends StatelessWidget {
  final String? mangaName;
  final String chapterName;
  final bool isBookmarked;
  final bool isVisible;
  final VoidCallback onClose;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onChapterList;

  const ReaderAppBar({
    super.key,
    this.mangaName,
    required this.chapterName,
    required this.isBookmarked,
    required this.isVisible,
    required this.onClose,
    required this.onBookmarkToggle,
    required this.onChapterList,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: isVisible ? 0 : -120,
      left: 0,
      right: 0,
      child: Material(
        color: const Color(0xFF0F0F0F),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            right: 4,
            bottom: 8,
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary),
                onPressed: onClose,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onChapterList,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mangaName != null)
                          Text(
                            mangaName!,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          chapterName,
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border_outlined,
                  color: isBookmarked ? c.accent : c.textSecondary,
                ),
                onPressed: onBookmarkToggle,
                tooltip: 'Bookmark',
              ),
              IconButton(
                icon: Icon(
                  Icons.format_list_numbered_outlined,
                  color: c.textSecondary,
                ),
                onPressed: onChapterList,
                tooltip: 'Chapter list',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
