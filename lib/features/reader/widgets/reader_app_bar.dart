import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/animated_press.dart';

/// Kenji manga reader chrome sits on dark pills regardless of app theme.
/// Always paint bright glyphs so light/sepia themes don't go dark-on-dark.
const Color _readerChromeBg = Color(0xFF1A1A1A);
const Color _readerChromeFg = Color(0xFFEFEFF0);
const Color _readerChromeFgMuted = Color(0xFFC7C6CA);

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
                    color: _readerChromeBg,
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
                          style: const TextStyle(
                            color: _readerChromeFg,
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
                              ? _readerChromeFgMuted
                              : _readerChromeFg,
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
              accentColor: c.accent,
              onAccentColor: c.onAccent,
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
  final Color? accentColor;
  final Color? onAccentColor;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.accentColor,
    this.onAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accent ? (accentColor ?? _readerChromeBg) : _readerChromeBg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: accent
              ? (onAccentColor ?? _readerChromeFg)
              : _readerChromeFg,
          size: 22,
        ),
      ),
    );
  }
}
