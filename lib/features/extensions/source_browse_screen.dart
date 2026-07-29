import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/models/manga.dart';
import '../../eval/dispatch_service.dart';
import '../../eval/models/filter_list.dart';
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

  List<Filter> _filters = [];
  Map<String, dynamic> _filterValues = {};
  bool _filtersLoaded = false;
  bool _showFilterSheet = false;

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
    _loadFilters();
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

  Future<void> _loadFilters() async {
    try {
      final fl = await _service.getFilterList(_source);
      if (!mounted) return;
      final values = <String, dynamic>{};
      for (final f in fl.filters) {
        _initFilterValue(f, values);
      }
      setState(() {
        _filters = fl.filters;
        _filterValues = values;
        _filtersLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _filtersLoaded = true);
    }
  }

  void _initFilterValue(Filter f, Map<String, dynamic> values) {
    switch (f.type) {
      case FilterType.text:
        values[f.name] = f.value as String? ?? '';
      case FilterType.check:
        values[f.name] = f.value as bool? ?? false;
      case FilterType.triState:
        values[f.name] = f.value as int? ?? 0;
      case FilterType.select:
        values[f.name] = f.value as int? ?? 0;
      case FilterType.sort:
        values[f.name] = f.value;
      case FilterType.group:
        final subs = <Map<String, dynamic>>[];
        for (final sf in f.subFilters ?? []) {
          final sv = <String, dynamic>{};
          _initFilterValue(sf, sv);
          subs.add(sv);
        }
        values[f.name] = subs;
      case FilterType.header:
      case FilterType.separator:
        break;
    }
  }

  void _openFilterSheet() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        filters: _filters,
        values: Map.from(_filterValues),
        onApply: (updated) {
          setState(() => _filterValues = updated);
          _performSearch(_searchQuery);
        },
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _loadPage();
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final filterList = _buildFilterList();
      final mangas = await _service.search(_source, 1, query, filters: filterList);
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

  FilterList? _buildFilterList() {
    if (_filterValues.isEmpty) return null;
    final built = <Filter>[];
    for (final f in _filters) {
      final builtFilter = _buildFilterFromValue(f, _filterValues);
      if (builtFilter != null) built.add(builtFilter);
    }
    if (built.isEmpty) return null;
    return FilterList(filters: built);
  }

  Filter? _buildFilterFromValue(Filter f, Map<String, dynamic> values) {
    final value = values[f.name];
    switch (f.type) {
      case FilterType.text:
        return Filter(key: f.name, name: f.name, type: f.type, value: value as String? ?? '');
      case FilterType.check:
        return Filter(key: f.name, name: f.name, type: f.type, value: value as bool? ?? false);
      case FilterType.triState:
        return Filter(key: f.name, name: f.name, type: f.type, value: value as int? ?? 0);
      case FilterType.select:
        return Filter(key: f.name, name: f.name, type: f.type, value: value as int? ?? 0, options: f.options);
      case FilterType.sort:
        return Filter(key: f.name, name: f.name, type: f.type, value: value, options: f.options);
      case FilterType.group:
        final subValuesList = value as List<Map<String, dynamic>>? ?? [];
        final subFilters = <Filter>[];
        for (var i = 0; i < (f.subFilters?.length ?? 0); i++) {
          final sf = f.subFilters![i];
          final sv = i < subValuesList.length ? subValuesList[i] : <String, dynamic>{};
          final builtSub = _buildFilterFromValue(sf, sv);
          if (builtSub != null) subFilters.add(builtSub);
        }
        return Filter(
          key: f.name, name: f.name, type: f.type,
          subFilters: subFilters,
        );
      case FilterType.header:
      case FilterType.separator:
        return null;
    }
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
          if (_searchActive && _filtersLoaded && _filters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterSheet,
            ),
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

class _FilterSheet extends StatefulWidget {
  final List<Filter> filters;
  final Map<String, dynamic> values;
  final void Function(Map<String, dynamic> updated) onApply;

  const _FilterSheet({
    required this.filters,
    required this.values,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = Map.from(widget.values);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<KomaColors>()!;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary)),
                TextButton(
                  onPressed: () {
                    widget.onApply(_values);
                    Navigator.of(context).pop();
                  },
                  child: Text('Apply', style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: widget.filters.map((f) => _buildFilterWidget(f, _values)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterWidget(Filter f, Map<String, dynamic> values) {
    final c = Theme.of(context).extension<KomaColors>()!;
    switch (f.type) {
      case FilterType.header:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(f.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
        );
      case FilterType.separator:
        return const Divider(height: 24);
      case FilterType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            decoration: InputDecoration(
              labelText: f.name,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            controller: TextEditingController(text: values[f.name] as String? ?? ''),
            onChanged: (v) => setState(() => values[f.name] = v),
          ),
        );
      case FilterType.check:
        return SwitchListTile(
          title: Text(f.name, style: TextStyle(color: c.textPrimary)),
          value: values[f.name] as bool? ?? false,
          onChanged: (v) => setState(() => values[f.name] = v),
        );
      case FilterType.triState:
        final triValue = values[f.name] as int? ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Ignore')),
                  ButtonSegment(value: 1, label: Text('Include')),
                  ButtonSegment(value: 2, label: Text('Exclude')),
                ],
                selected: {triValue},
                onSelectionChanged: (s) => setState(() => values[f.name] = s.first),
              ),
            ],
          ),
        );
      case FilterType.select:
        final selIdx = values[f.name] as int? ?? 0;
        final opts = f.options ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: f.name,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            value: selIdx < opts.length ? selIdx : 0,
            items: opts.asMap().entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value.name),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => values[f.name] = v);
            },
          ),
        );
      case FilterType.sort:
        final current = values[f.name] as Map?;
        final selIdx = (current?['index'] as int?) ?? 0;
        final ascending = (current?['ascending'] as bool?) ?? true;
        final opts = f.options ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              ...opts.asMap().entries.map((e) => RadioListTile<int>(
                title: Text(e.value.name, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                value: e.key,
                groupValue: selIdx,
                onChanged: (v) {
                  if (v != null) setState(() {
                    values[f.name] = {'index': v, 'ascending': ascending};
                  });
                },
                dense: true,
              )),
              SwitchListTile(
                title: const Text('Ascending', style: TextStyle(fontSize: 14)),
                value: ascending,
                onChanged: (v) => setState(() {
                  values[f.name] = {'index': selIdx, 'ascending': v};
                }),
                dense: true,
              ),
            ],
          ),
        );
      case FilterType.group:
        final subValuesList = (values[f.name] as List<Map<String, dynamic>>?) ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            title: Text(f.name, style: TextStyle(color: c.textPrimary)),
            children: (f.subFilters ?? []).asMap().entries.map((e) {
              final sf = e.value;
              final sv = e.key < subValuesList.length ? subValuesList[e.key] : <String, dynamic>{};
              return Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildFilterWidget(sf, sv),
              );
            }).toList(),
          ),
        );
    }
  }
}
