import 'package:isar_community/isar.dart';

import '../isar/collections/library_category.dart' as i;
import '../isar/collections/manga_extras.dart' as i;
import '../models/library_category.dart';

class CategoryRepository {
  final Isar _isar;
  CategoryRepository(this._isar);

  Future<List<LibraryCategory>> getCategories() async {
    final rows = await _isar.libraryCategorys.where().sortByOrder().findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<LibraryCategory?> getByName(String name) async {
    final row = await _isar.libraryCategorys
        .where()
        .nameEqualTo(name)
        .findFirst();
    return row == null ? null : _toModel(row);
  }

  /// Insert [category] or return the existing row with the same name.
  Future<int> upsertByName(LibraryCategory category) async {
    final existing = await getByName(category.name);
    if (existing != null) return existing.id;
    return _isar.writeTxn(
      () => _isar.libraryCategorys.put(_fromModel(category.copyWith(id: 0))),
    );
  }

  Future<int> insertCategory(LibraryCategory category) async {
    return _isar.writeTxn(
      () => _isar.libraryCategorys.put(_fromModel(category)),
    );
  }

  Future<i.MangaExtras?> extrasForManga(int mangaId) async {
    return _isar.mangaExtras.where().mangaIdEqualTo(mangaId).findFirst();
  }

  Future<Map<int, i.MangaExtras>> extrasByMangaIds(Iterable<int> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _isar.mangaExtras.where().findAll();
    final want = ids.toSet();
    return {
      for (final row in rows)
        if (want.contains(row.mangaId)) row.mangaId: row,
    };
  }

  Future<Map<int, i.MangaExtras>> allExtras() async {
    final rows = await _isar.mangaExtras.where().findAll();
    return {for (final row in rows) row.mangaId: row};
  }

  Future<void> upsertExtras({
    required int mangaId,
    List<int>? categoryIds,
    String? notes,
  }) async {
    final hasCats = categoryIds != null && categoryIds.isNotEmpty;
    final hasNotes = notes != null && notes.isNotEmpty;
    await _isar.writeTxn(() async {
      final existing = await _isar.mangaExtras
          .where()
          .mangaIdEqualTo(mangaId)
          .findFirst();
      if (!hasCats && !hasNotes && existing == null) return;
      if (!hasCats && !hasNotes && existing != null) {
        await _isar.mangaExtras.delete(existing.id ?? 0);
        return;
      }
      if (existing == null) {
        await _isar.mangaExtras.put(
          i.MangaExtras(
            mangaId: mangaId,
            categoryIds: categoryIds,
            notes: notes,
          ),
        );
      } else {
        existing.categoryIds = categoryIds;
        existing.notes = notes;
        await _isar.mangaExtras.put(existing);
      }
    });
  }

  static LibraryCategory _toModel(i.LibraryCategory c) => LibraryCategory(
    id: c.id ?? 0,
    name: c.name,
    order: c.order,
    flags: c.flags,
  );

  static i.LibraryCategory _fromModel(LibraryCategory c) => i.LibraryCategory(
    id: c.id == 0 ? Isar.autoIncrement : c.id,
    name: c.name,
    order: c.order,
    flags: c.flags,
  );
}
