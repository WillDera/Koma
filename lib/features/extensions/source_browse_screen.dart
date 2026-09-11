import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/manga.dart';
import '../../core/providers.dart';
import '../../core/services/extension_source_resolve.dart';
import '../../core/utils/image_headers.dart';
import '../../eval/dispatch_service.dart';
import '../../eval/models/filter_list.dart';
import '../../eval/models/m_manga.dart';
import '../../eval/models/m_source.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_motion.dart';
import '../../widgets/catalog_card_layout.dart';
import '../../widgets/catalog_cover_card.dart';
import '../../widgets/horizontal_tab_swipe.dart';
import '../../widgets/library_book_card.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';
import 'manga_detail_screen.dart';

Route<T> _scaleFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        scaleFadePageTransition(animation: animation, child: child),
  );
}

class SourceBrowseScreen extends ConsumerStatefulWidget {
  final String sourceId;
  final String sourceName;
  final String? baseUrl;

  /// Initial catalogue tab: `popular` (default) or `latest`.
  final String initialTab;

  /// When set, opens catalogue search with this query (Global Search source
  /// header → browse-with-query; Mihon BrowseSourceScreen parity).
  final String? initialQuery;

  const SourceBrowseScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
    this.baseUrl,
    this.initialTab = 'popular',
    this.initialQuery,
  });

  @override
  ConsumerState<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends ConsumerState<SourceBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final ExtensionDispatchService _service;
  MSource? _source;
  final _scrollCtrl = ScrollController();

  late final TabController _tabCtrl;

  List<MManga> _mangas = [];
  bool _loading = false;
  bool _hasNext = true;
  int _page = 1;
  String? _error;
  String _tab = 'popular';
  bool _booting = true;

  bool _searchActive = false;
  String _searchQuery = '';
  List<MManga> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchTimer;
  late final TextEditingController _searchCtrl;

  List<Filter> _filters = [];
  Map<String, dynamic> _filterValues = {};
  bool _filtersLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    _service = ref.read(extensionServiceProvider);
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'latest' ? 1 : 0,
    );
    _tab = widget.initialTab == 'latest' ? 'latest' : 'popular';
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
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final source = await resolveExtensionMSource(
        ref.read(repositoriesProvider),
        widget.sourceId,
        name: widget.sourceName,
        baseUrl: widget.baseUrl,
      );
      if (!mounted) return;
      _source = source;
      setState(() => _booting = false);

      final initialQ = widget.initialQuery?.trim() ?? '';
      if (initialQ.isNotEmpty) {
        setState(() {
          _searchActive = true;
          _searchQuery = initialQ;
        });
        // Sequential: shared QuickJS must not run filters + search together.
        await _loadFilters();
        if (!mounted) return;
        await _performSearch(initialQ);
      } else {
        await _loadPage();
        if (!mounted) return;
        unawaited(_loadFilters());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _error = '$e';
      });
    }
  }

  MSource get _requireSource {
    final s = _source;
    if (s == null) {
      throw StateError('Source not ready');
    }
    return s;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
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
        _searchCtrl.clear();
        _searchResults = [];
      }
    });
  }

  void _toggleSort() {
    final newTab = _tab == 'popular' ? 'latest' : 'popular';
    setState(() {
      _tab = newTab;
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _error = null;
    });
    _tabCtrl.animateTo(newTab == 'latest' ? 1 : 0);
    _loadPage();
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    setState(() => _searchQuery = query);
    if (query.isEmpty && _filters.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _loadPage() async {
    if (_loading || _source == null) return;
    setState(() => _loading = true);
    try {
      final source = _requireSource;
      final page = switch (_tab) {
        'latest' => await _service.getLatestUpdates(_page, source: source),
        _ => await _service.getPopular(_page, source: source),
      };
      if (!mounted) return;
      setState(() {
        _mangas.addAll(page.list);
        _hasNext = page.hasNextPage;
        _page++;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _hasNext = false;
      });
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
    if (_source == null) return;
    try {
      final fl = await _service.getFilterList(_requireSource);
      if (!mounted) return;
      final values = <String, dynamic>{};
      for (final f in fl.filters) {
        _initFilterValue(f, values);
      }
      setState(() {
        _filters = fl.filters;
        _filterValues = values;
        _filtersLoaded = true;
        _error = null;
      });
    } catch (e) {
      // Filters are optional — don't replace catalogue errors with filter noise.
      if (mounted) {
        setState(() => _filtersLoaded = true);
      }
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
          if (!_searchActive) {
            setState(() => _searchActive = true);
          }
          // Apply/Save always runs search with the new filter state (empty
          // query is fine when filters are active).
          _performSearch(_searchCtrl.text);
        },
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (_source == null) return;
    final q = query.trim();
    final filtersActive = _hasActiveFilterValues();
    if (q.isEmpty && !filtersActive) {
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _loadPage();
      return;
    }
    if (!_searchActive) {
      setState(() => _searchActive = true);
    }
    setState(() => _searchLoading = true);
    try {
      final filterList = _buildFilterList();
      final page = await _service.search(
        _requireSource,
        1,
        q,
        filters: filterList,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = page.list;
        _searchLoading = false;
        _error = null;
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

  /// True when the user changed any filter away from its default.
  bool _hasActiveFilterValues() {
    if (_filters.isEmpty) return false;
    for (final f in _filters) {
      if (_filterIsActive(f, _filterValues)) return true;
    }
    return false;
  }

  bool _filterIsActive(Filter f, Map<String, dynamic> values) {
    switch (f.type) {
      case FilterType.text:
        return (values[f.name] as String? ?? '').trim().isNotEmpty;
      case FilterType.check:
        return values[f.name] as bool? ?? false;
      case FilterType.triState:
        return (values[f.name] as int? ?? 0) != 0;
      case FilterType.select:
        return (values[f.name] as int? ?? 0) != (f.value as int? ?? 0);
      case FilterType.sort:
        return values[f.name] != null;
      case FilterType.group:
        final subs = values[f.name] as List<Map<String, dynamic>>? ?? const [];
        for (var i = 0; i < (f.subFilters?.length ?? 0); i++) {
          final sf = f.subFilters![i];
          final sv = i < subs.length ? subs[i] : <String, dynamic>{};
          if (_filterIsActive(sf, sv)) return true;
        }
        return false;
      case FilterType.header:
      case FilterType.separator:
        return false;
    }
  }

  FilterList? _buildFilterList() {
    if (_filters.isEmpty) return null;
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
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          value: value as String? ?? '',
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.check:
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          value: value as bool? ?? false,
          options: f.options,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.triState:
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          value: value as int? ?? 0,
          options: f.options,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.select:
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          value: value as int? ?? 0,
          options: f.options,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.sort:
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          value: value,
          options: f.options,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.group:
        final subValuesList = value as List<Map<String, dynamic>>? ?? [];
        final subFilters = <Filter>[];
        for (var i = 0; i < (f.subFilters?.length ?? 0); i++) {
          final sf = f.subFilters![i];
          final sv = i < subValuesList.length
              ? subValuesList[i]
              : <String, dynamic>{};
          final builtSub = _buildFilterFromValue(sf, sv);
          if (builtSub != null) subFilters.add(builtSub);
        }
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          subFilters: subFilters,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
      case FilterType.header:
      case FilterType.separator:
        return Filter(
          key: f.key,
          name: f.name,
          type: f.type,
          filterTypeId: f.filterTypeId,
          typeName: f.typeName,
        );
    }
  }

  VoidCallback _openManga(MManga m) {
    return () async {
      final repos = ref.read(repositoriesProvider);
      final existing = await repos.manga.getMangaByKey(widget.sourceId, m.url);
      if (existing != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          _scaleFadeRoute(
            MangaDetailScreen(
              sourceId: widget.sourceId,
              url: m.url,
              title: m.title,
              manga: existing,
              memo: m.memo,
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
        memo: m.memo,
      );
      final id = await repos.manga.insertManga(manga);
      if (!mounted) return;
      Navigator.push(
        context,
        _scaleFadeRoute(
          MangaDetailScreen(
            sourceId: widget.sourceId,
            url: m.url,
            title: m.title,
            manga: manga.copyWith(id: id),
            memo: m.memo,
          ),
        ),
      );
    };
  }

  Widget _catalogMangaBody({
    required List<MManga> mangas,
    required Map<String, String> headers,
    ScrollController? controller,
    bool hasNext = false,
    Future<void> Function()? onRefresh,
    int? coverMaxBytes,
  }) {
    final library = ref.watch(libraryProvider);
    final libraryUrls = <String>{
      for (final m in library.mangas)
        if (m.sourceId == widget.sourceId) m.url,
    };
    final gridView = library.isGridView;
    final variant = gridView
        ? CatalogCardLayout.gridVariant(library.cardVariant)
        : LibraryCardVariant.list;
    final columns = library.gridColumns;

    Widget child;
    if (gridView) {
      child = GridView.builder(
        controller: controller,
        padding: CatalogCardLayout.paddingFor(variant)
            .resolve(TextDirection.ltr)
            .add(const EdgeInsets.symmetric(vertical: 12)),
        gridDelegate: CatalogCardLayout.gridDelegate(
          columns: columns,
          variant: variant,
        ),
        itemCount: mangas.length + (hasNext ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= mangas.length) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final m = mangas[i];
          return CatalogCoverCard(
            title: m.title,
            imageUrl: m.thumbnailUrl,
            headers: headers,
            variant: variant,
            showBadge: false,
            inLibrary: libraryUrls.contains(m.url),
            coverMaxBytes: coverMaxBytes,
            onTap: _openManga(m),
          );
        },
      );
    } else {
      child = ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: mangas.length + (hasNext ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= mangas.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final m = mangas[i];
          return CatalogCoverCard(
            title: m.title,
            subtitle: m.author,
            imageUrl: m.thumbnailUrl,
            headers: headers,
            variant: LibraryCardVariant.list,
            showBadge: false,
            inLibrary: libraryUrls.contains(m.url),
            coverMaxBytes: coverMaxBytes,
            onTap: _openManga(m),
          );
        },
      );
    }
    if (onRefresh == null) return child;
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final headersAsync = ref.watch(sourceImageHeadersProvider(widget.sourceId));
    final coverBytesAsync = ref.watch(
      sourceCoverMaxBytesProvider(widget.sourceId),
    );
    final resolvedHeaders = headersAsync.maybeWhen(
      data: (h) => h,
      orElse: () {
        final baseUrl = _source?.baseUrl ?? widget.baseUrl ?? '';
        return ref.read(
          imageHeadersProvider(baseUrl.isNotEmpty ? baseUrl : null),
        );
      },
    );
    final coverMaxBytes = coverBytesAsync.asData?.value;
    final headers = resolvedHeaders;
    return ScreenBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: c.textPrimary,
          title: _searchActive
              ? TextField(
                  controller: _searchCtrl,
                  autofocus:
                      widget.initialQuery == null ||
                      widget.initialQuery!.trim().isEmpty,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: c.textSecondary),
                  ),
                  style: TextStyle(color: c.textPrimary),
                  onChanged: _onSearchChanged,
                  onSubmitted: (v) {
                    FocusScope.of(context).unfocus();
                    _performSearch(v);
                  },
                  textInputAction: TextInputAction.search,
                )
              : Text(widget.sourceName),
          actions: [
            if (_filtersLoaded && _filters.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterSheet,
              ),
            IconButton(
              icon: Icon(
                _tab == 'popular'
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
              ),
              onPressed: _booting ? null : _toggleSort,
              tooltip: _tab == 'popular' ? 'Sort: Popular' : 'Sort: Latest',
            ),
            IconButton(
              icon: Icon(_searchActive ? Icons.close : Icons.search),
              onPressed: _booting ? null : _toggleSearch,
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
        body: HorizontalTabSwipe(
          tabIndex: _tabCtrl.index,
          tabCount: 2,
          onTabChanged: (i) {
            if (_booting || _searchActive) return;
            _tabCtrl.animateTo(i);
          },
          child: _booting
              ? const Center(child: CircularProgressIndicator())
              : _searchActive
              ? _buildSearchBody(c, headers, coverMaxBytes)
              : _error != null && _mangas.isEmpty && !_loading
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: c.accent, fontSize: 13),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                )
              : _mangas.isEmpty && !_loading
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    const Center(child: Text('Nothing found')),
                  ],
                )
              : _catalogMangaBody(
                  mangas: _mangas,
                  headers: headers,
                  controller: _scrollCtrl,
                  hasNext: _hasNext && _error == null,
                  onRefresh: _refresh,
                  coverMaxBytes: coverMaxBytes,
                ),
        ),
      ),
    );
  }

  Widget _buildSearchBody(
    KomaColors c,
    Map<String, String> headers,
    int? coverMaxBytes,
  ) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final q = _searchQuery.trim();
    final filtersActive = _hasActiveFilterValues();
    // Filter-only searches (empty query) must still show results.
    if (q.isEmpty && !filtersActive && _searchResults.isEmpty) {
      return const Center(child: Text('Type to search or apply filters'));
    }
    if (_searchResults.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              _error != null
                  ? '$_error'
                  : q.isEmpty
                  ? 'No results for these filters'
                  : 'No results for "$q"',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary),
            ),
          ),
        ],
      );
    }
    return _catalogMangaBody(
      mangas: _searchResults,
      headers: headers,
      coverMaxBytes: coverMaxBytes,
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

  /// Tag groups rendered as a single TriState list: includeName → excludeName.
  late final Map<String, String?> _triTagPairs;

  /// Group names consumed by a paired TriState UI (skip when iterating).
  late final Set<String> _pairedGroupNames;

  @override
  void initState() {
    super.initState();
    _values = Map.from(widget.values);
    _triTagPairs = _discoverTagPairs(widget.filters);
    _pairedGroupNames = {
      for (final e in _triTagPairs.entries) ...[
        e.key,
        if (e.value != null) e.value!,
      ],
    };
  }

  /// Pair "Include …" / "Exclude …" CheckBox groups that share the same tags.
  Map<String, String?> _discoverTagPairs(List<Filter> filters) {
    final checkGroups = <Filter>[
      for (final f in filters)
        if (_isCheckOnlyGroup(f)) f,
    ];
    final include = <Filter>[];
    final exclude = <Filter>[];
    final other = <Filter>[];
    for (final g in checkGroups) {
      final n = g.name.toLowerCase();
      if (n.contains('include')) {
        include.add(g);
      } else if (n.contains('exclude')) {
        exclude.add(g);
      } else if (n.contains('tag') || n.contains('genre')) {
        other.add(g);
      }
    }

    final pairs = <String, String?>{};
    for (final inc in include) {
      Filter? match;
      for (final ex in exclude) {
        if (_sameTagNames(inc, ex)) {
          match = ex;
          break;
        }
      }
      pairs[inc.name] = match?.name;
      if (match != null) exclude.remove(match);
    }
    // Remaining exclude-only / genre CheckBox groups → TriState UI; Include
    // maps to unchecked exclude (source may not support positive include).
    for (final ex in exclude) {
      pairs[ex.name] = ex.name; // self-pair: exclude-only
    }
    for (final g in other) {
      pairs.putIfAbsent(g.name, () => g.name);
    }
    return pairs;
  }

  bool _isCheckOnlyGroup(Filter f) {
    if (f.type != FilterType.group) return false;
    final subs = f.subFilters ?? const <Filter>[];
    return subs.isNotEmpty && subs.every((s) => s.type == FilterType.check);
  }

  bool _sameTagNames(Filter a, Filter b) {
    final an = {...?a.subFilters?.map((s) => s.name)};
    final bn = {...?b.subFilters?.map((s) => s.name)};
    return an.isNotEmpty && an.length == bn.length && an.containsAll(bn);
  }

  Filter? _groupByName(String name) {
    for (final f in widget.filters) {
      if (f.name == name) return f;
    }
    return null;
  }

  int _triStateForTag({
    required String includeGroup,
    required String? excludeGroup,
    required String tagName,
  }) {
    final inc = _checkboxState(includeGroup, tagName);
    final exc = excludeGroup == null
        ? false
        : _checkboxState(excludeGroup, tagName);
    if (exc) return 2;
    if (inc && includeGroup != excludeGroup) return 1;
    // Exclude-only self-pair: checked means exclude.
    if (inc && includeGroup == excludeGroup) return 2;
    return 0;
  }

  bool _checkboxState(String groupName, String tagName) {
    final group = _groupByName(groupName);
    if (group == null) return false;
    final subs = _values[groupName] as List<Map<String, dynamic>>? ?? const [];
    final idx = group.subFilters?.indexWhere((s) => s.name == tagName) ?? -1;
    if (idx < 0 || idx >= subs.length) return false;
    return subs[idx][tagName] as bool? ?? false;
  }

  void _setTriStateForTag({
    required String includeGroup,
    required String? excludeGroup,
    required String tagName,
    required int state,
  }) {
    final includeOnly = includeGroup == excludeGroup;
    if (includeOnly) {
      // Exclude-only group: Ignore=off, Exclude=on. Include≈off (no include API).
      _setCheckbox(includeGroup, tagName, state == 2);
      return;
    }
    _setCheckbox(includeGroup, tagName, state == 1);
    if (excludeGroup != null) {
      _setCheckbox(excludeGroup, tagName, state == 2);
    }
  }

  void _setCheckbox(String groupName, String tagName, bool on) {
    final group = _groupByName(groupName);
    if (group == null) return;
    final subs = List<Map<String, dynamic>>.from(
      (_values[groupName] as List<Map<String, dynamic>>?) ?? const [],
    );
    final idx = group.subFilters?.indexWhere((s) => s.name == tagName) ?? -1;
    if (idx < 0) return;
    while (subs.length <= idx) {
      subs.add(<String, dynamic>{});
    }
    final map = Map<String, dynamic>.from(subs[idx]);
    map[tagName] = on;
    // Keep legacy key used by _initFilterValue (filter name as key).
    if (group.subFilters![idx].name == tagName) {
      map[group.subFilters![idx].name] = on;
    }
    // _initFilterValue stores under sf.name inside the sub map via recursive call
    // which uses values[f.name] = bool. So key is tag name.
    subs[idx] = {tagName: on};
    _values[groupName] = subs;
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
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onApply(_values);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                for (final f in widget.filters)
                  if (_triTagPairs.containsKey(f.name))
                    _buildTriTagGroup(f.name, _triTagPairs[f.name])
                  else if (!_pairedGroupNames.contains(f.name))
                    _buildFilterWidget(f, _values),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriTagGroup(String primaryName, String? excludeName) {
    final c = Theme.of(context).extension<KomaColors>()!;
    final primary = _groupByName(primaryName);
    if (primary == null) return const SizedBox.shrink();
    final excludeOnly = primaryName == excludeName;
    final title = excludeOnly
        ? primary.name
        : (primary.name.toLowerCase().contains('include')
              ? primary.name.replaceFirst(RegExp(r'include', caseSensitive: false), 'Tags')
              : 'Tags');
    final tags = primary.subFilters ?? const <Filter>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          title,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          excludeOnly
              ? 'Ignore / Exclude (this source has no include filter)'
              : 'Ignore / Include / Exclude',
          style: TextStyle(color: c.textTertiary, fontSize: 11),
        ),
        children: [
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag.name, style: TextStyle(color: c.textPrimary, fontSize: 13)),
                  const SizedBox(height: 4),
                  SegmentedButton<int>(
                    segments: [
                      const ButtonSegment(value: 0, label: Text('Ignore')),
                      if (!excludeOnly)
                        const ButtonSegment(value: 1, label: Text('Include')),
                      const ButtonSegment(value: 2, label: Text('Exclude')),
                    ],
                    selected: {
                      _triStateForTag(
                        includeGroup: primaryName,
                        excludeGroup: excludeName,
                        tagName: tag.name,
                      ),
                    },
                    onSelectionChanged: (s) => setState(() {
                      _setTriStateForTag(
                        includeGroup: primaryName,
                        excludeGroup: excludeName,
                        tagName: tag.name,
                        state: s.first,
                      );
                    }),
                  ),
                ],
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
          child: Text(
            f.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        );
      case FilterType.separator:
        return const Divider(height: 24);
      case FilterType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            decoration: InputDecoration(
              labelText: f.name,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            controller: TextEditingController(
              text: values[f.name] as String? ?? '',
            ),
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
              Text(
                f.name,
                style: TextStyle(fontSize: 14, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Ignore')),
                  ButtonSegment(value: 1, label: Text('Include')),
                  ButtonSegment(value: 2, label: Text('Exclude')),
                ],
                selected: {triValue},
                onSelectionChanged: (s) =>
                    setState(() => values[f.name] = s.first),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            initialValue: selIdx < opts.length ? selIdx : 0,
            items: opts
                .asMap()
                .entries
                .map(
                  (e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value.name)),
                )
                .toList(),
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
              Text(
                f.name,
                style: TextStyle(fontSize: 14, color: c.textPrimary),
              ),
              ...opts.asMap().entries.map(
                (e) => RadioListTile<int>(
                  title: Text(
                    e.value.name,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                  value: e.key,
                  groupValue: selIdx,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        values[f.name] = {'index': v, 'ascending': ascending};
                      });
                    }
                  },
                  dense: true,
                ),
              ),
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
        final subValuesList =
            (values[f.name] as List<Map<String, dynamic>>?) ?? [];
        // Ensure list length matches for nested edits.
        while (subValuesList.length < (f.subFilters?.length ?? 0)) {
          subValuesList.add(<String, dynamic>{});
        }
        values[f.name] = subValuesList;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            title: Text(f.name, style: TextStyle(color: c.textPrimary)),
            children: (f.subFilters ?? []).asMap().entries.map((e) {
              final sf = e.value;
              final sv = subValuesList[e.key];
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
