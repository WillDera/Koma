import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show routeObserver;
import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/repositories/manga_repository.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';

enum _HistoryFilter { all, books, manga }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with RouteAware {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Book> _books = [];
  List<InProgressManga> _mangaRows = [];
  bool _loading = true;
  int _lastSeenRevision = 0;
  _HistoryFilter _filter = _HistoryFilter.all;

  /// Cover providers cached per manga id so tile rebuilds reuse the same
  /// [ImageProvider] instance instead of constructing a new one each build.
  final Map<int, ImageProvider> _coverCache = {};

  @override
  void initState() {
    super.initState();
    _lastSeenRevision = ref.read(historyRevisionProvider);
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    // Watch the global history revision so we reload in real time when the
    // reader writes progress (shell-tab screens don't reliably get
    // RouteAware.didPopNext from root-level reader routes).
    final rev = ref.read(historyRevisionProvider);
    if (rev != _lastSeenRevision) {
      _lastSeenRevision = rev;
      _load();
    }
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repos = ref.read(repositoriesProvider);
    final results = await Future.wait([
      repos.books.getInProgressBooks(),
      repos.manga.getInProgressManga(),
    ]);
    _books = results[0] as List<Book>;
    _mangaRows = results[1] as List<InProgressManga>;
    // Cover URLs may have changed with the reloaded rows.
    _coverCache.clear();
    if (mounted) setState(() => _loading = false);
  }

  int get _totalCount => _books.length + _mangaRows.length;

