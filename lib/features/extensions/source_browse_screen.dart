import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/models/manga.dart';
import '../../eval/dispatch_service.dart';
import '../../eval/models/m_manga.dart';
import '../../eval/models/m_source.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../core/utils/custom_extended_image_provider.dart';
import 'manga_detail_screen.dart';

class SourceBrowseScreen extends ConsumerStatefulWidget {
  final String sourceId;
  final String sourceName;

  const SourceBrowseScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  ConsumerState<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends ConsumerState<SourceBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final ExtensionDispatchService _service;
  late final MSource _source;
  final _scrollCtrl = ScrollController();

  late final TabController _tabCtrl;

  List<MManga> _mangas = [];
  bool _loading = false;
  bool _hasNext = true;
  int _page = 1;
  String? _error;
  String _tab = 'popular';

  bool _searchActive = false;
  String _searchQuery = '';
  List<MManga> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _service = ref.read(extensionServiceProvider);
    _source = MSource(
      id: widget.sourceId,
      sourceId: widget.sourceId,
      name: widget.sourceName,
      lang: 'en',
      baseUrl: '',
      sourceType: SourceType.mihon,
    );
    _tabCtrl = TabController(length: 2, vsync: this);
    _scrollCtrl.addListener(_onScroll);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final tabs = ['popular', 'latest'];
        if (_tab != tabs[_tabCtrl.index]) {
          setState(() {
            _tab = tabs[_tabCtrl.index];
            _mangas = [];
            _page = 1;
            _hasNext = true;
            _error = null;
          });
          _loadPage();
        }
      }
    });
    _loadPage();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _tabCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 400 &&
        !_loading &&
        _hasNext) {
      _loadPage();
    }
  }

  void _toggleSearch() {
    _searchTimer?.cancel();
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchQuery = '';
        _searchResults = [];
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    setState(() => _searchQuery = query);
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final mangas = await _service.search(_source, 1, query);
      if (!mounted) return;
      setState(() {
        _searchResults = mangas;
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searchLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadPage() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = switch (_tab) {
        'latest' => await _service.getLatestUpdates(
            _page, source: _source),
        _ => await _service.getPopular(
            _page, source: _source),
      };
      if (!mounted) return;
      setState(() {
        _mangas.addAll(result);
        _hasNext = result.length >= 25;
        _page++;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _error = null;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: _searchActive
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: c.textSecondary),
                ),
                style: TextStyle(color: c.textPrimary),
                onChanged: _onSearchChanged,
                onSubmitted: (v) => _performSearch(v),
              )
            : Text(widget.sourceName),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
        bottom: _searchActive
            ? null
            : TabBar(
                controller: _tabCtrl,
                indicatorColor: c.accent,
                labelColor: c.accent,
                unselectedLabelColor: c.textSecondary,
                tabs: const [
                  Tab(text: 'Popular'),
                  Tab(text: 'Latest'),
                ],
              ),
      ),
      body: _searchActive
          ? _buildSearchBody(c)
          : _mangas.isEmpty && !_loading && _error == null
              ? ListView(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: c.accent, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 120),
                    const Center(child: Text('Nothing found')),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: GridView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: _mangas.length + (_hasNext ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _mangas.length) {
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final m = _mangas[i];
                      return _MangaGridCard(
                        manga: m,
                        onTap: () async {
                          final repos = ref.read(repositoriesProvider);
                          final existing = await repos.manga.getMangaByKey(
                            widget.sourceId,
                            m.url,
                          );
                          if (existing != null) {
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MangaDetailScreen(
                                  sourceId: widget.sourceId,
                                  url: m.url,
                                  title: m.title,
                                  manga: existing,
                                ),
                              ),
                            );
                            return;
                          }
                          final manga = Manga(
                            id: 0,
                            name: m.title,
                            url: m.url,
                            imageUrl: m.thumbnailUrl,
                            author: m.author,
                            artist: m.artist,
                            description: m.description,
                            status: m.status,
                            genres: m.genres,
                            sourceId: widget.sourceId,
                          );
                          final id = await repos.manga.insertManga(manga);
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MangaDetailScreen(
                                sourceId: widget.sourceId,
                                url: m.url,
                                title: m.title,
                                manga: manga.copyWith(id: id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildSearchBody(KomaColors c) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_searchQuery.isEmpty) {
      return const Center(child: Text('Type to search'));
    }
    if (_searchResults.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              _error != null ? '$_error' : 'No results for "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final m = _searchResults[i];
        return _MangaGridCard(
          manga: m,
          onTap: () async {
            final repos = ref.read(repositoriesProvider);
            final existing = await repos.manga.getMangaByKey(
              widget.sourceId,
              m.url,
            );
            if (existing != null) {
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MangaDetailScreen(
                    sourceId: widget.sourceId,
                    url: m.url,
                    title: m.title,
                    manga: existing,
                  ),
                ),
              );
              return;
            }
            final manga = Manga(
              id: 0,
              name: m.title,
              url: m.url,
              imageUrl: m.thumbnailUrl,
              author: m.author,
              artist: m.artist,
              description: m.description,
              status: m.status,
              genres: m.genres,
              sourceId: widget.sourceId,
            );
            final id = await repos.manga.insertManga(manga);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MangaDetailScreen(
                  sourceId: widget.sourceId,
                  url: m.url,
                  title: m.title,
                  manga: manga.copyWith(id: id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MangaGridCard extends StatelessWidget {
  final MManga manga;
  final VoidCallback onTap;

  const _MangaGridCard({required this.manga, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = manga.title;
    final thumb = manga.thumbnailUrl;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                            child: thumb != null && thumb.isNotEmpty
                  ? Image(
                      image: CustomExtendedNetworkImageProvider(thumb),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(c),
                    )
                  : _placeholder(c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(KomaColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: c.textTertiary),
      ),
    );
  }
}
