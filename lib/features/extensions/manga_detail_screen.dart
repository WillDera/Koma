import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../reader/manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final String sourceId;
  final String url;
  final String title;

  const MangaDetailScreen({
    super.key,
    required this.sourceId,
    required this.url,
    required this.title,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final _service = KeiyoushiService();
  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _chapters = [];
  bool _loading = true;
  bool _inLibrary = false;
  // ignore: unused_field
  int? _mangaId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getMangaDetails(
          sourceId: widget.sourceId,
          url: widget.url,
        ),
        _service.getChapterList(
          sourceId: widget.sourceId,
          url: widget.url,
        ),
      ]);
      if (!mounted) return;
      final details = results[0] as Map<String, dynamic>;
      setState(() {
        _details = details;
        _chapters = results[1] as List<Map<String, dynamic>>;
        _error = null;
      });
      // Check library status
      final db = context.read<DatabaseService>();
      final existing = await db.getMangaByKey(widget.sourceId, widget.url);
      if (!mounted) return;
      setState(() {
        _inLibrary = existing?.inLibrary ?? false;
        _mangaId = existing?.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToLibrary() async {
    final d = _details;
    if (d == null) return;
    final db = context.read<DatabaseService>();
    final manga = Manga(
      id: 0,
      name: d['title'] as String? ?? widget.title,
      url: widget.url,
      imageUrl: d['thumbnail_url'] as String?,
      author: d['author'] as String?,
      artist: d['artist'] as String?,
      description: d['description'] as String?,
      status: d['status'] as int? ?? 0,
      genres: (d['genre'] as String? ?? '').split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
      sourceId: widget.sourceId,
      inLibrary: true,
    );
    final id = await db.insertManga(manga);
    await db.setMangaInLibrary(id, true);
    // Save chapters
    final chapters = _chapters.asMap().entries.map((e) => MangaChapter(
      id: 0,
      mangaId: id,
      name: e.value['name'] as String? ?? '',
      url: e.value['url'] as String? ?? '',
      scanlator: e.value['scanlator'] as String?,
      dateUpload: e.value['date_upload'] as int? ?? 0,
      index: e.key,
    )).toList();
    await db.insertMangaChapters(id, chapters);
    if (!mounted) return;
    setState(() {
      _inLibrary = true;
      _mangaId = id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to library')),
    );
  }

  static const _statusLabels = {
    0: 'Unknown',
    1: 'Ongoing',
    2: 'Completed',
    3: 'Licensed',
    4: 'Publishing finished',
    5: 'Cancelled',
    6: 'On hiatus',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!, style: TextStyle(color: c.accent)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Header(
                      details: _details!,
                      c: c,
                      inLibrary: _inLibrary,
                      onAddToLibrary: _addToLibrary,
                    ),
                    const SizedBox(height: 24),
                    _ChaptersList(
                      chapters: _chapters,
                      c: c,
                      sourceId: widget.sourceId,
                      onChapterTap: (ch) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MangaReaderScreen(
                            sourceId: widget.sourceId,
                            chapterUrl: ch['url'] as String? ?? '',
                            chapterName: ch['name'] as String? ?? '',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> details;
  final StashReaderColors c;
  final bool inLibrary;
  final VoidCallback onAddToLibrary;

  const _Header({
    required this.details,
    required this.c,
    required this.inLibrary,
    required this.onAddToLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final title = details['title'] as String? ?? '';
    final thumb = details['thumbnail_url'] as String?;
    final author = details['author'] as String?;
    final artist = details['artist'] as String?;
    final description = details['description'] as String?;
    final genre = details['genre'] as String?;
    final status = details['status'] as int? ?? 0;
    final statusLabel = _MangaDetailScreenState._statusLabels[status] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppSpacing.brMd,
              child: thumb != null && thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: 120,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(c, 120, 180),
                    )
                  : _placeholder(c, 120, 180),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (author != null && author.isNotEmpty)
                    _infoRow('Author', author),
                  if (artist != null && artist.isNotEmpty)
                    _infoRow('Artist', artist),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: AppSpacing.brXs,
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
        if (genre != null && genre.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: genre
                .split(',')
                .map((g) => g.trim())
                .where((g) => g.isNotEmpty)
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: AppSpacing.brPill,
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: inLibrary ? null : onAddToLibrary,
            icon: Icon(
              inLibrary ? Icons.check : Icons.bookmark_add_outlined,
              size: 18,
            ),
            label: Text(inLibrary ? 'In library' : 'Add to library'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: c.textPrimary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(StashReaderColors c, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: c.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: c.textTertiary),
      ),
    );
  }
}

class _ChaptersList extends StatelessWidget {
  final List<Map<String, dynamic>> chapters;
  final StashReaderColors c;
  final String sourceId;
  final void Function(Map<String, dynamic> ch) onChapterTap;

  const _ChaptersList({
    required this.chapters,
    required this.c,
    required this.sourceId,
    required this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Center(
        child: Text(
          'No chapters',
          style: TextStyle(color: c.textTertiary, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chapters (${chapters.length})',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...chapters.map((ch) {
          final name = ch['name'] as String? ?? '';
          final chNum = ch['chapter_number'] as num?;
          final scanlator = ch['scanlator'] as String?;
          final dateUpload = ch['date_upload'] as int? ?? 0;
          final dateStr = dateUpload > 0
              ? DateFormat.yMMMd().format(
                  DateTime.fromMillisecondsSinceEpoch(dateUpload),
                )
              : '';

          return InkWell(
            onTap: () => onChapterTap(ch),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (chNum != null)
                              Text(
                                'Ch. ${chNum.toStringAsFixed(chNum == chNum.truncateToDouble() ? 0 : 1)}',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            if (chNum != null && scanlator != null)
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            if (scanlator != null)
                              Text(
                                scanlator,
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: TextStyle(color: c.textTertiary, fontSize: 11),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