  List<Book> get _filteredBooks {
    if (_filter == _HistoryFilter.manga) return const [];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _books;
    return _books
        .where((b) => b.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  List<InProgressManga> get _filteredManga {
    if (_filter == _HistoryFilter.books) return const [];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _mangaRows;
    return _mangaRows
        .where((r) => r.manga.name.toLowerCase().contains(q))
        .toList(growable: false);
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
    final repos = ref.read(repositoriesProvider);
    await repos.books.clearProgress(book.id);
    await _load();
  }

  Future<void> _clearMangaProgress(InProgressManga mangaRow) async {
    final name = mangaRow.manga.name;
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
    final repos = ref.read(repositoriesProvider);
    await repos.manga.clearMangaChapterHistory(mangaRow.manga.id);
    await _load();
  }

  Future<void> _clearAll() async {
    if (_totalCount == 0) return;
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Clear all history?',
      content:
          'Remove all books and manga from your reading history. '
          'Your library items will be kept.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear all'),
        ),
      ],
    );
    if (confirmed != true) return;
    final repos = ref.read(repositoriesProvider);
    for (final book in List<Book>.from(_books)) {
      await repos.books.clearProgress(book.id);
    }
    for (final row in List<InProgressManga>.from(_mangaRows)) {
      await repos.manga.clearMangaChapterHistory(row.manga.id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // React to reader progress writes in real time.
    ref.listen<int>(historyRevisionProvider, (prev, next) {
      if (next != _lastSeenRevision) {
        _lastSeenRevision = next;
        _load();
      }
    });
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final books = _filteredBooks;
    final manga = _filteredManga;
    final filteredCount = books.length + manga.length;
    final isEmpty = filteredCount == 0;

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: ListView.separated(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: isEmpty ? 2 : filteredCount + 1,
          separatorBuilder: (_, i) =>
              i == 0 ? const SizedBox.shrink() : const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OneHandSpacer(),
                  LibraryHeader(
                    title: 'History',
                    subtitle:
                        '$filteredCount ${filteredCount == 1 ? 'entry' : 'entries'}',
                    actions: [
                      if (_totalCount > 0) _ClearAllButton(onTap: _clearAll),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search history...',
                        hintStyle: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: AppIcon(
                            data: AppIcons.search,
                            size: 15,
                            color: c.textSecondary,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        filled: true,
                        fillColor: c.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppSpacing.brMd,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppSpacing.brMd,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppSpacing.brMd,
                          borderSide: BorderSide(color: c.accent, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        for (final f in _HistoryFilter.values) ...[
                          if (f != _HistoryFilter.all) const SizedBox(width: 8),
                          _FilterChip(
                            label: switch (f) {
                              _HistoryFilter.all => 'All',
                              _HistoryFilter.books => 'Books',
                              _HistoryFilter.manga => 'Manga',
                            },
                            selected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }
            if (isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 64),
                child: EmptyState(
                  icon: AppIcons.history,
                  title: _totalCount == 0
                      ? 'No history yet'
                      : 'No matching history',
                  subtitle: _totalCount == 0
                      ? 'Books and manga you\'re reading will appear here'
                      : 'Try a different search or filter',
                ),
              );
            }
            final idx = i - 1;
            if (idx < books.length) {
              return _bookTile(c, books[idx], idx);
            }
            return _mangaTile(c, manga[idx - books.length], idx);
          },
        ),
      ),
    );
  }

  /// Caps the entrance-animation stagger.
  static int _staggerIndex(int i) =>
      i < StaggeredEntrance.maxStaggerIndex
      ? i
      : StaggeredEntrance.maxStaggerIndex;

  Widget _bookTile(KomaColors c, Book book, int i) {
    final pct = (book.progress * 100).round();
    final subtitle = book.author != null && book.author!.isNotEmpty
        ? book.author!
        : book.totalChapters > 0
        ? 'Chapter ${book.currentChapterIndex + 1}'
        : null;
    return StaggeredEntrance(
      index: _staggerIndex(i + 1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: AnimatedPress(
          onTap: () => openBookFromCollection(context, book.id),
          child: _HistoryCard(
            cover: SizedBox(
              width: 56,
              height: 80,
              child: BookCover(
                book: book,
                expand: true,
                borderRadius: AppSpacing.brMd,
              ),
            ),
            typeLabel: 'Book',
            typeIcon: AppIcons.bookOpen,
            typeColor: c.accent,
            title: book.title,
            subtitle: subtitle,
            progress: book.progress,
            percentLabel: '$pct% complete',
            relativeTime: _formatRelativeTime(book.updatedAt),
            onRemove: () => _clearProgress(book),
          ),
        ),
      ),
    );
  }

  Widget _mangaTile(KomaColors c, InProgressManga row, int i) {
    final manga = row.manga;
    final name = manga.name;
    final author = manga.author;
    final imageUrl = manga.imageUrl;
    final headers = ref.watch(sourceImageHeadersProvider(manga.sourceId)).value;
    final id = manga.id;
    final sourceId = manga.sourceId;
    final url = manga.url;
    final readCount = row.readCount;
    final totalChapters = row.totalChapters;
    final progress = totalChapters > 0 ? readCount / totalChapters : 0.0;
    final pct = (progress * 100).round();
    final subtitle = totalChapters > 0
        ? '$readCount / $totalChapters chapters'
        : (author != null && author.isNotEmpty ? author : null);

    // Reuse one provider instance per manga. cachedCover() builds a fresh
    // ResizeImage/CustomExtendedNetworkImageProvider on every call, which
    // forces a resolve + cache lookup on each rebuild; caching by id keeps
    // the identity stable across scroll-driven rebuilds. Only cached once
    // headers have resolved, so the entry isn't pinned to a null-header
    // provider that would then never refresh.
    ImageProvider? coverProvider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final cached = _coverCache[id];
      if (cached != null) {
        coverProvider = cached;
      } else {
        coverProvider = cachedCover(
          imageUrl,
          headers: headers,
          width: 56,
          height: 80,
        );
        if (headers != null) _coverCache[id] = coverProvider;
      }
    }

    return StaggeredEntrance(
      index: _staggerIndex(i + 1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: AnimatedPress(
          onTap: () => context.pushNamed(
            Routes.mangaDetail,
            extra:
                (
                      sourceId: sourceId,
                      url: url,
                      title: name,
                      manga: manga,
                      memo: manga.memo,
                    )
                    as MangaDetailArgs,
          ),
          child: _HistoryCard(
            cover: ClipRRect(
              borderRadius: AppSpacing.brMd,
              child: SizedBox(
                width: 56,
                height: 80,
                child: coverProvider != null
                    ? Image(
                        image: coverProvider,
                        width: 56,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: c.surfaceMuted,
                          child: Icon(
                            Icons.broken_image,
                            size: 24,
                            color: c.textTertiary,
                          ),
                        ),
                      )
                    : Container(
                        color: c.surfaceMuted,
                        child: Icon(
                          Icons.auto_stories,
                          size: 24,
                          color: c.textTertiary,
                        ),
                      ),
              ),
            ),
            typeLabel: 'Manga',
            typeIcon: AppIcons.bookshelf,
            typeColor: AppColors.success,
            title: name,
            subtitle: subtitle,
            progress: progress,
            percentLabel: '$pct% complete',
            relativeTime: row.lastReadAt != null
                ? _formatRelativeTime(row.lastReadAt!)
                : null,
            onRemove: () => _clearMangaProgress(row),
          ),
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1A1A) : AppColors.dangerMuted,
          borderRadius: AppSpacing.brMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(data: AppIcons.delete, size: 14, color: AppColors.danger),
            const SizedBox(width: 6),
            const Text(
              'Clear all',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surfaceMuted,
          borderRadius: AppSpacing.brPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.onAccent : c.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Widget cover;
  final String typeLabel;
  final AppIconData typeIcon;
  final Color typeColor;
  final String title;
  final String? subtitle;
  final double progress;
  final String percentLabel;
  final String? relativeTime;
  final VoidCallback onRemove;

  const _HistoryCard({
    required this.cover,
    required this.typeLabel,
    required this.typeIcon,
    required this.typeColor,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.percentLabel,
    required this.relativeTime,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppSpacing.brLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  data: typeIcon,
                                  size: 9,
                                  color: typeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: AppIcon(
                        data: AppIcons.delete,
                        size: 14,
                        color: c.textSecondary,
                      ),
                      onPressed: onRemove,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                    if (relativeTime != null) ...[
                      const SizedBox(width: 8),
                      AppIcon(
                        data: AppIcons.clock,
                        size: 10,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        relativeTime!,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  percentLabel,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final days = diff.inDays;
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return '${days ~/ 7}w ago';
}
