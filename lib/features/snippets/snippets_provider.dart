import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../core/models/snippet.dart';
import '../../core/models/snippet_collection.dart';
import '../../core/services/database_service.dart';
import '../../core/services/stats_service.dart';

class SnippetsProvider extends ChangeNotifier {
  final DatabaseService _db;
  final StatsService _statsService;

  List<Snippet> _snippets = [];
  List<String> _allTags = [];
  List<SnippetCollection> _collections = [];
  String? _filterTag;
  int? _filterCollectionId;
  bool _loading = true;
  String? _error;
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  SnippetsProvider(this._db, this._statsService);

  List<Snippet> get snippets {
    var items = _snippets;
    if (_filterCollectionId == null) {
      items = items.where((s) => s.collectionId == null).toList();
    } else if (_filterCollectionId == -1) {
      // -1 means show all, collected + uncollected
    } else {
      items = items.where((s) => s.collectionId == _filterCollectionId).toList();
    }
    if (_filterTag == null) return items;
    final tag = _filterTag;
    return items.where((s) => s.tags.contains(tag)).toList();
  }

  List<String> get allTags => _allTags;
  List<SnippetCollection> get collections => _collections;
  String? get filterTag => _filterTag;
  int? get filterCollectionId => _filterCollectionId;
  bool get loading => _loading;
  String? get error => _error;
  Set<int> get selectedIds => _selectedIds;
  bool get selectionMode => _selectionMode;

  Future<void> loadSnippets() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _snippets = await _db.getSnippets();
      _allTags = await _db.getAllTags();
      _collections = await _db.getCollections();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  void setFilterTag(String? tag) {
    _filterTag = tag;
    notifyListeners();
  }

  void setFilterCollection(int? collectionId) {
    _filterCollectionId = collectionId;
    notifyListeners();
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
    List<String> tags = const [],
  }) async {
    final id = await _db.createSnippet(
      text: text,
      note: note,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
      color: color,
      bookId: bookId,
      chapterId: chapterId,
      collectionId: collectionId,
      tags: tags,
    );
    await _statsService.trackSnippet();
    await loadSnippets();
    return id;
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await _db.updateSnippet(snippet);
    await loadSnippets();
  }

  Future<void> deleteSnippet(int id) async {
    await _db.deleteSnippet(id);
    await loadSnippets();
  }

  Future<int> createCollection(String name, {String color = '#FFD700'}) async {
    final id = await _db.createCollection(name, color: color);
    await loadSnippets();
    return id;
  }

  Future<void> updateCollection(SnippetCollection collection) async {
    await _db.updateCollection(collection);
    await loadSnippets();
  }

  Future<void> deleteCollection(int id) async {
    await _db.deleteCollection(id);
    if (_filterCollectionId == id) _filterCollectionId = null;
    await loadSnippets();
  }

  Future<void> moveSnippetsToCollection(List<int> snippetIds, int? collectionId) async {
    for (final id in snippetIds) {
      final snippet = _snippets.firstWhereOrNull((s) => s.id == id);
      if (snippet != null) {
        await _db.updateSnippet(snippet.copyWith(collectionId: collectionId));
      }
    }
    await loadSnippets();
  }

  void toggleSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    } else {
      _selectedIds.add(id);
      _selectionMode = true;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
  }

  void selectAll() {
    if (_selectedIds.length == _snippets.length && _snippets.isNotEmpty) {
      clearSelection();
      return;
    }
    _selectedIds.clear();
    for (final s in _snippets) {
      _selectedIds.add(s.id);
    }
    _selectionMode = true;
    notifyListeners();
  }

  void inverseSelection() {
    if (_snippets.isEmpty) return;
    final selectedSet = _selectedIds.toSet();
    final allIds = _snippets.map((s) => s.id).toSet();
    _selectedIds.clear();
    for (final id in allIds) {
      if (!selectedSet.contains(id)) _selectedIds.add(id);
    }
    _selectionMode = _selectedIds.isNotEmpty;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await _db.deleteSelectedSnippets(_selectedIds.toList());
    _selectedIds.clear();
    _selectionMode = false;
    await loadSnippets();
  }
}
