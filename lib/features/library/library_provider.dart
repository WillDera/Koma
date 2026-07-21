import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/book.dart';
import '../../core/models/manga.dart';
import '../../core/services/database_service.dart';

class LibraryProvider extends ChangeNotifier {
  static const _keyIsGridView = 'library_is_grid_view';

  final DatabaseService _db;
  List<Book> _books = [];
  List<Manga> _mangas = [];
  bool _loading = true;
  String? _error;
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;
  bool _isGridView = false;

  LibraryProvider(this._db);

  bool get isGridView => _isGridView;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isGridView = prefs.getBool(_keyIsGridView) ?? false;
    notifyListeners();
  }

  void toggleLayout() {
    _isGridView = !_isGridView;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_keyIsGridView, _isGridView),
    );
  }

  List<Book> get books => _books;
  List<Manga> get mangas => _mangas;
  bool get loading => _loading;
  String? get error => _error;
  Set<int> get selectedIds => _selectedIds;
  bool get selectionMode => _selectionMode;

  Future<void> loadBooks() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _books = await _db.getBooks();
      _mangas = await _db.getMangasInLibrary();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<int> addBook(Book book) async {
    final id = await _db.insertBook(book);
    await loadBooks();
    return id;
  }

  Future<void> deleteBook(int id) async {
    await _db.deleteBook(id);
    _selectedIds.remove(id);
    await loadBooks();
  }

  Future<void> deleteManga(int id) async {
    await _db.deleteManga(id);
    _selectedIds.remove(id);
    await loadBooks();
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

  Future<void> deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    for (final id in _selectedIds.toList()) {
      await _db.deleteBook(id);
      await _db.deleteManga(id);
    }
    _selectedIds.clear();
    _selectionMode = false;
    await loadBooks();
  }
}
