import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/bookmark.dart';
import '../../core/providers.dart';
import '../../core/repositories/bookmark_repository.dart';

class BookmarksState {
  final List<Bookmark> bookmarks;
  final int? filterBookId;
  final bool loading;

  const BookmarksState({
    this.bookmarks = const [],
    this.filterBookId,
    this.loading = true,
  });

  BookmarksState copyWith({
    List<Bookmark>? bookmarks,
    int? filterBookId,
    bool? loading,
  }) {
    return BookmarksState(
      bookmarks: bookmarks ?? this.bookmarks,
      filterBookId: filterBookId ?? this.filterBookId,
      loading: loading ?? this.loading,
    );
  }
}

class BookmarksNotifier extends Notifier<BookmarksState> {
  @override
  BookmarksState build() => const BookmarksState();

  BookmarkRepository get _repos => ref.read(repositoriesProvider).bookmarks;

  Future<void> loadBookmarks({int? bookId}) async {
    state = state.copyWith(loading: true);
    try {
      final List<Bookmark> bookmarks;
      if (bookId != null) {
        bookmarks = await _repos.getBookmarksForBook(bookId);
      } else {
        bookmarks = await _repos.getAllBookmarks();
      }
      state = state.copyWith(bookmarks: bookmarks, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }

  Future<bool> isBookmarked(
    int bookId,
    int chapterId,
    int? pageNumber, {
    double? scrollPosition,
  }) async {
    return _repos.isBookmarked(
      bookId,
      chapterId,
      pageNumber,
      scrollPosition: scrollPosition,
    );
  }

  Future<void> toggleBookmark({
    required int bookId,
    required int chapterId,
    int? pageNumber,
    double? scrollPosition,
  }) async {
    final existing = await _repos.getBookmark(
      bookId,
      chapterId,
      pageNumber,
      scrollPosition: scrollPosition,
    );
    if (existing != null) {
      await _repos.deleteBookmark(existing.id);
    } else {
      await _repos.createBookmark(
        bookId: bookId,
        chapterId: chapterId,
        pageNumber: pageNumber,
        scrollPosition: scrollPosition,
      );
    }
    await loadBookmarks(bookId: bookId);
  }

  Future<void> deleteBookmark(int id) async {
    await _repos.deleteBookmark(id);
    // Reload whichever scope is active: if the current state was loaded for a
    // specific book (filterBookId set), keep that scope; otherwise reload all.
    final bookId = state.filterBookId;
    if (bookId != null) {
      await loadBookmarks(bookId: bookId);
    } else {
      // Drop the deleted bookmark from the in-memory list immediately so the
      // all-bookmarks view updates without a full reload.
      state = state.copyWith(
        bookmarks: state.bookmarks.where((b) => b.id != id).toList(),
        loading: false,
      );
    }
  }
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, BookmarksState>(
  BookmarksNotifier.new,
);
