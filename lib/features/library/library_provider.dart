import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/book.dart';
import '../../core/models/manga.dart';
import '../../core/providers.dart';

/// Immutable state for the library screen.
class LibraryState {
  const LibraryState({
    this.books = const [],
    this.mangas = const [],
    this.loading = true,
    this.error,
    this.selectedIds = const {},
    this.selectionMode = false,
    this.isGridView = false,
    this.showSourcePills = true,
    this.extensionNames = const {},
  });

  final List<Book> books;
  final List<Manga> mangas;
  final bool loading;
  final String? error;
  final Set<String> selectedIds;
  final bool selectionMode;
  final bool isGridView;
  final bool showSourcePills;
  final Map<String, String> extensionNames;

  LibraryState copyWith({
    List<Book>? books,
    List<Manga>? mangas,
    bool? loading,
    String? Function()? error,
    Set<String>? selectedIds,
    bool? selectionMode,
    bool? isGridView,
    bool? showSourcePills,
    Map<String, String>? extensionNames,
  }) {
    return LibraryState(
      books: books ?? this.books,
      mangas: mangas ?? this.mangas,
      loading: loading ?? this.loading,
      error: error != null ? error() : this.error,
      selectedIds: selectedIds ?? this.selectedIds,
      selectionMode: selectionMode ?? this.selectionMode,
      isGridView: isGridView ?? this.isGridView,
      showSourcePills: showSourcePills ?? this.showSourcePills,
      extensionNames: extensionNames ?? this.extensionNames,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  static const _keyIsGridView = 'library_is_grid_view';
  static const _keyShowSourcePills = 'library_show_source_pills';

  @override
  LibraryState build() => const LibraryState();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isGridView: prefs.getBool(_keyIsGridView) ?? false,
      showSourcePills: prefs.getBool(_keyShowSourcePills) ?? true,
    );
  }

  void toggleLayout() {
    final next = !state.isGridView;
    state = state.copyWith(isGridView: next);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_keyIsGridView, next),
    );
  }

  void setShowSourcePills(bool value) {
    state = state.copyWith(showSourcePills: value);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_keyShowSourcePills, value),
    );
  }

  Future<void> loadBooks() async {
    state = state.copyWith(loading: true, error: () => null);
    final repos = ref.read(repositoriesProvider);
    try {
      final books = await repos.books.getBooks();
      final mangas = await repos.manga.getMangasInLibrary();
      final extNames = <String, String>{};
      final extensions = await repos.extensions.getInstalledExtensions();
      for (final ext in extensions) {
        extNames[ext.id] = ext.name;
      }
      state = state.copyWith(
        books: books,
        mangas: mangas,
        extensionNames: extNames,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: () => e.toString(), loading: false);
    }
  }

  Future<int> addBook(Book book) async {
    final repos = ref.read(repositoriesProvider);
    final id = await repos.books.insertBook(book);
    await loadBooks();
    return id;
  }

  Future<void> deleteBook(int id) async {
    final repos = ref.read(repositoriesProvider);
    await repos.books.deleteBook(id);
    final ids = Set<String>.from(state.selectedIds)..remove('b:$id');
    state = state.copyWith(selectedIds: ids);
    await loadBooks();
  }

  Future<void> deleteManga(int id) async {
    final repos = ref.read(repositoriesProvider);
    final manga = state.mangas.firstWhereOrNull((m) => m.id == id);
    if (manga != null) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final mangaKey = sha256
            .convert(utf8.encode(manga.url))
            .toString()
            .substring(0, 16);
        final mangaDir = Directory(
            '${supportDir.path}/manga/${manga.sourceId}/$mangaKey');
        if (await mangaDir.exists()) {
          await mangaDir.delete(recursive: true);
        }
        final docsDir = await getApplicationDocumentsDirectory();
        final thumbHash =
            sha256.convert(utf8.encode(manga.imageUrl ?? '')).toString();
        final thumbFile =
            File('${docsDir.path}/thumbnails/$thumbHash.jpg');
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (_) {}
    }
      await repos.manga.deleteMangaChapters(id);
      await repos.manga.deleteManga(id);
      final ids = Set<String>.from(state.selectedIds)..remove('m:$id');
      state = state.copyWith(selectedIds: ids);
      await loadBooks();
  }

  void toggleSelection(String key) {
    final ids = Set<String>.from(state.selectedIds);
    bool mode = state.selectionMode;
    if (ids.contains(key)) {
      ids.remove(key);
      if (ids.isEmpty) mode = false;
    } else {
      ids.add(key);
      mode = true;
    }
    state = state.copyWith(selectedIds: ids, selectionMode: mode);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {}, selectionMode: false);
  }

  void selectAll() {
    if (state.selectedIds.length ==
            state.books.length + state.mangas.length &&
        state.books.length + state.mangas.length > 0) {
      clearSelection();
      return;
    }
    final ids = <String>{};
    for (final book in state.books) {
      ids.add('b:${book.id}');
    }
    for (final manga in state.mangas) {
      ids.add('m:${manga.id}');
    }
    state = state.copyWith(selectedIds: ids, selectionMode: true);
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) return;
    final repos = ref.read(repositoriesProvider);
    for (final key in state.selectedIds.toList()) {
      if (key.startsWith('b:')) {
        final id = int.parse(key.substring(2));
        await repos.books.deleteBook(id);
      } else if (key.startsWith('m:')) {
        final id = int.parse(key.substring(2));
        final manga =
            state.mangas.firstWhereOrNull((m) => m.id == id);
        if (manga != null) {
          try {
            final supportDir = await getApplicationSupportDirectory();
            final mangaKey = sha256
                .convert(utf8.encode(manga.url))
                .toString()
                .substring(0, 16);
            final mangaDir = Directory(
                '${supportDir.path}/manga/${manga.sourceId}/$mangaKey');
            if (await mangaDir.exists()) {
              await mangaDir.delete(recursive: true);
            }
            final docsDir = await getApplicationDocumentsDirectory();
            final thumbHash = sha256
                .convert(utf8.encode(manga.imageUrl ?? ''))
                .toString();
            final thumbFile =
                File('${docsDir.path}/thumbnails/$thumbHash.jpg');
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
            } catch (_) {}
            await repos.manga.deleteMangaChapters(id);
            await repos.manga.deleteManga(id);
          }
        }
    }
    state = state.copyWith(selectedIds: {}, selectionMode: false);
    await loadBooks();
  }
}
