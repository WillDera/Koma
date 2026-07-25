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

class _SourceBrowseScreenState extends State<SourceBrowseScreen>
    with SingleTickerProviderStateMixin {
  final _service = KeiyoushiService();
  final _scrollCtrl = ScrollController();

  late final TabController _tabCtrl;

  List<Map<String, dynamic>> _mangas = [];
  bool _loading = false;
  bool _hasNext = true;
  int _page = 1;
  String? _error;
  String _tab = 'popular';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _scrollCtrl.addListener(_onScroll);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final tabs = ['popular', 'latest'];
        if (_tab != tabs[_tabCtrl.index]) {
          setState(() {
            _tab = tabs[_tabCtrl.index];
            _mangas = [];
            _page = 1;
            _hasNext = true;
            _error = null;
          });
          _loadPage();
        }
      }
    });
    _loadPage();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
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
      final result = switch (_tab) {
        'latest' => await _service.getLatestUpdates(
            sourceId: widget.sourceId, page: _page),
        _ => await _service.getPopularManga(
            sourceId: widget.sourceId, page: _page),
      };
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(widget.sourceName),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: c.accent,
          labelColor: c.accent,
          unselectedLabelColor: c.textSecondary,
          tabs: const [
            Tab(text: 'Popular'),
            Tab(text: 'Latest'),
          ],
        ),
      ),
      body: _mangas.isEmpty && !_loading && _error == null
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
          : RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
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

  Widget _placeholder(KomaColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: c.textTertiary),
      ),
    );
  }
}
