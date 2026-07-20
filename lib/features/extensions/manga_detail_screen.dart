import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../library/library_provider.dart';
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
  Map<String, Map<String, dynamic>> _localChapters = {};
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
      final chapters = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _details = details;
        _chapters = chapters;
        _error = null;
      });
      // Check library status + local chapter data
      final db = context.read<DatabaseService>();
      final existing = await db.getMangaByKey(widget.sourceId, widget.url);
      if (existing != null) {
        final localChs = await db.getMangaChapters(existing.id);
        final chMap = <String, Map<String, dynamic>>{};
        for (final lc in localChs) {
          chMap[lc.url] = {
            'is_read': lc.isRead,
            'last_page_read': lc.lastPageRead,
          };
        }
        if (!mounted) return;
        setState(() {
          _inLibrary = existing.inLibrary;
          _mangaId = existing.id;
          _localChapters = chMap;
        });
      }
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
    // Save chapters (replace, since chapters may have changed)
    await db.deleteMangaChapters(id);
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
    // Refresh library in case user goes back
    if (mounted) context.read<LibraryProvider>().loadBooks();
    if (!mounted) return;
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
    final appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
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
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(
                      details: _details!,
                      c: c,
                      inLibrary: _inLibrary,
                      onAddToLibrary: _addToLibrary,
                      appBarHeight: appBarHeight,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ChaptersList(
                        chapters: _chapters,
                        localChapters: _localChapters,
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
                    ),
                  ],
                ),
    );
  }
}

class _Header extends StatefulWidget {
  final Map<String, dynamic> details;
  final StashReaderColors c;
  final bool inLibrary;
  final VoidCallback onAddToLibrary;
  final double appBarHeight;

