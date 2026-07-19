import 'package:flutter/material.dart';

import '../../core/services/keiyoushi_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import 'manga_detail_screen.dart';

class SourceBrowseScreen extends StatefulWidget {
  final String sourceId;
  final String sourceName;

  const SourceBrowseScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  State<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends State<SourceBrowseScreen> {
  final _service = KeiyoushiService();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _mangas = [];
  bool _loading = false;
  bool _hasNext = true;
  int _page = 1;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 400 &&
        !_loading &&
        _hasNext) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = _query.isEmpty
          ? await _service.getPopularManga(
              sourceId: widget.sourceId, page: _page)
          : await _service.searchManga(
              sourceId: widget.sourceId, query: _query, page: _page);
      if (!mounted) return;
      setState(() {
        _mangas.addAll(result.mangas);
        _hasNext = result.hasNextPage;
        _page++;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _error = null;
    });
    await _loadPage();
  }

  void _onSearchChanged(String value) {
    _query = value;
    setState(() {
      _mangas = [];
      _page = 1;
      _hasNext = true;
      _error = null;
    });
    _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(widget.sourceName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search ${widget.sourceName}…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _mangas.isEmpty && !_loading
            ? ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: c.accent, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 120),
                  const Center(child: Text('Nothing found')),
                ],
              )
            : GridView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: _mangas.length + (_hasNext ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _mangas.length) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final m = _mangas[i];
                  return _MangaGridCard(
                    manga: m,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MangaDetailScreen(
                          sourceId: widget.sourceId,
                          url: m['url'] as String? ?? '',
                          title: m['title'] as String? ?? '',
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MangaGridCard extends StatelessWidget {
  final Map<String, dynamic> manga;
  final VoidCallback onTap;

  const _MangaGridCard({required this.manga, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = manga['title'] as String? ?? '';
    final thumb = manga['thumbnail_url'] as String?;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brMd,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: thumb != null && thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(c),
                    )
                  : _placeholder(c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(StashReaderColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: c.textTertiary),
      ),
    );
  }
}
