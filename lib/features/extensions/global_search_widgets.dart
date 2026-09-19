import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/image_headers.dart';
import '../../core/utils/language.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_motion.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';
import '../discover/explore_view_prefs.dart';
import 'catalog_multi_select.dart';
import 'global_search_provider.dart';
import 'source_browse_screen.dart';

Route<T> _scaleFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        scaleFadePageTransition(animation: animation, child: child),
  );
}

/// Pinned / All / Has-results chips shared by Global Search + Discover manga.
class GlobalSearchFilterBar extends ConsumerWidget {
  const GlobalSearchFilterBar({
    super.key,
    this.compact = false,
    this.showCompactRailsToggle = false,
  });

  final bool compact;

  /// Explore-only: toggle short horizontal rails per source.
  final bool showCompactRailsToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final notifier = ref.read(globalSearchProvider.notifier);
    final compactRails = showCompactRailsToggle
        ? ref.watch(exploreCompactMangaRailsProvider)
        : false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 12,
            0,
            compact ? 20 : 12,
            8,
          ),
          child: Row(
            children: [
              GlobalSearchFilterChip(
                label: 'Pinned',
                selected: state.filter == GlobalSearchSourceFilter.pinned,
                onTap: () =>
                    notifier.setFilter(GlobalSearchSourceFilter.pinned),
              ),
              const SizedBox(width: 8),
              GlobalSearchFilterChip(
                label: 'All',
                selected: state.filter == GlobalSearchSourceFilter.all,
                onTap: () => notifier.setFilter(GlobalSearchSourceFilter.all),
              ),
              const Spacer(),
              if (showCompactRailsToggle) ...[
                GlobalSearchFilterChip(
                  label: 'Compact',
                  selected: compactRails,
                  onTap: () => ref
                      .read(exploreCompactMangaRailsProvider.notifier)
                      .toggle(),
                ),
                const SizedBox(width: 8),
              ],
              GlobalSearchFilterChip(
                label: 'Has results',
                selected: state.onlyShowHasResults,
                onTap: notifier.toggleOnlyHasResults,
              ),
            ],
          ),
        ),
        if (state.searching && state.total > 0)
          ThinProgressBar(
            progress: state.progress / state.total,
            height: 2,
            color: c.accent,
            trackColor: c.surfaceMuted,
          ),
      ],
    );
  }
}

class GlobalSearchFilterChip extends StatelessWidget {
  const GlobalSearchFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : c.surfaceMuted,
          borderRadius: AppSpacing.brPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.accent : c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Full scrolling body used by [GlobalSearchScreen].
class GlobalSearchResultsList extends ConsumerWidget {
  const GlobalSearchResultsList({
    super.key,
    this.padding,
    this.onMangaTap,
    this.enableMultiSelect = true,
  });

  final EdgeInsetsGeometry? padding;
  final void Function(GlobalSearchSourceItem item, Map<String, dynamic> manga)?
  onMangaTap;
  final bool enableMultiSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalSearchProvider);
    final visible = state.visibleItems;
    final compactRails = ref.watch(exploreCompactMangaRailsProvider);
    final selection = ref.watch(catalogMultiSelectProvider);

    if (visible.isEmpty) {
      final q = state.query.trim();
      if (q.isEmpty) {
        return const EmptyState(
          icon: AppIcons.search,
          emoji: '🔎',
          title: 'Search installed sources',
          subtitle: 'Results appear here as each source responds.',
          pillPrimary: true,
        );
      }
      if (state.searching) {
        return const EmptyState(
          icon: AppIcons.loading,
          emoji: '⏳',
          title: 'Searching…',
          subtitle: 'Scanning your installed extensions.',
        );
      }
      return EmptyState(
        icon: AppIcons.search,
        emoji: '📭',
        title: state.onlyShowHasResults
            ? 'No sources with results'
            : 'No results',
        subtitle: 'Try another query or switch filters.',
      );
    }

    return ListView.builder(
      padding: padding ?? const EdgeInsets.only(bottom: 32),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        return StaggeredFadeScale(
          index: i,
          child: GlobalSearchSourceSection(
            item: item,
            compactRails: compactRails,
            selectionActive: selection.isSelecting,
            selectedKeys: selection.byKey.keys.toSet(),
            onHeaderTap: () => openGlobalSearchSource(context, ref, item),
            onSeeAll: () => openGlobalSearchSource(context, ref, item),
            onMangaTap: (m) {
              final hit = CatalogHit.fromSearchMap(
                sourceId: item.source.sourceId,
                manga: m,
              );
              if (enableMultiSelect &&
                  ref
                      .read(catalogMultiSelectProvider.notifier)
                      .handleTap(hit)) {
                return;
              }
              if (onMangaTap != null) {
                onMangaTap!(item, m);
              } else {
                openGlobalSearchManga(context, item, m);
              }
            },
            onMangaLongPress: !enableMultiSelect
                ? null
                : (m) {
                    ref.read(catalogMultiSelectProvider.notifier).longPress(
                          CatalogHit.fromSearchMap(
                            sourceId: item.source.sourceId,
                            manga: m,
                          ),
                        );
                  },
          ),
        );
      },
    );
  }
}

