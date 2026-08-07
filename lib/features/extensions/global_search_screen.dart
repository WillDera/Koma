import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import '../../core/utils/image_headers.dart';
import '../../core/utils/language.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'global_search_provider.dart';
import 'source_browse_screen.dart';

/// Mihon-parity catalogue Global Search: per-source horizontal rows,
/// Pinned/All + Has-results chips, progressive Loading/Success/Error.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(globalSearchProvider.notifier).search(q);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _ctrl.text.trim();
    ref.read(globalSearchProvider.notifier).search(q);
  }

  void _openManga(GlobalSearchSourceItem item, Map<String, dynamic> manga) {
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

  void _openSource(GlobalSearchSourceItem item) {
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(globalSearchProvider);
    final notifier = ref.read(globalSearchProvider.notifier);
    final visible = state.visibleItems;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: notifier.setQuery,
          onSubmitted: (_) => _submit(),
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Global search',
            hintStyle: TextStyle(color: c.textSecondary),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: c.textSecondary),
              onPressed: _submit,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(state.searching ? 52 : 48),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Pinned',
                      selected: state.filter == GlobalSearchSourceFilter.pinned,
                      onTap: () =>
                          notifier.setFilter(GlobalSearchSourceFilter.pinned),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All',
                      selected: state.filter == GlobalSearchSourceFilter.all,
                      onTap: () =>
                          notifier.setFilter(GlobalSearchSourceFilter.all),
                    ),
                    const Spacer(),
                    _FilterChip(
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
          ),
        ),
      ),
      body: visible.isEmpty
          ? Center(
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
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final item = visible[i];
                return _SourceResultSection(
                  item: item,
                  onHeaderTap: () => _openSource(item),
                  onMangaTap: (m) => _openManga(item, m),
                );
              },
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _SourceResultSection extends ConsumerWidget {
  const _SourceResultSection({
    required this.item,
    required this.onHeaderTap,
    required this.onMangaTap,
  });

  final GlobalSearchSourceItem item;
  final VoidCallback onHeaderTap;
  final void Function(Map<String, dynamic> manga) onMangaTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final src = item.source;
    final lang = completeLanguageName(src.lang);
    final headers = ref.watch(
      imageHeadersProvider(
        (src.baseUrl != null && src.baseUrl!.isNotEmpty) ? src.baseUrl : null,
      ),
    );

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
          GlobalSearchItemKind.success => SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: item.mangas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final manga = item.mangas[i];
                return SizedBox(
                  width: 96,
                  child: _GlobalSearchCard(
                    manga: manga,
                    baseUrl: src.baseUrl,
                    headers: headers,
                    onTap: () => onMangaTap(manga),
                  ),
                );
              },
            ),
          ),
        },
      ],
    );
  }
}

class _GlobalSearchCard extends StatelessWidget {
  const _GlobalSearchCard({
    required this.manga,
    required this.headers,
    required this.onTap,
    this.baseUrl,
  });

  final Map<String, dynamic> manga;
  final Map<String, String> headers;
  final VoidCallback onTap;
  final String? baseUrl;

  String? get _thumb {
    final raw = manga['thumbnail_url'] as String?;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = baseUrl;
    if (base == null || base.isEmpty) return raw;
    return Uri.parse(base).resolve(raw).toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = manga['title'] as String? ?? '';
    final thumb = _thumb;
    return AnimatedPress(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppSpacing.brSm,
              child: thumb != null && thumb.isNotEmpty
                  ? Image(
                      image: CustomExtendedNetworkImageProvider(
                        thumb,
                        headers: headers,
                        showCloudFlareError: true,
                      ),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: c.surfaceMuted),
                    )
                  : Container(color: c.surfaceMuted),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
