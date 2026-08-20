import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../isar/collections/book.dart';
import '../isar/collections/chapter.dart';
import '../isar/collections/manga.dart';
import '../isar/collections/manga_extras.dart';
import 'app_storage.dart';

/// Rewrites absolute filesystem paths stored in Isar after a data-folder move.
///
/// Ebook covers ([Book.coverPath]), inline `file://` chapter media, and manga
/// custom covers are written as absolute paths at import time. Moving the
/// storage root relocates the files but leaves those strings pointing at the
/// old location — remapping them restores covers (Mihon avoids this by hashing
/// URLs at runtime; we keep absolute paths and rewrite on migrate).
class StoragePathRewrite {
  StoragePathRewrite._();

  /// Prefix-swap [oldDocuments]/[oldSupport] → current layout, then repair
  /// any leftover absolute paths that still miss their files.
  static Future<void> afterMigrate({
    required Isar isar,
    required String oldDocuments,
    required String oldSupport,
    required String newDocuments,
    required String newSupport,
  }) async {
    await isar.writeTxn(() async {
      await _rewriteBooks(
        isar,
        (path) => _swapPrefix(
          path,
          oldDocuments: oldDocuments,
          oldSupport: oldSupport,
          newDocuments: newDocuments,
          newSupport: newSupport,
        ),
      );
      await _rewriteChapters(
        isar,
        (html) => _swapPrefix(
          html,
          oldDocuments: oldDocuments,
          oldSupport: oldSupport,
          newDocuments: newDocuments,
          newSupport: newSupport,
        ),
      );
      await _rewriteMangaExtras(
        isar,
        (path) => _swapPrefix(
          path,
          oldDocuments: oldDocuments,
          oldSupport: oldSupport,
          newDocuments: newDocuments,
          newSupport: newSupport,
        ),
      );
      await _rewriteMangaImageUrls(
        isar,
        (path) => _swapPrefix(
          path,
          oldDocuments: oldDocuments,
          oldSupport: oldSupport,
          newDocuments: newDocuments,
          newSupport: newSupport,
        ),
      );
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsChaptersRepaired, true);
    await repairBrokenAbsolutePaths(isar);
  }

  /// Remaps absolute paths that reference known Koma folders but no longer
  /// resolve on disk (covers users who migrated before path rewrite existed).
  ///
  /// Chapter HTML rewrite is gated behind a one-shot prefs flag so startup
  /// stays cheap after the first repair.
  static Future<void> repairBrokenAbsolutePaths(Isar isar) async {
    final documents = (await AppStorage.documents()).path;
    final support = (await AppStorage.support()).path;

    await isar.writeTxn(() async {
      final books = await isar.books.where().findAll();
      final dirtyBooks = <Book>[];
      for (final book in books) {
        final path = book.coverPath;
        if (path == null || path.isEmpty) continue;
        if (await File(path).exists()) continue;
        final next = _remapKnownFolder(path, documents: documents, support: support);
        if (next != null && next != path && await File(next).exists()) {
          book.coverPath = next;
          dirtyBooks.add(book);
        }
      }
      if (dirtyBooks.isNotEmpty) {
        await isar.books.putAll(dirtyBooks);
      }

      final extras = await isar.mangaExtras.where().findAll();
      final dirtyExtras = <MangaExtras>[];
      for (final row in extras) {
        final path = row.customCoverPath;
        if (path == null || path.isEmpty) continue;
        if (await File(path).exists()) continue;
        final next = _remapKnownFolder(path, documents: documents, support: support);
        if (next != null && next != path && await File(next).exists()) {
          row.customCoverPath = next;
          dirtyExtras.add(row);
        }
      }
      if (dirtyExtras.isNotEmpty) {
        await isar.mangaExtras.putAll(dirtyExtras);
      }

      final mangas = await isar.mangas.where().findAll();
      final dirtyMangas = <Manga>[];
      for (final manga in mangas) {
        final url = manga.imageUrl;
        if (url == null || url.isEmpty) continue;
        if (!_looksLikeLocalPath(url)) continue;
        final stripped = url.startsWith('file:')
            ? Uri.parse(url).toFilePath()
            : url;
        if (await File(stripped).exists()) continue;
        final next = _remapKnownFolder(
          stripped,
          documents: documents,
          support: support,
        );
        if (next != null && next != stripped && await File(next).exists()) {
          manga.imageUrl = next;
          dirtyMangas.add(manga);
        }
      }
      if (dirtyMangas.isNotEmpty) {
        await isar.mangas.putAll(dirtyMangas);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsChaptersRepaired) == true) return;
    await isar.writeTxn(() async {
      final chapters = await isar.chapters.where().findAll();
      final dirtyChapters = <Chapter>[];
      for (final chapter in chapters) {
        final next = _remapEmbeddedPaths(
          chapter.content,
          documents: documents,
          support: support,
        );
        if (next != chapter.content) {
          chapter.content = next;
          dirtyChapters.add(chapter);
        }
      }
      if (dirtyChapters.isNotEmpty) {
        await isar.chapters.putAll(dirtyChapters);
      }
    });
    await prefs.setBool(_prefsChaptersRepaired, true);
  }

  static const _prefsChaptersRepaired = 'storage_chapter_paths_repaired_v1';

  static Future<void> _rewriteBooks(
    Isar isar,
    String Function(String) mapPath,
  ) async {
    final books = await isar.books.where().findAll();
    final dirty = <Book>[];
    for (final book in books) {
      final path = book.coverPath;
      if (path == null || path.isEmpty) continue;
      final next = mapPath(path);
      if (next != path) {
        book.coverPath = next;
        dirty.add(book);
      }
    }
    if (dirty.isNotEmpty) await isar.books.putAll(dirty);
  }

  static Future<void> _rewriteChapters(
    Isar isar,
    String Function(String) mapHtml,
  ) async {
    final chapters = await isar.chapters.where().findAll();
    final dirty = <Chapter>[];
    for (final chapter in chapters) {
      final next = mapHtml(chapter.content);
      if (next != chapter.content) {
        chapter.content = next;
        dirty.add(chapter);
      }
    }
    if (dirty.isNotEmpty) await isar.chapters.putAll(dirty);
  }

  static Future<void> _rewriteMangaExtras(
    Isar isar,
    String Function(String) mapPath,
  ) async {
    final rows = await isar.mangaExtras.where().findAll();
    final dirty = <MangaExtras>[];
    for (final row in rows) {
      final path = row.customCoverPath;
      if (path == null || path.isEmpty) continue;
      final next = mapPath(path);
      if (next != path) {
        row.customCoverPath = next;
        dirty.add(row);
      }
    }
    if (dirty.isNotEmpty) await isar.mangaExtras.putAll(dirty);
  }

  static Future<void> _rewriteMangaImageUrls(
    Isar isar,
    String Function(String) mapPath,
  ) async {
    final mangas = await isar.mangas.where().findAll();
    final dirty = <Manga>[];
    for (final manga in mangas) {
      final url = manga.imageUrl;
      if (url == null || url.isEmpty || !_looksLikeLocalPath(url)) continue;
      final next = mapPath(url);
      if (next != url) {
        manga.imageUrl = next;
        dirty.add(manga);
      }
    }
    if (dirty.isNotEmpty) await isar.mangas.putAll(dirty);
  }

  static String _swapPrefix(
    String value, {
    required String oldDocuments,
    required String oldSupport,
    required String newDocuments,
    required String newSupport,
  }) {
    var out = value;
    out = _replaceRoot(out, oldDocuments, newDocuments);
    if (_canon(oldSupport) != _canon(oldDocuments) ||
        _canon(newSupport) != _canon(newDocuments)) {
      out = _replaceRoot(out, oldSupport, newSupport);
    }
    return out;
  }

  static String _replaceRoot(String value, String fromRoot, String toRoot) {
    if (fromRoot.isEmpty || _canon(fromRoot) == _canon(toRoot)) return value;
    var out = value.replaceAll(fromRoot, toRoot);
    final fromUri = Uri.file(fromRoot).toString();
    final toUri = Uri.file(toRoot).toString();
    if (fromUri != fromRoot) {
      out = out.replaceAll(fromUri, toUri);
    }
    // Also swap trailing-slash variants.
    final fromSlash = fromRoot.endsWith('/') ? fromRoot : '$fromRoot/';
    final toSlash = toRoot.endsWith('/') ? toRoot : '$toRoot/';
    if (!value.contains(fromSlash)) {
      // already handled by bare replace when fromRoot was a prefix of paths
    } else {
      out = out.replaceAll(fromSlash, toSlash);
    }
    return out;
  }

  /// Maps `/…/covers/x`, `/…/ebook_media/…`, `/…/manga_covers/…` onto the
  /// current documents/support roots.
  static String? _remapKnownFolder(
    String stored, {
    required String documents,
    required String support,
  }) {
    final path = stored.startsWith('file:')
        ? Uri.parse(stored).toFilePath()
        : stored;
    const docFolders = ['covers', 'ebook_media', 'thumbnails', 'updates'];
    for (final folder in docFolders) {
      final marker = '/$folder/';
      final i = path.indexOf(marker);
      if (i >= 0) {
        final rel = path.substring(i + 1); // folder/…
        return p.join(documents, rel);
      }
    }
    const supportFolders = ['manga_covers', 'manga', 'extensions'];
    for (final folder in supportFolders) {
      final marker = '/$folder/';
      final i = path.indexOf(marker);
      if (i >= 0) {
        final rel = path.substring(i + 1);
        return p.join(support, rel);
      }
    }
    return null;
  }

  static String _remapEmbeddedPaths(
    String html, {
    required String documents,
    required String support,
  }) {
    return html.replaceAllMapped(
      RegExp(
        r'''(file://)?(/[^"'\s]+/(?:covers|ebook_media|thumbnails|manga_covers|manga)/[^"'\s]+)''',
      ),
      (m) {
        final hadFile = m.group(1) != null;
        final absolute = m.group(2)!;
        final next = _remapKnownFolder(
          absolute,
          documents: documents,
          support: support,
        );
        if (next == null || next == absolute) return m.group(0)!;
        return hadFile ? Uri.file(next).toString() : next;
      },
    );
  }

  static bool _looksLikeLocalPath(String value) {
    if (value.startsWith('file:')) return true;
    if (value.startsWith('/')) return true;
    return false;
  }

  static String _canon(String path) => p.normalize(Directory(path).absolute.path);
}
