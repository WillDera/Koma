import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_source.dart';
import '../../core/providers.dart';

/// Mihon Global Search source filter chips (Pinned / All).
enum GlobalSearchSourceFilter { pinned, all }

enum GlobalSearchItemKind { loading, success, error }

class GlobalSearchSourceItem {
  const GlobalSearchSourceItem({
    required this.source,
    required this.kind,
    this.mangas = const [],
    this.error,
  });

  final ExtensionSource source;
  final GlobalSearchItemKind kind;
  final List<Map<String, dynamic>> mangas;
  final String? error;

  GlobalSearchSourceItem copyWith({
    GlobalSearchItemKind? kind,
    List<Map<String, dynamic>>? mangas,
    String? Function()? error,
  }) {
    return GlobalSearchSourceItem(
      source: source,
      kind: kind ?? this.kind,
      mangas: mangas ?? this.mangas,
      error: error != null ? error() : this.error,
    );
  }
}

class GlobalSearchState {
  const GlobalSearchState({
    this.query = '',
    this.filter = GlobalSearchSourceFilter.all,
    this.onlyShowHasResults = false,
    this.items = const [],
    this.searching = false,
    this.progress = 0,
    this.total = 0,
  });

  final String query;
  final GlobalSearchSourceFilter filter;
  final bool onlyShowHasResults;
  final List<GlobalSearchSourceItem> items;
  final bool searching;
  final int progress;
  final int total;

  List<GlobalSearchSourceItem> get visibleItems {
    if (!onlyShowHasResults) return items;
    return items
        .where(
          (i) =>
              i.kind == GlobalSearchItemKind.loading ||
              (i.kind == GlobalSearchItemKind.success && i.mangas.isNotEmpty),
        )
        .toList(growable: false);
  }

  /// Total manga hits across successful sources (for Discover counts).
  int get mangaHitCount => items
      .where((i) => i.kind == GlobalSearchItemKind.success)
      .fold<int>(0, (sum, i) => sum + i.mangas.length);

  GlobalSearchState copyWith({
    String? query,
    GlobalSearchSourceFilter? filter,
    bool? onlyShowHasResults,
    List<GlobalSearchSourceItem>? items,
    bool? searching,
    int? progress,
    int? total,
  }) {
    return GlobalSearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      onlyShowHasResults: onlyShowHasResults ?? this.onlyShowHasResults,
      items: items ?? this.items,
      searching: searching ?? this.searching,
      progress: progress ?? this.progress,
      total: total ?? this.total,
    );
  }
}

/// Catalogue Global Search — Mihon [SearchViewModel] / [GlobalSearchViewModel]
/// parity: bounded fan-out of `getSearchManga(page=1)`, pinned/all filter,
/// Has-results chip, cancel on new query.
class GlobalSearchNotifier extends Notifier<GlobalSearchState> {
  static const _concurrency = 5;

  int _generation = 0;

  @override
  GlobalSearchState build() => const GlobalSearchState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  Future<void> setFilter(GlobalSearchSourceFilter filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter);
    if (state.query.trim().isNotEmpty) {
      await search();
    }
  }

  void toggleOnlyHasResults() {
    state = state.copyWith(onlyShowHasResults: !state.onlyShowHasResults);
  }

  Future<void> search([String? overrideQuery]) async {
    final query = (overrideQuery ?? state.query).trim();
    if (overrideQuery != null) {
      state = state.copyWith(query: overrideQuery);
    }
    if (query.isEmpty) {
      _generation++;
      state = state.copyWith(
        searching: false,
        items: const [],
        progress: 0,
        total: 0,
      );
      return;
    }

    final gen = ++_generation;
    final sources = await _selectedSources();
    if (gen != _generation) return;

    state = state.copyWith(
      searching: true,
      progress: 0,
      total: sources.length,
      items: [
        for (final s in sources)
          GlobalSearchSourceItem(source: s, kind: GlobalSearchItemKind.loading),
      ],
    );

    if (sources.isEmpty) {
      state = state.copyWith(searching: false);
      return;
    }

    final keiyoushi = ref.read(keiyoushiServiceProvider);
    var completed = 0;

    Future<void> runOne(int index) async {
      final src = sources[index];
      try {
        final page = await keiyoushi.searchManga(
          sourceId: src.sourceId,
          query: query,
          page: 1,
        );
        if (gen != _generation) return;
        _updateItem(
          src.sourceId,
          GlobalSearchSourceItem(
            source: src,
            kind: GlobalSearchItemKind.success,
            mangas: page.mangas,
          ),
        );
      } catch (e) {
        if (gen != _generation) return;
        _updateItem(
          src.sourceId,
          GlobalSearchSourceItem(
            source: src,
            kind: GlobalSearchItemKind.error,
            error: '$e',
          ),
        );
      } finally {
        if (gen == _generation) {
          completed++;
          state = state.copyWith(
            progress: completed,
            searching: completed < sources.length,
          );
        }
      }
    }

    // Bounded pool (Mihon: FixedThreadPool of 5).
    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (gen != _generation) return;
        final i = next++;
        if (i >= sources.length) return;
        await runOne(i);
      }
    }

    final workers = List.generate(
      _concurrency.clamp(1, sources.length),
      (_) => worker(),
    );
    await Future.wait(workers);
    if (gen == _generation) {
      state = state.copyWith(searching: false, progress: sources.length);
    }
  }

  void _updateItem(String sourceId, GlobalSearchSourceItem next) {
    final items = [
      for (final item in state.items)
        if (item.source.sourceId == sourceId) next else item,
    ];
    state = state.copyWith(items: items);
  }

  Future<List<ExtensionSource>> _selectedSources() async {
    final repos = ref.read(repositoriesProvider);
    final all = await repos.extensions.getInstalledExtensions();
    var sources = all
        .where((s) => s.isInstalled && s.isActive && !s.isObsolete)
        .toList();
    if (state.filter == GlobalSearchSourceFilter.pinned) {
      sources = sources.where((s) => s.isPinned).toList();
    }
    sources.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.lang.compareTo(b.lang);
    });
    return sources;
  }
}

final globalSearchProvider =
    NotifierProvider.autoDispose<GlobalSearchNotifier, GlobalSearchState>(
      GlobalSearchNotifier.new,
    );
