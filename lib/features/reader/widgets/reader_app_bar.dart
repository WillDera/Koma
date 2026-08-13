import 'package:flutter/material.dart';

/// Redesigned reader app bar inspired by mangayomi.
///
/// Shows manga name + chapter title, back button, chapter list button,
/// bookmark toggle. Animates in/out with the toolbar visibility.
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
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: isVisible ? 0 : -120,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            chapterName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
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
                    isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border_outlined,
                    color: isBookmarked ? Colors.orangeAccent : Colors.white70,
                  ),
                  onPressed: onBookmarkToggle,
                  tooltip: 'Bookmark',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.format_list_numbered_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: onChapterList,
                  tooltip: 'Chapter list',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
