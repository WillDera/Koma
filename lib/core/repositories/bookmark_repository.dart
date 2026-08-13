import 'dart:async';

import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';

import '../isar/collections/bookmark.dart' as i;
import '../models/bookmark.dart';

class BookmarkRepository {
  final Isar _isar;

  BookmarkRepository(this._isar);

  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final rows = await _isar.bookmarks
        .where()
        .bookIdEqualTo(bookId)
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  /// Returns every bookmark across all books/chapters, newest first.
  Future<List<Bookmark>> getAllBookmarks() async {
    final rows = await _isar.bookmarks.where().sortByCreatedAtDesc().findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Bookmark>> getBookmarksForChapter(
    int bookId,
    int chapterId,
  ) async {
    final rows = await _isar.bookmarks.where().bookIdEqualTo(bookId).findAll();
    return rows
        .where((b) => b.chapterId == chapterId)
        .map(_toModel)
        .toList(growable: false);
  }

  Future<bool> isBookmarked(
    int bookId,
    int chapterId,
    int? pageNumber, {
    double? scrollPosition,
  }) async {
    final rows = await _isar.bookmarks.where().bookIdEqualTo(bookId).findAll();
    final candidates = rows.where((b) => b.chapterId == chapterId).toList();
    if (pageNumber != null) {
      return candidates.any((b) => b.pageNumber == pageNumber);
    }
    if (scrollPosition != null) {
      final rounded = (scrollPosition * 10).round() / 10;
      return candidates.any((b) => b.scrollPosition == rounded);
    }
    return false;
  }

  Future<Bookmark?> getBookmark(
    int bookId,
    int chapterId,
    int? pageNumber, {
    double? scrollPosition,
  }) async {
    final rows = await _isar.bookmarks.where().bookIdEqualTo(bookId).findAll();
    final candidates = rows.where((b) => b.chapterId == chapterId).toList();
    if (pageNumber != null) {
      final found = candidates.firstWhereOrNull(
        (b) => b.pageNumber == pageNumber,
      );
      return found == null ? null : _toModel(found);
    }
    if (scrollPosition != null) {
      final rounded = (scrollPosition * 10).round() / 10;
      final found = candidates.firstWhereOrNull(
        (b) => b.scrollPosition == rounded,
      );
      return found == null ? null : _toModel(found);
    }
    return null;
  }

  Future<int> createBookmark({
    required int bookId,
    required int chapterId,
    int? pageNumber,
    double? scrollPosition,
  }) async {
    final now = DateTime.now();
    final row = i.Bookmark(
      bookId: bookId,
      chapterId: chapterId,
      pageNumber: pageNumber,
      scrollPosition: scrollPosition != null
          ? (scrollPosition * 10).round() / 10
          : null,
      createdAt: now,
    );
    return _isar.writeTxn(() async => _isar.bookmarks.put(row));
  }

  Future<void> deleteBookmark(int id) async {
    await _isar.writeTxn(() => _isar.bookmarks.delete(id));
  }

  Future<void> deleteBookmarkByKey(
    int bookId,
    int chapterId,
    int? pageNumber, {
    double? scrollPosition,
  }) async {
    final rows = await _isar.bookmarks.where().bookIdEqualTo(bookId).findAll();
    final candidates = rows.where((b) => b.chapterId == chapterId).toList();
    i.Bookmark? existing;
    if (pageNumber != null) {
      existing = candidates.firstWhereOrNull((b) => b.pageNumber == pageNumber);
    } else if (scrollPosition != null) {
      final rounded = (scrollPosition * 10).round() / 10;
      existing = candidates.firstWhereOrNull(
        (b) => b.scrollPosition == rounded,
      );
    }
    if (existing != null) {
      await _isar.writeTxn(() => _isar.bookmarks.delete(existing!.id!));
    }
  }

  Future<void> deleteBookmarksForChapter(int bookId, int chapterId) async {
    final rows = await _isar.bookmarks.where().bookIdEqualTo(bookId).findAll();
    final targets = rows.where((b) => b.chapterId == chapterId).toList();
    await _isar.writeTxn(
      () => _isar.bookmarks.deleteAll(targets.map((r) => r.id!).toList()),
    );
  }

  static Bookmark _toModel(i.Bookmark b) => Bookmark(
    id: b.id ?? 0,
    bookId: b.bookId,
    chapterId: b.chapterId,
    pageNumber: b.pageNumber,
    scrollPosition: b.scrollPosition,
    createdAt: b.createdAt,
  );
}
