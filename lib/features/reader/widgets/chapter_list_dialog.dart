import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/models/manga_chapter.dart';
import '../../../core/models/manga.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../widgets/animated_press.dart';

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
    // ref.* needs the element to finish mounting — never call from initState body.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repos = ref.read(repositoriesProvider);
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
    final c = context.colors;
    return Dialog(
      backgroundColor: c.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.brXl,
        side: BorderSide(color: c.border, width: 0.5),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 22, color: c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _manga?.name ?? 'Chapters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedPress(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: c.border),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: c.accent),
              )
            else if (_chapters == null || _chapters!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'No chapters',
                  style: TextStyle(color: c.textSecondary),
                ),
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
    final c = context.colors;
    final isRead = chapter.isRead;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedPress(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: isCurrent
                ? c.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: AppSpacing.brMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: isRead
                      ? c.textTertiary.withValues(alpha: 0.35)
                      : c.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
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
                            ? c.textTertiary
                            : c.textPrimary,
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
                            color: c.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Now',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
