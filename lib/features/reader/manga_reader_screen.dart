import 'package:flutter/material.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/models/manga_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _service.getPageList(
        sourceId: widget.sourceId,
        url: widget.chapterUrl,
      );
      final pages = raw.asMap().entries.map((e) => MangaPage(
        index: e.key,
        imageUrl: e.value['url'] as String? ?? '',
      )).toList();
      if (!mounted) return;
      setState(() {
        _pages = pages;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _loading
          ? AppBar(
              backgroundColor: Colors.black,
              title: Text(widget.chapterName,
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  itemBuilder: (_, i) {
                    final page = _pages[i];
                    return InteractiveViewer(
                      child: Image.network(
                        page.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress != null
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white54))
                                : child,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white38, size: 48),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