  const _Header({
    required this.details,
    required this.c,
    required this.inLibrary,
    required this.onAddToLibrary,
    this.appBarHeight = 0,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.details['title'] as String? ?? '';
    final thumb = widget.details['thumbnail_url'] as String?;
    final author = widget.details['author'] as String?;
    final artist = widget.details['artist'] as String?;
    final description = widget.details['description'] as String?;
    final genre = widget.details['genre'] as String?;
    final status = widget.details['status'] as int? ?? 0;
    final statusLabel = _MangaDetailScreenState._statusLabels[status] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thumb != null && thumb.isNotEmpty)
          _HeroSection(
            title: title,
            thumb: thumb,
            author: author,
            artist: artist,
            statusLabel: statusLabel,
            c: widget.c,
            topPadding: widget.appBarHeight + 24,
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: widget.c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (author != null && author.isNotEmpty)
                  _detailInfoRow(widget.c, 'Author', author),
                if (artist != null && artist.isNotEmpty)
                  _detailInfoRow(widget.c, 'Artist', artist),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.c.accentMuted,
                    borderRadius: AppSpacing.brXs,
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: widget.c.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        color: widget.c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _expanded ? 'READ LESS' : 'READ MORE',
                        style: TextStyle(
                          color: widget.c.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(color: widget.c.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        if (genre != null && genre.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tags',
                  style: TextStyle(
                    color: widget.c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: genre
                      .split(',')
                      .map((g) => g.trim())
                      .where((g) => g.isNotEmpty)
                      .map(
                        (g) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.c.surfaceMuted,
                            borderRadius: AppSpacing.brPill,
                          ),
                          child: Text(
                            '${_genreEmoji(g)}$g',
                            style: TextStyle(
                              color: widget.c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.inLibrary ? null : widget.onAddToLibrary,
              icon: Icon(
                widget.inLibrary ? Icons.check : Icons.bookmark_add_outlined,
                size: 18,
              ),
              label: Text(widget.inLibrary ? 'In library' : 'Add to library'),
            ),
          ),
        ),
      ],
    );
  }

  static String _genreEmoji(String genre) {
    const map = {
      'Action': '⚔️ ',
      'Adventure': '🗺️ ',
      'Comedy': '😂 ',
      'Drama': '🎭 ',
      'Romance': '💕 ',
      'Fantasy': '🐉 ',
      'Horror': '👻 ',
      'Sci-Fi': '🚀 ',
      'Slice of Life': '☕ ',
      'Mystery': '🔍 ',
      'Sports': '⚽ ',
      'Supernatural': '✨ ',
      'Ecchi': '💋 ',
      'Harem': '💘 ',
      'Isekai': '🌀 ',
      'Magic': '🔮 ',
      'School': '🏫 ',
      'Martial Arts': '🥋 ',
      'Music': '🎵 ',
      'Psychological': '🧠 ',
      'Thriller': '🔪 ',
      'Historical': '📜 ',
      'Mecha': '🤖 ',
      'Cooking': '🍳 ',
      'Gaming': '🎮 ',
      'Vampire': '🧛 ',
      'Zombie': '🧟 ',
      'Demons': '😈 ',
      'Samurai': '🗡️ ',
      'Survival': '🏕️ ',
      'Medical': '🏥 ',
      'Food': '🍜 ',
      'Animals': '🐾 ',
      'Military': '🎖️ ',
      'Police': '👮 ',
      'Mature': '🔞 ',
      'Tragedy': '😢 ',
      'Suspense': '⏳ ',
      'Parody': '😜 ',
      'Crossdressing': '👗 ',
      'Gender Bender': '🔄 ',
      'Delinquents': '👊 ',
      'Webtoon': '📱 ',
      'Manhwa': '📖 ',
      'Manhua': '📚 ',
      '4-Koma': '🎨 ',
      'Doujinshi': '✏️ ',
      'Kids': '👶 ',
      'Family': '👨‍👩‍👧 ',
      'Yaoi': '💙 ',
      'Yuri': '💗 ',
      'BL': '💙 ',
      'GL': '💗 ',
    };
    return map[genre] ?? '';
  }
}

Widget _detailInfoRow(StashReaderColors c, String label, String value) {
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

class _HeroSection extends StatelessWidget {
  final String title;
  final String thumb;
  final String? author;
  final String? artist;
  final String statusLabel;
  final StashReaderColors c;
  final double topPadding;

  const _HeroSection({
    required this.title,
    required this.thumb,
    this.author,
    this.artist,
    required this.statusLabel,
    required this.c,
    this.topPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (context, exception, stackTrace) => Container(color: c.surfaceMuted),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    c.bg,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: topPadding,
            bottom: 24,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppSpacing.brMd,
                  child: Image.network(
                    thumb,
                    width: 160,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, exception, stackTrace) => Container(
                      width: 160,
                      height: 300,
                      color: c.surfaceMuted,
                      child: Icon(Icons.image_outlined, size: 40, color: c.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (author?.isNotEmpty == true)
                        _detailInfoRow(c, 'Author', author!),
                      if (artist?.isNotEmpty == true)
                        _detailInfoRow(c, 'Artist', artist!),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          ),
        ],
      ),
    );
  }
}

class _ChaptersList extends StatelessWidget {
  final List<Map<String, dynamic>> chapters;
  final Map<String, Map<String, dynamic>> localChapters;
  final StashReaderColors c;
  final String sourceId;
  final void Function(Map<String, dynamic> ch) onChapterTap;

  const _ChaptersList({
    required this.chapters,
    required this.localChapters,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Chapters (${chapters.length})',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...chapters.map((ch) {
          final url = ch['url'] as String? ?? '';
          final local = localChapters[url];
          final isRead = local?['is_read'] as bool? ?? false;
          final lastPage = local?['last_page_read'] as int? ?? 0;
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
                border: Border(bottom: BorderSide(color: c.border, width: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: isRead ? c.accent : c.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isRead ? c.textTertiary : c.textPrimary,
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
                            if (chNum != null && (scanlator != null || lastPage > 0))
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            if (lastPage > 0)
                              Text(
                                'p.$lastPage',
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (lastPage > 0 && scanlator != null)
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
