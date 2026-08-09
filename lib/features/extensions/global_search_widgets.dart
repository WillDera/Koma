import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/image_headers.dart';
import '../../core/utils/language.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/library_book_card.dart';
import 'global_search_provider.dart';
import 'source_browse_screen.dart';

/// Pinned / All / Has-results chips shared by Global Search + Discover manga.
class GlobalSearchFilterBar extends ConsumerWidget {
  const GlobalSearchFilterBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final notifier = ref.read(globalSearchProvider.notifier);
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
              GlobalSearchFilterChip(
                label: 'Has results',
                selected: state.onlyShowHasResults,
                onTap: notifier.toggleOnlyHasResults,
              ),
            ],
          ),
        ),
        if (state.searching && state.total > 0)
          LinearProgressIndicator(
            value: state.progress / state.total,
            minHeight: 2,
            backgroundColor: c.surfaceMuted,
            color: c.accent,
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
    return Material(
      color: selected ? c.accentMuted : c.surfaceMuted,
      borderRadius: AppSpacing.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.accent : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full scrolling body used by [GlobalSearchScreen].
class GlobalSearchResultsList extends ConsumerWidget {
  const GlobalSearchResultsList({super.key, this.padding, this.onMangaTap});

  final EdgeInsetsGeometry? padding;
  final void Function(
    GlobalSearchSourceItem item,
    Map<String, dynamic> manga,
  )?
  onMangaTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final visible = state.visibleItems;

    if (visible.isEmpty) {
      return Center(
        child: Text(
          state.query.trim().isEmpty
              ? 'Search installed sources'
              : state.searching
              ? 'Searching…'
              : state.onlyShowHasResults
              ? 'No sources with results'
              : 'No results',
          style: TextStyle(color: c.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: padding ?? const EdgeInsets.only(bottom: 32),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        return GlobalSearchSourceSection(
          item: item,
          onHeaderTap: () => openGlobalSearchSource(context, ref, item),
          onMangaTap: (m) {
            if (onMangaTap != null) {
              onMangaTap!(item, m);
            } else {
              openGlobalSearchManga(context, item, m);
            }
          },
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
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final visible = state.visibleItems;

    if (visible.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: Text(
              state.query.trim().isEmpty
                  ? 'Search installed sources'
                  : state.searching
                  ? 'Searching…'
                  : state.onlyShowHasResults
                  ? 'No sources with results'
                  : 'No manga results',
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, i) {
        final item = visible[i];
        return GlobalSearchSourceSection(
          item: item,
          onHeaderTap: () => openGlobalSearchSource(context, ref, item),
          onMangaTap: (m) => openGlobalSearchManga(context, item, m),
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
  });

  final GlobalSearchSourceItem item;
  final VoidCallback onHeaderTap;
  final void Function(Map<String, dynamic> manga) onMangaTap;

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
    final showPills = library.showSourcePills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
          GlobalSearchItemKind.success => gridView
              ? Padding(
                  padding: CatalogCardLayout.paddingFor(variant).add(
                    const EdgeInsets.only(bottom: 12),
                  ),
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
                      return CatalogCoverCard(
                        title: manga['title'] as String? ?? '',
                        imageUrl: _thumb(manga, src.baseUrl),
                        headers: headers,
                        badge: src.name,
                        showBadge: showPills,
                        variant: variant,
                        onTap: () => onMangaTap(manga),
                      );
                    },
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      for (final manga in item.mangas)
                        CatalogCoverCard(
                          title: manga['title'] as String? ?? '',
                          imageUrl: _thumb(manga, src.baseUrl),
                          headers: headers,
                          badge: src.name,
                          showBadge: showPills,
                          variant: LibraryCardVariant.list,
                          onTap: () => onMangaTap(manga),
                        ),
                    ],
                  ),
                ),
        },
      ],
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
    MaterialPageRoute(
      builder: (_) => SourceBrowseScreen(
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
