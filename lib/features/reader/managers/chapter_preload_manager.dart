import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../core/models/manga_chapter.dart';
import '../models/page_data.dart';

/// Manages the flat page list and memory-bounded chapter caching for the
/// manga reader — directly ported from mangayomi's ChapterPreloadManager.
///
/// All pages from all loaded chapters live in a single [_pages] list.
/// Transition pages ("End of Chapter" separators) are inserted between
/// chapters as regular list items, enabling seamless cross-chapter scrolling.
class ChapterPreloadManager {
  /// The flat list of all page data from all loaded chapters.
  final List<PageData> _pages = [];

  /// Set of chapter IDs currently in memory.
  final Set<int> _loadedChapterIds = {};

  /// Queue of chapter IDs in order of loading (for LRU eviction).
  final Queue<int> _chapterLoadOrder = Queue();

  /// Separate flags to allow concurrent prev/next preloading.
  bool _isPreloadingNext = false;
  bool _isPreloadingPrev = false;

  /// Callback when pages are added/removed.
  void Function()? onPagesUpdated;

  /// Gets the list of pages (read-only).
  List<PageData> get pages => List.unmodifiable(_pages);

  /// Gets the current number of pages.
  int get pageCount => _pages.length;

  /// Gets the loaded chapter count.
  int get loadedChapterCount => _loadedChapterIds.length;

  /// Whether a previous chapter preload is in progress.
  bool get isPreloadingPrev => _isPreloadingPrev;

  /// Whether a next chapter preload is in progress.
  bool get isPreloadingNext => _isPreloadingNext;

  /// Returns `true` if pages from [chapter] are already in memory.
  bool isChapterLoaded(MangaChapter? chapter) {
    if (chapter == null) return false;
    return _loadedChapterIds.contains(chapter.id);
  }

  /// Initializes the manager with the first chapter's pages.
  void initialize(List<PageData> initialPages) {
    _pages.clear();
    _loadedChapterIds.clear();
    _chapterLoadOrder.clear();

    _pages.addAll(initialPages);

    // Track the initial chapter
    if (initialPages.isNotEmpty) {
      final chapter = initialPages.first.chapter;
      if (chapter != null) {
        _loadedChapterIds.add(chapter.id);
        _chapterLoadOrder.add(chapter.id);
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[ChapterPreload] Initialized with ${initialPages.length} pages',
      );
    }
  }

  /// Creates a transition page between chapters.
  PageData createTransitionPage({
    required MangaChapter currentChapter,
    required MangaChapter? nextChapter,
    required String mangaName,
    bool isLastChapter = false,
  }) {
    return PageData.transition(
      currentChapter: currentChapter,
      nextChapter: nextChapter,
      mangaName: mangaName,
      pageIndex: _pages.length,
      isLastChapter: isLastChapter,
    );
  }

  // ── Next-chapter preloading (append) ──

  /// Preloads the next chapter's pages by appending them.
  ///
  /// [chapterPages] - The list of [PageData] for the next chapter.
  /// [currentChapter] - The current chapter (for the transition page).
  ///
  /// Returns true if preloading was successful, false otherwise.
  Future<bool> preloadNextChapter(
    List<PageData> chapterPages,
    MangaChapter currentChapter,
  ) async {
    if (_isPreloadingNext) {
      if (kDebugMode) {
        debugPrint('[ChapterPreload] Already preloading next, skipping');
      }
      return false;
    }

    _isPreloadingNext = true;

    try {
      if (chapterPages.isEmpty) {
        if (kDebugMode) {
          debugPrint('[ChapterPreload] No pages in next chapter data');
        }
        return false;
      }

      final firstPage = chapterPages.first;
      if (firstPage.chapter == null) {
        if (kDebugMode) {
          debugPrint('[ChapterPreload] No chapter in first page');
        }
        return false;
      }

      final chapterId = firstPage.chapter!.id;
      if (_loadedChapterIds.contains(chapterId)) {
        if (kDebugMode) {
          debugPrint(
            '[ChapterPreload] Next chapter already loaded: $chapterId',
          );
        }
        return false;
      }

      // Create transition page
      final transitionPage = createTransitionPage(
        currentChapter: currentChapter,
        nextChapter: firstPage.chapter,
        mangaName: currentChapter.name,
      );

      // Update page indices for new pages
      final startIndex = _pages.length + 1;
      for (int i = 0; i < chapterPages.length; i++) {
        chapterPages[i].pageIndex = startIndex + i;
      }

      // Add to pages list
      _pages.add(transitionPage);
      _pages.addAll(chapterPages);

      // Track the new chapter
      _loadedChapterIds.add(chapterId);
      _chapterLoadOrder.add(chapterId);

      // Notify listeners
      onPagesUpdated?.call();

      if (kDebugMode) {
        debugPrint(
          '[ChapterPreload] Appended ${chapterPages.length} pages from next chapter',
        );
        debugPrint(
          '[ChapterPreload] Total pages: ${_pages.length}, Chapters: ${_loadedChapterIds.length}',
        );
      }

      return true;
    } finally {
      _isPreloadingNext = false;
    }
  }

  // ── Previous-chapter preloading (prepend) ──

