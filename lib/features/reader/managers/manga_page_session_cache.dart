import 'dart:io';

import '../models/page_data.dart';

/// Process-lifetime cache of chapter page lists (with resolved disk paths).
///
/// Survives leaving the manga reader so revisiting a chapter can skip
/// re-fetching page URLs and jump straight to on-disk image files when
/// still present. Bounded LRU by chapter count.
class MangaPageSessionCache {
  MangaPageSessionCache._();

  static const _maxChapters = 12;
  static final Map<String, List<PageData>> _entries = {};
  static final List<String> _lru = [];

  static String _key(String sourceId, String chapterUrl) =>
      '$sourceId\u0000$chapterUrl';

  /// Snapshot [pages] for [chapterUrl] under [sourceId].
  ///
  /// Transition separators are dropped; only real image pages are kept.
  static void store(
    String sourceId,
    String chapterUrl,
    List<PageData> pages,
  ) {
    final imagePages = pages.where((p) => !p.isTransitionPage).toList();
    if (imagePages.isEmpty) return;

    final key = _key(sourceId, chapterUrl);
    _entries[key] = [
      for (var i = 0; i < imagePages.length; i++)
        _clonePage(imagePages[i], pageIndex: i),
    ];
    _lru.remove(key);
    _lru.add(key);
    while (_lru.length > _maxChapters) {
      final oldest = _lru.removeAt(0);
      _entries.remove(oldest);
    }
  }

  /// Returns a fresh [PageData] list if this chapter was cached, else null.
  ///
  /// Clears resolved/local paths that no longer exist on disk so the reader
  /// falls back to the network/disk-image provider pipeline.
  static List<PageData>? lookup(String sourceId, String chapterUrl) {
    final key = _key(sourceId, chapterUrl);
    final hit = _entries[key];
    if (hit == null || hit.isEmpty) return null;

    _lru.remove(key);
    _lru.add(key);

    final out = <PageData>[];
    for (var i = 0; i < hit.length; i++) {
      final clone = _clonePage(hit[i], pageIndex: i);
      _scrubMissingPaths(clone);
      out.add(clone);
    }
    return out;
  }

  static void _scrubMissingPaths(PageData page) {
    final resolved = page.resolvedFilePath;
    if (resolved != null && resolved.isNotEmpty && !File(resolved).existsSync()) {
      page.resolvedFilePath = null;
    }
    final local = page.localPath;
    if (local != null && local.isNotEmpty && !File(local).existsSync()) {
      page.localPath = null;
    }
  }

  static PageData _clonePage(PageData src, {required int pageIndex}) {
    return PageData(
      mangaPage: src.mangaPage,
      chapter: src.chapter,
      pageIndex: pageIndex,
      localPath: src.localPath,
    )..resolvedFilePath = src.resolvedFilePath;
  }
}
