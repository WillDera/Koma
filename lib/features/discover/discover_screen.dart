import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/source_service.dart';
import '../../core/utils/image_cache.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/toast.dart';
import '../extensions/global_search_provider.dart';
import '../extensions/global_search_widgets.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<SourceSearchResult> _results = [];
  bool _searching = false;
  bool _loaded = false;
  bool _gridView = false;
  _DiscoverSection _section = _DiscoverSection.books;
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0);
  final Map<String, double> _downloading = {};
  bool get _oneHand => ref.watch(themeProvider).oneHandMode;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = (_scrollCtrl.offset / 60).clamp(0.0, 1.0);
    if ((p - _scrollProgress.value).abs() > 0.02) {
      _scrollProgress.value = p;
    }
  }

  SourceService _svc() => ref.read(sourceServiceProvider);

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _loaded = true;
      _results = [];
      // Show progressive per-source manga rows immediately.
      _section = _DiscoverSection.manga;
    });
    // Manga: progressive Global Search (per-source Loading → Success/Error).
    // Do not await — UI watches [globalSearchProvider].
    ref.read(globalSearchProvider.notifier).search(q);

    // Books stay independent so LibGen timeouts never block manga rows.
    final books = await _svc().search(q).then<List<SourceSearchResult>>(
      (v) => v,
      onError: (_) => <SourceSearchResult>[],
    );
    if (!mounted) return;
    final mangaState = ref.read(globalSearchProvider);
    setState(() {
      _results = books;
      if (_results.isEmpty &&
          (mangaState.mangaHitCount > 0 || mangaState.searching)) {
        _section = _DiscoverSection.manga;
      } else if (_results.isNotEmpty) {
        _section = _DiscoverSection.books;
      }
      _searching = false;
    });
  }

  void _clearSearch() {
    _ctrl.clear();
    ref.read(globalSearchProvider.notifier).search('');
    setState(() {
      _results = [];
      _loaded = false;
      _section = _DiscoverSection.books;
    });
  }

  Future<void> _showResultOptions(
    BuildContext context,
    SourceSearchResult result,
  ) async {
    final c = context.colors;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.author != null) ...[
              const SizedBox(height: 4),
              Text(
                result.author!,
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              [
                result.extension,
                result.size,
                result.language,
                result.year,
              ].nonNulls.join(' · '),
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AnimatedPress(
                onTap: () => Navigator.of(ctx).pop('download'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: AppSpacing.brLg,
                  ),
                  child: Center(
                    child: Text(
                      'Download',
                      style: TextStyle(
                        color: c.onAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textTertiary)),
          ),
        ],
      ),
    );
    if (confirmed != 'download') return;
    if (result.downloadUrl == null || result.downloadUrl!.isEmpty) {
      StashToast.show(
        context,
        message: 'No download link available for this result',
        icon: Icons.info_outline,
      );
      return;
    }

    final ext = result.extension ?? 'epub';
    if (result.tag == 'libgen') {
      await _pickMirrorAndDownload(context, result);
    } else {
      await _downloadDirect(result.downloadUrl!, result.title, ext);
    }
  }

  Future<void> _pickMirrorAndDownload(
    BuildContext context,
    SourceSearchResult result,
  ) async {
    StashToast.show(context, message: 'Loading mirrors…', icon: Icons.link);
    final links = await _svc().showDownloadOptions(result);
    if (!mounted) return;
    if (links.isEmpty) {
      if (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) {
        final ext = result.extension ?? 'epub';
        await _downloadDirect(result.downloadUrl!, result.title, ext);
      }
      return;
    }

    final c = context.colors;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose mirror',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...links.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedPress(
                    onTap: () => Navigator.of(ctx).pop(e.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: AppSpacing.brLg,
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Text(
                        e.key,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textTertiary)),
          ),
        ],
      ),
    );
    if (chosen == null || chosen.isEmpty) return;
    await _downloadDirect(chosen, result.title, result.extension ?? 'epub');
  }

  Future<void> _downloadDirect(String url, String title, String ext) async {
    setState(() => _downloading[title] = 0.0);
    final ok = await _svc().downloadFromLink(
      url,
      title,
      ext,
      onProgress: (p) {
        if (mounted) setState(() => _downloading[title] = p);
      },
    );
    if (!mounted) return;
    setState(() => _downloading.remove(title));
    if (ok) {
      ref.read(libraryProvider.notifier).loadBooks();
      StashToast.show(
        context,
        message: '$title added to library',
        icon: Icons.check,
      );
    } else {
      StashToast.show(
        context,
        message: 'Download failed',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleSize = _oneHand ? 64.0 : 32.0;
    final mangaState = ref.watch(globalSearchProvider);
    final mangaItemCount = mangaState.mangaHitCount;
    final mangaBusy = mangaState.searching;
    final hasMangaUi =
        mangaState.query
            .trim()
            .isNotEmpty &&
            (mangaState.items.isNotEmpty || mangaBusy);
    // Book wait only — manga has its own progressive spinner/progress bar.
    final searching = _searching;

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: OneHandSpacer()),
            SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollProgress,
                builder: (_, progress, _) => LibraryHeader(
                  title: 'Discover',
                  subtitle: 'Find books from your sources',
                  shrinkProgress: progress,
                  titleSize: titleSize,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StaggeredEntrance(
                child: FeaturePanel(
                  icon: AppIcons.compass,
                  title: 'Search across every shelf',
                  subtitle:
                      'Pull from book sources and installed manga extensions without leaving your desk.',
                  stats: [
                    PanelStat(value: '${_results.length}', label: 'Books'),
                    PanelStat(value: '$mangaItemCount', label: 'Manga'),
                    PanelStat(
                      value: _gridView ? 'Grid' : 'List',
                      label: 'View',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Search for a book or manga…',
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: AnimatedPress(
                    onTap: searching ? null : _search,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: AppSpacing.brLg,
                      ),
                      child: Center(
                        child: searching
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onAccent,
                                ),
                              )
                            : Text(
                                'Search',
                                style: TextStyle(
                                  color: c.onAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_results.isEmpty && !hasMangaUi)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: Center(
                    child: Text(
                      _loaded
                          ? 'No results'
                          : 'Enter a title to search across your sources',
                      style: TextStyle(color: c.textTertiary, fontSize: 14),
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _DiscoverControls(
                  section: _section,
                  bookCount: _results.length,
                  mangaCount: mangaItemCount,
                  gridView: _gridView,
                  onSectionChanged: (section) => setState(() {
                    _section = section;
                  }),
                  onLayoutChanged: () => setState(() {
                    _gridView = !_gridView;
                  }),
                ),
              ),
              if (_section == _DiscoverSection.books)
                _DiscoverBookResults(
                  key: const ValueKey('discover-books'),
                  results: _results,
                  gridView: _gridView,
                  downloading: _downloading,
                  onTap: (result) => _showResultOptions(context, result),
                )
              else
                ...[
                  const SliverToBoxAdapter(
                    child: GlobalSearchFilterBar(compact: true),
                  ),
                  const GlobalSearchResultsSliver(),
                ],
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

enum _DiscoverSection { books, manga }

class _DiscoverControls extends StatelessWidget {
  final _DiscoverSection section;
  final int bookCount;
  final int mangaCount;
  final bool gridView;
  final ValueChanged<_DiscoverSection> onSectionChanged;
  final VoidCallback onLayoutChanged;

  const _DiscoverControls({
    required this.section,
    required this.bookCount,
    required this.mangaCount,
    required this.gridView,
    required this.onSectionChanged,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: SegmentedControl<_DiscoverSection>(
              segments: {
                _DiscoverSection.books: 'Books $bookCount',
                _DiscoverSection.manga: 'Manga $mangaCount',
              },
              value: section,
              onChanged: onSectionChanged,
              height: 42,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedPress(
            onTap: onLayoutChanged,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: AppSpacing.brMd,
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Icon(
                gridView ? Icons.view_list : Icons.grid_view,
                size: 19,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverBookResults extends StatelessWidget {
  final List<SourceSearchResult> results;
  final bool gridView;
  final Map<String, double> downloading;
  final ValueChanged<SourceSearchResult> onTap;

  const _DiscoverBookResults({
    super.key,
    required this.results,
    required this.gridView,
    required this.downloading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: EmptyState(
            icon: AppIcons.search,
            title: 'No book results',
            subtitle: 'Try another title or switch to manga.',
          ),
        ),
      );
    }
    if (gridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => StaggeredEntrance(
              index: i + 1,
              child: _GridResultCard(
                result: results[i],
                downloadProgress: downloading[results[i].title],
                onTap: () => onTap(results[i]),
              ),
            ),
            childCount: results.length,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) {
            if (index.isOdd) return const SizedBox(height: 8);
            final i = index ~/ 2;
            return StaggeredEntrance(
              index: i + 1,
              child: _ResultCard(
                result: results[i],
                downloadProgress: downloading[results[i].title],
                onTap: () => onTap(results[i]),
              ),
            );
          },
          childCount: results.length * 2 - 1,
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SourceSearchResult result;
  final VoidCallback onTap;
  final double? downloadProgress;
  const _ResultCard({
    required this.result,
    required this.onTap,
    this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: AnimatedPress(
        onTap: downloadProgress != null ? null : onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: result.poster != null
                          ? Image(
                              image: cachedCover(result.poster!),
                              width: 48,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _posterPlaceholder(c),
                            )
                          : _posterPlaceholder(c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (result.author != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              result.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (result.extension != null)
                                _extensionBadge(c, result.extension!),
                              if (result.extension != null)
                                const SizedBox(width: 6),
                              Text(
                                result.sourceName,
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (result.size != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  result.size!,
                                  style: TextStyle(
                                    color: c.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
                  ],
                ),
              ),
              if (downloadProgress != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  child: LinearProgressIndicator(
                    value: downloadProgress,
                    minHeight: 3,
                    backgroundColor: c.surfaceMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extensionBadge(KomaColors c, String ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        ext.toUpperCase(),
        style: TextStyle(
          color: c.accent,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _posterPlaceholder(KomaColors c) {
    return Container(
      width: 48,
      height: 64,
      color: c.surfaceMuted,
      child: Icon(Icons.book, size: 24, color: c.textTertiary),
    );
  }
}

class _GridResultCard extends StatelessWidget {
  final SourceSearchResult result;
  final VoidCallback onTap;
  final double? downloadProgress;
  const _GridResultCard({
    required this.result,
    required this.onTap,
    this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: downloadProgress != null ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: result.poster != null
                    ? Image(
                        image: cachedCover(result.poster!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _posterPlaceholder(c),
                      )
                    : _posterPlaceholder(c),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (result.author != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        result.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (result.extension != null)
                        _extensionBadge(c, result.extension!),
                      const SizedBox(width: 6),
                      Text(
                        result.sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (result.size != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        result.size!,
                        style: TextStyle(color: c.textTertiary, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            if (downloadProgress != null)
              LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 3,
                backgroundColor: c.surfaceMuted,
              ),
          ],
        ),
      ),
    );
  }

  Widget _extensionBadge(KomaColors c, String ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        ext.toUpperCase(),
        style: TextStyle(
          color: c.accent,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _posterPlaceholder(KomaColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(child: Icon(Icons.book, size: 32, color: c.textTertiary)),
    );
  }
}
