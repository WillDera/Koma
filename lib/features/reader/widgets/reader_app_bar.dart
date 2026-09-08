import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/animated_press.dart';

/// Kenji-style manga top chrome: circular back + title pill + circle actions
/// (matches [ReaderBottomBar]).
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
    final title = mangaName?.trim();
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: isVisible ? 0 : -120,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
        ),
        child: Row(
          children: [
            _CircleBtn(
              icon: Icons.arrow_back_ios_new,
              onTap: onClose,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedPress(
                onTap: onChapterList,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        chapterName,
                        style: TextStyle(
                          color: title != null && title.isNotEmpty
                              ? c.textTertiary
                              : c.textPrimary,
                          fontSize: title != null && title.isNotEmpty
                              ? 11
                              : 13,
                          fontWeight: title != null && title.isNotEmpty
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleBtn(
              icon: isBookmarked
                  ? Icons.bookmark
                  : Icons.bookmark_border_outlined,
              onTap: onBookmarkToggle,
              accent: isBookmarked,
            ),
            const SizedBox(width: 8),
            _CircleBtn(
              icon: Icons.format_list_numbered_outlined,
              onTap: onChapterList,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent ? c.accent : const Color(0xFF1A1A1A),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: accent ? c.onAccent : c.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}
