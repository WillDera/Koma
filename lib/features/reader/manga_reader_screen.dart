import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/keiyoushi_service.dart';
import '../../core/models/manga_page.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';

class MangaReaderScreen extends StatefulWidget {
  final String sourceId;
  final String chapterUrl;
  final String chapterName;

  const MangaReaderScreen({
    super.key,
    required this.sourceId,
    required this.chapterUrl,
    required this.chapterName,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final _service = KeiyoushiService();
  List<MangaPage> _pages = [];
  bool _loading = true;
  String? _error;
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _showToolbar = false;
  final List<TransformationController> _zoomCtrls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _zoomCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
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
        _zoomCtrls.addAll(List.generate(pages.length, (_) => TransformationController()));
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

  void _retryPage(int index) {
    // Force rebuild the failed image by toggling the key
    setState(() {
      _pages[index] = MangaPage(
        index: index,
        imageUrl: _pages[index].imageUrl,
        headers: _pages[index].headers,
      );
    });
  }

  Future<void> _downloadCurrentImage() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style:
                                const TextStyle(color: Colors.redAccent),
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
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _pages.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (_, i) {
                        final page = _pages[i];
                        final zc = i < _zoomCtrls.length
                            ? _zoomCtrls[i]
                            : TransformationController();
                        return GestureDetector(
                          onTap: _toggleToolbar,
                          onDoubleTap: () {
                            final matrix = zc.value;
                            final scale = matrix.getMaxScaleOnAxis();
                            if (scale > 1.1) {
                              zc.value = Matrix4.identity();
                            } else {
                              final pos = Alignment.center;
                              final offset = Alignment.center.inscribe(
                                const Size(1, 1),
                                Offset.zero & const Size(400, 600),
                              );
                              zc.value = Matrix4.identity()
                                ..translate(offset.width, offset.height)
                                ..scale(2.0)
                                ..translate(-offset.width, -offset.height);
                            }
                          },
                          child: InteractiveViewer(
                            transformationController: zc,
                            minScale: 1.0,
                            maxScale: 5.0,
                            child: Image.network(
                              page.imageUrl,
                              headers: page.headers,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (_, child, progress) =>
                                  progress != null
                                      ? const Center(
                                          child:
                                              CircularProgressIndicator(
                                            color: Colors.white54,
                                          ),
                                        )
                                      : child,
                              errorBuilder: (_, _, _) => Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.broken_image,
                                        color: Colors.white38, size: 48),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _retryPage(i),
                                      icon: const Icon(Icons.refresh,
                                          color: Colors.white54),
                                      label: const Text('Retry',
                                          style: TextStyle(
                                              color: Colors.white54)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Overlay toolbar
                    if (_showToolbar) ...[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _ReaderTopBar(
                          chapterName: widget.chapterName,
                          pageNumber: _currentPage + 1,
                          totalPages: _pages.length,
                          onClose: () => Navigator.pop(context),
                          onDownload: _downloadCurrentImage,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _ReaderBottomBar(
                          currentPage: _currentPage,
                          totalPages: _pages.length,
                          onPageChanged: (i) {
                            _pageCtrl.jumpToPage(i);
                            setState(() => _currentPage = i);
                          },
                        ),
                      ),
                    ],
                    if (!_showToolbar)
                      Positioned(
                        bottom: 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: AppSpacing.brPill,
                            ),
                            child: Text(
                              '${_currentPage + 1} / ${_pages.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ── Top bar overlay ────────────────────────────────────────────────────
class _ReaderTopBar extends StatelessWidget {
  final String chapterName;
  final int pageNumber;
  final int totalPages;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  const _ReaderTopBar({
    required this.chapterName,
    required this.pageNumber,
    required this.totalPages,
    required this.onClose,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: onDownload,
            tooltip: 'Save page',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Snippet — coming soon')),
              );
            },
            tooltip: 'Bookmark',
          ),
        ],
      ),
    );
  }
}

// ── Bottom scrub bar ───────────────────────────────────────────────────
class _ReaderBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final void Function(int) onPageChanged;

  const _ReaderBottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