  /// Preloads the previous chapter's pages by prepending them.
  ///
  /// [chapterPages] - The list of [PageData] for the previous chapter.
  /// [currentChapter] - The current chapter (for the transition page).
  ///
  /// Returns the number of pages prepended (including transition page).
  Future<int> preloadPrevChapter(
    List<PageData> chapterPages,
    MangaChapter currentChapter,
  ) async {
    if (_isPreloadingPrev) {
      if (kDebugMode) {
        debugPrint('[ChapterPreload] Already preloading prev, skipping');
      }
      return 0;
    }

    _isPreloadingPrev = true;

    try {
      if (chapterPages.isEmpty) {
        if (kDebugMode) {
          debugPrint('[ChapterPreload] No pages in prev chapter data');
        }
        return 0;
      }

      final firstPage = chapterPages.first;
      if (firstPage.chapter == null) {
        if (kDebugMode) {
          debugPrint('[ChapterPreload] No chapter in prev first page');
        }
        return 0;
      }

      final chapterId = firstPage.chapter!.id;
      if (_loadedChapterIds.contains(chapterId)) {
        if (kDebugMode) {
          debugPrint(
            '[ChapterPreload] Prev chapter already loaded: $chapterId',
          );
        }
        return 0;
      }

      // Transition page: marks end of prev chapter → start of current chapter
      final transitionPage = PageData.transition(
        currentChapter: firstPage.chapter!,
        nextChapter: currentChapter,
        mangaName: currentChapter.name,
        pageIndex: 0, // recalculated below
      );

      // Build prepend list: prev chapter pages + transition page
      final prependList = [...chapterPages, transitionPage];
      final prependCount = prependList.length;

      // Assign pageIndex to prepended pages (0 .. prependCount-1)
      for (int i = 0; i < prependList.length; i++) {
        prependList[i].pageIndex = i;
      }

      // Shift pageIndex of all existing pages
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].pageIndex = _pages[i].pageIndex + prependCount;
      }

      // Prepend to pages list
      _pages.insertAll(0, prependList);

      // Track the new chapter
      _loadedChapterIds.add(chapterId);
      _chapterLoadOrder.addFirst(chapterId);

      // Notify listeners
      onPagesUpdated?.call();

      if (kDebugMode) {
        debugPrint(
          '[ChapterPreload] Prepended ${chapterPages.length} pages from prev chapter',
        );
        debugPrint(
          '[ChapterPreload] Total pages: ${_pages.length}, Chapters: ${_loadedChapterIds.length}',
        );
      }

      return prependCount;
    } finally {
      _isPreloadingPrev = false;
    }
  }

  /// Adds a "last chapter" transition page (end of manga).
  bool addLastChapterTransition(MangaChapter chapter) {
    // Check if already added
    if (_pages.isNotEmpty && (_pages.last.isLastChapter)) {
      return false;
    }

    final transitionPage = createTransitionPage(
      currentChapter: chapter,
      nextChapter: null,
      mangaName: chapter.name,
      isLastChapter: true,
    );

    _pages.add(transitionPage);
    onPagesUpdated?.call();

    if (kDebugMode) {
      debugPrint('[ChapterPreload] Added last chapter transition');
    }

    return true;
  }

  /// Evicts old chapters' cached data when the loaded chapters exceed the
  /// threshold (keeps current + 1 each side).
  void evictOldChapters(MangaChapter currentChapter) {
    final currentId = currentChapter.id;

    // Build ordered list of chapter IDs from pages
    final loadedIdsInOrder = <int>[];
    final seen = <int>{};
    for (final page in _pages) {
      if (page.isTransitionPage || page.chapter == null) continue;
      final id = page.chapter!.id;
      if (seen.add(id)) {
        loadedIdsInOrder.add(id);
      }
    }

    final currentIndex = loadedIdsInOrder.indexOf(currentId);
    if (currentIndex == -1) return;

    final idsToKeep = <int>{currentId};
    if (currentIndex - 1 >= 0) {
      idsToKeep.add(loadedIdsInOrder[currentIndex - 1]);
    }
    if (currentIndex + 1 < loadedIdsInOrder.length) {
      idsToKeep.add(loadedIdsInOrder[currentIndex + 1]);
    }

    final idsToEvict = _loadedChapterIds.difference(idsToKeep);
    if (idsToEvict.isEmpty) return;

    // Single linear pass over pages to evict old chapters
    for (int i = 0; i < _pages.length; i++) {
      final page = _pages[i];
      if (page.isTransitionPage || page.chapter == null) continue;
      if (idsToEvict.contains(page.chapter!.id)) {
        if (kDebugMode) {
          debugPrint(
            '[ChapterPreload] Evicting chapter page index $i for ${page.chapter!.id}',
          );
        }
        // Clear cached local path
        page.localPath = null;
      }
    }

    _loadedChapterIds.removeAll(idsToEvict);
    _chapterLoadOrder.removeWhere((id) => idsToEvict.contains(id));
  }

  /// Marks a chapter as loaded again (used after reloading evicted pages).
  void markChapterAsLoaded(MangaChapter chapter) {
    final chapterId = chapter.id;
    _loadedChapterIds.add(chapterId);
    if (!_chapterLoadOrder.contains(chapterId)) {
      _chapterLoadOrder.add(chapterId);
    }
  }

  /// Disposes of all resources.
  void dispose() {
    _pages.clear();
    _loadedChapterIds.clear();
    _chapterLoadOrder.clear();
    onPagesUpdated = null;

    if (kDebugMode) {
      debugPrint('[ChapterPreload] Disposed');
    }
  }
}
