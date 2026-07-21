import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/services/keiyoushi_service.dart';
import '../../core/models/manga_page.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import 'reader_settings_sheet.dart';

class MangaReaderScreen extends StatefulWidget {
  final String sourceId;
  final String mangaUrl;
  final String chapterUrl;
  final String chapterName;

  const MangaReaderScreen({
    super.key,
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
  List<MangaPage> _pages = [];
  bool _loading = true;
  String? _error;
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _showToolbar = false;
  final List<TransformationController> _zoomCtrls = [];

  ReaderSettings _settings = ReaderSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    for (final c in _zoomCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _toggleToolbar() => setState(() => _showToolbar = !_showToolbar);

  void _onPageChanged(int i) => setState(() => _currentPage = i);

  void _goToPage(int i) {
    final clamped = i.clamp(0, _pages.length - 1);
    _pageCtrl.animateToPage(clamped,
        duration: Duration(milliseconds: _settings.animatePageTransition ? 250 : 0),
        curve: Curves.easeOut);
    setState(() => _currentPage = clamped);
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
    if (_currentPage >= _pages.length) return;
    final page = _pages[_currentPage];
    if (page.imageUrl.isEmpty) return;
    try {
      final uri = Uri.parse(page.imageUrl);
      final req = http.MultipartRequest('GET', uri);
      page.headers?.forEach((k, v) => req.headers[k] = v);
      final streamed = await req.send();
      final bytes = await streamed.stream.toBytes();
      if (!mounted) return;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/page_${_currentPage + 1}.jpg');
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
    Clipboard.setData(ClipboardData(text: _pages[_currentPage].imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image URL copied to clipboard')),
    );
  }

  void _copyCurrentPage() {
    Clipboard.setData(ClipboardData(text: _pages[_currentPage].imageUrl));
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
          setState(() => _settings = s);
          if (s.keepScreenOn) {
            WidgetsBinding.instance.scheduleFrame();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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

    return Scaffold(
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
              // Tap zones for navigation (on TOP of page viewer)
              if (!_showToolbar)
                Positioned.fill(child: _buildTapZones()),
              // Toolbar overlay
              if (_showToolbar) ...[
                GestureDetector(
                  onTap: _toggleToolbar,
                  child: Container(color: Colors.black26),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ReaderTopBar(
                    chapterName: widget.chapterName,
                    onClose: () => Navigator.pop(context),
                    onSave: _saveCurrentPage,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: _ReaderBottomBar(
                      currentPage: _currentPage,
                      totalPages: _pages.length,
                      showNavigator: _settings.showPageNavigator,
                      onPageChanged: _goToPage,
                      onSettings: _showSettings,
                    ),
                  ),
                ),
              ],
              // Page number overlay (when toolbar hidden)
              if (!_showToolbar && _settings.showPageNumber)
                _buildPageNumberOverlay(orientation),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageNumberOverlay(Orientation orientation) {
    final placement = _settings.progressBarPlacement;
    final text = '${_currentPage + 1} / ${_pages.length}';
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: AppSpacing.brPill,
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
    );

    if (placement == ProgressBarPlacement.horizontalTop) {
      return Positioned(top: MediaQuery.of(context).padding.top + 8, left: 0, right: 0, child: Center(child: pill));
    }
    if (placement == ProgressBarPlacement.horizontalBottom) {
      return Positioned(bottom: 32, left: 0, right: 0, child: Center(child: pill));
    }
    if (placement == ProgressBarPlacement.verticalLeft) {
      return Positioned(left: 8, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: -1, child: pill)));
    }
    return Positioned(right: 8, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: 1, child: pill)));
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
                    onTap: () => _goToPage(_currentPage - 1),
                    onLongPress: _showLongPressMenu,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: const _BottomRightClipper(),
                  child: GestureDetector(
                    onTap: () => _goToPage(_currentPage + 1),
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
            onTap: () => _goToPage(_currentPage - 1),
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
            onTap: () => _goToPage(_currentPage + 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
        ]);
      case TapZoneMode.leftCenterRight:
        return Row(children: [
          Expanded(flex: 2, child: GestureDetector(
            onTap: () => _goToPage(_currentPage - 1),
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
            onTap: () => _goToPage(_currentPage + 1),
            onLongPress: _showLongPressMenu,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          )),
        ]);
    }
  }

  Widget _buildWebtoonPages() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final offset = notification.metrics.pixels;
          final viewport = notification.metrics.viewportDimension;
          final page = (offset / viewport).round().clamp(0, _pages.length - 1);
          if (page != _currentPage) {
            setState(() => _currentPage = page);
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: List.generate(_pages.length, (i) {
            final page = _pages[i];
            final img = page.localPath != null
                ? Image.file(
                    File(page.localPath!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const AspectRatio(aspectRatio: 16/9, child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48))),
                  )
                : Image.network(
                    page.imageUrl,
                    headers: page.headers,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (_, child, progress) =>
                        progress != null
                            ? const AspectRatio(aspectRatio: 16/9, child: Center(child: CircularProgressIndicator(color: Colors.white54)))
                            : child,
                    errorBuilder: (_, _, _) => const AspectRatio(aspectRatio: 16/9, child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48))),
                  );
            return img;
          }),
        ),
      ),
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
        minScale: _settings.disableZoomOut ? 1.0 : 1.0,
        maxScale: 5.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildBookModePages(Axis axis, bool reverse) {
    // Simple book mode: show 2 pages side by side in landscape
    final even = _currentPage.isEven ? _currentPage : _currentPage - 1;
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

// ── Top bar overlay ────────────────────────────────────────────────────
class _ReaderTopBar extends StatelessWidget {
  final String chapterName;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _ReaderTopBar({
    required this.chapterName,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 4,
        right: 4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              chapterName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: onSave,
            tooltip: 'Save page',
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ─────────────────────────────────────────────────────────
class _ReaderBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool showNavigator;
  final void Function(int) onPageChanged;
  final VoidCallback onSettings;

  const _ReaderBottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.showNavigator,
    required this.onPageChanged,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showNavigator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: currentPage > 0
                        ? () => onPageChanged(currentPage - 1)
                        : null,
                    tooltip: 'Previous',
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape:
                                const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white12,
                          ),
                          child: Slider(
                            value: currentPage.toDouble(),
                            min: 0,
                            max: (totalPages - 1).toDouble(),
                            divisions: totalPages - 1,
                            onChanged: (v) => onPageChanged(v.round()),
                          ),
                        ),
                        Text(
                          '${currentPage + 1} / $totalPages',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: currentPage < totalPages - 1
                        ? () => onPageChanged(currentPage + 1)
                        : null,
                    tooltip: 'Next',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                    onPressed: onSettings,
                    tooltip: 'Settings',
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
