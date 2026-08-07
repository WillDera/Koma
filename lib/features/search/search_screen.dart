import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart' as ch_model;
import '../../core/models/snippet.dart';
import '../../core/providers.dart';
import '../../core/services/search_service.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_header.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/search_result_row.dart';
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
  final ScrollController _scrollCtrl = ScrollController();
  double _scrollProgress = 0;
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  Timer? _debounce;
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSearches();
    });
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
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
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
    if (query
        .trim()
        .isEmpty) {
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

  bool get _oneHand => ref.watch(themeProvider).oneHandMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: OneHandSpacer()),
          SliverToBoxAdapter(
            child: LibraryHeader(
              title: 'Search',
              titleSize: _oneHand ? 64 : 32,
              shrinkProgress: _oneHand ? _scrollProgress : 0.0,
              subtitle: 'Across your library, chapters, and snippets',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: StashTextField(
                controller: _searchController,
                focusNode: _focusNode,
                hint: 'Find anything…',
                leadingIcon: Icons.search,
                showClearButton: true,
                onChanged: _onQueryChanged,
              ),
            ),
          ),
          ..._bodySlivers(context),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(BuildContext context) {
    if (_searching) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Skeleton(
                  height: 64,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
      ];
    }
    if (_query.isEmpty) return _idleSlivers(context);
    if (_results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: AppIcons.search,
            title: 'No results',
            subtitle: 'Nothing matched "$_query". Try a different keyword.',
          ),
        ),
      ];
    }
    return _resultSlivers(context);
  }

  List<Widget> _idleSlivers(BuildContext context) {
    final c = context.colors;
    if (_recentSearches.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: AppIcons.search,
            title: 'Search your library',
            subtitle:
                'Type a title, author, phrase, or tag. Results stream as you type.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        'Recent searches',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                );
              }
              final q = _recentSearches[index - 1];
              return AnimatedPress(
                onTap: () {
                  _searchController.text = q;
                  _search(q);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: AppSpacing.brLg,
                    border: Border.all(color: c.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: c.textTertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.north_west, size: 16, color: c.textTertiary),
                    ],
                  ),
                ),
              );
            },
            childCount: 1 + _recentSearches.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _resultSlivers(BuildContext context) {
    final books = _results.where((r) => r.type == 'book').toList();
    final chapters = _results.where((r) => r.type == 'chapter').toList();
    final snippets = _results.where((r) => r.type == 'snippet').toList();

    // Flat entries for lazy SliverList builds (headers, gaps, result rows).
    final entries = <_SearchRow>[];
    void addSection(
      String title,
      List<SearchResult> items,
      _SearchItemKind kind,
    ) {
      if (items.isEmpty) return;
      if (entries.isNotEmpty) {
        entries.add(const _SearchRow.gap(16));
      }
      entries.add(_SearchRow.header(title, items.length));
      entries.add(const _SearchRow.gap(8));
      for (final r in items) {
        entries.add(_SearchRow.item(r, kind));
      }
    }

    addSection('Books', books, _SearchItemKind.book);
    addSection('Chapters', chapters, _SearchItemKind.chapter);
    addSection('Snippets', snippets, _SearchItemKind.snippet);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final entry = entries[i];
              return switch (entry.kind) {
                _SearchRowKind.gap => SizedBox(height: entry.gapHeight),
                _SearchRowKind.header =>
                  _sectionHeader(entry.title!, entry.count!),
                _SearchRowKind.item => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: switch (entry.itemKind!) {
                    _SearchItemKind.book => _bookResult(entry.result!),
                    _SearchItemKind.chapter => _chapterResult(entry.result!),
                    _SearchItemKind.snippet => _snippetResult(entry.result!),
                  },
                ),
              };
            },
            childCount: entries.length,
          ),
        ),
      ),
    ];
  }

  Widget _sectionHeader(String title, int count) {
    final c = context.colors;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: AppSpacing.brPill,
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bookResult(SearchResult r) {
    final book = r.item as Book;
    return SearchResultRow(
      variant: SearchResultRowVariant.book,
      icon: Icons.menu_book,
      title: book.title,
      subtitle: book.author,
      progress: book.progress,
      onTap: () => _openReader(book.id),
    );
  }

  Widget _chapterResult(SearchResult r) {
    final chapter = r.item as ch_model.Chapter;
    return SearchResultRow(
      variant: SearchResultRowVariant.chapter,
      icon: Icons.article_outlined,
      title: chapter.title,
      subtitle: r.matchPreview,
      onTap: () => _openReader(chapter.bookId),
    );
  }

  Widget _snippetResult(SearchResult r) {
    final snippet = r.item as Snippet;
    return SearchResultRow(
      variant: SearchResultRowVariant.snippet,
      icon: Icons.format_quote,
      title: snippet.text,
      subtitle: snippet.sourceTitle,
      onTap: () => _openReader(snippet.bookId ?? 0),
    );
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
}

enum _SearchRowKind { gap, header, item }

enum _SearchItemKind { book, chapter, snippet }

class _SearchRow {
  final _SearchRowKind kind;
  final double gapHeight;
  final String? title;
  final int? count;
  final SearchResult? result;
  final _SearchItemKind? itemKind;

  const _SearchRow.gap(this.gapHeight)
    : kind = _SearchRowKind.gap,
      title = null,
      count = null,
      result = null,
      itemKind = null;

  const _SearchRow.header(this.title, this.count)
    : kind = _SearchRowKind.header,
      gapHeight = 0,
      result = null,
      itemKind = null;

  const _SearchRow.item(this.result, this.itemKind)
    : kind = _SearchRowKind.item,
      gapHeight = 0,
      title = null,
      count = null;
}
