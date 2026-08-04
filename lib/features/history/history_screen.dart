import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart' show routeObserver;
import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/repositories/manga_repository.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with RouteAware {
  final ScrollController _scrollCtrl = ScrollController();

  /// Scroll progress drives only the header's title shrink. Held in a
  /// notifier so scrolling rebuilds the header alone instead of the whole
  /// list (a setState here rebuilt every visible tile many times per second).
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0);

  List<Book> _books = [];
  List<InProgressManga> _mangaRows = [];
  bool _loading = true;
  int _lastSeenRevision = 0;

  /// Cover providers cached per manga id so tile rebuilds reuse the same
  /// [ImageProvider] instance instead of constructing a new one each build.
  final Map<int, ImageProvider> _coverCache = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _lastSeenRevision = ref.read(historyRevisionProvider);
    _load();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final p = max <= 0 ? 0.0 : (_scrollCtrl.offset / max).clamp(0.0, 1.0);
    if ((p - _scrollProgress.value).abs() > 0.01) {
      _scrollProgress.value = p;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollProgress.dispose();
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

  bool get _oneHand => ref.watch(themeProvider).oneHandMode;

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
    final ts = _oneHand ? 64.0 : 32.0;
    final oneHand = _oneHand;
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
              _shrinkingHeader(
                title: 'History',
                titleSize: ts,
                oneHand: oneHand,
              ),
              const SizedBox(height: 80),
              const EmptyState(
                icon: AppIcons.history,
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
                  _shrinkingHeader(
                    title: 'History',
                    subtitle: '$count in progress',
                    titleSize: ts,
                    oneHand: oneHand,
                  ),
                  StaggeredEntrance(
                    child: FeaturePanel(
                      icon: AppIcons.bookshelf,
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

  /// Header that rebuilds on scroll without dragging the list with it.
  ///
  /// Only the title shrink depends on scroll position, so the notifier is
  /// listened to here rather than driving a screen-level setState. Outside
  /// one-hand mode the shrink is disabled, so the listener is skipped
  /// entirely and the header rebuilds only when its data changes.
  Widget _shrinkingHeader({
    required String title,
    required double titleSize,
    required bool oneHand,
    String? subtitle,
  }) {
    if (!oneHand) {
      return LibraryHeader(
        title: title,
        subtitle: subtitle,
        titleSize: titleSize,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: _scrollProgress,
      builder: (_, progress, _) => LibraryHeader(
        title: title,
        subtitle: subtitle,
        titleSize: titleSize,
        shrinkProgress: progress,
      ),
    );
  }

  /// Caps the entrance-animation stagger.
  ///
  /// [StaggeredEntrance] delays its controller by `35ms * index`, so an
  /// uncapped list index schedules timers seconds into the future — item 100
  /// would start animating 3.5s after build. Tiles are built lazily during
  /// scroll, which turned that into a rolling wave of animating widgets.
  static int _staggerIndex(int i) => i < _kMaxStagger ? i : _kMaxStagger;

  static const int _kMaxStagger = 8;

  Widget _bookTile(KomaColors c, int i) {
    final book = _books[i];
    final pct = (book.progress * 100).toInt();
    return StaggeredEntrance(
      index: _staggerIndex(i + 1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: AnimatedPress(
          onTap: () => context.pushNamed(
            Routes.reader,
            extra:
                (
                      bookId: book.id,
                      snippetChapterId: null,
                      snippetScrollOffset: null,
                      snippetStartOffset: null,
                      snippetEndOffset: null,
                    )
                    as ReaderArgs,
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
    final pct = (progress * 100).toInt();

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
          width: 48,
          height: 64,
        );
        if (headers != null) _coverCache[id] = coverProvider;
      }
    }

    return StaggeredEntrance(
      index: _staggerIndex(i + _books.length + 1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
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
                    child: coverProvider != null
                        ? Image(
                            image: coverProvider,
                            width: 48,
                            height: 64,
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
}
