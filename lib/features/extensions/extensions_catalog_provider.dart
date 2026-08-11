import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/extension_repo.dart';
import '../../core/models/extension_source.dart';
import '../../core/providers.dart';
import '../../core/services/extension_manager.dart';

String extractPkgFromApkPath(String apkPath) {
  final fileName = apkPath.split('/').last;
  if (fileName.endsWith('.apk')) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

Set<String> installedPkgsOf(List<ExtensionSource> installed) {
  final set = <String>{};
  for (final s in installed) {
    final pkg = extractPkgFromApkPath(s.apkPath);
    if (pkg.isNotEmpty) set.add(pkg);
    if (s.isJs || s.isDart) {
      if (s.sourceId.isNotEmpty) set.add(s.sourceId);
      if (s.id.isNotEmpty) set.add(s.id);
    }
  }
  return set;
}

/// Session-scoped Extensions hub state (Loaded / Available indexes).
///
/// Survives leaving and re-entering [ExtensionsScreen] so catalogues do not
/// flash empty / reload from scratch. Background refresh still runs.
class ExtensionsCatalogState {
  final List<ExtensionRepo> repos;
  final List<ExtensionSource> installed;
  final Map<int, List<ExtensionIndexEntry>> fullIndexCache;
  final Map<int, List<ExtensionIndexEntry>> indexCache;
  final Set<int> loadingIndex;
  final bool bootstrapped;
  final bool refreshing;
  final String? error;

  const ExtensionsCatalogState({
    this.repos = const [],
    this.installed = const [],
    this.fullIndexCache = const {},
    this.indexCache = const {},
    this.loadingIndex = const {},
    this.bootstrapped = false,
    this.refreshing = false,
    this.error,
  });

  bool get hasAnyFetched => indexCache.isNotEmpty || fullIndexCache.isNotEmpty;

  ExtensionsCatalogState copyWith({
    List<ExtensionRepo>? repos,
    List<ExtensionSource>? installed,
    Map<int, List<ExtensionIndexEntry>>? fullIndexCache,
    Map<int, List<ExtensionIndexEntry>>? indexCache,
    Set<int>? loadingIndex,
    bool? bootstrapped,
    bool? refreshing,
    Object? error = _unset,
  }) {
    return ExtensionsCatalogState(
      repos: repos ?? this.repos,
      installed: installed ?? this.installed,
      fullIndexCache: fullIndexCache ?? this.fullIndexCache,
      indexCache: indexCache ?? this.indexCache,
      loadingIndex: loadingIndex ?? this.loadingIndex,
      bootstrapped: bootstrapped ?? this.bootstrapped,
      refreshing: refreshing ?? this.refreshing,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class ExtensionsCatalogNotifier extends Notifier<ExtensionsCatalogState> {
  late final ExtensionManager _mgr;
  Future<void>? _bootstrapFuture;

  @override
  ExtensionsCatalogState build() {
    _mgr = ExtensionManager(
      ref.watch(repositoriesProvider),
      ref.watch(keiyoushiServiceProvider),
    );
    Future.microtask(ensureBootstrapped);
    return const ExtensionsCatalogState();
  }

  ExtensionManager get manager => _mgr;

  /// Cold open or re-enter: load installed immediately; fetch missing indexes.
  Future<void> ensureBootstrapped() {
    return _bootstrapFuture ??= _bootstrap();
  }

  Future<void> _bootstrap() async {
    state = state.copyWith(refreshing: true);
    try {
      try {
        await _mgr.reconcileTrust();
      } catch (_) {}
      final repos = await _mgr.listRepos();
      final installed = await _mgr.listInstalled();
      state = state.copyWith(
        repos: repos,
        installed: installed,
        bootstrapped: true,
        refreshing: false,
        error: null,
      );
      unawaited(ref.read(extensionUpdateCountProvider.notifier).refresh());
      unawaited(_mgr.refreshIconCache());
      // Background-fetch every repo that has no cached index yet.
      unawaited(fetchMissingIndexes());
    } catch (e) {
      state = state.copyWith(
        bootstrapped: true,
        refreshing: false,
        error: '$e',
      );
    }
  }

  /// Soft refresh installed list without wiping available indexes.
  Future<void> refreshInstalled() async {
    try {
      try {
        await _mgr.reconcileTrust();
      } catch (_) {}
      final repos = await _mgr.listRepos();
      final installed = await _mgr.listInstalled();
      final pkgs = installedPkgsOf(installed);
      final nextIndex = <int, List<ExtensionIndexEntry>>{
        for (final e in state.fullIndexCache.entries)
          e.key: e.value
              .where((x) => !pkgs.contains(x.pkg))
              .toList(growable: false),
      };
      state = state.copyWith(
        repos: repos,
        installed: installed,
        indexCache: nextIndex,
        error: null,
      );
      unawaited(ref.read(extensionUpdateCountProvider.notifier).refresh());
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> removeRepo(int repoId) async {
    await _mgr.removeRepo(repoId);
    final full = Map<int, List<ExtensionIndexEntry>>.from(state.fullIndexCache)
      ..remove(repoId);
    final avail = Map<int, List<ExtensionIndexEntry>>.from(state.indexCache)
      ..remove(repoId);
    state = state.copyWith(fullIndexCache: full, indexCache: avail);
    await refreshInstalled();
  }

  Future<void> fetchIndex(ExtensionRepo repo) async {
    if (state.loadingIndex.contains(repo.id)) return;
    state = state.copyWith(
      loadingIndex: {...state.loadingIndex, repo.id},
    );
    try {
      final entries = await _mgr.fetchIndex(repo);
      await _mgr.checkForObsoleteSources(entries, repo.url);
      await _mgr.checkForUpdates(entries, repo.url);
      final installed = await _mgr.listInstalled();
      final pkgs = installedPkgsOf(installed);
      final full = Map<int, List<ExtensionIndexEntry>>.from(
        state.fullIndexCache,
      )..[repo.id] = entries;
      final avail = Map<int, List<ExtensionIndexEntry>>.from(state.indexCache)
        ..[repo.id] = entries
            .where((e) => !pkgs.contains(e.pkg))
            .toList(growable: false);
      state = state.copyWith(
        fullIndexCache: full,
        indexCache: avail,
        installed: installed,
        error: null,
      );
      unawaited(ref.read(extensionUpdateCountProvider.notifier).refresh());
    } catch (e) {
      state = state.copyWith(error: '$e');
    } finally {
      final loading = Set<int>.from(state.loadingIndex)..remove(repo.id);
      state = state.copyWith(loadingIndex: loading);
    }
  }

  Future<void> fetchMissingIndexes() async {
    for (final repo in state.repos) {
      if (state.fullIndexCache.containsKey(repo.id)) continue;
      await fetchIndex(repo);
    }
  }

  Future<void> fetchAllIndexes() async {
    for (final repo in state.repos) {
      await fetchIndex(repo);
    }
  }
}

final extensionsCatalogProvider =
    NotifierProvider<ExtensionsCatalogNotifier, ExtensionsCatalogState>(
      ExtensionsCatalogNotifier.new,
    );
