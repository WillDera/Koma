import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart' as ch_model;
import '../../core/models/manga.dart';
import '../../core/models/snippet.dart';
import '../../core/providers.dart';
import '../../core/services/search_service.dart';
import '../../core/utils/cached_network.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/screen_chrome.dart';
import '../../widgets/text_field.dart';
import '../../widgets/toast.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  Timer? _debounce;
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSearches();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  void _saveSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = (prefs.getStringList('recent_searches') ?? []);
    searches.remove(query);
    searches.insert(0, query);
    if (searches.length > 10) searches.removeLast();
    await prefs.setStringList('recent_searches', searches);
    if (mounted) setState(() => _recentSearches = searches);
  }

  void _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    if (mounted) setState(() => _recentSearches = []);
  }

  /// Debounce live typing: wait 2s after the last keystroke before searching.
  /// Empty query clears results immediately. Recent-chip taps use [_search].
  void _onQueryChanged(String query) {
    setState(() => _query = query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _searchGen++;
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(seconds: 2),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() => _query = query);
    if (query.trim().isEmpty) {
      _searchGen++;
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    final gen = ++_searchGen;
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(searchServiceProvider)
          .searchAll(query.trim());
      if (!mounted || gen != _searchGen) return;
      setState(() => _results = results);
      _saveSearch(query.trim());
    } catch (e) {
      if (mounted && gen == _searchGen) {
        StashToast.show(
          context,
          message: 'Search failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted && gen == _searchGen) {
        setState(() => _searching = false);
      }
    }
  }

  List<Manga> _mangaMatches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final mangas = ref.read(libraryProvider).mangas;
    return mangas.where((m) {
      final title = m.name.toLowerCase();
      final author = (m.author ?? '').toLowerCase();
      final genres = m.genres.join(' ').toLowerCase();
      return title.contains(q) || author.contains(q) || genres.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim();

    return ScreenBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchHeader(c),
            Expanded(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _bodySlivers(context, q),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchHeader(KomaColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButtonRound(
            iconData: AppIcons.back,
            size: 38,
            variant: IconButtonVariant.tonal,
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StashTextField(
              controller: _searchController,
              focusNode: _focusNode,
              hint: 'Search your library...',
              leadingIcon: Icons.search,
              showClearButton: true,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _search,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(BuildContext context, String q) {
    if (_searching) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Skeleton(
                  height: 92,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
      ];
    }
    if (q.isEmpty) return _idleSlivers(context);
    final mangas = _mangaMatches(q);
    final hasServiceResults = _results.isNotEmpty;
    if (!hasServiceResults && mangas.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: AppIcons.search,
            title: 'No results found',
            subtitle: 'No items matching "$q" in your library',
          ),
        ),
      ];
    }
    return _resultSlivers(context, q, mangas);
  }

  List<Widget> _idleSlivers(BuildContext context) {
    final c = context.colors;
    final library = ref.watch(libraryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            if (_recentSearches.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'RECENT SEARCHES',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  AnimatedPress(
                    onTap: _clearRecentSearches,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final term in _recentSearches)
                    AnimatedPress(
                      onTap: () {
                        _searchController.text = term;
                        _search(term);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? c.surfaceMuted
                              : const Color(0xFFE0E0EC),
                          borderRadius: AppSpacing.brPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              data: AppIcons.search,
                              size: 12,
                              color: c.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              term,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'BROWSE LIBRARY',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _browseTile(
                    icon: AppIcons.bookOpen,
                    iconColor: AppColors.figmaViolet,
                    background: isDark
                        ? const Color(0xFF161626)
                        : AppColors.lightAccentMuted,
                    title: '${library.books.length} Books',
                    subtitle: 'In your library',
                    textColor: c.textPrimary,
                    mutedColor: c.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _browseTile(
                    icon: AppIcons.bookshelf,
                    iconColor: AppColors.figmaGreen,
                    background: isDark
                        ? const Color(0xFF16261E)
                        : const Color(0xFFDCFCE7),
                    title: '${library.mangas.length} Manga',
                    subtitle: 'In your library',
                    textColor: c.textPrimary,
                    mutedColor: c.textSecondary,
                  ),
                ),
              ],
            ),
            if (_recentSearches.isEmpty) ...[
              const SizedBox(height: 32),
              EmptyState(
                icon: AppIcons.search,
                title: 'Search your library',
                subtitle:
                    'Type a title, author, phrase, or tag. Results stream as you type.',
              ),
            ],
          ]),
        ),
      ),
    ];
  }

  Widget _browseTile({
    required AppIconData icon,
    required Color iconColor,
    required Color background,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppSpacing.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(data: icon, size: 24, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultSlivers(
    BuildContext context,
    String q,
    List<Manga> mangas,
  ) {
    final books = _results.where((r) => r.type == 'book').toList();
    final chapters = _results.where((r) => r.type == 'chapter').toList();
    final snippets = _results.where((r) => r.type == 'snippet').toList();
    final total =
        books.length + mangas.length + chapters.length + snippets.length;

    final entries = <_SearchRow>[];
    void addSection(
      String title,
      int count,
      Color accent,
      AppIconData icon,
      List<_SearchRow> items,
    ) {
      if (items.isEmpty) return;
      if (entries.isNotEmpty) {
        entries.add(const _SearchRow.gap(16));
      }
      entries.add(_SearchRow.header(title, count, accent, icon));
      entries.add(const _SearchRow.gap(8));
      entries.addAll(items);
    }

    addSection(
      'Books',
      books.length,
      AppColors.figmaVioletLight,
      AppIcons.bookOpen,
      books
          .map((r) => _SearchRow.item(r, _SearchItemKind.book))
          .toList(),
    );
    addSection(
      'Manga',
      mangas.length,
      AppColors.figmaGreen,
      AppIcons.bookshelf,
      mangas.map(_SearchRow.manga).toList(),
    );
    addSection(
      'Chapters',
      chapters.length,
      context.colors.accent,
      AppIcons.note,
      chapters
          .map((r) => _SearchRow.item(r, _SearchItemKind.chapter))
          .toList(),
    );
    addSection(
      'Snippets',
      snippets.length,
      AppColors.figmaAmber,
      AppIcons.bookmark,
      snippets
          .map((r) => _SearchRow.item(r, _SearchItemKind.snippet))
          .toList(),
    );

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$total result${total == 1 ? '' : 's'} for "$q"',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              final entry = entries[i - 1];
              return switch (entry.kind) {
                _SearchRowKind.gap => SizedBox(height: entry.gapHeight),
                _SearchRowKind.header => _sectionHeader(
                  entry.title!,
                  entry.count!,
                  entry.accent!,
                  entry.icon!,
                ),
                _SearchRowKind.item => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: switch (entry.itemKind!) {
                    _SearchItemKind.book => _bookResult(entry.result!),
                    _SearchItemKind.chapter => _chapterResult(entry.result!),
                    _SearchItemKind.snippet => _snippetResult(entry.result!),
                    _SearchItemKind.manga => _mangaResult(entry.manga!),
                  },
                ),
              };
            },
            childCount: 1 + entries.length,
          ),
        ),
      ),
    ];
  }

  Widget _sectionHeader(
    String title,
    int count,
    Color accent,
    AppIconData icon,
  ) {
    return Row(
      children: [
        AppIcon(data: icon, size: 13, color: accent),
        const SizedBox(width: 6),
        Text(
          '$title ($count)',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _bookResult(SearchResult r) {
    final book = r.item as Book;
    final chapterLabel = book.totalChapters > 0
        ? 'Chapter ${book.currentChapterIndex + 1} of ${book.totalChapters}'
        : (book.author ?? '');
    return _resultCard(
      onTap: () => _openReader(book.id),
      cover: _bookCover(book),
      title: book.title,
      subtitle: book.author,
      meta: chapterLabel.isEmpty ? null : chapterLabel,
      footer: book.progress > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ThinProgressBar(
                progress: book.progress.clamp(0.0, 1.0),
                height: 4,
                color: AppColors.figmaViolet,
                trackColor: context.colors.surfaceMuted,
              ),
            )
          : null,
    );
  }

  Widget _mangaResult(Manga manga) {
    final status = _mangaStatusLabel(manga.status);
    final statusColor = _mangaStatusColor(manga.status);
    return _resultCard(
      onTap: () => _openManga(manga),
      cover: _mangaCover(manga),
      title: manga.name,
      subtitle: manga.author,
      meta: manga.genres.isNotEmpty ? manga.genres.first : null,
      footer: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.13),
              borderRadius: AppSpacing.brXs,
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chapterResult(SearchResult r) {
    final chapter = r.item as ch_model.Chapter;
    return _resultCard(
      onTap: () => _openReader(chapter.bookId),
      cover: _iconCover(AppIcons.note),
      title: chapter.title,
      subtitle: r.matchPreview,
    );
  }

  Widget _snippetResult(SearchResult r) {
    final snippet = r.item as Snippet;
    return _resultCard(
      onTap: () => _openReader(snippet.bookId ?? 0),
      cover: _iconCover(AppIcons.bookmark),
      title: snippet.text,
      subtitle: snippet.sourceTitle,
    );
  }

  Widget _resultCard({
    required VoidCallback onTap,
    required Widget cover,
    required String title,
    String? subtitle,
    String? meta,
    Widget? footer,
  }) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      scaleDown: 0.99,
      child: Container(
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
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (meta != null && meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookCover(Book book) {
    final c = context.colors;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return ClipRRect(
      borderRadius: AppSpacing.brMd,
      child: SizedBox(
        width: 48,
        height: 68,
        child: hasCover
            ? Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceMuted),
              )
            : ColoredBox(color: c.surfaceMuted),
      ),
    );
  }

  Widget _mangaCover(Manga manga) {
    final c = context.colors;
    final url = manga.imageUrl;
    return ClipRRect(
      borderRadius: AppSpacing.brMd,
      child: SizedBox(
        width: 48,
        height: 68,
        child: url != null && url.isNotEmpty
            ? Image(
                image: coverProvider(url, maxBytes: 80 << 10),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceMuted),
              )
            : ColoredBox(color: c.surfaceMuted),
      ),
    );
  }

  Widget _iconCover(AppIconData icon) {
    final c = context.colors;
    return Container(
      width: 48,
      height: 68,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: AppSpacing.brMd,
      ),
      alignment: Alignment.center,
      child: AppIcon(data: icon, size: 20, color: c.textSecondary),
    );
  }

  String _mangaStatusLabel(int status) {
    return switch (status) {
      1 => 'Ongoing',
      2 => 'Completed',
      4 => 'Finished',
      5 => 'Cancelled',
      6 => 'On hiatus',
      _ => 'Unknown',
    };
  }

  Color _mangaStatusColor(int status) {
    return switch (status) {
      1 => AppColors.figmaGreen,
      2 => AppColors.figmaVioletLight,
      5 || 6 => AppColors.figmaAmber,
      _ => context.colors.textSecondary,
    };
  }

  void _openReader(int bookId) {
    if (bookId == 0) return;
    context.pushNamed(
      Routes.reader,
      extra:
          (
                bookId: bookId,
                snippetChapterId: null,
                snippetScrollOffset: null,
                snippetStartOffset: null,
                snippetEndOffset: null,
              )
              as ReaderArgs,
    );
  }

  void _openManga(Manga manga) {
    context.pushNamed(
      Routes.mangaDetail,
      extra:
          (
                sourceId: manga.sourceId,
                url: manga.url,
                title: manga.name,
                manga: manga,
                memo: manga.memo,
              )
              as MangaDetailArgs,
    );
  }
}

enum _SearchRowKind { gap, header, item }

enum _SearchItemKind { book, chapter, snippet, manga }

class _SearchRow {
  final _SearchRowKind kind;
  final double gapHeight;
  final String? title;
  final int? count;
  final Color? accent;
  final AppIconData? icon;
  final SearchResult? result;
  final Manga? manga;
  final _SearchItemKind? itemKind;

  const _SearchRow.gap(this.gapHeight)
    : kind = _SearchRowKind.gap,
      title = null,
      count = null,
      accent = null,
      icon = null,
      result = null,
      manga = null,
      itemKind = null;

  const _SearchRow.header(this.title, this.count, this.accent, this.icon)
    : kind = _SearchRowKind.header,
      gapHeight = 0,
      result = null,
      manga = null,
      itemKind = null;

  const _SearchRow.item(this.result, this.itemKind)
    : kind = _SearchRowKind.item,
      gapHeight = 0,
      title = null,
      count = null,
      accent = null,
      icon = null,
      manga = null;

  const _SearchRow.manga(this.manga)
    : kind = _SearchRowKind.item,
      gapHeight = 0,
      title = null,
      count = null,
      accent = null,
      icon = null,
      result = null,
      itemKind = _SearchItemKind.manga;
}
