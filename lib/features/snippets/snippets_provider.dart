import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_collection.dart';
import '../../core/providers.dart';

/// Immutable state for the snippets screen.
class SnippetsState {
  const SnippetsState({
    this.allSnippets = const [],
    this.allTags = const [],
    this.collections = const [],
    this.filterTag,
    this.filterCollectionId,
    this.loading = true,
    this.error,
    this.selectedIds = const {},
    this.selectionMode = false,
  });

  final List<Snippet> allSnippets;
  final List<String> allTags;
  final List<SnippetCollection> collections;
  final String? filterTag;
  final int? filterCollectionId;
  final bool loading;
  final String? error;
  final Set<int> selectedIds;
  final bool selectionMode;

  /// Filtered view of snippets based on current collection + tag filters.
  List<Snippet> get snippets {
    var items = allSnippets;
    if (filterCollectionId == null) {
      items = items.where((s) => s.collectionId == null).toList();
    } else if (filterCollectionId == -1) {
      // -1 means show all
    } else {
      items =
          items.where((s) => s.collectionId == filterCollectionId).toList();
    }
    if (filterTag == null) return items;
    final tag = filterTag;
    return items.where((s) => s.tags.contains(tag)).toList();
  }

  SnippetsState copyWith({
    List<Snippet>? allSnippets,
    List<String>? allTags,
    List<SnippetCollection>? collections,
    String? Function()? filterTag,
    int? Function()? filterCollectionId,
    bool? loading,
    String? Function()? error,
    Set<int>? selectedIds,
    bool? selectionMode,
  }) {
    return SnippetsState(
      allSnippets: allSnippets ?? this.allSnippets,
      allTags: allTags ?? this.allTags,
      collections: collections ?? this.collections,
      filterTag: filterTag != null ? filterTag() : this.filterTag,
      filterCollectionId: filterCollectionId != null
          ? filterCollectionId()
          : this.filterCollectionId,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
      selectedIds: selectedIds ?? this.selectedIds,
      selectionMode: selectionMode ?? this.selectionMode,
    );
  }
}

class SnippetsNotifier extends Notifier<SnippetsState> {
  @override
  SnippetsState build() => const SnippetsState();

  Future<void> loadSnippets() async {
    state = state.copyWith(loading: true, error: () => null);
    final repos = ref.read(repositoriesProvider);
    try {
      final snippets = await repos.snippets.getSnippets();
      final tags = await repos.snippets.getAllTags();
      final collections = await repos.snippets.getCollections();
      state = state.copyWith(
        allSnippets: snippets,
        allTags: tags,
        collections: collections,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), loading: false);
    }
  }

  void setFilterTag(String? tag) {
    state = state.copyWith(filterTag: () => tag);
  }

  void setFilterCollection(int? collectionId) {
    state = state.copyWith(filterCollectionId: () => collectionId);
  }

  Future<int> createSnippet({
    required String text,
    String? note,
    String? sourceTitle,
    String? sourceUrl,
    String? color,
    int? bookId,
    int? chapterId,
    int? collectionId,
    int? startOffset,
    int? endOffset,
    double? scrollPosition,
    List<String> tags = const [],
  }) async {
    final repos = ref.read(repositoriesProvider);
    final id = await repos.snippets.createSnippet(
      text: text,
      note: note,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
      color: color,
      bookId: bookId,
      chapterId: chapterId,
      collectionId: collectionId,
      startOffset: startOffset,
      endOffset: endOffset,
      scrollPosition: scrollPosition,
      tags: tags,
    );
    await ref.read(statsServiceProvider).trackSnippet();
    await loadSnippets();
    return id;
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await ref.read(repositoriesProvider).snippets.updateSnippet(snippet);
    await loadSnippets();
  }

  Future<void> deleteSnippet(int id) async {
    await ref.read(repositoriesProvider).snippets.deleteSnippet(id);
    await loadSnippets();
  }

  Future<int> createCollection(String name, {String color = '#FFD700'}) async {
    final id = await ref
        .read(repositoriesProvider)
        .snippets.createCollection(name, color: color);
    await loadSnippets();
    return id;
  }

  Future<void> updateCollection(SnippetCollection collection) async {
    await ref.read(repositoriesProvider).snippets.updateCollection(collection);
    await loadSnippets();
  }

  Future<void> deleteCollection(int id) async {
    await ref.read(repositoriesProvider).snippets.deleteCollection(id);
    if (state.filterCollectionId == id) {
      state = state.copyWith(filterCollectionId: () => null);
    }
    await loadSnippets();
  }

  Future<void> moveSnippetsToCollection(
      List<int> snippetIds, int? collectionId) async {
      final repos = ref.read(repositoriesProvider);
      for (final id in snippetIds) {
        final snippet =
            state.allSnippets.firstWhereOrNull((s) => s.id == id);
        if (snippet != null) {
          await repos.snippets.updateSnippet(
            snippet.copyWith(collectionId: collectionId));
      }
    }
    await loadSnippets();
  }

  void toggleSelection(int id) {
    final ids = Set<int>.from(state.selectedIds);
    bool mode = state.selectionMode;
    if (ids.contains(id)) {
      ids.remove(id);
      if (ids.isEmpty) mode = false;
    } else {
      ids.add(id);
      mode = true;
    }
    state = state.copyWith(selectedIds: ids, selectionMode: mode);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {}, selectionMode: false);
  }

  void selectAll() {
    final filtered = state.snippets;
    if (state.selectedIds.length == filtered.length && filtered.isNotEmpty) {
      clearSelection();
      return;
    }
    final ids = <int>{};
    for (final s in filtered) {
      ids.add(s.id);
    }
    state = state.copyWith(selectedIds: ids, selectionMode: true);
  }

  void inverseSelection() {
    final filtered = state.snippets;
    if (filtered.isEmpty) return;
    final current = state.selectedIds;
    final allIds = filtered.map((s) => s.id).toSet();
    final inverted = <int>{};
    for (final id in allIds) {
      if (!current.contains(id)) inverted.add(id);
    }
    state = state.copyWith(
      selectedIds: inverted,
      selectionMode: inverted.isNotEmpty,
    );
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) return;
    await ref
        .read(repositoriesProvider)
        .snippets.deleteSelectedSnippets(state.selectedIds.toList());
    state = state.copyWith(selectedIds: {}, selectionMode: false);
    await loadSnippets();
  }
}
