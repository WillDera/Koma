import 'package:flutter/foundation.dart';
import '../managers/chapter_preload_manager.dart';
import '../models/page_data.dart';
import '../../../core/models/manga_chapter.dart';

/// Mixin that wraps [ChapterPreloadManager] and provides memory-bounded
/// chapter caching for the manga reader — directly ported from mangayomi's
/// ReaderMemoryManagement.
///
/// Usage: mix this into the reader's State class.
mixin ReaderMemoryManagement {
  /// The preload manager that handles memory-bounded chapter caching.
  late final ChapterPreloadManager _preloadManager = ChapterPreloadManager();

  /// Whether the preload manager has been initialized.
  bool _isPreloadManagerInitialized = false;

  /// Gets the preload manager.
  ChapterPreloadManager get preloadManager => _preloadManager;

  /// Gets all currently loaded pages.
  List<PageData> get pages => _preloadManager.pages;

  /// Gets the total page count.
  int get pageCount => _preloadManager.pageCount;

  /// Initializes the preload manager with initial chapter data.
  ///
  /// [initialPages] - The initial chapter pages to load.
  /// [onPagesUpdated] - Callback when pages are added/removed.
  void initializePreloadManager(
    List<PageData> initialPages, {
    VoidCallback? onPagesUpdated,
  }) {
    if (_isPreloadManagerInitialized) {
      if (kDebugMode) {
        debugPrint('[ReaderMemoryManagement] Already initialized, skipping');
      }
      return;
    }

    _preloadManager.onPagesUpdated = onPagesUpdated;
    _preloadManager.initialize(initialPages);
    _isPreloadManagerInitialized = true;

    if (kDebugMode) {
      debugPrint(
        '[ReaderMemoryManagement] Initialized with ${initialPages.length} pages',
      );
    }
  }

  /// Preloads the next chapter with automatic memory management.
  ///
  /// [chapterPages] - The page data for the chapter to preload.
  /// [currentChapter] - The current chapter.
  ///
  /// Returns true if the chapter was preloaded, false otherwise.
  Future<bool> preloadNextChapter(
    List<PageData> chapterPages,
    MangaChapter currentChapter,
  ) async {
    return await _preloadManager.preloadNextChapter(
      chapterPages,
      currentChapter,
    );
  }

  /// Preloads the previous chapter by prepending its pages.
  ///
  /// Returns the number of pages prepended (> 0 means all existing indices
  /// shifted by that amount). The caller must adjust the scroll / page index.
  Future<int> preloadPreviousChapter(
    List<PageData> chapterPages,
    MangaChapter currentChapter,
  ) async {
    return await _preloadManager.preloadPrevChapter(
      chapterPages,
      currentChapter,
    );
  }

  /// Whether [chapter] pages are already loaded in the preload manager.
  bool isChapterLoaded(MangaChapter? chapter) {
    return _preloadManager.isChapterLoaded(chapter);
  }

  /// Adds a "last chapter" transition page (end of manga).
  ///
  /// Returns true if added successfully, false if already added.
  bool addLastChapterTransition(MangaChapter chapter) {
    return _preloadManager.addLastChapterTransition(chapter);
  }

  /// Disposes the preload manager and clears all cached data.
  void disposePreloadManager() {
    if (!_isPreloadManagerInitialized) return;
    _preloadManager.dispose();
    _isPreloadManagerInitialized = false;

    if (kDebugMode) {
      debugPrint('[ReaderMemoryManagement] Disposed');
    }
  }
}
