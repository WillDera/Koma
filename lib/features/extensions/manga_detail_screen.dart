import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../library/library_provider.dart';
import '../reader/manga_reader_screen.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/icon_button_round.dart';

enum _ChapterFilter { downloaded, read, unread }
enum _FilterMode { ignore, include, exclude }
enum _DownloadMode { all, unread, range }
enum _SortMode { nameAsc, nameDesc, dateAsc, dateDesc, chapterAsc, chapterDesc }

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
  String? _localThumbnail;

  final Map<String, String> _downloadProgress = {}; // url -> queued | done | error
  bool _offlineMode = false;

  final Map<_ChapterFilter, _FilterMode> _filterModes = {
  };
  _SortMode _sortMode = _SortMode.chapterAsc;

  static const _keySortMode = 'manga_chapter_sort_mode';

  List<Map<String, dynamic>> _sortedChapters(List<Map<String, dynamic>> chapters) {
    final sorted = List<Map<String, dynamic>>.from(chapters);
    switch (_sortMode) {
      case _SortMode.nameAsc:
        sorted.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      case _SortMode.nameDesc:
        sorted.sort((a, b) => (b['name'] as String? ?? '').compareTo(a['name'] as String? ?? ''));
      case _SortMode.dateAsc:
        sorted.sort((a, b) => (a['date_upload'] as int? ?? 0).compareTo(b['date_upload'] as int? ?? 0));
      case _SortMode.dateDesc:
        sorted.sort((a, b) => (b['date_upload'] as int? ?? 0).compareTo(a['date_upload'] as int? ?? 0));
      case _SortMode.chapterAsc:
        final mapping = _chapterNumberMap(sorted);
        sorted.sort((a, b) => (mapping[a] ?? -1.0).compareTo(mapping[b] ?? -1.0));
      case _SortMode.chapterDesc:
        final mapping = _chapterNumberMap(sorted);
        sorted.sort((a, b) => (mapping[b] ?? -1.0).compareTo(mapping[a] ?? -1.0));
    }
    return sorted;
  }

  /// Build a map of chapter map → parsed chapter number.
  /// Uses source [chapter_number] if valid (> -1), otherwise parses from [name].
  Map<Map<String, dynamic>, double> _chapterNumberMap(List<Map<String, dynamic>> chapters) {
    final map = <Map<String, dynamic>, double>{};
    for (final ch in chapters) {
      final raw = ch['chapter_number'] as num?;
      map[ch] = raw != null && raw > -1
          ? raw.toDouble()
          : _parseChapterNumber(ch['name'] as String? ?? '', ch['chapter_number'] as num?);
    }
    return map;
  }

  /// Port of Mihon's [ChapterRecognition.parseChapterNumber].
  /// Extracts the chapter number from the name when the source doesn't set it.
  static double _parseChapterNumber(String name, num? chapterNumber) {
    if (chapterNumber != null && (chapterNumber == -2 || chapterNumber > -1)) {
      return chapterNumber.toDouble();
    }
    final cleaned = name
        .toLowerCase()
        .replaceAll(',', '.')
        .replaceAll('-', '.')
        .replaceAll(RegExp(r'\s(?=extra|special|omake)'), '');
    final matches = _numberRegex.allMatches(cleaned).toList();
    if (matches.isEmpty) return chapterNumber?.toDouble() ?? -1.0;
    if (matches.length == 1) return _parseMatch(matches.first);
    // Multiple numbers: strip volume/season/etc. tags, try "Ch.xx" first
    final stripped = cleaned.replaceAll(RegExp(r'\b(?:v|ver|vol|version|volume|season|s)[^a-z]?[0-9]+'), '');
    final basicMatch = _basicRegex.firstMatch(stripped);
    if (basicMatch != null) return _parseMatch(basicMatch);
    final fallback = _numberRegex.firstMatch(stripped);
    return fallback != null ? _parseMatch(fallback) : -1.0;
  }

  static final _numberRegex = RegExp(r'([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?');
  static final _basicRegex = RegExp(r'(?<=ch\.) *([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?');

  static double _parseMatch(RegExpMatch m) {
    final main = double.parse(m.group(1)!);
    final decimal = m.group(2);
    final alpha = m.group(3);
    if (decimal != null) return main + double.parse(decimal);
    if (alpha != null) return main + _alphaValue(alpha);
    return main;
  }

  static double _alphaValue(String alpha) {
    final a = alpha.startsWith('.') ? alpha.substring(1) : alpha;
    if (a == 'extra') return 0.99;
    if (a == 'omake') return 0.98;
    if (a == 'special') return 0.97;
    if (a.length == 1) {
      final n = a.codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
      if (n >= 1 && n <= 9) return n / 10.0;
    }
    return 0.0;
  }

  void _showSortSheet() {
    final current = _sortMode;
    showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.textTertiary,
                  borderRadius: AppSpacing.brPill,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sort chapters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _SortOption(
              icon: Icons.sort_by_alpha,
              label: 'Name (A-Z)',
              selected: current == _SortMode.nameAsc,
              onTap: () => Navigator.pop(context, _SortMode.nameAsc),
            ),
            _SortOption(
              icon: Icons.sort_by_alpha,
              label: 'Name (Z-A)',
              selected: current == _SortMode.nameDesc,
              onTap: () => Navigator.pop(context, _SortMode.nameDesc),
            ),
            _SortOption(
              icon: Icons.sort,
              label: 'Date (oldest first)',
              selected: current == _SortMode.dateAsc,
              onTap: () => Navigator.pop(context, _SortMode.dateAsc),
            ),
            _SortOption(
              icon: Icons.sort,
              label: 'Date (newest first)',
              selected: current == _SortMode.dateDesc,
              onTap: () => Navigator.pop(context, _SortMode.dateDesc),
            ),
            _SortOption(
              icon: Icons.swap_vert,
              label: 'Chapter (ascending)',
              selected: current == _SortMode.chapterAsc,
              onTap: () => Navigator.pop(context, _SortMode.chapterAsc),
            ),
            _SortOption(
              icon: Icons.swap_vert,
              label: 'Chapter (descending)',
              selected: current == _SortMode.chapterDesc,
              onTap: () => Navigator.pop(context, _SortMode.chapterDesc),
            ),
          ],
        ),
      ),
    ).then((value) async {
      if (value != null && mounted) {
        setState(() => _sortMode = value);
        (await SharedPreferences.getInstance()).setInt(_keySortMode, value.index);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSortMode();
    _load();
  }

  Future<void> _loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keySortMode);
    if (index != null && index < _SortMode.values.length) {
      _sortMode = _SortMode.values[index];
    }
  }

  Future<void> _cacheThumbnail(String url) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hash = sha256.convert(utf8.encode(url)).toString();
      final thumbDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);
      final path = '${thumbDir.path}/$hash.jpg';
      if (File(path).existsSync()) return;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await File(path).writeAsBytes(response.bodyBytes);
      }
    } catch (_) {
      // ignore cache failures
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offlineMode = false;
    });
    final db = context.read<DatabaseService>();
    final existing = await db.getMangaByKey(widget.sourceId, widget.url);

    // Phase 1: Show cached DB data immediately (like Mihon)
    if (existing != null) {
      await _showCached(existing, db);
    }

    // Phase 2: Background refresh from source — non-blocking
    _refreshFromSource(db, existing);
  }

  Future<void> _refreshFromSource(DatabaseService db, Manga? existing) async {
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
      final thumb = details['thumbnail_url'] as String?;
      if (thumb != null && thumb.isNotEmpty) {
        _cacheThumbnail(thumb);
      }
      if (!mounted) return;
      setState(() {
        _details = details;
        _chapters = chapters;
        _error = null;
      });
      if (thumb != null && thumb.isNotEmpty) {
        precacheImage(NetworkImage(thumb), context);
      }
      // Check library status + local chapter data
      if (existing != null) {
        final localChs = await db.getMangaChapters(existing.id);
        final chMap = <String, Map<String, dynamic>>{};
        for (final lc in localChs) {
          chMap[lc.url] = {
            'is_read': lc.isRead,
            'last_page_read': lc.lastPageRead,
            'is_downloaded': lc.isDownloaded,
          };
        }
        if (!mounted) return;
        final downloadedKeys = await _service.getDownloadedChapterKeys(
          sourceId: widget.sourceId,
          mangaUrl: widget.url,
        );
        final downloadProgress = <String, String>{};
        for (final ch in _chapters) {
          final url = ch['url'] as String? ?? '';
          final key = sha256.convert(utf8.encode(url)).toString().substring(0, 16);
          if (downloadedKeys.contains(key)) {
            downloadProgress[url] = 'done';
          }
        }
        setState(() {
          _inLibrary = existing.inLibrary;
          _mangaId = existing.id;
          _localChapters = chMap;
          _downloadProgress
            ..clear()
            ..addAll(downloadProgress);
        });
        // Phase 3: Sync fresh chapters to DB for next visit
        await db.insertMangaChapters(existing.id, chapters.asMap().entries.map((e) {
          final ch = e.value;
          return MangaChapter(
            id: 0,
            mangaId: existing.id,
            name: ch['name'] as String? ?? '',
            url: ch['url'] as String? ?? '',
            scanlator: ch['scanlator'] as String?,
            dateUpload: ch['date_upload'] as int? ?? 0,
            index: e.key,
            isDownloaded: _downloadProgress[ch['url'] as String? ?? ''] == 'done',
          );
        }).toList());
      }
    } catch (e) {
      if (existing != null) {
        if (!mounted) return;
        setState(() => _offlineMode = true);
      } else {
        if (!mounted) return;
        setState(() => _error = '$e');
      }
    } finally {
      if (existing == null && mounted) setState(() => _loading = false);
    }
  }

  /// Show cached chapters from DB while source fetch runs in background.
  Future<void> _showCached(Manga existing, DatabaseService db) async {
    final localChs = await db.getMangaChapters(existing.id);
    final chMap = <String, Map<String, dynamic>>{};
    for (final lc in localChs) {
      chMap[lc.url] = {
        'is_read': lc.isRead,
        'last_page_read': lc.lastPageRead,
      };
    }
    if (!mounted) return;
    final downloadedKeys = await _service.getDownloadedChapterKeys(
      sourceId: widget.sourceId,
      mangaUrl: widget.url,
    );
    final downloadProgress = <String, String>{};
    for (final lc in localChs) {
      final key = sha256.convert(utf8.encode(lc.url)).toString().substring(0, 16);
      if (downloadedKeys.contains(key)) downloadProgress[lc.url] = 'done';
    }
    setState(() {
      _details = {
        'title': existing.name,
        'thumbnail_url': existing.imageUrl,
        'author': existing.author,
        'artist': existing.artist,
        'description': existing.description,
        'status': existing.status,
        'genre': existing.genres.join(', '),
      };
      _chapters = localChs.map((c) => {
        'url': c.url,
        'name': c.name,
        'chapter_number': c.index.toDouble(),
        'scanlator': c.scanlator,
        'date_upload': c.dateUpload,
      }).toList();
      _inLibrary = true;
      _mangaId = existing.id;
      _localChapters = chMap;
      _downloadProgress
        ..clear()
        ..addAll(downloadProgress);
      _loading = false;
    });
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
    final chapters = _chapters.asMap().entries.map((e) {
      final url = e.value['url'] as String? ?? '';
      return MangaChapter(
        id: 0,
        mangaId: id,
        name: e.value['name'] as String? ?? '',
        url: url,
        scanlator: e.value['scanlator'] as String?,
        dateUpload: e.value['date_upload'] as int? ?? 0,
        index: e.key,
        isDownloaded: _downloadProgress[url] == 'done',
      );
    }).toList();
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

  void _showFilterSheet() {
    final filters = Map<_ChapterFilter, _FilterMode>.from(_filterModes);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.textTertiary,
                        borderRadius: AppSpacing.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ChapterFilterOption(
                    icon: Icons.cloud_download_outlined,
                    label: 'Downloaded',
                    mode: filters[_ChapterFilter.downloaded] ?? _FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(filters[_ChapterFilter.downloaded] ?? _FilterMode.ignore);
                      setSheetState(() => filters[_ChapterFilter.downloaded] = next);
                      setState(() => _filterModes[_ChapterFilter.downloaded] = next);
                    },
                  ),
                  _ChapterFilterOption(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Read',
                    mode: filters[_ChapterFilter.read] ?? _FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(filters[_ChapterFilter.read] ?? _FilterMode.ignore);
                      setSheetState(() => filters[_ChapterFilter.read] = next);
                      setState(() => _filterModes[_ChapterFilter.read] = next);
                    },
                  ),
                  _ChapterFilterOption(
                    icon: Icons.radio_button_unchecked_rounded,
                    label: 'Unread',
                    mode: filters[_ChapterFilter.unread] ?? _FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(filters[_ChapterFilter.unread] ?? _FilterMode.ignore);
                      setSheetState(() => filters[_ChapterFilter.unread] = next);
                      setState(() => _filterModes[_ChapterFilter.unread] = next);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  _FilterMode _nextFilterMode(_FilterMode mode) => switch (mode) {
    _FilterMode.ignore => _FilterMode.include,
    _FilterMode.include => _FilterMode.exclude,
    _FilterMode.exclude => _FilterMode.ignore,
  };

  Future<void> _showDownloadDialog() async {
    _DownloadMode? selectedMode;
    final startController = TextEditingController();
    final endController = TextEditingController();

    final confirmed = await showModalBottomSheet<_DownloadMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isRange = selectedMode == _DownloadMode.range;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.textTertiary,
                        borderRadius: AppSpacing.brPill,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Download chapters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DownloadOption(
                    icon: Icons.library_add_outlined,
                    label: 'All chapters',
                    selected: selectedMode == _DownloadMode.all,
                    onTap: () {
                      selectedMode = _DownloadMode.all;
                      setSheetState(() {});
                    },
                  ),
                  _DownloadOption(
                    icon: Icons.visibility_off_outlined,
                    label: 'Unread chapters',
                    selected: selectedMode == _DownloadMode.unread,
                    onTap: () {
                      selectedMode = _DownloadMode.unread;
                      setSheetState(() {});
                    },
                  ),
                  _DownloadOption(
                    icon: Icons.edit_outlined,
                    label: 'Range...',
                    selected: selectedMode == _DownloadMode.range,
                    onTap: () {
                      selectedMode = _DownloadMode.range;
                      setSheetState(() {});
                    },
                  ),
                  if (isRange) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Start chapter',
                              hintText: '1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'End chapter',
                              hintText: '10',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selectedMode == null
                          ? null
                          : () {
                              if (selectedMode == _DownloadMode.range) {
                                final startText = startController.text.trim();
                                final endText = endController.text.trim();
                                if (startText.isEmpty || endText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Enter both start and end chapter')),
                                  );
                                  return;
                                }
                                final start = int.tryParse(startText);
                                final end = int.tryParse(endText);
                                if (start == null || end == null || start < 1 || end < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Enter valid chapter numbers')),
                                  );
                                  return;
                                }
                                if (end < start) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('End must be >= start')),
                                  );
                                  return;
                                }
                                Navigator.pop(context, _DownloadMode.range);
                                _downloadChapters(_DownloadMode.range, rangeStart: start, rangeEnd: end);
                                return;
                              }
                              Navigator.pop(context, selectedMode);
                            },
                      child: const Text('Download'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == null) return;

    if (confirmed == _DownloadMode.all) {
      await _downloadChapters(_DownloadMode.all);
    } else if (confirmed == _DownloadMode.unread) {
      await _downloadChapters(_DownloadMode.unread);
    }
  }

  Future<void> _downloadChapters(_DownloadMode mode, {int? rangeStart, int? rangeEnd}) async {
    final chapters = _chapters;
    if (chapters.isEmpty) return;

    List<Map<String, dynamic>> targets;
    if (mode == _DownloadMode.all) {
      targets = chapters;
    } else if (mode == _DownloadMode.unread) {
      targets = chapters.where((ch) {
        final url = ch['url'] as String? ?? '';
        final local = _localChapters[url];
        final isRead = local?['is_read'] as bool? ?? false;
        return !isRead;
      }).toList();
    } else {
      final start = rangeStart ?? 1;
      final end = rangeEnd ?? start;
      targets = chapters.where((ch) {
        final chNum = ch['chapter_number'] as num?;
        if (chNum == null) return false;
        return chNum >= start && chNum <= end;
      }).toList();
    }

    if (targets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chapters match the selection')),
        );
      }
      return;
    }

    try {
      setState(() {
        for (final t in targets) {
          final url = t['url'] as String? ?? '';
          _downloadProgress[url] = 'queued';
        }
      });
      final result = await _service.downloadChapters(
        sourceId: widget.sourceId,
        mangaUrl: widget.url,
        chapters: targets,
      );
      if (!mounted) return;
      final db = context.read<DatabaseService>();
      for (final t in targets) {
        final url = t['url'] as String? ?? '';
        final done = result.containsKey(url);
        // Find the local chapter row for this manga + url and mark it
        if (_mangaId != null && done) {
          final chUrl = url;
          final existing = await db.getMangaChapterByUrl(_mangaId!, chUrl);
          if (existing != null) {
            await db.markMangaChapterDownloaded(existing.id, true);
          }
        }
      }
      setState(() {
        for (final t in targets) {
          final url = t['url'] as String? ?? '';
          final done = result.containsKey(url);
          _downloadProgress[url] = done ? 'done' : 'error';
          if (done && _localChapters.containsKey(url)) {
            _localChapters[url] = {
              ..._localChapters[url]!,
              'is_downloaded': true,
            };
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${result.length} chapter(s)')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final t in targets) {
          final url = t['url'] as String? ?? '';
          _downloadProgress[url] = 'error';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadSingleChapter(Map<String, dynamic> ch) async {
    final url = ch['url'] as String? ?? '';
    try {
      setState(() => _downloadProgress[url] = 'queued');
      final result = await _service.downloadChapters(
        sourceId: widget.sourceId,
        mangaUrl: widget.url,
        chapters: [ch],
      );
      if (!mounted) return;
      final done = result.containsKey(url);
      if (_mangaId != null && done) {
        final db = context.read<DatabaseService>();
        final existing = await db.getMangaChapterByUrl(_mangaId!, url);
        if (existing != null) {
          await db.markMangaChapterDownloaded(existing.id, true);
        }
      }
      setState(() {
        _downloadProgress[url] = done ? 'done' : 'error';
        if (done && _localChapters.containsKey(url)) {
          _localChapters[url] = {
            ..._localChapters[url]!,
            'is_downloaded': true,
          };
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.containsKey(url) ? "Downloaded" : "Failed"} ${ch['name'] ?? 'chapter'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadProgress[url] = 'error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  bool _chapterMatchesFilter(Map<String, dynamic> ch) {
    final modes = _filterModes.values;
    if (modes.every((m) => m == _FilterMode.ignore)) return true;

    final url = ch['url'] as String? ?? '';
    final local = _localChapters[url];
    final isRead = local?['is_read'] as bool? ?? false;
    final isDownloaded = local != null;

    final downloadedMatch = _filterModes[_ChapterFilter.downloaded] == _FilterMode.ignore
        || (_filterModes[_ChapterFilter.downloaded] == _FilterMode.include) == isDownloaded;
    if (!downloadedMatch) return false;

    final readMatch = _filterModes[_ChapterFilter.read] == _FilterMode.ignore
        || (_filterModes[_ChapterFilter.read] == _FilterMode.include) == isRead;
    if (!readMatch) return false;

    final unreadMatch = _filterModes[_ChapterFilter.unread] == _FilterMode.ignore
        || (_filterModes[_ChapterFilter.unread] == _FilterMode.include) == !isRead;
    if (!unreadMatch) return false;

    return true;
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
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: c.textPrimary),
            tooltip: 'Filter chapters',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Icon(Icons.download_rounded, color: c.textPrimary),
            tooltip: 'Download chapters',
            onPressed: _offlineMode ? null : _showDownloadDialog,
          ),
        ],
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
                        localThumbnail: _localThumbnail,
                        sourceId: widget.sourceId,
                        url: widget.url,
                      ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ChaptersList(
                        chapters: _sortedChapters(_chapters.where(_chapterMatchesFilter).toList()),
                        localChapters: _localChapters,
                        downloadProgress: _downloadProgress,
                        offlineMode: _offlineMode,
                        c: c,
                        sourceId: widget.sourceId,
                        sortMode: _sortMode,
                        onSortChanged: _showSortSheet,
                        onChapterTap: (ch) async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MangaReaderScreen(
                                mangaId: _mangaId,
                                sourceId: widget.sourceId,
                                mangaUrl: widget.url,
                                chapterUrl: ch['url'] as String? ?? '',
                                chapterName: ch['name'] as String? ?? '',
                              ),
                            ),
                          );
                          if (_mangaId != null && mounted) {
                            final db = context.read<DatabaseService>();
                            final localChs = await db.getMangaChapters(_mangaId!);
                            final chMap = <String, Map<String, dynamic>>{};
                            for (final lc in localChs) {
                              chMap[lc.url] = {
                                'is_read': lc.isRead,
                                'last_page_read': lc.lastPageRead,
                                'is_downloaded': lc.isDownloaded,
                              };
                            }
                            setState(() {
                              _localChapters
                                ..clear()
                                ..addAll(chMap);
                            });
                          }
                        },
                        onDownloadTap: (ch) => _downloadSingleChapter(ch),
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
  final String? localThumbnail;
  final String sourceId;
  final String url;

  const _Header({
    required this.details,
    required this.c,
    required this.inLibrary,
    required this.onAddToLibrary,
    this.appBarHeight = 0,
    this.localThumbnail,
    required this.sourceId,
    required this.url,
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
            appBarHeight: widget.appBarHeight,
            localThumbnail: widget.localThumbnail,
            sourceId: widget.sourceId,
            url: widget.url,
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

class _ChapterFilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final _FilterMode mode;
  final VoidCallback onTap;

  const _ChapterFilterOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$label filter',
      value: switch (mode) {
        _FilterMode.ignore => 'not applied',
        _FilterMode.include => 'included',
        _FilterMode.exclude => 'excluded',
      },
      child: AnimatedPress(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              Icon(icon, size: 21, color: c.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _TriStateGlyph(mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DownloadOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Icon(icon, size: 21, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriStateGlyph extends StatelessWidget {
  final _FilterMode mode;

  const _TriStateGlyph({required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, glyph) = switch (mode) {
      _FilterMode.ignore => (c.textTertiary, null),
      _FilterMode.include => (c.accent, Icons.check_rounded),
      _FilterMode.exclude => (const Color(0xFFC44C4C), Icons.close_rounded),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: mode == _FilterMode.ignore ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: glyph == null ? null : Icon(glyph, size: 17, color: c.onAccent),
    );
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Icon(icon, size: 21, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: c.accent),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String title;
  final String thumb;
  final String? author;
  final String? artist;
  final String statusLabel;
  final StashReaderColors c;
  final double appBarHeight;
  final String? localThumbnail;
  final String sourceId;
  final String url;

  const _HeroSection({
    required this.title,
    required this.thumb,
    this.author,
    this.artist,
    required this.statusLabel,
    required this.c,
    this.appBarHeight = 80,
    this.localThumbnail,
    required this.sourceId,
    required this.url,
  });

  Widget _buildImage({required BoxFit fit, double? width, double? height}) {
    if (localThumbnail != null) {
      return Image.file(
        File(localThumbnail!),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, exception, stackTrace) => Container(
          width: width,
          height: height,
          color: c.surfaceMuted,
        ),
      );
    }
    return Image.network(
      thumb,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, exception, stackTrace) => Container(
        width: width,
        height: height,
        color: c.surfaceMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = appBarHeight + 24 + 300 + 24;
    return SizedBox(
      height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildImage(fit: BoxFit.cover),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [
                       Colors.black.withValues(alpha: 0.15),
                       Colors.black.withValues(alpha: 0.45),
                       Colors.black.withValues(alpha: 0.85),
                       Colors.black,
                     ],
                     stops: const [0.0, 0.35, 0.7, 1.0],
                   ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: appBarHeight + 24,
              bottom: 24,
              child: Row(
                children: [
                  Hero(
                    tag: 'manga-thumbnail-$sourceId-$url',
                    child: ClipRRect(
                      borderRadius: AppSpacing.brMd,
                      child: _buildImage(width: 160, height: 300, fit: BoxFit.cover),
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
  final Map<String, String> downloadProgress;
  final bool offlineMode;
  final StashReaderColors c;
  final String sourceId;
  final void Function(Map<String, dynamic> ch) onChapterTap;
  final void Function(Map<String, dynamic> ch)? onDownloadTap;
  final _SortMode sortMode;
  final VoidCallback? onSortChanged;

  const _ChaptersList({
    required this.chapters,
    required this.localChapters,
    required this.downloadProgress,
    required this.offlineMode,
    required this.c,
    required this.sourceId,
    required this.onChapterTap,
    this.onDownloadTap,
    this.sortMode = _SortMode.chapterAsc,
    this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Center(
        child: Text(
          offlineMode ? 'No downloaded chapters' : 'No chapters',
          style: TextStyle(color: c.textTertiary, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.only(bottom: 12),
           child: Row(
             children: [
               Expanded(
                 child: Row(
                   children: [
                     Text(
                       'Chapters',
                       style: TextStyle(
                         color: c.textPrimary,
                         fontSize: 16,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(width: 10),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                       decoration: BoxDecoration(
                         color: c.surfaceMuted,
                         borderRadius: AppSpacing.brPill,
                       ),
                       child: Text(
                         '${chapters.length}',
                         style: TextStyle(
                           color: c.textSecondary,
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                     ),
                     if (offlineMode) ...[
                       const SizedBox(width: 8),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                         decoration: BoxDecoration(
                           color: Colors.orange.withAlpha(30),
                           borderRadius: AppSpacing.brPill,
                           border: Border.all(color: Colors.orange.withAlpha(80)),
                         ),
                         child: Text(
                           'Offline',
                           style: TextStyle(
                             color: Colors.orange.shade300,
                             fontSize: 11,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ),
                     ],
                   ],
                 ),
               ),
               IconButton(
                 icon: Icon(
                   switch (sortMode) {
                     _SortMode.nameAsc => Icons.sort_by_alpha,
                     _SortMode.nameDesc => Icons.sort_by_alpha,
                     _SortMode.dateAsc => Icons.sort,
                     _SortMode.dateDesc => Icons.sort,
                     _SortMode.chapterAsc => Icons.swap_vert,
                     _SortMode.chapterDesc => Icons.swap_vert,
                   },
                   size: 20,
                   color: c.textSecondary,
                 ),
                 tooltip: 'Sort chapters',
                 onPressed: onSortChanged,
               ),
             ],
           ),
         ),
        ...chapters.map((ch) {
          final url = ch['url'] as String? ?? '';
          final local = localChapters[url];
          final isRead = local?['is_read'] as bool? ?? false;
          final name = ch['name'] as String? ?? '';
          final chNum = ch['chapter_number'] as num?;
          final scanlator = ch['scanlator'] as String?;
          final dateUpload = ch['date_upload'] as int? ?? 0;
          final dateStr = dateUpload > 0
              ? DateFormat.yMMMd().format(
                  DateTime.fromMillisecondsSinceEpoch(dateUpload),
                )
              : '';

          return AnimatedPress(
            onTap: () => onChapterTap(ch),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border, width: 0.3)),
              ),
              child: Row(
                children: [
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isRead && (local?['last_page_read'] as int? ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Page ${(local?['last_page_read'] as int? ?? 0) + 1}',
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (chNum != null)
                              Text(
                                'Ch. ${chNum.toStringAsFixed(chNum == chNum.truncateToDouble() ? 0 : 1)}',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            if (chNum != null && dateStr.isNotEmpty)
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            if (dateStr.isNotEmpty && scanlator != null)
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            if (scanlator != null)
                              Text(
                                scanlator,
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        if (downloadProgress[url] == 'queued')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              backgroundColor: c.surfaceMuted,
                              color: c.accent,
                              minHeight: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (downloadProgress[url] == 'done')
                    IconButtonRound(
                      icon: Icons.check_circle_outline,
                      size: 32,
                      iconColor: Colors.green,
                      onPressed: null,
                    )
                  else if (downloadProgress[url] == 'error')
                    IconButtonRound(
                      icon: Icons.error_outline,
                      size: 32,
                      iconColor: Colors.redAccent,
                      onPressed: () => onDownloadTap?.call(ch),
                    )
                  else if (downloadProgress[url] == 'queued')
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (!offlineMode)
                    IconButtonRound(
                      icon: Icons.download_rounded,
                      size: 32,
                      onPressed: onDownloadTap == null
                          ? null
                          : () => onDownloadTap!(ch),
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