/// Sliver form for embedding inside Discover's CustomScrollView.
class GlobalSearchResultsSliver extends ConsumerWidget {
  const GlobalSearchResultsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalSearchProvider);
    final visible = state.visibleItems;
    final compactRails = ref.watch(exploreCompactMangaRailsProvider);
    final selection = ref.watch(catalogMultiSelectProvider);

    if (visible.isEmpty) {
      final q = state.query.trim();
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: q.isEmpty
              ? const EmptyState(
                  icon: AppIcons.search,
                  emoji: '🔎',
                  title: 'Search installed sources',
                  subtitle: 'Manga hits from your extensions.',
                )
              : state.searching
              ? const EmptyState(
                  icon: AppIcons.loading,
                  emoji: '⏳',
                  title: 'Searching…',
                )
              : EmptyState(
                  icon: AppIcons.search,
                  emoji: '📭',
                  title: state.onlyShowHasResults
                      ? 'No sources with results'
                      : 'No manga results',
                ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final item = visible[i];
        return StaggeredFadeScale(
          index: i,
          child: GlobalSearchSourceSection(
            item: item,
            compactRails: compactRails,
            selectionActive: selection.isSelecting,
            selectedKeys: selection.byKey.keys.toSet(),
            onHeaderTap: () => openGlobalSearchSource(context, ref, item),
            onMangaTap: (m) {
              final hit = CatalogHit.fromSearchMap(
                sourceId: item.source.sourceId,
                manga: m,
              );
              if (ref
                  .read(catalogMultiSelectProvider.notifier)
                  .handleTap(hit)) {
                return;
              }
              openGlobalSearchManga(context, item, m);
            },
            onMangaLongPress: (m) {
              ref.read(catalogMultiSelectProvider.notifier).longPress(
                    CatalogHit.fromSearchMap(
                      sourceId: item.source.sourceId,
                      manga: m,
                    ),
                  );
            },
            onSeeAll: () => openGlobalSearchSource(context, ref, item),
          ),
        );
      }, childCount: visible.length),
    );
  }
}

class GlobalSearchSourceSection extends ConsumerWidget {
  const GlobalSearchSourceSection({
    super.key,
    required this.item,
    required this.onHeaderTap,
    required this.onMangaTap,
    this.onMangaLongPress,
    this.onSeeAll,
    this.compactRails = false,
    this.selectionActive = false,
    this.selectedKeys = const {},
  });

  static const _railPreviewCount = 5;
  static const _railCoverWidth = 118.0;
  static const _railHeight = 200.0;

  final GlobalSearchSourceItem item;
  final VoidCallback onHeaderTap;
  final void Function(Map<String, dynamic> manga) onMangaTap;
  final void Function(Map<String, dynamic> manga)? onMangaLongPress;
  final VoidCallback? onSeeAll;

  /// Explore compact mode: horizontal rail of up to 5 covers + See all.
  final bool compactRails;
  final bool selectionActive;
  final Set<String> selectedKeys;

  String _hitKey(Map<String, dynamic> manga) =>
      '${item.source.sourceId}\u001f${(manga['url'] as String? ?? '').trim()}';

