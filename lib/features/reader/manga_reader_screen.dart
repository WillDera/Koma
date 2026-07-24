import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/database_service.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/models/manga_page.dart';
import '../../core/models/manga_chapter.dart';
import '../../theme/app_theme.dart';
import 'reader_settings_sheet.dart';
import 'widgets/reader_app_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/page_indicator.dart';
import 'widgets/navigation_overlay.dart';
import 'widgets/chapter_list_dialog.dart';

/// A page that knows which chapter it belongs to — the key to seamless
/// multi-chapter reading (same pattern as mangayomi's UChapDataPreload).
class _ChapterPage extends MangaPage {
  final int chapterId;
  final String chapterName;
  _ChapterPage({
    required super.index,
    required super.imageUrl,
    required this.chapterId,
    required this.chapterName,
    super.headers,
    super.localPath,
  });
}

class MangaReaderScreen extends StatefulWidget {
  final int? mangaId;
  final String sourceId;
  final String mangaUrl;
  final String chapterUrl;
  final String chapterName;

  const MangaReaderScreen({
    super.key,
    this.mangaId,
    required this.sourceId,
    required this.mangaUrl,
    required this.chapterUrl,
    required this.chapterName,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen>
    with WidgetsBindingObserver {
  final _service = KeiyoushiService();
  DatabaseService? _db;
  List<MangaPage> _pages = [];
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
  bool _isPreloadingNext = false;
  final List<TransformationController> _zoomCtrls = [];
  int? _chapterId;
  Timer? _saveTimer;

  ReaderSettings _settings = ReaderSettings();

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    WidgetsBinding.instance.addObserver(this);
    _itemPositionsListener.itemPositions.addListener(_onWebtoonScroll);
    _loadBookmark();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadSettings();
    if (widget.mangaId != null && _db != null) {
      final ch = await _db!.getMangaChapterByUrl(widget.mangaId!, widget.chapterUrl);
      if (ch != null && mounted) {
        _chapterId = ch.id;
        if (!ch.isOpened) _db!.markMangaChapterOpened(ch.id);
      }
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
    for (final c in _zoomCtrls) { c.dispose(); }
    super.dispose();
  }

  void _applySystemUI() {
    if (_settings.fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.black,
      ));
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.black,
      ));
    }
  }

  void _restoreSystemUI() { SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) { _flushPageProgress(); }
    else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) { WidgetsBinding.instance.scheduleFrame(); }
  }

  Future<void> _load() async {
    try {
      final raw = await _service.getPageList(
        sourceId: widget.sourceId, url: widget.chapterUrl,
      );
      final pages = raw.asMap().entries.map((e) {
        final imgUrl = e.value['imageUrl'] as String?;
        final rawHeaders = e.value['headers'] as Map?;
        final headers = rawHeaders?.map((k, v) => MapEntry(k.toString(), v.toString()));
        return _ChapterPage(
          index: e.key,
          imageUrl: imgUrl ?? (e.value['url'] as String? ?? ''),
          headers: headers,
          chapterId: _chapterId ?? 0,
          chapterName: widget.chapterName,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _zoomCtrls.addAll(List.generate(pages.length, (_) => TransformationController()));
        _loading = false;
      });
      await _initProgress();
      _preloadNextChapter();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reader_${widget.mangaId}');
    if (raw != null && mounted) {
      try { _settings = ReaderSettings.fromJson(json.decode(raw) as Map<String, dynamic>); } catch (_) {}
    }
    if (mounted) _applySystemUI();
  }

  Future<void> _saveSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_${widget.mangaId}', json.encode(_settings.toJson()));
  }

  Future<void> _initProgress() async {
    if (_chapterId == null) return;
    _showNavigationOverlay = true;
    if (_settings.readingMode == ReadingMode.webtoon) {
      final db = _db;
      if (widget.mangaId == null || db == null) return;
      final ch = await db.getMangaChapterByUrl(widget.mangaId!, widget.chapterUrl);
      if (ch == null || !mounted) return;
      if (ch.lastPageRead > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { _itemScrollCtrl.jumpTo(index: ch.lastPageRead.clamp(0, _pages.length - 1)); }
        });
      }
    }
  }

  void _schedulePageSave(int page) {
    _currentPageNotifier.value = page;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flushPageProgress);
  }

  void _flushPageProgress() { _saveTimer?.cancel(); _saveTimer = null; _saveProgress(); }

  void _toggleToolbar() => setState(() => _showToolbar = !_showToolbar);

  /// Tracks scroll position. When user scrolls into a different chapter's
  /// pages, saves progress for the old chapter and starts tracking the new one.
  void _onWebtoonScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions.first.index;
    if (first == _currentPageNotifier.value || first >= _pages.length) return;
    _currentPageNotifier.value = first;

    final page = _pages[first];
    if (page is _ChapterPage && _chapterId != null && page.chapterId != _chapterId) {
      _flushPageProgress();
      _chapterId = page.chapterId;
      _loadBookmark();
    }
    _schedulePageSave(first);
  }

  /// Saves the page's own .index (0-based per chapter), not the flat list index.
  Future<void> _saveProgress() async {
    if (_chapterId == null || _db == null) return;
    final flatIdx = _currentPageNotifier.value;
    final page = flatIdx < _pages.length ? _pages[flatIdx] : null;
    final pageIndex = page is _ChapterPage ? page.index : flatIdx;
    await _db!.updateMangaChapterProgress(_chapterId!, pageIndex);
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    _currentPageNotifier.value = i;
    _schedulePageSave(i);
  }

  void _goToPage(int i) {
    HapticFeedback.lightImpact();
    final clamped = i.clamp(0, _pages.length - 1);
    if (_settings.readingMode == ReadingMode.webtoon) {
      _itemScrollCtrl.scrollTo(
        index: clamped, duration: Duration(milliseconds: _settings.animatePageTransition ? 250 : 0),
        curve: Curves.easeOut,
      );
    } else {
      if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(
          clamped, duration: Duration(milliseconds: _settings.animatePageTransition ? 250 : 0),
          curve: Curves.easeOut,
        );
      }
    }
    _schedulePageSave(clamped);
  }

  // ── Seamless next-chapter preload (mangayomi pattern) ──

  void _preloadNextChapter() {
    if (_isPreloadingNext || widget.mangaId == null || _chapterId == null) return;
    // Already preloaded?
    if (_pages.any((p) => p is _ChapterPage && p.chapterId != _chapterId)) return;

    _isPreloadingNext = true;
    _db!.getMangaChapters(widget.mangaId!).then((chapters) {
      if (!mounted) { _isPreloadingNext = false; return; }
      // Find next chapter by matching index+1
      MangaChapter? currentCh;
      for (final c in chapters) { if (c.url == widget.chapterUrl) { currentCh = c; break; } }
      if (currentCh == null) { _isPreloadingNext = false; return; }

      MangaChapter? next;
      for (final c in chapters) { if (c.index == currentCh.index + 1) { next = c; break; } }
      if (next == null) { _isPreloadingNext = false; return; }

      _service.getPageList(sourceId: widget.sourceId, url: next.url).then((raw) {
        _isPreloadingNext = false;
        if (!mounted) return;
        final nextPages = raw.asMap().entries.map((e) {
          final imgUrl = e.value['imageUrl'] as String?;
          final rawHeaders = e.value['headers'] as Map?;
          final headers = rawHeaders?.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _ChapterPage(
            index: e.key, imageUrl: imgUrl ?? (e.value['url'] as String? ?? ''),
            headers: headers, chapterId: next!.id, chapterName: next.name,
          );
        }).toList();
        if (nextPages.isEmpty) return;

        final newZooms = List<TransformationController>.from(_zoomCtrls);
        for (int i = _pages.length; i < _pages.length + nextPages.length; i++) {
          newZooms.add(TransformationController());
        }
        if (!mounted) return;
        setState(() {
          _pages = [..._pages, ...nextPages];
          _zoomCtrls
            ..clear()
            ..addAll(newZooms);
        });
      }).catchError((_) { _isPreloadingNext = false; });
    }).catchError((_) { _isPreloadingNext = false; });
  }

  void _navigateToNextChapter() {
    for (int i = _currentPageNotifier.value + 1; i < _pages.length; i++) {
      if (_pages[i] is _ChapterPage && (_pages[i] as _ChapterPage).chapterId != _chapterId) {
        _goToPage(i); return;
      }
    }
    // Not preloaded — reload with the actual next chapter
    if (widget.mangaId == null) return;
    _db!.getMangaChapters(widget.mangaId!).then((chapters) {
      if (!mounted) return;
      MangaChapter? currentCh;
      for (final c in chapters) { if (c.url == widget.chapterUrl) { currentCh = c; break; } }
      if (currentCh == null) return;
      MangaChapter? next;
      for (final c in chapters) { if (c.index == currentCh.index + 1) { next = c; break; } }
      if (next == null) return;
      final nextUrl = next.url;
      final nextName = next.name;
      _saveProgress().then((_) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
          MangaReaderScreen(mangaId: widget.mangaId, sourceId: widget.sourceId,
            mangaUrl: widget.mangaUrl, chapterUrl: nextUrl, chapterName: nextName,
          )
        ));
      });
    });
  }

  void _navigateToPrevChapter() {
    for (int i = _currentPageNotifier.value - 1; i >= 0; i--) {
      if (_pages[i] is _ChapterPage && (_pages[i] as _ChapterPage).chapterId != _chapterId) {
        _goToPage(i); return;
      }
    }
  }

  void _reloadWithChapter(MangaChapter chapter) {
    _saveProgress().then((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        MangaReaderScreen(mangaId: widget.mangaId, sourceId: widget.sourceId,
          mangaUrl: widget.mangaUrl, chapterUrl: chapter.url, chapterName: chapter.name,
        )
      ));
    });
  }

  void _loadBookmark() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('reader_${widget.mangaId}_${widget.chapterUrl}_bk');
    if (saved != null && mounted) { setState(() => _isBookmarked = saved); }
  }

  void _toggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    if (widget.mangaId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reader_${widget.mangaId}_${widget.chapterUrl}_bk', _isBookmarked);
    }
  }

  void _showChapterList() {
    if (widget.mangaId == null) return;
    showDialog<MangaChapter>(context: context, builder: (ctx) =>
      ChapterListDialog(mangaId: widget.mangaId!, sourceId: widget.sourceId,
        mangaUrl: widget.mangaUrl, currentChapterUrl: widget.chapterUrl,
      ),
    ).then((result) {
      if (result != null && mounted) { _reloadWithChapter(result); }
    });
  }

  void _showSettings() {
    _showNavigationOverlay = false;
    showModalBottomSheet(context: context, backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => ReaderSettingsSheet(settings: _settings, onChanged: (s) {
        final oldMode = _settings.readingMode;
        setState(() => _settings = s);
        _saveSettings();
        _applySystemUI();
        if (s.keepScreenOn) { WidgetsBinding.instance.scheduleFrame(); }
        if (oldMode != s.readingMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _initProgress(); });
        }
      }),
    );
  }

  void _toggleCropBorders() { setState(() => _settings.cropBorders = !_settings.cropBorders); _saveSettings(); }

  // ── Page actions ──

  void _retryPage(int index) {
    setState(() { _pages[index] = _ChapterPage(
      index: index, imageUrl: _pages[index].imageUrl,
      headers: _pages[index].headers, chapterId: _chapterId ?? 0, chapterName: widget.chapterName,
    ); });
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
      final file = File('${Directory.systemTemp.path}/page_${current + 1}.jpg');
      await file.writeAsBytes(bytes);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${file.path}'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'))); }
    }
  }

  void _shareCurrentPage() {
    final current = _currentPageNotifier.value;
    Clipboard.setData(ClipboardData(text: _pages[current].imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL copied to clipboard')));
  }

  void _copyCurrentPage() {
    final current = _currentPageNotifier.value;
    Clipboard.setData(ClipboardData(text: _pages[current].imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL copied')));
  }

  void _showLongPressMenu() {
    if (!_settings.showActionsOnLongTap) return;
    showModalBottomSheet(context: context, backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Save page'),
          onTap: () { Navigator.pop(ctx); _saveCurrentPage(); }),
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share page'),
          onTap: () { Navigator.pop(ctx); _shareCurrentPage(); }),
        ListTile(leading: const Icon(Icons.content_copy), title: const Text('Copy page URL'),
          onTap: () { Navigator.pop(ctx); _copyCurrentPage(); }),
      ])),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    if (_error != null) {
      return Scaffold(backgroundColor: Colors.black, body: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () { setState(() { _error = null; _loading = true; }); _load(); },
            icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ])),
      ));
    }

    final isRtl = _settings.readingMode == ReadingMode.rightToLeft;
    final isWebtoon = _settings.readingMode == ReadingMode.webtoon;
    final isVertical = isWebtoon || _settings.readingMode == ReadingMode.longStrip || _settings.readingMode == ReadingMode.longStripWithGaps;
    final axis = isVertical ? Axis.vertical : Axis.horizontal;
    final reverse = isRtl;

    return PopScope(canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveProgress().then((_) { if (context.mounted) Navigator.of(context).pop(); });
      },
      child: Scaffold(backgroundColor: Colors.black,
        body: OrientationBuilder(builder: (context, orientation) {
          final showBookMode = _settings.bookMode && orientation == Orientation.landscape;
          return Stack(children: [
            isWebtoon ? _buildWebtoonPages() : showBookMode
              ? _buildBookModePages(axis, reverse)
              : PageView.builder(controller: _pageCtrl, scrollDirection: axis, reverse: reverse,
                itemCount: _pages.length, onPageChanged: _onPageChanged,
                itemBuilder: (_, i) => _buildPage(i)),

            if (_showNavigationOverlay)
              NavigationOverlay(onDismiss: () => setState(() => _showNavigationOverlay = false), navigationLayout: 0),

            if (_showToolbar)
              Positioned.fill(child: GestureDetector(onTap: _toggleToolbar, behavior: HitTestBehavior.translucent, child: const SizedBox.expand()))
            else if (!_showNavigationOverlay)
              Positioned.fill(child: _buildTapZones()),

            ReaderAppBar(chapterName: widget.chapterName, isBookmarked: _isBookmarked, isVisible: _showToolbar,
              onClose: () { _saveProgress().then((_) { if (context.mounted) Navigator.of(context).pop(); }); },
              onBookmarkToggle: _toggleBookmark, onChapterList: _showChapterList),

            ReaderBottomBar(pageListenable: _currentPageNotifier, totalPages: _pages.length,
              showNavigator: _settings.showPageNavigator, onPageChanged: _goToPage,
              onSettings: _showSettings, onCropToggle: _toggleCropBorders,
              onPreviousChapter: _navigateToPrevChapter, onNextChapter: _navigateToNextChapter, isVisible: _showToolbar),

            PageIndicator(pageListenable: _currentPageNotifier, totalPages: _pages.length,
              isVisible: _showToolbar, showPageNumbers: _settings.showPageNumber),
          ]);
        }),
      ),
    );
  }

  Widget _buildTapZones() {
    switch (_settings.tapZones) {
      case TapZoneMode.leftTopRightBottom:
        return LayoutBuilder(builder: (_, constraints) => Stack(children: [
          Positioned.fill(child: ClipPath(clipper: const _TopLeftClipper(), child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value - 1), onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent))),
          Positioned.fill(child: ClipPath(clipper: const _BottomRightClipper(), child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value + 1), onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent))),
        ]));
      case TapZoneMode.leftRight:
        return Row(children: [
          Expanded(child: GestureDetector(onTap: () => _goToPage(_currentPageNotifier.value - 1),
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Expanded(child: GestureDetector(onTap: _toggleToolbar,
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Expanded(child: GestureDetector(onTap: () => _goToPage(_currentPageNotifier.value + 1),
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
        ]);
      case TapZoneMode.leftCenterRight:
        return Row(children: [
          Expanded(flex: 2, child: GestureDetector(onTap: () => _goToPage(_currentPageNotifier.value - 1),
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Expanded(flex: 6, child: GestureDetector(onTap: _toggleToolbar,
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Expanded(flex: 2, child: GestureDetector(onTap: () => _goToPage(_currentPageNotifier.value + 1),
            onLongPress: _showLongPressMenu, behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
        ]);
    }
  }

  Widget _buildWebtoonPages() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollCtrl,
      itemPositionsListener: _itemPositionsListener,
      scrollDirection: Axis.vertical, itemCount: _pages.length + 1, minCacheExtent: 2000,
      itemBuilder: (context, i) {
        if (i == _pages.length) { return const SizedBox(height: 200); } // bottom spacer

        final page = _pages[i];
        if (i > 0 && _pages[i - 1] is _ChapterPage && page is _ChapterPage &&
            (_pages[i - 1] as _ChapterPage).chapterId != page.chapterId) {
          return Column(children: [
            Container(height: 40, color: const Color(0xFF1a1a1a), alignment: Alignment.center,
              child: Text('▬ End of chapter ▬',
                style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2))),
            _buildWebtoonImage(page, i),
          ]);
        }
        return _buildWebtoonImage(page, i);
      },
    );
  }

  Widget _buildWebtoonImage(MangaPage page, int flatIndex) {
    return Image(
      image: page.localPath != null
          ? FileImage(File(page.localPath!))
          : NetworkImage(page.imageUrl, headers: page.headers),
      key: page is _ChapterPage
          ? ValueKey('p${(page as _ChapterPage).chapterId}-${page.index}')
          : ValueKey('p-img-$flatIndex'),
      fit: BoxFit.contain,
      width: double.infinity,
      loadingBuilder: (_, child, progress) =>
          progress != null
              ? const AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator(color: Colors.white54)))
              : child,
      errorBuilder: (_, __, ___) => const AspectRatio(aspectRatio: 16/9, child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48))),
    );
  }

  Widget _buildPage(int index) {
    if (index >= _pages.length) return const SizedBox();
    final page = _pages[index];
    final zc = index < _zoomCtrls.length ? _zoomCtrls[index] : TransformationController();
    final padding = _settings.sidePadding;
    final hPad = (MediaQuery.of(context).size.width * padding) / 2;
    final vPad = (MediaQuery.of(context).size.height * padding) / 2;

    Widget imageWidget = page.localPath != null
        ? Image.file(File(page.localPath!), fit: _settings.cropBorders ? BoxFit.cover : BoxFit.contain,
            width: double.infinity, height: double.infinity,
            errorBuilder: (_, _, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.broken_image, color: Colors.white38, size: 48), const SizedBox(height: 8),
              TextButton.icon(onPressed: () => _retryPage(index), icon: const Icon(Icons.refresh, color: Colors.white54),
                label: const Text('Retry', style: TextStyle(color: Colors.white54))),
            ])))
        : Image.network(page.imageUrl, headers: page.headers, fit: _settings.cropBorders ? BoxFit.cover : BoxFit.contain,
            width: double.infinity, height: double.infinity,
            loadingBuilder: (_, child, progress) => progress != null
              ? const Center(child: CircularProgressIndicator(color: Colors.white54)) : child,
            errorBuilder: (_, _, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.broken_image, color: Colors.white38, size: 48), const SizedBox(height: 8),
              TextButton.icon(onPressed: () => _retryPage(index), icon: const Icon(Icons.refresh, color: Colors.white54),
                label: const Text('Retry', style: TextStyle(color: Colors.white54))),
            ])));

    if (_settings.disableDoubleTap && _settings.disableZoomOut) {
      return Padding(padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad), child: imageWidget);
    }
    return GestureDetector(
      onDoubleTap: _settings.disableDoubleTap ? null : () {
        final matrix = zc.value;
        if (matrix.getMaxScaleOnAxis() > 1.1) { zc.value = Matrix4.identity(); }
        else { zc.value = Matrix4.identity()..scale(2.0); }
      },
      child: InteractiveViewer(transformationController: zc, minScale: _settings.disableZoomOut ? 1.0 : 0.5, maxScale: 5.0,
        child: Padding(padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad), child: imageWidget)),
    );
  }

  Widget _buildBookModePages(Axis axis, bool reverse) {
    return PageView.builder(controller: _pageCtrl, scrollDirection: axis, reverse: reverse,
      itemCount: (_pages.length / 2).ceil(), onPageChanged: (i) => _onPageChanged(i * 2),
      itemBuilder: (_, spreadIndex) {
        final leftIdx = spreadIndex * 2;
        final rightIdx = leftIdx + 1;
        return Row(children: [
          Expanded(child: leftIdx < _pages.length ? _buildPage(leftIdx) : const SizedBox()),
          Container(width: 1, color: Colors.white12),
          Expanded(child: rightIdx < _pages.length ? _buildPage(rightIdx) : const SizedBox()),
        ]);
      },
    );
  }
}

class _TopLeftClipper extends CustomClipper<Path> {
  const _TopLeftClipper();
  @override Path getClip(Size size) => Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(0, size.height)..close();
  @override bool shouldReclip(_) => false;
}

class _BottomRightClipper extends CustomClipper<Path> {
  const _BottomRightClipper();
  @override Path getClip(Size size) => Path()..moveTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
  @override bool shouldReclip(_) => false;
}
