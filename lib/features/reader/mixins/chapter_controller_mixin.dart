import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/manga_chapter.dart';
import '../../../core/models/manga_page.dart';
import '../managers/chapter_preload_manager.dart';
import '../models/page_data.dart';

/// Optional chapter navigator used by alternate reader shells.
///
/// [fetchPages] must return network/local page images for a chapter (wire to
/// [ExtensionDispatchService.getPageList] so JS and Mihon both work). The
/// legacy [keiyoushiService] duck-type is kept only for older call sites.
class ChapterControllerMixin {
  MangaChapter? currentChapter;
  List<MangaChapter> chapters = [];
  String sourceId = '';

  /// Preferred: `Future<List<Map<String, dynamic>>> Function(MangaChapter)`.
  Future<List<Map<String, dynamic>>> Function(MangaChapter chapter)? fetchPages;

  /// Legacy duck-typed KeiyoushiService.getPageList(sourceId:, chapterUrl:).
  dynamic keiyoushiService;

  final ChapterPreloadManager _preloadManager = ChapterPreloadManager();

  List<PageData> get pages => _preloadManager.pages;
  int get pageCount => _preloadManager.pageCount;

  void initializePreloadManager(
    List<PageData> initialPages, {
    VoidCallback? onPagesUpdated,
  }) {
    _preloadManager.onPagesUpdated = onPagesUpdated;
    _preloadManager.initialize(initialPages);
  }

  Future<bool?> preloadNextChapter(MangaChapter current) async {
    if (chapters.isEmpty) return false;
    final idx = chapters.indexWhere((c) => c.url == current.url);
    if (idx < 0 || idx >= chapters.length - 1) return false;

    final next = chapters[idx + 1];
    if (_preloadManager.isChapterLoaded(next)) return false;

    return await _preloadManager.preloadNextChapter(
      await _fetchChapterPages(next),
      current,
    );
  }

  Future<int> preloadPreviousChapter(MangaChapter current) async {
    if (chapters.isEmpty) return 0;
    final idx = chapters.indexWhere((c) => c.url == current.url);
    if (idx <= 0) return 0;

    final prev = chapters[idx - 1];
    if (_preloadManager.isChapterLoaded(prev)) return 0;

    return await _preloadManager.preloadPrevChapter(
      await _fetchChapterPages(prev),
      current,
    );
  }

  Future<List<PageData>> _fetchChapterPages(MangaChapter chapter) async {
    try {
      late final List<Map<String, dynamic>> pageList;
      final fetch = fetchPages;
      if (fetch != null) {
        pageList = await fetch(chapter);
      } else {
        pageList = await keiyoushiService.getPageList(
          sourceId: sourceId,
          chapterUrl: chapter.url,
        ) as List<Map<String, dynamic>>;
      }

      return pageList
          .map((p) {
            final pd = PageData.page(
              mangaPage: MangaPage(
                index: p['index'] as int? ?? 0,
                imageUrl: (p['url'] as String?) ??
                    (p['imageUrl'] as String?) ??
                    '',
                chapterUrl: chapter.url,
              ),
              chapter: chapter,
              pageIndex: 0,
            );
            pd.localPath = p['localPath'] as String?;
            return pd;
          })
          .toList(growable: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChapterController] Failed to fetch pages: $e');
      }
      return [];
    }
  }

  Future<bool> advanceToNextChapter() async {
    final current = currentChapter;
    if (current == null || chapters.isEmpty) return false;

    final idx = chapters.indexWhere((c) => c.url == current.url);
    if (idx < 0 || idx >= chapters.length - 1) return false;

    final next = chapters[idx + 1];
    return await loadChapter(next);
  }

  Future<bool> advanceToPreviousChapter() async {
    final current = currentChapter;
    if (current == null || chapters.isEmpty) return false;

    final idx = chapters.indexWhere((c) => c.url == current.url);
    if (idx <= 0) return false;

    final prev = chapters[idx - 1];
    return await loadChapter(prev);
  }

  Future<bool> loadChapter(MangaChapter chapter) async {
    final pages = await _fetchChapterPages(chapter);
    if (pages.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ChapterController] No pages for chapter ${chapter.name}');
      }
      return false;
    }

    currentChapter = chapter;
    initializePreloadManager(pages);

    if (kDebugMode) {
      debugPrint(
        '[ChapterController] Loaded chapter ${chapter.name}: ${pages.length} pages',
      );
    }
    return true;
  }

  void disposePreloadManager() {
    _preloadManager.dispose();
  }
}