  String? _thumb(Map<String, dynamic> manga, String? baseUrl) {
    final raw = manga['thumbnail_url'] as String?;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (baseUrl == null || baseUrl.isEmpty) return raw;
    return Uri.parse(baseUrl).resolve(raw).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final src = item.source;
    final lang = completeLanguageName(src.lang);
    final library = ref.watch(libraryProvider);
    final headers = ref.watch(
      imageHeadersProvider(
        (src.baseUrl != null && src.baseUrl!.isNotEmpty) ? src.baseUrl : null,
      ),
    );
    final gridView = library.isGridView;
    final variant = gridView
        ? CatalogCardLayout.gridVariant(library.cardVariant)
        : LibraryCardVariant.list;
    final columns = library.gridColumns;
    final showPills = library.showCardChrome;
    final minimalChrome = library.minimalCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedPress(
          onTap: onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: src.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (lang.isNotEmpty)
                          TextSpan(
                            text: '  $lang',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textTertiary, size: 20),
              ],
            ),
          ),
        ),
        switch (item.kind) {
          GlobalSearchItemKind.loading => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          GlobalSearchItemKind.error => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              item.error ?? 'Error',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ),
          GlobalSearchItemKind.success when item.mangas.isEmpty => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No results',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ),
          GlobalSearchItemKind.success => compactRails
              ? _compactRailsBody(
                  context,
                  headers: headers,
                  showPills: showPills,
                  minimalChrome: minimalChrome,
                )
              : gridView
              ? Padding(
                  padding: CatalogCardLayout.paddingFor(
                    variant,
                  ).add(const EdgeInsets.only(bottom: 12)),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: CatalogCardLayout.gridDelegate(
                      columns: columns,
                      variant: variant,
                    ),
                    itemCount: item.mangas.length,
                    itemBuilder: (_, i) {
                      final manga = item.mangas[i];
                      final key = _hitKey(manga);
                      return StaggeredFadeScale(
                        index: i,
                        child: CatalogCoverCard(
                          title: manga['title'] as String? ?? '',
                          imageUrl: _thumb(manga, src.baseUrl),
                          headers: headers,
                          badge: src.name,
                          showBadge: showPills,
                          minimalChrome: minimalChrome,
                          variant: variant,
                          selectionMode: selectionActive,
                          selected: selectedKeys.contains(key),
                          onTap: () => onMangaTap(manga),
                          onLongPress: onMangaLongPress == null
                              ? null
                              : () => onMangaLongPress!(manga),
                        ),
                      );
                    },
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < item.mangas.length; i++)
                        StaggeredFadeScale(
                          index: i,
                          child: CatalogCoverCard(
                            title: item.mangas[i]['title'] as String? ?? '',
                            imageUrl: _thumb(item.mangas[i], src.baseUrl),
                            headers: headers,
                            badge: src.name,
                            showBadge: showPills,
                            minimalChrome: minimalChrome,
                            variant: LibraryCardVariant.list,
                            selectionMode: selectionActive,
                            selected: selectedKeys.contains(
                              _hitKey(item.mangas[i]),
                            ),
                            onTap: () => onMangaTap(item.mangas[i]),
                            onLongPress: onMangaLongPress == null
                                ? null
                                : () => onMangaLongPress!(item.mangas[i]),
                          ),
                        ),
                    ],
                  ),
                ),
        },
      ],
    );
  }

  Widget _compactRailsBody(
    BuildContext context, {
    required Map<String, String>? headers,
    required bool showPills,
    required bool minimalChrome,
  }) {
    final src = item.source;
    final preview = item.mangas.length > _railPreviewCount
        ? item.mangas.take(_railPreviewCount).toList(growable: false)
        : item.mangas;
    final seeAll = onSeeAll ?? onHeaderTap;
    final count = preview.length + 1; // + See all card

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: _railHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            if (i == preview.length) {
              return _ExploreSeeAllCard(
                width: _railCoverWidth,
                onTap: seeAll,
              );
            }
            final manga = preview[i];
            final key = _hitKey(manga);
            return SizedBox(
              width: _railCoverWidth,
              child: CatalogCoverCard(
                title: manga['title'] as String? ?? '',
                imageUrl: _thumb(manga, src.baseUrl),
                headers: headers,
                badge: src.name,
                showBadge: showPills,
                minimalChrome: minimalChrome,
                variant: LibraryCardVariant.grid,
                selectionMode: selectionActive,
                selected: selectedKeys.contains(key),
                onTap: () => onMangaTap(manga),
                onLongPress: onMangaLongPress == null
                    ? null
                    : () => onMangaLongPress!(manga),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Same footprint as a rail cover: no art, accent chevron + “See all”.
class _ExploreSeeAllCard extends StatelessWidget {
  const _ExploreSeeAllCard({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: AppSpacing.brMd,
                  border: Border.all(
                    color: c.border.withValues(alpha: 0.7),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.16),
                      border: Border.all(color: c.accent, width: 1.5),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: c.accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'See all',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openGlobalSearchSource(
  BuildContext context,
  WidgetRef ref,
  GlobalSearchSourceItem item,
) {
  final query = ref.read(globalSearchProvider).query.trim();
  Navigator.of(context).push(
    _scaleFadeRoute(
      SourceBrowseScreen(
        sourceId: item.source.sourceId,
        sourceName: item.source.name,
        baseUrl: item.source.baseUrl,
        initialQuery: query.isEmpty ? null : query,
      ),
    ),
  );
}

void openGlobalSearchManga(
  BuildContext context,
  GlobalSearchSourceItem item,
  Map<String, dynamic> manga,
) {
  final url = (manga['url'] as String? ?? '').trim();
  if (url.isEmpty) return;
  final title = manga['title'] as String? ?? '';
  context.pushNamed(
    Routes.mangaDetail,
    extra:
        (
              sourceId: item.source.sourceId,
              url: url,
              title: title,
              manga: null,
              memo: coerceMemoJson(manga['memo'] as String?),
            )
            as MangaDetailArgs,
  );
}
