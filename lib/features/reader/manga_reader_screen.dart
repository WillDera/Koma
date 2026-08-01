import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/manga_chapter.dart';
import '../../core/models/manga_page.dart';
import '../../core/providers.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/extension_manager.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../features/snippets/bookmarks_provider.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import 'mixins/reader_memory_management.dart';
import 'models/page_data.dart';
import 'reader_settings_sheet.dart';
import 'views/manga_image_view_paged.dart';
import 'views/manga_image_view_webtoon.dart';
import 'views/reader_view_props.dart';
import 'widgets/chapter_list_dialog.dart';
import 'widgets/color_filter_widget.dart';
import 'widgets/image_actions_dialog.dart';
import 'widgets/navigation_overlay.dart';
import 'widgets/page_indicator.dart';
import 'widgets/reader_app_bar.dart';
import 'widgets/reader_bottom_bar.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final int? mangaId;
  final String sourceId;
  final String mangaUrl;
  final String chapterUrl;
  final String chapterName;
  final int? pageNumber;

  const MangaReaderScreen({
    super.key,
    this.mangaId,
    required this.sourceId,
    required this.mangaUrl,
    required this.chapterUrl,
    required this.chapterName,
    this.pageNumber,
  });

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen>
    with WidgetsBindingObserver, ReaderMemoryManagement {
  final _service = KeiyoushiService();
  Repositories? _repos;
  ExtensionManager? _extensionManager;
  bool _loading = true;
  String? _error;
  final _pageCtrl = PageController();
  final ItemScrollController _itemScrollCtrl = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  bool _showToolbar = false;
  bool _showNavigationOverlay = false;
  bool _isBookmarked = false;
  final List<TransformationController> _zoomCtrls = [];
  Timer? _saveTimer;

  /// The full chapter list for this manga (cached for navigation lookups).
  List<MangaChapter> _chapters = [];

  /// The DB chapter row for the page currently being read.
  MangaChapter? _currentChapter;

  /// Guard against duplicate next-chapter preloading.
  bool _isNextChapterPreloading = false;

  /// Set when the last chapter transition has been shown.
  bool _isLastPageTransition = false;

  /// Number of pages from the end that trigger preload.
  final int _pagePreloadAmount = 5;

  ReaderSettings _settings = ReaderSettings();

  List<PageData> get _pages => pages;

  @override
  void initState() {
    super.initState();
    _repos = ref.read(repositoriesProvider);
    _extensionManager = ref.read(extensionManagerProvider);
    WidgetsBinding.instance.addObserver(this);
    _itemPositionsListener.itemPositions.addListener(_onWebtoonScroll);
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadSettings();
    if (widget.mangaId != null && _repos != null) {
      final ch = await _repos!.manga.getMangaChapterByUrl(
        widget.mangaId!,
        widget.chapterUrl,
      );
      if (ch != null && mounted) {
        _currentChapter = ch;
        if (!ch.isOpened) {
          await _repos!.manga.markMangaChapterOpened(ch.id);
        }
      }
      _chapters = await _repos!.manga.getMangaChapters(widget.mangaId!);
    }
    if (mounted) _load();
  }

  @override
  void dispose() {
    _flushPageProgress();
    _restoreSystemUI();
    _itemPositionsListener.itemPositions.removeListener(_onWebtoonScroll);
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    _currentPageNotifier.dispose();
    for (final c in _zoomCtrls) {
      c.dispose();
    }
    _zoomCtrls.clear();
    disposePreloadManager();
    super.dispose();
  }

  void _applySystemUI() {
    if (_settings.fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ));
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ));
    }
  }

  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flushPageProgress();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  /// Resolve the sourceId: translate old Mihon numeric IDs to the hex
  /// sourceId used by the Dalvik server cache. Falls back to [widget.sourceId]
  /// when no matching extension is found.
  Future<String> _resolveSourceId() async {
    if (_extensionManager == null) return widget.sourceId;
    final resolved = await _extensionManager!.resolveSourceId(widget.sourceId);
    return resolved.isNotEmpty ? resolved : widget.sourceId;
  }

  Future<void> _load() async {
    try {
      final sourceId = await _resolveSourceId();
      final raw = await _service.getPageList(
        sourceId: sourceId,
        url: widget.chapterUrl,
        memo: _currentChapter?.memo,
      );
      if (!mounted) return;

      final currentCh = _getCurrentChapter();
      if (currentCh == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final pageDataList = raw.asMap().entries.map((e) {
        final imgUrl = e.value['imageUrl'] as String?;
        final rawHeaders = e.value['headers'] as Map?;
        final headers =
            rawHeaders?.map((k, v) => MapEntry(k.toString(), v.toString()));
        return PageData.page(
          mangaPage: MangaPage(
            index: e.key,
            imageUrl: imgUrl ?? (e.value['url'] as String? ?? ''),
            headers: headers,
          ),
          chapter: currentCh,
          pageIndex: e.key,
        );
      }).toList();

      // Initialize the preload manager with the current chapter's pages
      initializePreloadManager(pageDataList, onPagesUpdated: () {
        if (mounted) setState(() {});
      });

      setState(() {
        _zoomCtrls.addAll(
          List.generate(
            pageDataList.length,
            (_) => TransformationController(),
          ),
        );
        _loading = false;
      });

      await _initProgress();
      _proactivePreload();
      _updateBookmarkState();
      if (widget.pageNumber != null) {
        _jumpToPageByNumber(widget.pageNumber!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Returns the _currentChapter, or looks it up if null.
  MangaChapter? _getCurrentChapter() {
    if (_currentChapter != null) return _currentChapter;
    // Fallback: create a minimal chapter for the current URL
    return MangaChapter(
      id: 0,
      mangaId: widget.mangaId ?? 0,
      name: widget.chapterName,
      url: widget.chapterUrl,
      index: 0,
    );
  }

  /// Returns a reading-order list (oldest chapter first, newest chapter last)
  /// by sorting the cached chapters by their [MangaChapter.index] descending.
  ///
  /// Extensions return chapters newest-first, so lowest index = newest chapter.
  /// To get reading order we need the reverse: highest index → oldest chapter.
  /// This is equivalent to mangayomi's getChapterListForReading() which returns
  /// chapters sorted by parsed chapter number, ascending.
  List<MangaChapter> get _readingOrderChapters {
    final sorted = List<MangaChapter>.from(_chapters)
      ..sort((a, b) => b.index.compareTo(a.index));
    return sorted;
  }

  /// Finds the current chapter's position in reading order and returns the
  /// chapter at [position + 1], or null if this is the last chapter.
  /// Same pattern as mangayomi's getNextChapter().
  MangaChapter? _findNextChapter(MangaChapter ch) {
    final list = _readingOrderChapters;
    for (int i = 0; i < list.length; i++) {
      if (list[i].url == ch.url) {
        if (i + 1 < list.length) return list[i + 1];
        return null;
      }
    }
    return null;
  }

  /// Finds the current chapter's position in reading order and returns the
  /// chapter at [position - 1], or null if this is the first chapter.
  /// Same pattern as mangayomi's getPrevChapter().
  MangaChapter? _findPrevChapter(MangaChapter ch) {
    final list = _readingOrderChapters;
    for (int i = 0; i < list.length; i++) {
      if (list[i].url == ch.url) {
        if (i - 1 >= 0) return list[i - 1];
        return null;
      }
    }
    return null;
  }

  Future<void> _loadSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reader_${widget.mangaId}');
    if (raw != null && mounted) {
      try {
        _settings =
            ReaderSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (mounted) _applySystemUI();
  }

  Future<void> _saveSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reader_${widget.mangaId}',
      json.encode(_settings.toJson()),
    );
  }

  Future<void> _initProgress() async {
    if (_currentChapter == null || _pages.isEmpty) return;
    _showNavigationOverlay = true;
    if (_settings.readingMode == ReadingMode.webtoon ||
        _settings.readingMode == ReadingMode.longStrip ||
        _settings.readingMode == ReadingMode.longStripWithGaps) {
      final ch = _currentChapter;
      if (ch == null) return;
      if (ch.lastPageRead > 0) {
        // Find the flat index from the per-chapter page index
        int targetIdx = ch.lastPageRead.clamp(0, _pages.length - 1);
        // If there are multiple chapters loaded, find the right page by
        // matching chapter id + page index
        for (int i = 0; i < _pages.length; i++) {
          if (_pages[i].chapter?.id == ch.id &&
              _pages[i].index == ch.lastPageRead) {
            targetIdx = i;
            break;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _itemScrollCtrl.jumpTo(
              index: targetIdx.clamp(0, _pages.length - 1),
            );
          }
        });
      }
    }
  }

  void _schedulePageSave(int flatIndex) {
    _currentPageNotifier.value = flatIndex;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flushPageProgress);
  }

  void _flushPageProgress() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _saveProgress();
  }

  void _toggleToolbar() => setState(() => _showToolbar = !_showToolbar);

  // ── Scroll listener (continuous modes — webtoon, long strip) ──

  /// Listens for scroll position changes.
  ///
  /// When the user scrolls into a page belonging to a different chapter,
  /// saves progress for the outgoing chapter and swaps the chapter tracking.
  /// This is the same pattern as mangayomi's _readProgressListener().
  void _onWebtoonScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final flatIndex = positions.first.index;
    if (flatIndex >= _pages.length) return;
    if (flatIndex == _currentPageNotifier.value) return;

    final page = _pages[flatIndex];
    if (page.isTransitionPage) return;

    _currentPageNotifier.value = flatIndex;

    // Chapter boundary detection — same as mangayomi:
    // when the visible page's chapter differs from the tracked chapter,
    // flush progress for the old chapter and start tracking the new one.
    if (_currentChapter != null &&
        page.chapter != null &&
        page.chapter!.id != _currentChapter!.id) {
      _flushPageProgress();
      if (mounted) {
        setState(() {
          _currentChapter = page.chapter;
        });
      }
      _updateBookmarkState();
    }

    // ── Next-chapter preload trigger when near the end ──
    final distToEnd = _pages.length - 1 - positions.last.index;
    if (distToEnd <= _pagePreloadAmount && !_isLastPageTransition) {
      _triggerNextChapterPreload();
    }

    _schedulePageSave(flatIndex);
    _updateBookmarkState();
  }

  // ── Page change listener (paged modes — L2R, RTL) ──

  void _onPageChanged(int flatIndex) {
    if (flatIndex >= _pages.length) return;
    HapticFeedback.selectionClick();
    _currentPageNotifier.value = flatIndex;

    final page = _pages[flatIndex];

    // Chapter boundary detection for paged modes
    if (_currentChapter != null &&
        page.chapter != null &&
        page.chapter!.id != _currentChapter!.id) {
      _flushPageProgress();
      if (mounted) {
        setState(() {
          _currentChapter = page.chapter;
        });
      }
      _updateBookmarkState();
    }

    // ── Next-chapter preload trigger when near the end ──
    final distToEnd = _pages.length - 1 - flatIndex;
    if (distToEnd <= _pagePreloadAmount && !_isLastPageTransition) {
      _triggerNextChapterPreload();
    }

    _schedulePageSave(flatIndex);
    _updateBookmarkState();
  }

  void _goToPage(int flatIndex) {
    if (_pages.isEmpty) return;
    HapticFeedback.lightImpact();
    final clamped = flatIndex.clamp(0, _pages.length - 1);
    if (_settings.readingMode == ReadingMode.webtoon ||
        _settings.readingMode == ReadingMode.longStrip ||
        _settings.readingMode == ReadingMode.longStripWithGaps) {
      _itemScrollCtrl.scrollTo(
        index: clamped,
        duration:
            Duration(milliseconds: _settings.animatePageTransition ? 250 : 0),
        curve: Curves.easeOut,
      );
    } else {
      if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(
          clamped,
          duration:
              Duration(milliseconds: _settings.animatePageTransition ? 250 : 0),
          curve: Curves.easeOut,
        );
      }
    }
    _schedulePageSave(clamped);
  }

  void _jumpToPageByNumber(int chapterRelativePage) {
    if (_pages.isEmpty) return;
    final target = _pages.indexWhere((p) {
      if (p.isTransitionPage) return false;
      return p.chapter?.id == _currentChapter?.id &&
          p.mangaPage?.index == chapterRelativePage;
    });
    if (target >= 0) {
      _goToPage(target);
    }
  }

  /// Saves the chapter-relative page index (not the flat list index),
  /// same as mangayomi's setPageIndex().
  Future<void> _saveProgress() async {
    if (_currentChapter == null || _repos == null) return;
    final flatIdx = _currentPageNotifier.value;
    if (flatIdx >= _pages.length) return;
    final page = _pages[flatIdx];
    final chapterRelativeIndex = page.index;
    final chapterId =
        (page.chapter ?? _currentChapter)!.id;
    await _repos!.manga.updateMangaChapterProgress(chapterId, chapterRelativeIndex);

    final ch = page.chapter;
    if (ch != null) {
      final chPages = _pages.where((p) =>
          p.chapter?.id == ch.id && !p.isTransitionPage).length;
      if (chPages > 0 && chapterRelativeIndex >= chPages - 1) {
        await _repos!.manga.markMangaChapterRead(chapterId);
      }
    }

    // Notify history-aware screens that progress changed so they can
    // refresh in real time (the shell-tab screens don't reliably receive
    // RouteAware.didPopNext from this root-level reader route).
    if (mounted) {
      ref.read(historyRevisionProvider.notifier).bump();
    }
  }

  // ── Seamless next-chapter preloading ──

  /// Proactively starts loading the next chapter at reader init.
  void _proactivePreload() {
    _triggerNextChapterPreload();
  }

  /// Fires off next-chapter page fetching if not already in progress.
  Future<void> _triggerNextChapterPreload() async {
    if (_isNextChapterPreloading || _isLastPageTransition) return;
    if (_currentChapter == null) return;

    _isNextChapterPreloading = true;
    try {
      if (!mounted) {
        _isNextChapterPreloading = false;
        return;
      }
      final nextChapter = _findNextChapter(_currentChapter!);
      if (nextChapter == null) {
        // No next chapter — add the end-of-manga transition
        _isNextChapterPreloading = false;
        if (mounted) _addLastPageTransition(_currentChapter!);
        return;
      }
      if (isChapterLoaded(nextChapter)) {
        _isNextChapterPreloading = false;
        return;
      }
      final raw = await _service.getPageList(
        sourceId: await _resolveSourceId(),
        url: nextChapter.url,
        memo: nextChapter.memo,
      );
      if (!mounted) {
        _isNextChapterPreloading = false;
        return;
      }
      final nextPages = raw.asMap().entries.map((e) {
        final imgUrl = e.value['imageUrl'] as String?;
        final rawHeaders = e.value['headers'] as Map?;
        final headers =
            rawHeaders?.map((k, v) => MapEntry(k.toString(), v.toString()));
        return PageData.page(
          mangaPage: MangaPage(
            index: e.key,
            imageUrl: imgUrl ?? (e.value['url'] as String? ?? ''),
            headers: headers,
          ),
          chapter: nextChapter,
        );
      }).toList();

      if (nextPages.isEmpty) {
        _isNextChapterPreloading = false;
        return;
      }

      // Use mixin to preload with memory management
      final success = await preloadNextChapter(nextPages, _currentChapter!);
      if (success && mounted) {
        // Add zoom controllers for new pages
        final newPagesCount = nextPages.length + 1; // +1 for transition page
        setState(() {
          for (int i = 0; i < newPagesCount; i++) {
            _zoomCtrls.add(TransformationController());
          }
        });
      }
      _isNextChapterPreloading = false;
    } catch (_) {
      _isNextChapterPreloading = false;
    }
  }

  void _addLastPageTransition(MangaChapter chap) {
    if (_isLastPageTransition) return;
    if (!mounted || pageCount == 0) return;
    if (_pages.last.isLastChapter) return;

    final added = addLastChapterTransition(chap);
    if (added && mounted) {
      setState(() {
        _isLastPageTransition = true;
        _zoomCtrls.add(TransformationController());
      });
    }
  }

  // ── Chapter navigation ──

  void _navigateToNextChapter() {
    if (widget.mangaId == null || _currentChapter == null) return;

    // If next chapter is preloaded in the flat list, jump to the first
    // page after the transition separator
    for (int i = 0; i < _pages.length; i++) {
      if (_pages[i].isTransitionPage &&
          _pages[i].chapter?.id == _currentChapter!.id) {
        // Jump to the page right after this transition
        if (i + 1 < _pages.length) {
          _goToPage(i + 1);
          return;
        }
      }
    }

    // Fallback: navigate with pushReplacement
    final next = _findNextChapter(_currentChapter!);
    if (next == null) return;
    _saveProgress().then((_) {
      if (mounted) _reloadWithChapter(next);
    });
  }

  void _navigateToPrevChapter() {
    if (widget.mangaId == null || _currentChapter == null) return;
    final prev = _findPrevChapter(_currentChapter!);
    if (prev == null) return;
    _saveProgress().then((_) {
      if (mounted) _reloadWithChapter(prev);
    });
  }

  void _reloadWithChapter(MangaChapter chapter) {
    _saveProgress().then((_) {
      if (!mounted) return;
      context.pushReplacementNamed(
        Routes.mangaReader,
        extra: (
          mangaId: widget.mangaId,
          sourceId: widget.sourceId,
          mangaUrl: widget.mangaUrl,
          chapterUrl: chapter.url,
          chapterName: chapter.name,
        pageNumber: widget.pageNumber,
        ),
      );
    });
  }

  Future<void> _updateBookmarkState() async {
    if (widget.mangaId == null) return;
    if (_pages.isEmpty) return;
    final flatIndex = _currentPageNotifier.value;
    if (flatIndex >= _pages.length) return;
    final page = _pages[flatIndex];
    final chapter = page.chapter;
    if (chapter == null) return;

    final pageNumber = page.mangaPage?.index ?? 0;
    final bookmarked = await ref.read(bookmarksProvider.notifier).isBookmarked(
      widget.mangaId!,
      chapter.id,
      pageNumber,
    );

    if (mounted) {
      setState(() => _isBookmarked = bookmarked);
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.mangaId == null) return;
    if (_pages.isEmpty) return;
    final flatIndex = _currentPageNotifier.value;
    if (flatIndex >= _pages.length) return;
    final page = _pages[flatIndex];
    final chapter = page.chapter;
    if (chapter == null) return;

    final pageNumber = page.mangaPage?.index ?? 0;
    await ref.read(bookmarksProvider.notifier).toggleBookmark(
      bookId: widget.mangaId!,
      chapterId: chapter.id,
      pageNumber: pageNumber,
    );

    await _updateBookmarkState();
  }

  void _showChapterList() {
    if (widget.mangaId == null) return;
    showDialog<MangaChapter>(
      context: context,
      builder: (ctx) => ChapterListDialog(
        mangaId: widget.mangaId!,
        sourceId: widget.sourceId,
        mangaUrl: widget.mangaUrl,
        currentChapterUrl: widget.chapterUrl,
      ),
    ).then((result) {
      if (result != null && mounted) {
        _reloadWithChapter(result);
      }
    });
  }

  void _showSettings() {
    _showNavigationOverlay = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ReaderSettingsSheet(
        settings: _settings,
        onChanged: (s) {
          final oldMode = _settings.readingMode;
          setState(() => _settings = s);
          _saveSettings();
          _applySystemUI();
          if (s.keepScreenOn) {
            WidgetsBinding.instance.scheduleFrame();
          }
          if (oldMode != s.readingMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _initProgress();
            });
          }
        },
      ),
    );
  }

  void _toggleCropBorders() {
    setState(() => _settings.cropBorders = !_settings.cropBorders);
    _saveSettings();
  }

  // ── Page actions ──

  void _retryPage(int index) {
    // No-op: the page will naturally reload from the widget
    setState(() {});
  }

  Future<void> _saveCurrentPage() async {
    final current = _currentPageNotifier.value;
    if (current >= _pages.length) return;
    final page = _pages[current];
    if (page.imageUrl.isEmpty) return;
    try {
      final uri = Uri.parse(page.imageUrl);
      final req = http.MultipartRequest('GET', uri);
      page.headers?.forEach((k, v) => req.headers[k] = v);
      final streamed = await req.send();
      final bytes = await streamed.stream.toBytes();
      if (!mounted) return;
      final file = File(
        '${Directory.systemTemp.path}/page_${current + 1}.jpg',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _shareCurrentPage() {
    final current = _currentPageNotifier.value;
    Clipboard.setData(ClipboardData(text: _pages[current].imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image URL copied to clipboard')),
    );
  }

  void _copyCurrentPage() {
    final current = _currentPageNotifier.value;
    Clipboard.setData(ClipboardData(text: _pages[current].imageUrl));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Image URL copied')));
  }

  void _showLongPressMenu() {
    if (!_settings.showActionsOnLongTap) return;
    final page = _currentPageNotifier.value < _pages.length
        ? _pages[_currentPageNotifier.value]
        : null;
    ImageActionsDialog.show(
      context,
      imageUrl: page?.imageUrl,
      localPath: page?.localPath,
      onSave: _saveCurrentPage,
      onShare: _shareCurrentPage,
      onCopyUrl: _copyCurrentPage,
    );
  }

  // ── Build ──

  ReaderViewProps _viewProps() => ReaderViewProps(
        pages: _pages,
        settings: _settings,
        currentPage: _currentPageNotifier,
        zoomControllers: _zoomCtrls,
        onPageChanged: _onPageChanged,
        onGoToPage: _goToPage,
        onToggleToolbar: _toggleToolbar,
        onLongPress: _showLongPressMenu,
        onRetryPage: _retryPage,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isRtl = _settings.readingMode == ReadingMode.rightToLeft;
    final isWebtoon = _settings.readingMode == ReadingMode.webtoon;
    final isContinuous = isWebtoon ||
        _settings.readingMode == ReadingMode.longStrip ||
        _settings.readingMode == ReadingMode.longStripWithGaps;
    final axis = isContinuous ? Axis.vertical : Axis.horizontal;
    final reverse = isRtl;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveProgress().then((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: OrientationBuilder(
          builder: (context, orientation) {
            final showBookMode =
                _settings.bookMode && orientation == Orientation.landscape;
            final props = _viewProps();
            return Stack(
              children: [
                ColorFilterWidget(
                  brightness: _settings.brightness,
                  contrast: _settings.contrast,
                  saturation: _settings.saturation,
                  tint: _settings.tintColor,
                  tintOpacity: _settings.tintOpacity,
                  child: isContinuous
                      ? MangaImageViewWebtoon(
                          props: props,
                          itemScrollController: _itemScrollCtrl,
                          itemPositionsListener: _itemPositionsListener,
                        )
                      : MangaImageViewPaged(
                          props: props,
                          pageController: _pageCtrl,
                          axis: axis,
                          reverse: reverse,
                          bookMode: showBookMode,
                        ),
                ),

                if (_showNavigationOverlay)
                  NavigationOverlay(
                    onDismiss: () =>
                        setState(() => _showNavigationOverlay = false),
                    navigationLayout: 0,
                  ),

                if (_showToolbar)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleToolbar,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  )
                else if (!_showNavigationOverlay)
                  Positioned.fill(
                    child: isContinuous
                        ? GestureDetector(
                            onTap: _toggleToolbar,
                            onLongPress: _showLongPressMenu,
                            behavior: HitTestBehavior.translucent,
                            child: const SizedBox.expand(),
                          )
                        : ReaderTapZones(props: props),
                  ),

                ReaderAppBar(
                  chapterName: _currentChapter?.name ?? widget.chapterName,
                  isBookmarked: _isBookmarked,
                  isVisible: _showToolbar,
                  onClose: () {
                    _saveProgress().then((_) {
                      if (context.mounted) Navigator.of(context).pop();
                    });
                  },
                  onBookmarkToggle: _toggleBookmark,
                  onChapterList: _showChapterList,
                ),

                ReaderBottomBar(
                  pageListenable: _currentPageNotifier,
                  totalPages: _pages.length,
                  showNavigator: _settings.showPageNavigator,
                  onPageChanged: _goToPage,
                  onSettings: _showSettings,
                  onCropToggle: _toggleCropBorders,
                  onPreviousChapter: _navigateToPrevChapter,
                  onNextChapter: _navigateToNextChapter,
                  isVisible: _showToolbar,
                ),

                PageIndicator(
                  pageListenable: _currentPageNotifier,
                  totalPages: _pages.length,
                  isVisible: _showToolbar,
                  showPageNumbers: _settings.showPageNumber,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
