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
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _loadSettings();
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

  Future<void> _load() async {
    try {
      // Check for locally downloaded files first
      final localUrls = await _service.getLocalPages(
        sourceId: widget.sourceId,
        mangaUrl: widget.mangaUrl,
        chapterUrl: widget.chapterUrl,
      );
      if (localUrls.isNotEmpty) {
        final pages = localUrls.asMap().entries.map((e) => MangaPage(
          index: e.key,
          imageUrl: e.value,
          localPath: e.value,
        )).toList();
        if (!mounted) return;
        setState(() {
          _pages = pages;
          _zoomCtrls.addAll(List.generate(pages.length, (_) => TransformationController()));
          _loading = false;
        });
        await _initProgress();
        return;
      }

      final raw = await _service.getPageList(
        sourceId: widget.sourceId,
        url: widget.chapterUrl,
      );
      final pages = raw.asMap().entries.map((e) {
        final imgUrl = e.value['imageUrl'] as String?;
        final rawHeaders = e.value['headers'] as Map?;
        final headers = rawHeaders?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        return MangaPage(
          index: e.key,
          imageUrl: imgUrl ?? (e.value['url'] as String? ?? ''),
          headers: headers,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _zoomCtrls
            .addAll(List.generate(pages.length, (_) => TransformationController()));
        _loading = false;
      });
      await _initProgress();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'reader_${widget.mangaId}';
    final raw = prefs.getString(key);
    if (raw != null && mounted) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        _settings = ReaderSettings.fromJson(map);
      } catch (_) {}
    }
    if (mounted) _applySystemUI();
  }

  Future<void> _saveSettings() async {
    if (widget.mangaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_${widget.mangaId}', json.encode(_settings.toJson()));
  }

  Future<void> _initProgress() async {
    if (widget.mangaId == null || _db == null) return;
    final ch = await _db!.getMangaChapterByUrl(widget.mangaId!, widget.chapterUrl);
    if (ch == null || !mounted) return;
    _chapterId = ch.id;
    _showNavigationOverlay = true;
    if (!ch.isOpened) {
      _db!.markMangaChapterOpened(ch.id);
    }
    final isWebtoon = _settings.readingMode == ReadingMode.webtoon;
    if (isWebtoon && ch.lastPageRead > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _itemScrollCtrl.jumpTo(index: ch.lastPageRead.clamp(0, _pages.length - 1));
        }
      });
    } else if (!isWebtoon) {
      final lp = ch.lastPageRead;
      if (lp > 0 && lp < _pages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goToPage(lp);
        });
      }
    }
  }

  void _schedulePageSave(int page) {
    // Only update the notifier — do NOT call setState. A setState here
    // would rebuild the whole tree, recreating the ListView.builder and
    // every Image inside it, which the user perceives as "screens reload
    // and the panel jumps to the top" when they scroll back up.
    _currentPageNotifier.value = page;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flushPageProgress);
  }

  Future<void> _saveProgress() async {
    if (_chapterId == null || _db == null) return;
    final page = _currentPageNotifier.value;
    await _db!.updateMangaChapterProgress(_chapterId!, page);
    if (page >= _pages.length - 1) {
      await _db!.markMangaChapterRead(_chapterId!);
    }
  }

  void _flushPageProgress() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _saveProgress();
  }

  void _toggleToolbar() => setState(() => _showToolbar = !_showToolbar);

  void _onWebtoonScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions.first.index;
    if (first != _currentPageNotifier.value) {
      _schedulePageSave(first);
    }
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    _schedulePageSave(i);
  }

  void _goToPage(int i) {
    HapticFeedback.lightImpact();
    final clamped = i.clamp(0, _pages.length - 1);
    if (_settings.readingMode == ReadingMode.webtoon) {
      _itemScrollCtrl.scrollTo(
        index: clamped,
        duration: Duration(
            milliseconds: _settings.animatePageTransition ? 250 : 0),
        curve: Curves.easeOut,
      );
    } else {
      if (_pageCtrl.hasClients) {
        _pageCtrl.animateToPage(
          clamped,
          duration: Duration(
              milliseconds: _settings.animatePageTransition ? 250 : 0),
          curve: Curves.easeOut,
        );
      }
    }
    _schedulePageSave(clamped);
  }

  void _retryPage(int index) {
    setState(() {
      _pages[index] = MangaPage(
        index: index,
        imageUrl: _pages[index].imageUrl,
        headers: _pages[index].headers,
      );
    });
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
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/page_${current + 1}.jpg');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image URL copied')),
    );
  }

  void _showLongPressMenu() {
    if (!_settings.showActionsOnLongTap) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Save page'),
              onTap: () {
                Navigator.pop(ctx);
                _saveCurrentPage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share page'),
              onTap: () {
                Navigator.pop(ctx);
                _shareCurrentPage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy page URL'),
              onTap: () {
                Navigator.pop(ctx);
                _copyCurrentPage();
              },
            ),
          ],
        ),
      ),
    );
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
              if (!mounted) return;
              _initProgress();
            });
          }
        },
      ),
    );
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
        // Navigate to selected chapter — in a real app this would
        // reload the reader with the new chapter. For now just
        // show the chapter name.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigating to ${result.name}')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                Text(_error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center),
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

    // Determine page view axis and scroll direction
    final isRtl = _settings.readingMode == ReadingMode.rightToLeft;
    final isWebtoon = _settings.readingMode == ReadingMode.webtoon;
    final isVertical = isWebtoon ||
        _settings.readingMode == ReadingMode.longStrip ||
        _settings.readingMode == ReadingMode.longStripWithGaps;

    final axis = isVertical ? Axis.vertical : Axis.horizontal;
    final reverse = isRtl;

    // Orientation lock
    final orientations = <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];
    if (_settings.rotationMode == RotationMode.landscape) {
      orientations.addAll([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else if (_settings.rotationMode == RotationMode.free) {
      orientations.addAll([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }

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
          final isLandscape = orientation == Orientation.landscape;
          final showBookMode = _settings.bookMode && isLandscape;

          return Stack(
            children: [
              // Page viewer (bottom layer)
              isWebtoon
                  ? _buildWebtoonPages()
                  : showBookMode
                      ? _buildBookModePages(axis, reverse)
                      : PageView.builder(
                          controller: _pageCtrl,
                          scrollDirection: axis,
                          reverse: reverse,
                          itemCount: _pages.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (_, i) => _buildPage(i),
                        ),
              // Navigation overlay (shown on first open)
              if (_showNavigationOverlay)
                NavigationOverlay(
                  onDismiss: () => setState(() => _showNavigationOverlay = false),
                  navigationLayout: 0,
                ),
              // Tap zones for navigation (on TOP of page viewer)
              if (!_showToolbar && !_showNavigationOverlay)
                Positioned.fill(child: _buildTapZones()),
              // New redesigned ReaderAppBar
              ReaderAppBar(
                chapterName: widget.chapterName,
                isBookmarked: false,
                isVisible: _showToolbar,
                onClose: () {
                  _saveProgress().then((_) {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                },
                onBookmarkToggle: () {},
                onChapterList: _showChapterList,
              ),
              // New redesigned ReaderBottomBar
              ReaderBottomBar(
                pageListenable: _currentPageNotifier,
                totalPages: _pages.length,
                showNavigator: _settings.showPageNavigator,
                onPageChanged: _goToPage,
                onSettings: _showSettings,
                isVisible: _showToolbar,
              ),
              // New PageIndicator (always shown when UI hidden)
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

  Widget _buildTapZones() {
    switch (_settings.tapZones) {
      case TapZoneMode.leftTopRightBottom:
        return LayoutBuilder(
          builder: (_, constraints) => Stack(
            children: [
              Positioned.fill(
                child: ClipPath(
                  clipper: const _TopLeftClipper(),
                  child: GestureDetector(
                    onTap: () => _goToPage(_currentPageNotifier.value - 1),
                    onLongPress: _showLongPressMenu,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: const _BottomRightClipper(),
                  child: GestureDetector(
                    onTap: () => _goToPage(_currentPageNotifier.value + 1),
                    onLongPress: _showLongPressMenu,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
            ],
          ),
        );
      case TapZoneMode.leftRight:
        return Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value - 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
          Expanded(child: GestureDetector(
            onTap: _toggleToolbar,
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
          Expanded(child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value + 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
        ]);
      case TapZoneMode.leftCenterRight:
        return Row(children: [
          Expanded(flex: 2, child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value - 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
          Expanded(flex: 6, child: GestureDetector(
            onTap: _toggleToolbar,
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
          Expanded(flex: 2, child: GestureDetector(
            onTap: () => _goToPage(_currentPageNotifier.value + 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
        ]);
    }
  }

  Widget _buildWebtoonPages() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollCtrl,
      itemPositionsListener: _itemPositionsListener,
      scrollDirection: Axis.vertical,
      itemCount: _pages.length,
      minCacheExtent: 2000,
      itemBuilder: (context, i) {
        final page = _pages[i];
        return Image(
          image: page.localPath != null
              ? FileImage(File(page.localPath!))
              : NetworkImage(page.imageUrl, headers: page.headers),
          key: ValueKey('webtoon-${page.index}'),
          fit: BoxFit.contain,
          width: double.infinity,
          loadingBuilder: (_, child, progress) =>
              progress != null
                  ? const AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator(color: Colors.white54)))
                  : child,
          errorBuilder: (_, __, ___) => const AspectRatio(aspectRatio: 16/9, child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48))),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    if (index >= _pages.length) return const SizedBox();
    final page = _pages[index];
    final zc = index < _zoomCtrls.length
        ? _zoomCtrls[index]
        : TransformationController();

    final padding = _settings.sidePadding;
    final horizontalPadding = (MediaQuery.of(context).size.width * padding) / 2;
    final verticalPadding = (MediaQuery.of(context).size.height * padding) / 2;

    Widget imageWidget = page.localPath != null
        ? Image.file(
            File(page.localPath!),
            fit: _settings.cropBorders ? BoxFit.cover : BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _retryPage(index),
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    label: const Text('Retry', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          )
        : Image.network(
      page.imageUrl,
      headers: page.headers,
      fit: _settings.cropBorders ? BoxFit.cover : BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) =>
          progress != null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white54))
              : child,
      errorBuilder: (_, _, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _retryPage(index),
              icon: const Icon(Icons.refresh, color: Colors.white54),
              label:
                  const Text('Retry', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );

    if (_settings.disableDoubleTap && _settings.disableZoomOut) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: imageWidget,
      );
    }

    return GestureDetector(
      onDoubleTap: _settings.disableDoubleTap
          ? null
          : () {
              final matrix = zc.value;
              final scale = matrix.getMaxScaleOnAxis();
              if (scale > 1.1) {
                zc.value = Matrix4.identity();
              } else {
                zc.value = Matrix4.identity()..scale(2.0);
              }
            },
      child: InteractiveViewer(
        transformationController: zc,
        minScale: _settings.disableZoomOut ? 1.0 : 0.5,
        maxScale: 5.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildBookModePages(Axis axis, bool reverse) {
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: axis,
      reverse: reverse,
      itemCount: (_pages.length / 2).ceil(),
      onPageChanged: (i) => _onPageChanged(i * 2),
      itemBuilder: (_, spreadIndex) {
        final leftIdx = spreadIndex * 2;
        final rightIdx = leftIdx + 1;
        return Row(
          children: [
            Expanded(child: leftIdx < _pages.length ? _buildPage(leftIdx) : const SizedBox()),
            Container(width: 1, color: Colors.white12),
            Expanded(child: rightIdx < _pages.length ? _buildPage(rightIdx) : const SizedBox()),
          ],
        );
      },
    );
  }
}

// ── Tap zone clippers ──────────────────────────────────────────────────
class _TopLeftClipper extends CustomClipper<Path> {
  const _TopLeftClipper();
  @override
  Path getClip(Size size) => Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(0, size.height)..close();
  @override
  bool shouldReclip(_) => false;
}

class _BottomRightClipper extends CustomClipper<Path> {
  const _BottomRightClipper();
  @override
  Path getClip(Size size) => Path()..moveTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
  @override
  bool shouldReclip(_) => false;
}
