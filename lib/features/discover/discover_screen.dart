import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/models/manga.dart';
import '../../core/models/source.dart';
import '../../core/providers.dart';
import '../../core/repositories/manga_repository.dart';
import '../../core/services/hidden_titles_prefs.dart';
import '../../core/services/local_manga_recs_service.dart';
import '../../core/services/personalized_catalog_picks_service.dart';
import '../../core/services/discover_metadata_cache.dart';
import '../../core/services/trackers/base_tracker.dart';
import '../../core/services/metadata_enrichment_service.dart';
import '../../core/services/source_service.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../features/reader/reader_settings_sheet.dart';
import '../../router/book_navigation.dart';
import '../../router/router.dart';
import '../../router/shell.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/horizontal_tab_swipe.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/library_header.dart';
import '../../widgets/library_layout_sheet.dart';
import '../../widgets/media_rail.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/toast.dart';
import '../extensions/global_search_provider.dart';
import '../extensions/global_search_widgets.dart';
import '../library/library_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchFocus = FocusNode();
  Timer? _idleUnfocus;
  List<SourceSearchResult> _results = [];
  bool _searching = false;
  bool _loaded = false;
  _DiscoverSection _section = _DiscoverSection.books;
  final Map<String, double> _downloading = {};
  List<Source> _sources = [];
  String? _sourceSubtitle;
  BecauseYouReadRec? _becauseYouRead;
  PersonalizedCatalogPicks? _trackerPicks;
  bool _viewingAllPicks = false;
  bool _picksLoadingMore = false;
  List<_ExploreContinueItem> _continueItems = const [];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onDiscoverScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSources();
      _loadBecauseYouRead();
      _loadTrackerPicks();
      _loadContinue();
    });
  }

  @override
  void dispose() {
    _idleUnfocus?.cancel();
    _scrollCtrl.removeListener(_onDiscoverScroll);
    _searchFocus.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onDiscoverScroll() {
    if (!_viewingAllPicks || _picksLoadingMore) return;
    final picks = _trackerPicks;
    if (picks == null || !picks.hasMore) return;
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _loadMoreTrackerPicks();
    }
  }

  void _setSection(_DiscoverSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  void _scheduleIdleUnfocus() {
    _idleUnfocus?.cancel();
    _idleUnfocus = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _searchFocus.hasFocus) _searchFocus.unfocus();
    });
  }

  void _unfocusSearch() {
    _idleUnfocus?.cancel();
    _searchFocus.unfocus();
  }

  Future<void> _loadSources() async {
    try {
      final repos = ref.read(repositoriesProvider);
      var sources = await repos.stats.getSources();
      if (!mounted) return;
      final enabled = sources.where((s) => s.enabled).toList();
      setState(() {
        _sources = sources;
        if (enabled.isEmpty) {
          _sourceSubtitle = 'No sources enabled';
        } else if (enabled.length == 1) {
          _sourceSubtitle = enabled.first.name;
        } else {
          _sourceSubtitle = '${enabled.length} sources';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sourceSubtitle = 'Find books from your sources');
    }
  }

  Future<void> _loadBecauseYouRead() async {
    try {
      final recs = await LocalMangaRecsService(
        ref.read(repositoriesProvider),
      ).load();
      if (!mounted) return;
      setState(() => _becauseYouRead = recs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _becauseYouRead = null);
    }
  }

  Future<void> _loadTrackerPicks() async {
    try {
      final picks = await PersonalizedCatalogPicksService(
        ref.read(repositoriesProvider),
      ).load(limit: PersonalizedCatalogPicksService.defaultPageSize);
      if (!mounted) return;
      setState(() => _trackerPicks = picks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _trackerPicks = null);
    }
  }

  Future<void> _loadContinue() async {
    try {
      final repos = ref.read(repositoriesProvider);
      final results = await Future.wait([
        repos.books.getInProgressBooks(),
        repos.manga.getInProgressManga(),
        HiddenTitlesPrefs.hiddenBookIds(),
      ]);
      if (!mounted) return;
      final hiddenBooks = results[2] as Set<int>;
      final books = [
        for (final b in results[0] as List<Book>)
          if (!hiddenBooks.contains(b.id)) b,
      ];
      final mangas = (results[1] as List<InProgressManga>)
          .where(
            (m) =>
                m.manga.inLibrary &&
                !ViewerFlags.isHidden(m.manga.viewerFlags),
          )
          .toList(growable: false);
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final merged = <_ExploreContinueItem>[
        for (final b in books) _ExploreContinueItem.book(b, b.updatedAt),
        for (final m in mangas)
          _ExploreContinueItem.manga(m, m.lastReadAt ?? epoch),
      ]..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      setState(() => _continueItems = merged.take(12).toList());
    } catch (_) {
      // Continue rail is best-effort.
    }
  }

  Future<void> _loadMoreTrackerPicks() async {
    final current = _trackerPicks;
    if (current == null || !current.hasMore || _picksLoadingMore) return;
    setState(() => _picksLoadingMore = true);
    try {
      final next = await PersonalizedCatalogPicksService(
        ref.read(repositoriesProvider),
      ).loadMore(current);
      if (!mounted) return;
      setState(() {
        _trackerPicks = next;
        _picksLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _picksLoadingMore = false);
    }
  }

  void _openTrackerPicksViewAll() {
    setState(() => _viewingAllPicks = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final picks = _trackerPicks;
      if (picks == null || !picks.hasMore) return;
      // Short first page may not scroll — prefetch the next batch.
      if (_scrollCtrl.position.maxScrollExtent < 80) {
        _loadMoreTrackerPicks();
      }
    });
  }

  void _closeTrackerPicksViewAll() {
    setState(() => _viewingAllPicks = false);
  }

  void _openTrackerPick(TrackSearchResult hit) {
    // Stay on Explore: pushing Global Search above the shell makes the next
    // system/back gesture hit MainShell's tab PopScope and jump to Library.
    _ctrl.text = hit.title;
    setState(() {
      _section = _DiscoverSection.manga;
      _viewingAllPicks = false;
    });
    _search();
  }

  void _exitSearchToIdle() {
    _idleUnfocus?.cancel();
    _searchFocus.unfocus();
    _ctrl.clear();
    ref.read(globalSearchProvider.notifier).search('');
    ref.read(discoverMetadataProvider.notifier).clearQueue();
    setState(() {
      _results = [];
      _loaded = false;
      _searching = false;
      _viewingAllPicks = false;
    });
  }

  void _openSourcePicker() {
    if (_section == _DiscoverSection.manga) {
      context.pushNamed(Routes.extensions);
      return;
    }
    _showBookSourceSheet();
  }

  Future<void> _showBookSourceSheet() async {
    await _loadSources();
    if (!mounted) return;
    final c = context.colors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Ebook sources',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.pushNamed(Routes.sources);
                        },
                        child: Text(
                          'Manage',
                          style: TextStyle(color: c.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_sources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No sources configured',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  )
                else
                  ..._sources.map(
                    (s) => ListTile(
                      leading: Icon(
                        Icons.public,
                        color: s.enabled ? c.accent : c.textTertiary,
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                        [
                          if (s.language != null && s.language!.isNotEmpty)
                            s.language!.toUpperCase(),
                          s.baseUrl,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Switch(
                        value: s.enabled,
                        onChanged: (v) async {
                          final repos = ref.read(repositoriesProvider);
                          final updated = s.copyWith(enabled: v);
                          await repos.stats.updateSource(updated);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadSources();
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  SourceService _svc() => ref.read(sourceServiceProvider);

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _unfocusSearch();
    setState(() {
      _searching = true;
      _loaded = true;
      _results = [];
      _viewingAllPicks = false;
      // Keep the Books/Manga tab the user started the search from.
    });
    ref.read(discoverMetadataProvider.notifier).clearQueue();
    // Manga: progressive Global Search (per-source Loading → Success/Error).
    // Do not await — UI watches [globalSearchProvider].
    ref.read(globalSearchProvider.notifier).search(q);

    // Books stay independent so LibGen timeouts never block manga rows.
    final books = await _svc().search(q).then<List<SourceSearchResult>>(
      (v) => v,
      onError: (_) => <SourceSearchResult>[],
    );
    if (!mounted) return;
    setState(() {
      _results = books;
      _searching = false;
    });
    // Fire-and-forget; no-ops when the Settings toggle is off.
    unawaited(ref.read(discoverMetadataProvider.notifier).enqueue(books));
  }

  void _clearSearch() {
    _ctrl.clear();
    ref.read(globalSearchProvider.notifier).search('');
    ref.read(discoverMetadataProvider.notifier).clearQueue();
    setState(() {
      _results = [];
      // Keep _loaded so we stay on the Books|Manga search chrome.
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
    final hasDownload =
        (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) ||
        (result.md5 != null && result.md5!.length == 32);
    if (!hasDownload) {
      StashToast.show(
        context,
        message: 'No download link available for this result',
        icon: Icons.info_outline,
      );
      return;
    }

    if (result.tag == 'libgen' || result.tag == 'annas-archive') {
      await _pickMirrorAndDownload(context, result);
    } else {
      await _downloadDirect(result, result.downloadUrl!);
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
      if (result.tag == 'annas-archive') {
        StashToast.show(
          context,
          message:
              'No download mirrors found. Add a RapidAPI or Anna\'s Archive secret key in Settings, or try another result.',
          icon: Icons.info_outline,
        );
        return;
      }
      if (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) {
        await _downloadDirect(result, result.downloadUrl!);
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
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
            ),
            child: ListView(
              shrinkWrap: true,
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
          ),
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
    // User picked one mirror — do not cycle through every other option.
    await _downloadDirect(result, chosen);
  }

  Future<void> _downloadDirect(
    SourceSearchResult result,
    String url, {
    List<String> fallbackUrls = const [],
  }) async {
    final title = result.title;
    final ext = result.extension ?? 'epub';
    setState(() => _downloading[title] = 0.0);
    final bookId = await _svc().downloadFromLink(
      url,
      title,
      ext,
      fallbackUrls: fallbackUrls,
      onProgress: (p) {
        if (mounted) setState(() => _downloading[title] = p);
      },
    );
    if (!mounted) return;
    setState(() => _downloading.remove(title));
    if (bookId != null) {
      final hit = ref.read(discoverMetadataProvider)[
        discoverMetadataCacheKey(result.title, result.author)
      ];
      // Same preference as the Discover card: enriched cover, else LibGen poster.
      final poster = result.poster;
      final enrichedCover = hit?.coverUrl;
      final displayCover =
          (enrichedCover != null && enrichedCover.isNotEmpty)
          ? enrichedCover
          : (poster != null && poster.isNotEmpty ? poster : null);
      if ((hit != null && hit.found) ||
          (displayCover != null && displayCover.isNotEmpty)) {
        await MetadataEnrichmentService(
          ref.read(repositoriesProvider).books,
        ).applyDiscoverHit(
          bookId,
          hit ?? const DiscoverMetadataHit(found: false),
          coverUrlOverride: displayCover,
        );
      }
      if (!mounted) return;
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
    final mangaState = ref.watch(globalSearchProvider);
    final library = ref.watch(libraryProvider);
    ref.listen(libraryProvider, (_, _) {
      _loadContinue();
    });
    final mangaItemCount = mangaState.mangaHitCount;
    final hasMangaUi =
        mangaState.query.trim().isNotEmpty &&
        (mangaState.items.isNotEmpty || mangaState.searching);
    final searching = _searching;
    final gridView = library.isGridView;
    final showIdle = !_loaded && _results.isEmpty && !hasMangaUi;
    final idleHasHero =
        showIdle && (library.books.isNotEmpty || library.mangas.isNotEmpty);
    final subtitle = showIdle
        ? (_sourceSubtitle ?? 'Browse your library & sources')
        : (_section == _DiscoverSection.manga
            ? 'Manga extensions'
            : (_sourceSubtitle ?? 'Find books from your sources'));
    // Keep back on Explore for view-all / search; only idle rails defer to
    // MainShell (which switches to Library).
    final interceptBack = _viewingAllPicks || !showIdle;
    final claimed = ref.read(shellBackInterceptorProvider);
    if (claimed != interceptBack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(shellBackInterceptorProvider.notifier).set(interceptBack);
      });
    }

    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_viewingAllPicks) {
          _closeTrackerPicksViewAll();
          return;
        }
        if (!showIdle) _exitSearchToIdle();
      },
      child: ScreenBackdrop(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: idleHasHero && !_viewingAllPicks
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: HorizontalTabSwipe(
        tabIndex: _section == _DiscoverSection.books ? 0 : 1,
        tabCount: 2,
        onTabChanged: (i) => _setSection(
          i == 0 ? _DiscoverSection.books : _DiscoverSection.manga,
        ),
        // Bleed the recommendation cover under the status bar on idle.
        child: SafeArea(
          top: !idleHasHero || _viewingAllPicks,
          bottom: false,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!idleHasHero || _viewingAllPicks) ...[
                const SliverToBoxAdapter(child: OneHandSpacer()),
                SliverToBoxAdapter(
                  child: LibraryHeader(
                    title: 'Explore',
                    subtitle: subtitle,
                    actions: [
                      IconButtonRound(
                        iconData: AppIcons.grid,
                        size: 38,
                        variant: IconButtonVariant.tonal,
                        iconColor: c.textSecondary,
                        tooltip: 'Layout',
                        onPressed: () => LibraryLayoutSheet.show(context),
                      ),
                      IconButtonRound(
                        iconData: AppIcons.filter,
                        size: 38,
                        variant: IconButtonVariant.tonal,
                        iconColor: c.textSecondary,
                        tooltip: 'Sources',
                        onPressed: _openSourcePicker,
                      ),
                    ],
                  ),
                ),
              ],
              if (showIdle && _viewingAllPicks)
                ..._trackerPicksViewAllSlivers(context, library)
              else if (showIdle)
                ..._idleChromeSlivers(
                  context,
                  library,
                  searching,
                  bleedHero: idleHasHero,
                ),
              if (!showIdle) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SegmentedControl<_DiscoverSection>(
                      segments: const {
                        _DiscoverSection.books: 'Books',
                        _DiscoverSection.manga: 'Manga',
                      },
                      value: _section,
                      onChanged: _setSection,
                      height: 42,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _searchBar(searching: searching),
                ),
              ],
            if (!showIdle && _loaded && _results.isEmpty && !hasMangaUi)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: EmptyState(
                    icon: AppIcons.search,
                    emoji: '🔎',
                    title: 'No results',
                    subtitle: 'Try another title or switch Books / Manga.',
                  ),
                ),
              )
            else if (!showIdle) ...[
              if (_section == _DiscoverSection.books) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      '${_results.length} result${_results.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                _DiscoverBookResults(
                  key: const ValueKey('discover-books'),
                  results: _results,
                  gridView: gridView,
                  cardVariant: library.cardVariant,
                  gridColumns: library.gridColumns,
                  showSourcePills: library.showSourcePills,
                  downloading: _downloading,
                  onTap: (result) => _showResultOptions(context, result),
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      '$mangaItemCount result${mangaItemCount == 1 ? '' : 's'}',
                      style: TextStyle(color: c.textTertiary, fontSize: 12),
                    ),
                  ),
                ),
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
      ),
      ),
      ),
    );
  }

  Widget _searchBar({required bool searching, bool compact = false}) {
    final c = context.colors;
    final hint = _section == _DiscoverSection.books
        ? 'Search books, authors…'
        : 'Search manga, authors…';
    final hasQuery = _ctrl.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 0, 20, compact ? 10 : 14),
      child: Container(
        height: compact ? 50 : 54,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brPill,
          border: Border.all(
            color: c.border.withValues(alpha: 0.65),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              size: 22,
              color: c.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _searchFocus,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: c.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) {
                  setState(() {});
                  _scheduleIdleUnfocus();
                },
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (hasQuery)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear',
                onPressed: _clearSearch,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: c.textTertiary,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 6, 6),
              child: AnimatedPress(
                onTap: searching ? null : _search,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: searching
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.onAccent,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: c.onAccent,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openManga(Manga manga) {
    context.pushNamed(
      Routes.mangaDetail,
      extra: (
        sourceId: manga.sourceId,
        url: manga.url,
        title: manga.name,
        manga: manga,
        memo: manga.memo,
      ) as MangaDetailArgs,
    );
  }

  void _openRecommendation({Book? book, Manga? manga}) {
    if (book != null) {
      openBookReader(
        context,
        bookId: book.id,
        fileExtension: book.fileExtension,
      );
      return;
    }
    if (manga != null) _openManga(manga);
  }

  List<Widget> _trackerPicksViewAllSlivers(
    BuildContext context,
    LibraryState library,
  ) {
    final picks = _trackerPicks;
    if (picks == null || picks.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: MediaRailViewAllBar(
            title: 'Picks for you',
            onBack: _closeTrackerPicksViewAll,
          ),
        ),
        const SliverToBoxAdapter(
          child: MediaRailEmptyHint(message: 'No picks available right now.'),
        ),
      ];
    }

    final variant = CatalogCardLayout.gridVariant(library.cardVariant);
    final c = context.colors;
    return [
      SliverToBoxAdapter(
        child: MediaRailViewAllBar(
          title: 'Picks for you',
          countLabel:
              '${picks.items.length} from ${picks.sourceName}'
              '${picks.hasMore ? ' · scroll for more' : ''}',
          onBack: _closeTrackerPicksViewAll,
        ),
      ),
      SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: library.gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final hit = picks.items[i];
              return StaggeredFadeScale(
                index: i,
                child: CatalogCoverCard(
                  title: hit.title,
                  subtitle: picks.sourceName,
                  imageUrl: hit.coverUrl,
                  variant: variant,
                  onTap: () => _openTrackerPick(hit),
                ),
              );
            },
            childCount: picks.items.length,
          ),
        ),
      ),
      if (_picksLoadingMore || picks.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Center(
              child: _picksLoadingMore
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  : Text(
                      'Scroll for more picks',
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _idleChromeSlivers(
    BuildContext context,
    LibraryState library,
    bool searching, {
    required bool bleedHero,
  }) {
    final booksByCreated = [...library.books]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final mangasByCreated = [...library.mangas]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final booksByUpdated = [...library.books]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final mangasByUpdated = [...library.mangas]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Mixed newly-added / latest, newest first across books + manga.
    final newlyAdded = <({Book? book, Manga? manga})>[
      ...booksByCreated.map((b) => (book: b, manga: null)),
      ...mangasByCreated.map((m) => (book: null, manga: m)),
    ]..sort((a, b) {
        final ad = a.book?.createdAt ?? a.manga!.createdAt;
        final bd = b.book?.createdAt ?? b.manga!.createdAt;
        return bd.compareTo(ad);
      });
    final latest = <({Book? book, Manga? manga})>[
      ...booksByUpdated.map((b) => (book: b, manga: null)),
      ...mangasByUpdated.map((m) => (book: null, manga: m)),
    ]..sort((a, b) {
        final ad = a.book?.updatedAt ?? a.manga!.updatedAt;
        final bd = b.book?.updatedAt ?? b.manga!.updatedAt;
        return bd.compareTo(ad);
      });

    final hasLibrary = newlyAdded.isNotEmpty;
    final newlyPreview = newlyAdded.take(12).toList();
    final latestPreview = latest.take(12).toList();

    Book? recBook;
    Manga? recManga;
    if (latest.isNotEmpty) {
      recBook = latest.first.book;
      recManga = latest.first.manga;
    }

    final slivers = <Widget>[
      if (hasLibrary && (recBook != null || recManga != null))
        SliverToBoxAdapter(
          child: StaggeredFadeScale(
            index: 0,
            child: _ExploreRecommendationHero(
              book: recBook,
              manga: recManga,
              bleedIntoStatusBar: bleedHero,
              onSources: _openSourcePicker,
              onStartReading: () =>
                  _openRecommendation(book: recBook, manga: recManga),
            ),
          ),
        ),
      // Search is secondary on idle — no Books|Manga segment.
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: hasLibrary ? 4 : 0),
          child: _searchBar(searching: searching, compact: true),
        ),
      ),
    ];

    if (!hasLibrary) {
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: EmptyState(
              icon: AppIcons.search,
              emoji: '🧭',
              title: 'Find your next read',
              subtitle: 'Add extensions to search manga and ebooks',
              primaryActionLabel: 'Browse Extensions',
              onPrimaryAction: () => context.pushNamed(Routes.extensions),
              pillPrimary: true,
            ),
          ),
        ),
      );
      return slivers;
    }

    if (_continueItems.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Continue reading',
            subtitle: '${_continueItems.length} in progress',
            height: 200,
            onViewAll: () => context.goNamed(Routes.library),
            itemCount: _continueItems.length,
            itemBuilder: (context, i) {
              final item = _continueItems[i];
              final book = item.book;
              if (book != null) {
                final path = book.coverPath;
                return MediaRailCover(
                  width: 118,
                  child: StaggeredFadeScale(
                    index: i + 1,
                    child: CatalogCoverCard(
                      title: book.title,
                      subtitle: '${(book.progress * 100).round()}% · Resume',
                      imageProvider:
                          path != null &&
                              path.isNotEmpty &&
                              File(path).existsSync()
                          ? FileImage(File(path))
                          : null,
                      variant: LibraryCardVariant.grid,
                      onTap: () => openBookFromCollection(context, book.id),
                    ),
                  ),
                );
              }
              final row = item.manga!;
              final manga = row.manga;
              final custom = manga.customCoverPath;
              return MediaRailCover(
                width: 118,
                child: StaggeredFadeScale(
                  index: i + 1,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: '${(row.progress * 100).round()}% · Resume',
                    imageProvider:
                        custom != null &&
                            custom.isNotEmpty &&
                            File(custom).existsSync()
                        ? FileImage(File(custom))
                        : null,
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final trackerPicks = _trackerPicks;
    if (trackerPicks != null && trackerPicks.items.isNotEmpty) {
      final preview = trackerPicks.items
          .take(PersonalizedCatalogPicksService.defaultPageSize)
          .toList();
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Picks for you',
            subtitle: trackerPicks.sourceName,
            onViewAll: _openTrackerPicksViewAll,
            itemCount: preview.length,
            itemBuilder: (context, i) {
              final hit = preview[i];
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i + 1,
                  child: CatalogCoverCard(
                    title: hit.title,
                    subtitle: trackerPicks.sourceName,
                    imageUrl: hit.coverUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openTrackerPick(hit),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (newlyPreview.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Newly Added',
            subtitle: '${newlyAdded.length} recent',
            onViewAll: () => context.goNamed(Routes.library),
            itemCount: newlyPreview.length,
            itemBuilder: (context, i) {
              final item = newlyPreview[i];
              final book = item.book;
              if (book != null) {
                final path = book.coverPath;
                return MediaRailCover(
                  child: StaggeredFadeScale(
                    index: i + 1,
                    child: CatalogCoverCard(
                      title: book.title,
                      subtitle: book.author,
                      imageProvider:
                          path != null &&
                              path.isNotEmpty &&
                              File(path).existsSync()
                          ? FileImage(File(path))
                          : null,
                      variant: LibraryCardVariant.grid,
                      onTap: () => openBookFromCollection(context, book.id),
                    ),
                  ),
                );
              }
              final manga = item.manga!;
              final custom = manga.customCoverPath;
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i + 1,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: manga.author,
                    imageProvider:
                        custom != null &&
                            custom.isNotEmpty &&
                            File(custom).existsSync()
                        ? FileImage(File(custom))
                        : null,
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Because you read + Latest Titles stay below the fold as secondary rails.
    final because = _becauseYouRead;
    if (because != null && because.suggestions.isNotEmpty) {
      final seedTitle = because.seed.name;
      final shortSeed = seedTitle.length > 28
          ? '${seedTitle.substring(0, 28)}…'
          : seedTitle;
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Because you read',
            subtitle: shortSeed,
            itemCount: because.suggestions.length,
            itemBuilder: (context, i) {
              final manga = because.suggestions[i];
              final custom = manga.customCoverPath;
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i + 1,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: manga.author,
                    imageProvider:
                        custom != null &&
                            custom.isNotEmpty &&
                            File(custom).existsSync()
                        ? FileImage(File(custom))
                        : null,
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (latestPreview.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: MediaRail(
            title: 'Latest Titles',
            onViewAll: () => context.goNamed(Routes.library),
            itemCount: latestPreview.length,
            itemBuilder: (context, i) {
              final item = latestPreview[i];
              final book = item.book;
              if (book != null) {
                final path = book.coverPath;
                return MediaRailCover(
                  child: StaggeredFadeScale(
                    index: i + 1,
                    child: CatalogCoverCard(
                      title: book.title,
                      subtitle: book.author,
                      imageProvider:
                          path != null &&
                              path.isNotEmpty &&
                              File(path).existsSync()
                          ? FileImage(File(path))
                          : null,
                      variant: LibraryCardVariant.grid,
                      onTap: () => openBookFromCollection(context, book.id),
                    ),
                  ),
                );
              }
              final manga = item.manga!;
              final custom = manga.customCoverPath;
              return MediaRailCover(
                child: StaggeredFadeScale(
                  index: i + 1,
                  child: CatalogCoverCard(
                    title: manga.name,
                    subtitle: manga.author,
                    imageProvider:
                        custom != null &&
                            custom.isNotEmpty &&
                            File(custom).existsSync()
                        ? FileImage(File(custom))
                        : null,
                    imageUrl: manga.imageUrl,
                    variant: LibraryCardVariant.grid,
                    onTap: () => _openManga(manga),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return slivers;
  }
}

class _ExploreContinueItem {
  const _ExploreContinueItem._({
    required this.lastReadAt,
    this.book,
    this.manga,
  });

  factory _ExploreContinueItem.book(Book book, DateTime lastReadAt) =>
      _ExploreContinueItem._(lastReadAt: lastReadAt, book: book);

  factory _ExploreContinueItem.manga(
    InProgressManga manga,
    DateTime lastReadAt,
  ) =>
      _ExploreContinueItem._(lastReadAt: lastReadAt, manga: manga);

  final DateTime lastReadAt;
  final Book? book;
  final InProgressManga? manga;
}

class _ExploreRecommendationHero extends ConsumerWidget {
  const _ExploreRecommendationHero({
    required this.onStartReading,
    required this.onSources,
    this.bleedIntoStatusBar = false,
    this.book,
    this.manga,
  });

  final Book? book;
  final Manga? manga;
  final bool bleedIntoStatusBar;
  final VoidCallback onStartReading;
  final VoidCallback onSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final topInset =
        bleedIntoStatusBar ? MediaQuery.paddingOf(context).top : 0.0;
    final title = book?.title ?? manga?.name ?? '';
    final author = book?.author ?? manga?.author;
    final metaParts = <String>[
      if (author != null && author.isNotEmpty) author,
      if (book != null && book!.totalChapters > 0)
        '${book!.totalChapters} chapter${book!.totalChapters == 1 ? '' : 's'}',
      if (book != null &&
          book!.totalChapters <= 0 &&
          book!.fileExtension.isNotEmpty)
        book!.fileExtension.toUpperCase(),
      if (manga != null && manga!.genres.isNotEmpty) manga!.genres.first,
    ];
    final meta = metaParts.join('  ·  ');
    final heroHeight = 300.0 + topInset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: heroHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _heroCover(context, ref, c),
              // Soft top veil so Explore chrome stays readable on light covers.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.22, 0.55, 1.0],
                  ),
                ),
              ),
              if (bleedIntoStatusBar)
                Positioned(
                  top: topInset + 6,
                  left: 20,
                  right: 12,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Explore',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      IconButtonRound(
                        iconData: AppIcons.filter,
                        size: 40,
                        variant: IconButtonVariant.filled,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        iconColor: Colors.white,
                        tooltip: 'Sources',
                        onPressed: onSources,
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: AppSpacing.brPill,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 6),
                          Text(
                            'Your Recommendation of the Day',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.6,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onStartReading,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.onAccent,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Start Reading'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCover(BuildContext context, WidgetRef ref, KomaColors c) {
    if (book != null) {
      return BookCover(
        book: book!,
        variant: BookCoverVariant.hero,
        borderRadius: BorderRadius.zero,
        expand: true,
      );
    }
    final m = manga!;
    final custom = m.customCoverPath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      return Image.file(File(custom), fit: BoxFit.cover);
    }
    if (m.imageUrl != null && m.imageUrl!.isNotEmpty) {
      final headers =
          ref.watch(sourceImageHeadersProvider(m.sourceId)).value;
      return Image(
        image: cachedCover(m.imageUrl!, headers: headers),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: c.iconWell),
      );
    }
    return ColoredBox(color: c.iconWell);
  }
}

enum _DiscoverSection { books, manga }

class _DiscoverBookResults extends ConsumerWidget {
  final List<SourceSearchResult> results;
  final bool gridView;
  final LibraryCardVariant cardVariant;
  final int gridColumns;
  final bool showSourcePills;
  final Map<String, double> downloading;
  final ValueChanged<SourceSearchResult> onTap;

  const _DiscoverBookResults({
    super.key,
    required this.results,
    required this.gridView,
    required this.cardVariant,
    required this.gridColumns,
    required this.showSourcePills,
    required this.downloading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(discoverMetadataProvider);
    final enrichOn =
        ref.watch(discoverMetadataEnabledProvider).value ??
        kDiscoverMetadataEnabledDefault;
    if (results.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: EmptyState(
            icon: AppIcons.search,
            emoji: '🔎',
            title: 'No book results',
            subtitle: 'Try another title or switch to manga.',
          ),
        ),
      );
    }
    if (gridView) {
      final variant = CatalogCardLayout.gridVariant(cardVariant);
      return SliverPadding(
        padding: CatalogCardLayout.paddingFor(variant),
        sliver: SliverGrid(
          gridDelegate: CatalogCardLayout.gridDelegate(
            columns: gridColumns,
            variant: variant,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final result = results[i];
              return StaggeredFadeScale(
                index: i + 1,
                child: _bookCard(
                  result: result,
                  meta: meta,
                  enrichOn: enrichOn,
                  variant: variant,
                ),
              );
            },
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
            final result = results[i];
            return StaggeredFadeScale(
              index: i + 1,
              child: _bookCard(
                result: result,
                meta: meta,
                enrichOn: enrichOn,
                variant: LibraryCardVariant.list,
              ),
            );
          },
          childCount: results.length * 2 - 1,
        ),
      ),
    );
  }

  Widget _bookCard({
    required SourceSearchResult result,
    required Map<String, DiscoverMetadataHit> meta,
    required bool enrichOn,
    required LibraryCardVariant variant,
  }) {
    final hit = enrichOn
        ? meta[discoverMetadataCacheKey(result.title, result.author)]
        : null;
    final coverUrl = hit?.coverUrl;
    final hasEnriched = coverUrl != null && coverUrl.isNotEmpty;
    final poster = result.poster;
    // Prefer OL/Google when enrichment is on and ready; otherwise LibGen poster
    // (fictionruscovers / fictioncovers on libgen.li).
    final displayUrl = hasEnriched
        ? coverUrl
        : (poster != null && poster.isNotEmpty ? poster : null);
    return CatalogCoverCard(
      title: result.title,
      subtitle: result.author,
      imageUrl: displayUrl,
      headers: displayUrl != null ? discoverCoverHeaders(displayUrl) : null,
      badge: result.sourceName,
      secondaryBadge: result.size,
      formatBadge: _formatLabel(result.extension),
      showBadge: showSourcePills,
      variant: variant,
      downloadProgress: downloading[result.title],
      onTap: () => onTap(result),
    );
  }

  static String? _formatLabel(String? extension) {
    if (extension == null) return null;
    final label = extension.trim().replaceAll('.', '').toUpperCase();
    return label.isEmpty ? null : label;
  }
}
