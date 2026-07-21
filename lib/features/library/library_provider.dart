import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  final Set<String> _selectedIds = {};
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
  Set<String> get selectedIds => _selectedIds;
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
    _selectedIds.remove('b:$id');
    await loadBooks();
  }

  Future<void> deleteManga(int id) async {
    final manga = _mangas.firstWhereOrNull((m) => m.id == id);
    if (manga != null) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final mangaKey = sha256.convert(utf8.encode(manga.url)).toString().substring(0, 16);
        final mangaDir = Directory('${supportDir.path}/manga/${manga.sourceId}/$mangaKey');
        if (await mangaDir.exists()) {
          await mangaDir.delete(recursive: true);
        }
        final docsDir = await getApplicationDocumentsDirectory();
        final thumbHash = sha256.convert(utf8.encode(manga.imageUrl ?? '')).toString();
        final thumbFile = File('${docsDir.path}/thumbnails/$thumbHash.jpg');
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (_) {
        // ignore cleanup failures
      }
    }
    await _db.deleteMangaChapters(id);
    await _db.deleteManga(id);
    _selectedIds.remove('m:$id');
    await loadBooks();
  }

  void toggleSelection(String key) {
    if (_selectedIds.contains(key)) {
      _selectedIds.remove(key);
      if (_selectedIds.isEmpty) _selectionMode = false;
    } else {
      _selectedIds.add(key);
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
    if (_selectedIds.length == _books.length + _mangas.length && _books.length + _mangas.length > 0) {
      clearSelection();
      return;
    }
    for (final book in _books) {
      _selectedIds.add('b:${book.id}');
    }
    for (final manga in _mangas) {
      _selectedIds.add('m:${manga.id}');
    }
    _selectionMode = true;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    for (final key in _selectedIds.toList()) {
      if (key.startsWith('b:')) {
        final id = int.parse(key.substring(2));
        await _db.deleteBook(id);
      } else if (key.startsWith('m:')) {
        final id = int.parse(key.substring(2));
        final manga = _mangas.firstWhereOrNull((m) => m.id == id);
        if (manga != null) {
          try {
            final supportDir = await getApplicationSupportDirectory();
            final mangaKey = sha256.convert(utf8.encode(manga.url)).toString().substring(0, 16);
            final mangaDir = Directory('${supportDir.path}/manga/${manga.sourceId}/$mangaKey');
            if (await mangaDir.exists()) {
              await mangaDir.delete(recursive: true);
            }
            final docsDir = await getApplicationDocumentsDirectory();
            final thumbHash = sha256.convert(utf8.encode(manga.imageUrl ?? '')).toString();
            final thumbFile = File('${docsDir.path}/thumbnails/$thumbHash.jpg');
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          } catch (_) {
            // ignore cleanup failures
          }
          await _db.deleteMangaChapters(id);
          await _db.deleteManga(id);
        }
      }
    }
    _selectedIds.clear();
    _selectionMode = false;
    await loadBooks();
  }
}
