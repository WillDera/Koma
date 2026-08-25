import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/source.dart';
import '../../core/providers.dart';
import '../../core/services/discover_metadata_cache.dart';
import '../../core/services/metadata_enrichment_service.dart';
import '../../core/services/source_service.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/horizontal_tab_swipe.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/library_book_card.dart';
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
  final _searchFocus = FocusNode();
  Timer? _idleUnfocus;
  List<SourceSearchResult> _results = [];
  bool _searching = false;
  bool _loaded = false;
  _DiscoverSection _section = _DiscoverSection.books;
  final Map<String, double> _downloading = {};
  List<Source> _sources = [];
  String? _sourceSubtitle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSources());
  }

  @override
  void dispose() {
    _idleUnfocus?.cancel();
    _searchFocus.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    _unfocusSearch();
    ref.read(globalSearchProvider.notifier).search('');
    ref.read(discoverMetadataProvider.notifier).clearQueue();
    setState(() {
      _results = [];
      _loaded = false;
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

    if (result.tag == 'libgen') {
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
    final fallbacks = links.values.where((u) => u != chosen).toList();
    await _downloadDirect(result, chosen, fallbackUrls: fallbacks);
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
    final mangaItemCount = mangaState.mangaHitCount;
    final hasMangaUi =
        mangaState.query.trim().isNotEmpty &&
        (mangaState.items.isNotEmpty || mangaState.searching);
    final searching = _searching;
    final gridView = library.isGridView;
    final showIdle = !_loaded && _results.isEmpty && !hasMangaUi;
    final subtitle = _section == _DiscoverSection.manga
        ? 'Manga extensions'
        : (_sourceSubtitle ?? 'Find books from your sources');

    return ScreenBackdrop(
      child: HorizontalTabSwipe(
        tabIndex: _section == _DiscoverSection.books ? 0 : 1,
        tabCount: 2,
        onTabChanged: (i) => _setSection(
          i == 0 ? _DiscoverSection.books : _DiscoverSection.manga,
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: OneHandSpacer()),
              SliverToBoxAdapter(
                child: LibraryHeader(
                  title: 'Discover',
                  subtitle: subtitle,
                  actions: [
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: _section == _DiscoverSection.books
                                ? 'Search books...'
                                : 'Search manga...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _ctrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _scheduleIdleUnfocus();
                          },
                          onSubmitted: (_) => _search(),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedPress(
                        onTap: searching ? null : _search,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: AppSpacing.brMd,
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
                              : Text(
                                  'Search',
                                  style: TextStyle(
                                    color: c.onAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (showIdle)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: EmptyState(
                    icon: AppIcons.search,
                    title: 'Find your next read',
                    subtitle: 'Search across your configured sources',
                  ),
                ),
              )
            else if (_loaded && _results.isEmpty && !hasMangaUi)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: EmptyState(
                    icon: AppIcons.search,
                    title: 'No results',
                    subtitle: 'Try another title or switch Books / Manga.',
                  ),
                ),
              )
            else ...[
              if (_section == _DiscoverSection.books) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          '${_results.length} result${_results.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        AnimatedPress(
                          onTap: () =>
                              ref.read(libraryProvider.notifier).toggleLayout(),
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
    );
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
              return StaggeredEntrance(
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
            return StaggeredEntrance(
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
