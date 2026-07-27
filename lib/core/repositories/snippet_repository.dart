import 'dart:async';

import 'package:isar_community/isar.dart';

import '../isar/collections/snippet.dart' as i;
import '../isar/collections/snippet_collection.dart' as i;
import '../isar/collections/tag.dart' as i;
import '../models/snippet.dart';
import '../models/snippet_collection.dart';

/// Snippets + collections + tag catalog.
///
/// Tags are stored denormalized on each [i.Snippet] (List<String>) AND
/// in the [i.Tag] catalog (unique by name). Writes must update BOTH
/// places to keep the catalog in sync — see [_upsertTags].
class SnippetRepository {
  final Isar _isar;
  SnippetRepository(this._isar);

  // ── Snippets: Future API ───────────────────────────────────────────

  Future<List<Snippet>> getSnippets() async {
    final rows = await _isar.snippets.where().sortByCreatedAtDesc().findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Snippet>> searchSnippets(String term) async {
    final lower = term.toLowerCase();
    final rows = await _isar.snippets
        .filter()
        .textContains(lower, caseSensitive: false)
        .or()
        .noteContains(lower, caseSensitive: false)
        .or()
        .sourceTitleContains(lower, caseSensitive: false)
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Snippet>> getSnippetsForBook(int bookId) async {
    final rows = await _isar.snippets
        .where()
        .bookIdEqualTo(bookId)
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<List<Snippet>> getSnippetsForCollection(int collectionId) async {
    final rows = await _isar.snippets
        .where()
        .collectionIdEqualTo(collectionId)
        .sortByCreatedAtDesc()
        .findAll();
    return rows.map(_toModel).toList(growable: false);
  }

  Future<Snippet?> getSnippet(int id) async {
    final row = await _isar.snippets.get(id);
    return row == null ? null : _toModel(row);
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
    final now = DateTime.now();
    final row = i.Snippet(
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
      createdAt: now,
      updatedAt: now,
    );
    return _isar.writeTxn(() async {
      final id = await _isar.snippets.put(row);
      await _upsertTags(tags);
      return id;
    });
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await _isar.writeTxn(() async {
      await _isar.snippets.put(_fromModel(snippet));
      await _upsertTags(snippet.tags);
    });
  }

  Future<void> deleteSnippet(int id) async {
    await _isar.writeTxn(() => _isar.snippets.delete(id));
  }

  Future<void> deleteSelectedSnippets(List<int> ids) async {
    await _isar.writeTxn(() => _isar.snippets.deleteAll(ids));
  }

  // ── Snippets: Stream API ───────────────────────────────────────────

  Stream<List<Snippet>> watchSnippets({bool fireImmediately = true}) {
    return _isar.snippets
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_toModel).toList());
  }

  Stream<List<Snippet>> watchSnippetsForBook(int bookId,
      {bool fireImmediately = true}) {
    return _isar.snippets
        .where()
        .bookIdEqualTo(bookId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_toModel).toList());
  }

  Stream<List<Snippet>> watchSnippetsForCollection(int collectionId,
      {bool fireImmediately = true}) {
    return _isar.snippets
        .where()
        .collectionIdEqualTo(collectionId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_toModel).toList());
  }

  // ── Collections ────────────────────────────────────────────────────

  Future<List<SnippetCollection>> getCollections() async {
    final rows =
        await _isar.snippetCollections.where().sortByCreatedAtDesc().findAll();
    return rows.map(_collToModel).toList(growable: false);
  }

  Future<int> createCollection(String name,
      {String color = '#FFD700'}) async {
    final row = i.SnippetCollection(name: name, color: color);
    return _isar.writeTxn(() => _isar.snippetCollections.put(row));
  }

  Future<void> updateCollection(SnippetCollection collection) async {
    await _isar.writeTxn(
        () => _isar.snippetCollections.put(_collFromModel(collection)));
  }

  Future<void> deleteCollection(int id) async {
    await _isar.writeTxn(() async {
      // Mirror Drift's ON DELETE SET NULL on snippets.collection_id.
      final affected =
          await _isar.snippets.where().collectionIdEqualTo(id).findAll();
      for (final s in affected) {
        s.collectionId = null;
      }
      await _isar.snippets.putAll(affected);
      await _isar.snippetCollections.delete(id);
    });
  }

  Stream<List<SnippetCollection>> watchCollections(
      {bool fireImmediately = true}) {
    return _isar.snippetCollections
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map(_collToModel).toList());
  }

  // ── Tag catalog ────────────────────────────────────────────────────

  Future<List<String>> getAllTags() async {
    final rows = await _isar.tags.where().sortByName().findAll();
    return rows.map((t) => t.name).toList(growable: false);
  }

  Stream<List<String>> watchAllTags({bool fireImmediately = true}) {
    return _isar.tags
        .where()
        .sortByName()
        .watch(fireImmediately: fireImmediately)
        .map((rows) => rows.map((t) => t.name).toList());
  }

  Future<bool> getTagExists(String name) async {
    final found = await _isar.tags.where().nameEqualTo(name).findFirst();
    return found != null;
  }

  Future<void> createTag(String name) async {
    await _isar.writeTxn(() => _isar.tags.put(i.Tag(name: name)));
  }

  /// Insert any tags that aren't already in the catalog. Idempotent —
  /// existing tag names are skipped (the unique index replaces on conflict).
  Future<void> _upsertTags(List<String> tagNames) async {
    if (tagNames.isEmpty) return;
    final existing = <String>{};
    for (final name in tagNames) {
      final found = await _isar.tags.where().nameEqualTo(name).findFirst();
      if (found != null) {
        existing.add(name);
      }
    }
    final toAdd = tagNames.where((n) => !existing.contains(n)).toList();
    if (toAdd.isEmpty) return;
    await _isar.tags.putAll(toAdd.map((n) => i.Tag(name: n)).toList());
  }

  // ── Conversions ────────────────────────────────────────────────────

  static Snippet _toModel(i.Snippet s) => Snippet(
        id: s.id ?? 0,
        text: s.text,
        note: s.note,
        sourceTitle: s.sourceTitle,
        sourceUrl: s.sourceUrl,
        color: s.color,
        bookId: s.bookId,
        chapterId: s.chapterId,
        collectionId: s.collectionId,
        startOffset: s.startOffset,
        endOffset: s.endOffset,
        scrollPosition: s.scrollPosition,
        tags: s.tags ?? const [],
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static i.Snippet _fromModel(Snippet s) => i.Snippet(
        id: s.id == 0 ? Isar.autoIncrement : s.id,
        text: s.text,
        note: s.note,
        sourceTitle: s.sourceTitle,
        sourceUrl: s.sourceUrl,
        color: s.color,
        bookId: s.bookId,
        chapterId: s.chapterId,
        collectionId: s.collectionId,
        startOffset: s.startOffset,
        endOffset: s.endOffset,
        scrollPosition: s.scrollPosition,
        tags: s.tags,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static SnippetCollection _collToModel(i.SnippetCollection c) =>
      SnippetCollection(
        id: c.id ?? 0,
        name: c.name,
        color: c.color,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  static i.SnippetCollection _collFromModel(SnippetCollection c) =>
      i.SnippetCollection(
        id: c.id == 0 ? Isar.autoIncrement : c.id,
        name: c.name,
        color: c.color,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );
}
