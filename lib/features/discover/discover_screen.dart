import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/source_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/ebook_service.dart';
import '../library/library_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

import '../../theme/tokens/app_spacing.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/library_header.dart';
import '../../widgets/one_hand_spacer.dart';
import '../../widgets/toast.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<SourceSearchResult> _results = [];
  bool _searching = false;
  bool _loaded = false;
  bool _gridView = false;
  double _scrollProgress = 0;
  final Map<String, double> _downloading = {};
  bool get _oneHand => context.watch<ThemeProvider>().oneHandMode;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = (_scrollCtrl.offset / 60).clamp(0.0, 1.0);
    if (p != _scrollProgress) {
      setState(() => _scrollProgress = p);
    }
  }

  SourceService _svc() => SourceService(
        context.read<DatabaseService>(),
        EbookService(),
      );

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _loaded = true;
    });
    try {
      final results = await _svc().search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _showResultOptions(
      BuildContext context, SourceSearchResult result) async {
    final c = context.colors;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            if (result.author != null) ...[
              const SizedBox(height: 4),
              Text(result.author!,
                  style: TextStyle(color: c.textSecondary, fontSize: 14)),
            ],
            const SizedBox(height: 8),
            Text(
              [
                result.extension,
                result.size,
                result.language,
                result.year,
              ].nonNulls.join(' · '),
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AnimatedPress(
                onTap: () => Navigator.of(ctx).pop('download'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: AppSpacing.brLg,
                  ),
                  child: Center(
                    child: Text('Download',
                        style: TextStyle(
                            color: c.onAccent,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  Text('Cancel', style: TextStyle(color: c.textTertiary))),
        ],
      ),
    );
    if (confirmed != 'download') return;
    if (result.downloadUrl == null || result.downloadUrl!.isEmpty) {
      StashToast.show(context,
          message: 'No download link available for this result',
          icon: Icons.info_outline);
      return;
    }

    final ext = result.extension ?? 'epub';
    if (result.tag == 'libgen') {
      await _pickMirrorAndDownload(context, result);
    } else {
      await _downloadDirect(result.downloadUrl!, result.title, ext);
    }
  }

  Future<void> _pickMirrorAndDownload(
      BuildContext context, SourceSearchResult result) async {
    StashToast.show(context, message: 'Loading mirrors…', icon: Icons.link);
    final links = await _svc().showDownloadOptions(result);
    if (!mounted) return;
    if (links.isEmpty) {
      if (result.downloadUrl != null && result.downloadUrl!.isNotEmpty) {
        final ext = result.extension ?? 'epub';
        await _downloadDirect(result.downloadUrl!, result.title, ext);
      }
      return;
    }

    final c = context.colors;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose mirror',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...links.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnimatedPress(
                      onTap: () => Navigator.of(ctx).pop(e.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: AppSpacing.brLg,
                          border:
                              Border.all(color: c.border, width: 0.5),
                        ),
                        child: Text(e.key,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: c.textTertiary))),
        ],
      ),
    );
    if (chosen == null || chosen.isEmpty) return;
    await _downloadDirect(chosen, result.title, result.extension ?? 'epub');
  }

  Future<void> _downloadDirect(String url, String title, String ext) async {
    setState(() => _downloading[title] = 0.0);
    final ok = await _svc().downloadFromLink(url, title, ext,
        onProgress: (p) {
      if (mounted) setState(() => _downloading[title] = p);
    });
    if (!mounted) return;
    setState(() => _downloading.remove(title));
    if (ok) {
      context.read<LibraryProvider>().loadBooks();
      StashToast.show(context,
          message: '$title added to library', icon: Icons.check);
    } else {
      StashToast.show(context,
          message: 'Download failed', icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleSize = _oneHand ? 64.0 : 32.0;
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const OneHandSpacer(),
          LibraryHeader(
            title: 'Discover',
            subtitle: 'Find books from your sources',
            shrinkProgress: _scrollProgress,
            titleSize: titleSize,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Search for a book…',
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedPress(
                onTap: _searching ? null : _search,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: AppSpacing.brLg,
                  ),
                  child: Center(
                    child: _searching
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c.onAccent))
                        : Text('Search',
                            style: TextStyle(
                                color: c.onAccent,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Text(
                  _loaded
                      ? 'No results'
                      : 'Enter a title to search across your sources',
                  style: TextStyle(color: c.textTertiary, fontSize: 14),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text('${_results.length} results',
                      style:
                          TextStyle(color: c.textTertiary, fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _gridView = !_gridView),
                    child: Icon(
                        _gridView ? Icons.view_list : Icons.grid_view,
                        size: 20,
                        color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (_gridView)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _GridResultCard(
                      result: _results[i],
                      downloadProgress: _downloading[_results[i].title],
                      onTap: () => _showResultOptions(context, _results[i])),
                ),
              )
            else
              ..._results.map((r) => _ResultCard(
                  result: r,
                  downloadProgress: _downloading[r.title],
                  onTap: () => _showResultOptions(context, r))),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SourceSearchResult result;
  final VoidCallback onTap;
  final double? downloadProgress;
  const _ResultCard(
      {required this.result, required this.onTap, this.downloadProgress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: AnimatedPress(
        onTap: downloadProgress != null ? null : onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppSpacing.brLg,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: result.poster != null
                          ? Image.network(
                              result.poster!,
                              width: 48,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _posterPlaceholder(c),
                            )
                          : _posterPlaceholder(c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          if (result.author != null) ...[
                            const SizedBox(height: 2),
                            Text(result.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 13)),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (result.extension != null)
                                _extensionBadge(c, result.extension!),
                              if (result.extension != null)
                                const SizedBox(width: 6),
                              Text(result.sourceName,
                                  style: TextStyle(
                                      color: c.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              if (result.size != null) ...[
                                const SizedBox(width: 8),
                                Text(result.size!,
                                    style: TextStyle(
                                        color: c.textTertiary, fontSize: 11)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 16, color: c.textTertiary),
                  ],
                ),
              ),
              if (downloadProgress != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18)),
                  child: LinearProgressIndicator(
                    value: downloadProgress,
                    minHeight: 3,
                    backgroundColor: c.surfaceMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _extensionBadge(StashReaderColors c, String ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(ext.toUpperCase(),
          style: TextStyle(
              color: c.accent, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Widget _posterPlaceholder(StashReaderColors c) {
    return Container(
      width: 48,
      height: 64,
      color: c.surfaceMuted,
      child: Icon(Icons.book, size: 24, color: c.textTertiary),
    );
  }
}

class _GridResultCard extends StatelessWidget {
  final SourceSearchResult result;
  final VoidCallback onTap;
  final double? downloadProgress;
  const _GridResultCard(
      {required this.result, required this.onTap, this.downloadProgress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: downloadProgress != null ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppSpacing.brLg,
          border: Border.all(color: c.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: result.poster != null
                    ? Image.network(
                        result.poster!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _posterPlaceholder(c),
                      )
                    : _posterPlaceholder(c),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (result.author != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(result.author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 11)),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (result.extension != null)
                        _extensionBadge(c, result.extension!),
                      const SizedBox(width: 6),
                      Text(result.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (result.size != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(result.size!,
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 10)),
                    ),
                ],
              ),
            ),
            if (downloadProgress != null)
              LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 3,
                backgroundColor: c.surfaceMuted,
              ),
          ],
        ),
      ),
    );
  }

  Widget _extensionBadge(StashReaderColors c, String ext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(ext.toUpperCase(),
          style: TextStyle(
              color: c.accent, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Widget _posterPlaceholder(StashReaderColors c) {
    return Container(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.book, size: 32, color: c.textTertiary),
      ),
    );
  }
}
