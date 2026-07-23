import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../app.dart' show routeObserver;
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';
import '../extensions/manga_detail_screen.dart';
import '../reader/reader_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with RouteAware {
  final ScrollController _scrollCtrl = ScrollController();
  double _scrollProgress = 0;
  List<Book> _books = [];
  List<Map<String, dynamic>> _mangaRows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    if ((p - _scrollProgress).abs() > 0.01) {
      setState(() => _scrollProgress = p);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _load();
  }

  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<DatabaseService>();
    final results = await Future.wait([
      db.getInProgressBooks(),
      db.getInProgressManga(),
    ]);
    _books = results[0] as List<Book>;
    _mangaRows = results[1] as List<Map<String, dynamic>>;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clearProgress(Book book) async {
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear reading history?',
      content:
          'Remove "${book.title}" from your history. '
          'The book and its chapters will be kept.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    );
    if (confirmed != true) return;
    final db = context.read<DatabaseService>();
    await db.clearProgress(book.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final ts = _oneHand ? 64.0 : 32.0;
    final sp = _oneHand ? _scrollProgress : 0.0;
    final total = _books.length + _mangaRows.length;
    if (total == 0) {
      return ScreenBackdrop(
        child: SafeArea(
          bottom: false,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              const OneHandSpacer(),
              LibraryHeader(
                title: 'History',
                titleSize: ts,
                shrinkProgress: sp,
              ),
              const SizedBox(height: 80),
              const EmptyState(
                icon: Icons.history,
                title: 'No reading history',
                subtitle: 'Books and manga you\'re reading will appear here',
              ),
            ],
          ),
        ),
      );
    }
    final count = total;
    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: ListView.separated(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: count + 1,
          separatorBuilder: (_, i) =>
              i == 0 ? const SizedBox.shrink() : const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Column(
                children: [
                  const OneHandSpacer(),
                  LibraryHeader(
                    title: 'History',
                    subtitle: '$count in progress',
                    titleSize: ts,
                    shrinkProgress: sp,
                  ),
                  StaggeredEntrance(
                    child: FeaturePanel(
                      icon: Icons.local_library_outlined,
                      title: 'Pick up where you left off',
                      subtitle:
                          'Your active books and manga are ordered for quick returns and clean resets.',
                      stats: [
                        PanelStat(value: '$count', label: 'Active'),
                        PanelStat(
                          value:
                              '${_books.isNotEmpty ? (_books.fold<double>(0, (sum, b) => sum + b.progress) / _books.length * 100).round() : 0}%',
                          label: 'Average',
                        ),
                      ],
                    ),
                  ),
                  SectionLabel(title: 'Continue', meta: '$count'),
                ],
              );
            }
            final idx = i - 1;
            if (idx < _books.length) {
              return _bookTile(c, idx);
            } else {
              return _mangaTile(c, idx - _books.length);
            }
          },
        ),
      ),
    );
  }

  Widget _bookTile(KomaColors c, int i) {
    final book = _books[i];
    final pct = (book.progress * 100).toInt();
    return StaggeredEntrance(
      index: i + 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: AnimatedPress(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(bookId: book.id),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.border, width: 0.5),
              boxShadow: AppSpacing.shadow2(
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 64,
                  child: BookCover(
                    book: book,
                    variant: BookCoverVariant.compact,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (book.author != null && book.author!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ThinProgressBar(
                              progress: book.progress,
                              height: 4,
                              color: c.accent,
                              trackColor: c.border,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: c.textTertiary,
                    ),
                    onPressed: () => _clearProgress(book),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mangaTile(KomaColors c, int i) {
    final row = _mangaRows[i];
    final name = row['name'] as String? ?? '';
    final author = row['author'] as String?;
    final imageUrl = row['image_url'] as String?;
    final id = row['id'] as int;
    final sourceId = row['source_id'] as String? ?? '';
    final url = row['url'] as String? ?? '';
    final readCount = row['read_count'] as int? ?? 0;
    final totalChapters = row['total_chapters'] as int? ?? 0;
    final progress = totalChapters > 0 ? readCount / totalChapters : 0.0;
    final pct = (progress * 100).toInt();

    return StaggeredEntrance(
      index: i + _books.length + 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: AnimatedPress(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MangaDetailScreen(
                sourceId: sourceId,
                url: url,
                title: name,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.border, width: 0.5),
              boxShadow: AppSpacing.shadow2(
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: c.surfaceMuted, child: Icon(Icons.broken_image, size: 24, color: c.textTertiary)))
                        : Container(color: c.surfaceMuted, child: Icon(Icons.auto_stories, size: 24, color: c.textTertiary)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (author != null && author.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ThinProgressBar(
                              progress: progress,
                              height: 4,
                              color: c.accent,
                              trackColor: c.border,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: c.textTertiary,
                    ),
                    onPressed: () => _clearMangaProgress(row),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearMangaProgress(Map<String, dynamic> mangaRow) async {
    final name = mangaRow['name'] as String? ?? '';
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear reading history?',
      content:
          'Remove "$name" from your history. '
          'The manga will be kept in your library.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    );
    if (confirmed != true) return;
    final db = context.read<DatabaseService>();
    await db.clearMangaChapterHistory(mangaRow['id'] as int);
    await _load();
  }
}
