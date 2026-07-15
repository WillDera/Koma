import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/book.dart';
import '../../core/models/chapter.dart' as ch_model;
import '../../core/models/snippet.dart';
import '../../core/services/database_service.dart';
import '../../core/services/search_service.dart';
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
import '../reader/reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  double _scrollProgress = 0;
  SearchService? _searchService;
  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final db = context.read<DatabaseService>();
    _searchService = SearchService(db.db);
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

  Future<void> _search(String query) async {
    setState(() => _query = query);
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _searchService!.searchAll(query.trim());
      if (!mounted) return;
      setState(() => _results = results);
      _saveSearch(query.trim());
    } catch (e) {
      if (mounted) {
        StashToast.show(
          context,
          message: 'Search failed: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const OneHandSpacer(),
          LibraryHeader(
            title: 'Search',
            titleSize: _oneHand ? 64 : 32,
            shrinkProgress: _oneHand ? _scrollProgress : 0.0,
            subtitle: 'Across your library, chapters, and snippets',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: StashTextField(
              controller: _searchController,
              focusNode: _focusNode,
              hint: 'Find anything…',
              leadingIcon: Icons.search,
              showClearButton: true,
              onChanged: _search,
            ),
          ),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_searching) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Skeleton(
                height: 64,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
        ],
      );
    }
    if (_query.isEmpty) return _buildIdle(context);
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing matched "$_query". Try a different keyword.',
      );
    }
    return _buildResults(context);
  }

  Widget _buildIdle(BuildContext context) {
    final c = context.colors;
    if (_recentSearches.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: 'Search your library',
        subtitle:
            'Type a title, author, phrase, or tag. Results stream as you type.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
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
        const SizedBox(height: 12),
        for (final q in _recentSearches) ...[
          AnimatedPress(
            onTap: () {
              _searchController.text = q;
              _search(q);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
                  Icon(
                    Icons.north_west,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final books = _results.where((r) => r.type == 'book').toList();
    final chapters = _results.where((r) => r.type == 'chapter').toList();
    final snippets = _results.where((r) => r.type == 'snippet').toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (books.isNotEmpty) ...[
          _sectionHeader('Books', books.length),
          const SizedBox(height: 8),
          ...books.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _bookResult(r),
              )),
        ],
        if (chapters.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader('Chapters', chapters.length),
          const SizedBox(height: 8),
          ...chapters.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _chapterResult(r),
              )),
        ],
        if (snippets.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader('Snippets', snippets.length),
          const SizedBox(height: 8),
          ...snippets.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _snippetResult(r),
              )),
        ],
      ],
    );
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId)),
    );
  }
}
