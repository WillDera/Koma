import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/models/manga_chapter.dart';
import '../../../core/models/manga.dart';

/// Dialog for viewing and jumping to chapters from within the reader.
///
/// Inspired by mangayomi's chapter list dialog. Shows chapters grouped
/// with read status, current chapter highlighted, and bookmark indicators.
class ChapterListDialog extends ConsumerStatefulWidget {
  final int mangaId;
  final String sourceId;
  final String mangaUrl;
  final String currentChapterUrl;

  const ChapterListDialog({
    super.key,
    required this.mangaId,
    required this.sourceId,
    required this.mangaUrl,
    required this.currentChapterUrl,
  });

  @override
  ConsumerState<ChapterListDialog> createState() => _ChapterListDialogState();
}

class _ChapterListDialogState extends ConsumerState<ChapterListDialog> {
  List<MangaChapter>? _chapters;
  Manga? _manga;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repos = ref.watch(repositoriesProvider);
    final manga = await repos.manga.getMangaByKey(
      widget.sourceId,
      widget.mangaUrl,
    );
    final chapters = await repos.manga.getMangaChapters(widget.mangaId);
    if (mounted) {
      setState(() {
        _manga = manga;
        _chapters = chapters.reversed
            .toList(); // newest first, matching detail page
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _manga?.name ?? 'Chapters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            // List
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_chapters == null || _chapters!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('No chapters'),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: _chapters!.length,
                  itemBuilder: (context, i) {
                    final ch = _chapters![i];
                    final isCurrent = ch.url == widget.currentChapterUrl;
                    return _ChapterTile(
                      chapter: ch,
                      isCurrent: isCurrent,
                      onTap: () => Navigator.pop(context, ch),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final MangaChapter chapter;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ChapterTile({
    required this.chapter,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = chapter.isRead;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isCurrent
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Read indicator
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.grey.withValues(alpha: 0.3)
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isRead
                              ? theme.textTheme.bodySmall?.color?.withValues(
                                  alpha: 0.4,
                                )
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chapter.lastPageRead > 0 && !isRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Page ${chapter.lastPageRead + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Current indicator
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Now',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
