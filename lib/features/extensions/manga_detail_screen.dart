import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/providers.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../router/router.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/icon_button_round.dart';
import 'manga_detail_providers.dart';

enum _DownloadMode { all, unread, range }

/// Normalize a chapter URL for consistent key matching between DB and network.
String _normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'^/+'), '');

/// Prefer a non-blank remote title; otherwise keep the seeded/catalog title.
String _preferTitle(String? remote, String fallback) {
  final t = remote?.trim() ?? '';
  return t.isNotEmpty ? t : fallback;
}

Map<String, dynamic> _mergeDetailsPreservingTitle(
  Map<String, dynamic>? existing,
  Map<String, dynamic> incoming,
) {
  final merged = <String, dynamic>{...?existing, ...incoming};
  final remoteTitle = (incoming['title'] as String?)?.trim() ?? '';
  if (remoteTitle.isEmpty) {
    final keep =
        (existing?['title'] as String?)?.trim().isNotEmpty == true
        ? existing!['title']
        : null;
    if (keep != null) {
      merged['title'] = keep;
    }
  }
  return merged;
}

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String sourceId;
  final String url;
  final String title;

  /// Pre-loaded manga data from library — if set, shown instantly without DB query.
  final Manga? manga;

  /// Raw JSON of the source-side `SManga.memo` (e.g. allanime `{"slug":...}`).
  /// Round-tripped to the Dalvik server so `getMangaUpdate`/`getChapterList`
  /// work for sources that derive URLs from memo.
  final String? memo;

  const MangaDetailScreen({
    super.key,
    required this.sourceId,
    required this.url,
    required this.title,
    this.manga,
    this.memo,
  });

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  /// Shared process-scoped service — never construct a fresh [KeiyoushiService]
  /// here (its init path hits getDalvikPort / a TCP probe).
  KeiyoushiService get _service => ref.read(keiyoushiServiceProvider);
  int? _mangaId;
  String? _localThumbnail;
  bool _inLibrary = false;

  /// Bumped on every [_init] so in-flight network/Isar work from a previous
  /// open (or a superseded refresh) cannot mutate the current screen.
  int _loadGen = 0;

  /// False until [prepareFor] runs after the first frame. Prevents painting
  /// the previous manga from the global provider before this screen binds.
  bool _sessionReady = false;

  static const _keySortMode = 'manga_chapter_sort_mode';

  bool get _isCurrentBinding => ref
      .read(mangaDetailProvider.notifier)
      .isBoundTo(sourceId: widget.sourceId, url: widget.url);

  List<Map<String, dynamic>> _sortedChapters(
    List<Map<String, dynamic>> chapters,
  ) {
    final sortMode = ref.read(mangaDetailProvider).sortMode;
    final sorted = List<Map<String, dynamic>>.from(chapters);
    switch (sortMode) {
      case SortMode.nameAsc:
        sorted.sort(
          (a, b) => (a['name'] as String? ?? '').compareTo(
            b['name'] as String? ?? '',
          ),
        );
      case SortMode.nameDesc:
        sorted.sort(
          (a, b) => (b['name'] as String? ?? '').compareTo(
            a['name'] as String? ?? '',
          ),
        );
      case SortMode.dateAsc:
        sorted.sort(
          (a, b) => (a['date_upload'] as int? ?? 0).compareTo(
            b['date_upload'] as int? ?? 0,
          ),
        );
      case SortMode.dateDesc:
        sorted.sort(
          (a, b) => (b['date_upload'] as int? ?? 0).compareTo(
            a['date_upload'] as int? ?? 0,
          ),
        );
      case SortMode.chapterAsc:
        final mapping = _chapterNumberMap(sorted);
        sorted.sort(
          (a, b) => (mapping[a] ?? -1.0).compareTo(mapping[b] ?? -1.0),
        );
      case SortMode.chapterDesc:
        final mapping = _chapterNumberMap(sorted);
        sorted.sort(
          (a, b) => (mapping[b] ?? -1.0).compareTo(mapping[a] ?? -1.0),
        );
    }
    return sorted;
  }

  /// Build a map of chapter map → parsed chapter number.
  /// Uses source [chapter_number] if valid (> -1), otherwise parses from [name].
  Map<Map<String, dynamic>, double> _chapterNumberMap(
    List<Map<String, dynamic>> chapters,
  ) {
    final map = <Map<String, dynamic>, double>{};
    for (final ch in chapters) {
      final raw = ch['chapter_number'] as num?;
      map[ch] = raw != null && raw > -1
          ? raw.toDouble()
          : _parseChapterNumber(
              ch['name'] as String? ?? '',
              ch['chapter_number'] as num?,
            );
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
    final stripped = cleaned.replaceAll(
      RegExp(r'\b(?:v|ver|vol|version|volume|season|s)[^a-z]?[0-9]+'),
      '',
    );
    final basicMatch = _basicRegex.firstMatch(stripped);
    if (basicMatch != null) return _parseMatch(basicMatch);
    final fallback = _numberRegex.firstMatch(stripped);
    return fallback != null ? _parseMatch(fallback) : -1.0;
  }

  static final _numberRegex = RegExp(r'([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?');
  static final _basicRegex = RegExp(
    r'(?<=ch\.) *([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?',
  );

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
    final current = ref.read(mangaDetailProvider).sortMode;
    showModalBottomSheet<SortMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: context.colors.border, width: 0.5),
          ),
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
              selected: current == SortMode.nameAsc,
              onTap: () => Navigator.pop(context, SortMode.nameAsc),
            ),
            _SortOption(
              icon: Icons.sort_by_alpha,
              label: 'Name (Z-A)',
              selected: current == SortMode.nameDesc,
              onTap: () => Navigator.pop(context, SortMode.nameDesc),
            ),
            _SortOption(
              icon: Icons.sort,
              label: 'Date (oldest first)',
              selected: current == SortMode.dateAsc,
              onTap: () => Navigator.pop(context, SortMode.dateAsc),
            ),
            _SortOption(
              icon: Icons.sort,
              label: 'Date (newest first)',
              selected: current == SortMode.dateDesc,
              onTap: () => Navigator.pop(context, SortMode.dateDesc),
            ),
            _SortOption(
              icon: Icons.swap_vert,
              label: 'Chapter (ascending)',
              selected: current == SortMode.chapterAsc,
              onTap: () => Navigator.pop(context, SortMode.chapterAsc),
            ),
            _SortOption(
              icon: Icons.swap_vert,
              label: 'Chapter (descending)',
              selected: current == SortMode.chapterDesc,
              onTap: () => Navigator.pop(context, SortMode.chapterDesc),
            ),
          ],
        ),
      ),
    ).then((value) async {
      if (value != null && mounted) {
        final notifier = ref.read(mangaDetailProvider.notifier);
        await notifier.setSortMode(SortMode.values[value.index]);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Provider writes are illegal in initState/build. Bind + load after the
    // first frame; until then show a spinner so stale global state is hidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSortMode();
      _init();
    });
  }

  Future<void> _init() async {
    if (!mounted) return;
    final gen = ++_loadGen;
    ref.read(mangaDetailProvider.notifier).prepareFor(
      sourceId: widget.sourceId,
      url: widget.url,
      title: widget.title,
      memo: widget.memo ?? widget.manga?.memo,
    );
    _mangaId = null;
    _inLibrary = false;
    _localThumbnail = null;
    if (mounted) setState(() => _sessionReady = true);

    final m = widget.manga;
    if (m != null && m.id > 0) {
      // Library manga or pre-inserted from source browse
      await _ensureIsarManga(m);
      if (!mounted || gen != _loadGen) return;
      await _loadFromIsarById(m.id);
      if (!mounted || gen != _loadGen) return;
      // Fetch fresh data + chapters in background. Mirrors mangayomi's
      // updateMangaDetailProvider(mangaId, isInit: true): skips network
      // fetch if chapters are already cached (checked inside).
      _refreshFromSource(gen: gen);
    } else if (m != null) {
      // Source browse / non-library: pre-populate from passed metadata,
      // no DB write needed — show instantly, fetch fresh data in background.
      final repos = ref.read(repositoriesProvider);
      if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
      final notifier = ref.read(mangaDetailProvider.notifier);
      notifier
        ..setDetails({
          'title': _preferTitle(m.name, widget.title),
          'thumbnail_url': m.imageUrl,
          'author': m.author,
          'artist': m.artist,
          'description': m.description,
          'status': m.status,
          'genre': m.genres.join(', '),
          if ((widget.memo ?? m.memo) != null)
            'memo': widget.memo ?? m.memo,
        })
        ..setSourceName(
          (await repos.extensions.getInstalledExtensions())
                  .where(
                    (e) =>
                        e.sourceId == widget.sourceId || e.id == widget.sourceId,
                  )
                  .firstOrNull
                  ?.name ??
              '',
        )
        ..setLoading(false)
        ..setError(null);
      if (!mounted || gen != _loadGen) return;
      // Fetch fresh data + chapters in background
      _refreshFromSource(gen: gen);
    } else {
      final repos = ref.read(repositoriesProvider);
      final existing = await repos.manga.getMangaByKey(
        widget.sourceId,
        widget.url,
      );
      if (!mounted || gen != _loadGen) return;
      if (existing != null) {
        await _ensureIsarManga(existing);
        if (!mounted || gen != _loadGen) return;
        await _loadFromIsarById(existing.id);
        if (!mounted || gen != _loadGen) return;
        _refreshFromSource(gen: gen);
      } else {
        _loadFromIsarByKey(gen: gen);
      }
    }
  }

  /// Ensure manga exists in Isar before loading. Idempotent — if already
  /// present, returns immediately.
  Future<void> _ensureIsarManga(Manga manga) async {
    final repos = ref.read(repositoriesProvider);
    final existing = await repos.manga.getMangaById(manga.id);
    if (existing != null) return;

    await repos.manga.insertManga(manga);
    final chapters = await repos.manga.getMangaChapters(manga.id);
    if (chapters.isNotEmpty) {
      await repos.manga.deleteMangaChapters(manga.id);
      await repos.manga.insertMangaChapters(manga.id, chapters);
    }
  }

  /// Load cached manga + chapters from Isar by ID and set up reactive
  /// listeners. Runs after _ensureIsarForManga guarantees Isar has the data.
  Future<void> _loadFromIsarById(int mangaId) async {
    final repos = ref.read(repositoriesProvider);
    final m = await repos.manga.getMangaById(mangaId);
    if (m == null || !mounted || !_isCurrentBinding) return;
    if (m.sourceId != widget.sourceId || m.url != widget.url) return;
    _mangaId = m.id;
    _inLibrary = m.inLibrary;
    final notifier = ref.read(mangaDetailProvider.notifier);
    notifier
      ..setDetails({
        'title': _preferTitle(m.name, widget.title),
        'thumbnail_url': m.imageUrl,
        'author': m.author,
        'artist': m.artist,
        'description': m.description,
        'status': m.status,
        'genre': m.genres.join(', '),
        if ((widget.memo ?? m.memo) != null)
          'memo': widget.memo ?? m.memo,
      })
      ..setMangaId(m.id)
      ..setInLibrary(m.inLibrary, m.id)
      ..setLoading(false);

    final chapters = await repos.manga.getMangaChapters(mangaId);
    if (chapters.isNotEmpty && mounted && _isCurrentBinding) {
      final chList = chapters
          .map(
            (c) => <String, dynamic>{
              'url': c.url,
              'name': c.name,
              'chapter_number': c.index.toDouble(),
              'scanlator': c.scanlator,
              'date_upload': c.dateUpload,
              'is_read': c.isRead,
              'last_page_read': c.lastPageRead,
              'is_opened': c.isOpened,
              'is_downloaded': c.isDownloaded,
              if (c.readAt != null) 'read_at': c.readAt!.toIso8601String(),
            },
          )
          .toList();
      notifier
        ..setChapters(chList)
        ..setLocalChapters({
          for (final c in chapters)
            c.url: {
              'is_read': c.isRead,
              'last_page_read': c.lastPageRead,
              'is_downloaded': c.isDownloaded,
              'is_opened': c.isOpened,
              'read_at': c.readAt?.toIso8601String(),
            },
        });
    }
  }

  /// Look up manga by sourceId + url in Isar, then delegate to
  /// [_loadFromIsarById]. Also loads extension source name.
  void _loadFromIsarByKey({required int gen}) {
    final repos = ref.read(repositoriesProvider);
    repos.manga.getMangaByKey(widget.sourceId, widget.url).then((m) {
      if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
      if (m != null) {
        _loadFromIsarById(m.id).then((_) {
          if (mounted && gen == _loadGen) _refreshFromSource(gen: gen);
        });
        return;
      }
      // Non-library manga: still need source name, then show loading
      repos.extensions.getInstalledExtensions().then((exts) {
        if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
        for (final ext in exts) {
          if (ext.sourceId == widget.sourceId || ext.id == widget.sourceId) {
            ref.read(mangaDetailProvider.notifier).setSourceName(ext.name);
            break;
          }
        }
      });
      // Seed catalog title/memo so the UI isn't blank if refresh fails,
      // and so getMangaUpdate can hydrate AllAnime-style memo.
      final seed = <String, dynamic>{
        if (widget.title.trim().isNotEmpty) 'title': widget.title,
        if ((widget.memo ?? '').isNotEmpty) 'memo': widget.memo,
      };
      if (seed.isNotEmpty) {
        ref.read(mangaDetailProvider.notifier).setDetails(seed);
      }
      // Trigger network fetch since no cached data
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && gen == _loadGen) _refreshFromSource(gen: gen);
      });
    });
  }

  Future<void> _loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keySortMode);
    if (index != null && index < SortMode.values.length) {
      ref
          .read(mangaDetailProvider.notifier)
          .setSortMode(SortMode.values[index]);
    }
  }

  Future<void> _cacheThumbnail(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hash = sha256.convert(utf8.encode(url)).toString();
      final thumbDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);
      final path = '${thumbDir.path}/$hash.jpg';
      if (File(path).existsSync()) return;
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        await File(path).writeAsBytes(response.bodyBytes);
      }
    } catch (_) {
      // ignore cache failures
    }
  }

  /// Fetches fresh data from the extension source and persists to Isar.
  /// After the write, [mangaDetailStreamProvider] and
  /// [mangaChaptersStreamProvider] re-emit automatically — the UI updates
  /// reactively via [_syncManga] / [_syncChapters].
  Future<void> _refreshFromSource({int? gen}) async {
    final expectedGen = gen ?? _loadGen;
    // Mirrors mangayomi's updateMangaDetailProvider: if chapters already
    // exist in Isar (cached), skip the network fetch. The Isar reactive
    // streams already have the data.
    if (_mangaId != null) {
      final repos = ref.read(repositoriesProvider);
      final existing = await repos.manga.getMangaChapters(_mangaId!);
      if (existing.isNotEmpty) return;
    }
    if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
    try {
      final result = await _service.getMangaUpdate(
        sourceId: widget.sourceId,
        url: widget.url,
        memo: widget.memo ?? widget.manga?.memo,
        title: widget.title.isNotEmpty
            ? widget.title
            : (ref.read(mangaDetailProvider).details?['title'] as String?),
        thumbnailUrl:
            ref.read(mangaDetailProvider).details?['thumbnail_url'] as String?,
        author: ref.read(mangaDetailProvider).details?['author'] as String?,
        artist: ref.read(mangaDetailProvider).details?['artist'] as String?,
        description:
            ref.read(mangaDetailProvider).details?['description'] as String?,
        genre: ref.read(mangaDetailProvider).details?['genre'] as String?,
      );
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
      var details = Map<String, dynamic>.from(result.details);
      var chapters = result.chapters;

      if (chapters.isEmpty) {
        try {
          final fallback = await _service.getChapterList(
            sourceId: widget.sourceId,
            url: widget.url,
            memo: widget.memo ?? widget.manga?.memo,
            title: widget.title,
          );
          if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) {
            return;
          }
          if (fallback.isNotEmpty) chapters = fallback;
        } catch (_) {}
      }

      final thumb = details['thumbnail_url'] as String?;
      if (thumb != null && thumb.isNotEmpty) {
        // The extension's `thumbnail_url` can be a bare site root (e.g. mangadna
        // returns `https://mangadna.com/` when the card's `data-src` is empty) —
        // fetching it yields HTML, not an image. Treat root URLs as "no cover".
        final uri = Uri.tryParse(thumb);
        final isRoot = uri != null && (uri.path.isEmpty || uri.path == '/');
        if (!isRoot) {
          final headers = await ref.read(
            sourceImageHeadersProvider(widget.sourceId).future,
          );
          if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) {
            return;
          }
          _cacheThumbnail(thumb, headers: headers);
          precacheImage(cachedCover(thumb, headers: headers), context);
        }
      }
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
      if (_mangaId != null) {
        await _persistChapters(_mangaId!, details, chapters);
      }
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
      final notifier = ref.read(mangaDetailProvider.notifier);
      final existing = ref.read(mangaDetailProvider).details;
      notifier
        ..setDetails(_mergeDetailsPreservingTitle(existing, details))
        ..setChapters(
          chapters.map((ch) => Map<String, dynamic>.from(ch)).toList(),
        )
        ..setError(null)
        ..setLoading(false);
    } catch (e) {
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
      ref.read(mangaDetailProvider.notifier).setError('$e');
    } finally {
      if (mounted && expectedGen == _loadGen && _isCurrentBinding) {
        ref.read(mangaDetailProvider.notifier).setLoading(false);
      }
    }
  }

  Future<void> _persistChapters(
    int mangaId,
    Map<String, dynamic> details,
    List<Map<String, dynamic>> chapters,
  ) async {
    final repos = ref.read(repositoriesProvider);
    final manga = await repos.manga.getMangaById(mangaId);
    if (manga == null) return;
    if (details.isNotEmpty) {
      final incomingTitle = (details['title'] as String?)?.trim() ?? '';
      final incomingMemo = details['memo'] as String?;
      await repos.manga.updateManga(
        manga.copyWith(
          name: incomingTitle.isNotEmpty ? incomingTitle : manga.name,
          imageUrl: details['thumbnail_url'] as String? ?? manga.imageUrl,
          author: details['author'] as String? ?? manga.author,
          artist: details['artist'] as String? ?? manga.artist,
          description: details['description'] as String? ?? manga.description,
          status: details['status'] as int? ?? manga.status,
          genres: (details['genre'] as String? ?? '')
              .split(',')
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty)
              .toList(),
          memo: (incomingMemo != null && incomingMemo.isNotEmpty)
              ? incomingMemo
              : manga.memo,
        ),
      );
    }
    if (chapters.isEmpty) return;

    final existingChapters = await repos.manga.getMangaChapters(mangaId);
    final existingByUrl = <String, MangaChapter>{
      for (final c in existingChapters)
        if (c.url.isNotEmpty) c.url.trim(): c,
    };

    final merged = <MangaChapter>[];
    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final url = (ch['url'] as String? ?? '').trim();
      if (url.isEmpty) continue;
      final existing = existingByUrl[url];
      if (existing != null) {
        merged.add(
          existing.copyWith(
            name: ch['name'] as String? ?? existing.name,
            scanlator: ch['scanlator'] as String? ?? existing.scanlator,
            dateUpload: ch['date_upload'] as int? ?? existing.dateUpload,
            index: i,
            memo: ch['memo'] as String? ?? existing.memo,
          ),
        );
      } else {
        merged.add(
          MangaChapter(
            id: 0,
            mangaId: mangaId,
            name: ch['name'] as String? ?? '',
            url: url,
            scanlator: ch['scanlator'] as String?,
            dateUpload: ch['date_upload'] as int? ?? 0,
            index: i,
            memo: ch['memo'] as String?,
          ),
        );
      }
    }
    await repos.manga.deleteMangaChapters(mangaId);
    await repos.manga.insertMangaChapters(mangaId, merged);
  }

  /// Applies manga metadata to local state during build (called from
  /// whenData inside ref.watch). No setState needed — ref.watch triggers the
  /// rebuild automatically when the stream emits a new value.
  void _applyManga(Manga? manga) {
    if (manga == null || !mounted || !_isCurrentBinding) return;
    // Reject emissions for a different row (stale global mangaId).
    if (manga.sourceId != widget.sourceId || manga.url != widget.url) return;
    if (_mangaId != null && manga.id != _mangaId) return;
    final notifier = ref.read(mangaDetailProvider.notifier);
    notifier
      ..setDetails({
        'title': _preferTitle(manga.name, widget.title),
        'thumbnail_url': manga.imageUrl,
        'author': manga.author,
        'artist': manga.artist,
        'description': manga.description,
        'status': manga.status,
        'genre': manga.genres.join(', '),
        if ((widget.memo ?? manga.memo) != null)
          'memo': widget.memo ?? manga.memo,
      })
      ..setLoading(false)
      ..setError(null);
    setState(() {
      _mangaId = manga.id;
      _inLibrary = manga.inLibrary;
    });
  }

  /// Merges chapter progress from Isar stream into the display chapter maps.
  /// Also updates localChapters and downloadProgress. Called from whenData
  /// on the mangaChaptersStreamProvider watch.
  void _applyChapters(List<MangaChapter> chapters) {
    if (!mounted || !_isCurrentBinding) return;
    final chMap = <String, Map<String, dynamic>>{};
    final downloadProgress = <String, String>{};
    for (final lc in chapters) {
      chMap[lc.url] = {
        'is_read': lc.isRead,
        'last_page_read': lc.lastPageRead,
        'is_downloaded': lc.isDownloaded,
        'is_opened': lc.isOpened,
        'read_at': lc.readAt?.toIso8601String(),
      };
      if (lc.isDownloaded) downloadProgress[lc.url] = 'done';
    }
    final notifier = ref.read(mangaDetailProvider.notifier);
    final existing = notifier.state.chapters;
    List<Map<String, dynamic>> merged;
    if (existing.isEmpty) {
      merged = chapters
          .map(
            (c) => <String, dynamic>{
              'url': c.url,
              'name': c.name,
              'chapter_number': c.index.toDouble(),
              'scanlator': c.scanlator,
              'date_upload': c.dateUpload,
              'is_read': c.isRead,
              'last_page_read': c.lastPageRead,
              'is_opened': c.isOpened,
              'is_downloaded': c.isDownloaded,
              'memo': c.memo,
              if (c.readAt != null) 'read_at': c.readAt!.toIso8601String(),
            },
          )
          .toList();
    } else {
      merged = existing.map((ch) {
        final local = chMap[_normalizeUrl(ch['url'] as String? ?? '')];
        if (local == null) return ch;
        return {
          ...ch,
          'is_read': local['is_read'],
          'last_page_read': local['last_page_read'],
          'is_downloaded': local['is_downloaded'],
          'is_opened': local['is_opened'],
          'read_at': local['read_at'],
        };
      }).toList();
    }
    notifier
      ..setChapters(merged)
      ..setLocalChapters(chMap)
      ..setDownloadProgress(downloadProgress);
  }

  Future<void> _addToLibrary() async {
    if (!_isCurrentBinding) return;
    final repos = ref.read(repositoriesProvider);
    final gen = _loadGen;

    if (_mangaId != null) {
      // Ensure chapters are in Isar before marking as library
      final existingChapters = await repos.manga.getMangaChapters(_mangaId!);
      if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
      if (existingChapters.isEmpty) {
        final detail = ref.read(mangaDetailProvider);
        if (detail.chapters.isNotEmpty) {
          final chapterModels = detail.chapters.asMap().entries.map((e) {
            final url = e.value['url'] as String? ?? '';
            final local = detail.localChapters[url];
            return MangaChapter(
              id: 0,
              mangaId: _mangaId!,
              name: e.value['name'] as String? ?? '',
              url: url,
              scanlator: e.value['scanlator'] as String?,
              dateUpload: e.value['date_upload'] as int? ?? 0,
              index: e.key,
              isRead: local?['is_read'] as bool? ?? false,
              lastPageRead: local?['last_page_read'] as int? ?? 0,
              isDownloaded: detail.downloadProgress[url] == 'done',
              isOpened: local?['is_opened'] as bool? ?? false,
              memo: e.value['memo'] as String?,
            );
          }).toList();
          await repos.manga.deleteMangaChapters(_mangaId!);
          await repos.manga.insertMangaChapters(_mangaId!, chapterModels);
        } else {
          await _refreshFromSource(gen: gen);
        }
      }
      if (!mounted || gen != _loadGen || !_isCurrentBinding || _mangaId == null) {
        return;
      }
      await repos.manga.setMangaInLibrary(_mangaId!, true);
      final m = await repos.manga.getMangaById(_mangaId!);
      if (m != null && m.sourceId == widget.sourceId && m.url == widget.url) {
        final d = ref.read(mangaDetailProvider).details;
        await repos.manga.updateManga(
          m.copyWith(
            name: _preferTitle(d?['title'] as String?, widget.title),
            imageUrl: d?['thumbnail_url'] as String?,
            author: d?['author'] as String?,
            artist: d?['artist'] as String?,
            description: d?['description'] as String?,
            status: d?['status'] as int? ?? 0,
            genres: (d?['genre'] as String? ?? '')
                .split(',')
                .map((g) => g.trim())
                .where((g) => g.isNotEmpty)
                .toList(),
            memo: (d?['memo'] as String?)?.isNotEmpty == true
                ? d!['memo'] as String
                : (widget.memo ?? m.memo),
          ),
        );
      }
      if (!mounted || gen != _loadGen) return;
      setState(() => _inLibrary = true);
      if (mounted) ref.read(libraryProvider.notifier).loadBooks();
    } else {
      // First time insertion — ensure chapters exist before creating manga row
      var detail = ref.read(mangaDetailProvider);
      if (detail.chapters.isEmpty) {
        await _refreshFromSource(gen: gen);
        if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
        detail = ref.read(mangaDetailProvider);
      }
      final d = detail.details ?? {};
      final manga = Manga(
        id: 0,
        name: _preferTitle(d['title'] as String?, widget.title),
        url: widget.url,
        imageUrl: d['thumbnail_url'] as String?,
        author: d['author'] as String?,
        artist: d['artist'] as String?,
        description: d['description'] as String?,
        status: d['status'] as int? ?? 0,
        genres: (d['genre'] as String? ?? '')
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList(),
        sourceId: widget.sourceId,
        inLibrary: true,
        memo: (d['memo'] as String?)?.isNotEmpty == true
            ? d['memo'] as String
            : widget.memo,
      );
      final id = await repos.manga.insertManga(manga);
      if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
      await repos.manga.deleteMangaChapters(id);
      final chapterModels = detail.chapters.asMap().entries.map((e) {
        final url = e.value['url'] as String? ?? '';
        final local = detail.localChapters[url];
        return MangaChapter(
          id: 0,
          mangaId: id,
          name: e.value['name'] as String? ?? '',
          url: url,
          scanlator: e.value['scanlator'] as String?,
          dateUpload: e.value['date_upload'] as int? ?? 0,
          index: e.key,
          isRead: local?['is_read'] as bool? ?? false,
          lastPageRead: local?['last_page_read'] as int? ?? 0,
          isDownloaded: detail.downloadProgress[url] == 'done',
          isOpened: local?['is_opened'] as bool? ?? false,
          memo: e.value['memo'] as String?,
        );
      }).toList();
      await repos.manga.insertMangaChapters(id, chapterModels);
      if (!mounted || gen != _loadGen || !_isCurrentBinding) return;
      setState(() {
        _inLibrary = true;
        _mangaId = id;
      });
      ref.read(mangaDetailProvider.notifier).setInLibrary(true, id);
      if (mounted) ref.read(libraryProvider.notifier).loadBooks();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to library')));
  }

  Future<void> _removeFromLibrary() async {
    if (_mangaId == null) return;
    final repos = ref.read(repositoriesProvider);
    await repos.manga.setMangaInLibrary(_mangaId!, false);
    if (mounted) {
      setState(() => _inLibrary = false);
      ref.read(libraryProvider.notifier).loadBooks();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from library')));
  }

  void _showFilterSheet() {
    final filters = Map<ChapterFilter, FilterMode>.from(
      ref.read(mangaDetailProvider).filterModes,
    );
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: context.colors.border, width: 0.5),
                ),
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
                  ChapterFilterOption(
                    icon: Icons.cloud_download_outlined,
                    label: 'Downloaded',
                    mode:
                        filters[ChapterFilter.downloaded] ?? FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(
                        filters[ChapterFilter.downloaded] ?? FilterMode.ignore,
                      );
                      setSheetState(
                        () => filters[ChapterFilter.downloaded] = next,
                      );
                      ref
                          .read(mangaDetailProvider.notifier)
                          .setFilterMode(ChapterFilter.downloaded, next);
                    },
                  ),
                  ChapterFilterOption(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Read',
                    mode: filters[ChapterFilter.read] ?? FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(
                        filters[ChapterFilter.read] ?? FilterMode.ignore,
                      );
                      setSheetState(() => filters[ChapterFilter.read] = next);
                      ref
                          .read(mangaDetailProvider.notifier)
                          .setFilterMode(ChapterFilter.read, next);
                    },
                  ),
                  ChapterFilterOption(
                    icon: Icons.radio_button_unchecked_rounded,
                    label: 'Unread',
                    mode: filters[ChapterFilter.unread] ?? FilterMode.ignore,
                    onTap: () {
                      final next = _nextFilterMode(
                        filters[ChapterFilter.unread] ?? FilterMode.ignore,
                      );
                      setSheetState(() => filters[ChapterFilter.unread] = next);
                      ref
                          .read(mangaDetailProvider.notifier)
                          .setFilterMode(ChapterFilter.unread, next);
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

  FilterMode _nextFilterMode(FilterMode mode) => switch (mode) {
    FilterMode.ignore => FilterMode.include,
    FilterMode.include => FilterMode.exclude,
    FilterMode.exclude => FilterMode.ignore,
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: context.colors.border, width: 0.5),
                ),
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
                                    const SnackBar(
                                      content: Text(
                                        'Enter both start and end chapter',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final start = int.tryParse(startText);
                                final end = int.tryParse(endText);
                                if (start == null ||
                                    end == null ||
                                    start < 1 ||
                                    end < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter valid chapter numbers',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (end < start) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('End must be >= start'),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(context, _DownloadMode.range);
                                _downloadChapters(
                                  _DownloadMode.range,
                                  rangeStart: start,
                                  rangeEnd: end,
                                );
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

  Future<void> _downloadChapters(
    _DownloadMode mode, {
    int? rangeStart,
    int? rangeEnd,
  }) async {
    final detail = ref.read(mangaDetailProvider);
    final chapters = detail.chapters;
    if (chapters.isEmpty) return;

    List<Map<String, dynamic>> targets;
    if (mode == _DownloadMode.all) {
      targets = chapters;
    } else if (mode == _DownloadMode.unread) {
      targets = chapters.where((ch) {
        final url = ch['url'] as String? ?? '';
        final local = detail.localChapters[url];
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
      final notifier = ref.read(mangaDetailProvider.notifier);
      final progress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      for (final t in targets) {
        final url = t['url'] as String? ?? '';
        progress[url] = 'queued';
      }
      notifier.setDownloadProgress(progress);
      final result = await _service.downloadChapters(
        sourceId: widget.sourceId,
        mangaUrl: widget.url,
        chapters: targets,
      );
      if (!mounted) return;
      final repos = ref.read(repositoriesProvider);
      for (final t in targets) {
        final url = t['url'] as String? ?? '';
        final done = result.containsKey(url);
        if (_mangaId != null && done) {
          final chUrl = url;
          final existing = await repos.manga.getMangaChapterByUrl(
            _mangaId!,
            chUrl,
          );
          if (existing != null) {
            await repos.manga.markMangaChapterDownloaded(existing.id, true);
          }
        }
      }
      final newProgress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      final localChapters = Map<String, Map<String, dynamic>>.from(
        ref.read(mangaDetailProvider).localChapters,
      );
      for (final t in targets) {
        final url = t['url'] as String? ?? '';
        final done = result.containsKey(url);
        newProgress[url] = done ? 'done' : 'error';
        if (done && localChapters.containsKey(url)) {
          localChapters[url] = {...localChapters[url]!, 'is_downloaded': true};
        }
      }
      notifier
        ..setDownloadProgress(newProgress)
        ..setLocalChapters(localChapters);
      if (mounted) {
        final failed = targets.length - result.length;
        final msg = failed <= 0
            ? 'Downloaded ${result.length} chapter(s)'
            : 'Downloaded ${result.length} of ${targets.length} '
                '(incomplete or blocked — try again after opening the chapter online)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final notifier = ref.read(mangaDetailProvider.notifier);
      final progress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      for (final t in targets) {
        final url = t['url'] as String? ?? '';
        progress[url] = 'error';
      }
      notifier.setDownloadProgress(progress);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _downloadSingleChapter(Map<String, dynamic> ch) async {
    final url = ch['url'] as String? ?? '';
    try {
      final notifier = ref.read(mangaDetailProvider.notifier);
      final progress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      progress[url] = 'queued';
      notifier.setDownloadProgress(progress);
      final result = await _service.downloadChapters(
        sourceId: widget.sourceId,
        mangaUrl: widget.url,
        chapters: [ch],
      );
      if (!mounted) return;
      final done = result.containsKey(url);
      if (_mangaId != null && done) {
        final repos = ref.read(repositoriesProvider);
        final existing = await repos.manga.getMangaChapterByUrl(_mangaId!, url);
        if (existing != null) {
          await repos.manga.markMangaChapterDownloaded(existing.id, true);
        }
      }
      final newProgress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      final localChapters = Map<String, Map<String, dynamic>>.from(
        ref.read(mangaDetailProvider).localChapters,
      );
      newProgress[url] = done ? 'done' : 'error';
      if (done && localChapters.containsKey(url)) {
        localChapters[url] = {...localChapters[url]!, 'is_downloaded': true};
      }
      notifier
        ..setDownloadProgress(newProgress)
        ..setLocalChapters(localChapters);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              done
                  ? 'Downloaded ${ch['name'] ?? 'chapter'}'
                  : 'Incomplete download — site may be Cloudflare-blocked. '
                      'Open the chapter once online, then retry.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final notifier = ref.read(mangaDetailProvider.notifier);
      final progress = Map<String, String>.from(
        ref.read(mangaDetailProvider).downloadProgress,
      );
      progress[url] = 'error';
      notifier.setDownloadProgress(progress);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  List<String> _downloadedChapterUrls() {
    final detail = ref.read(mangaDetailProvider);
    final urls = <String>{};
    for (final entry in detail.downloadProgress.entries) {
      if (entry.value == 'done' && entry.key.isNotEmpty) urls.add(entry.key);
    }
    for (final entry in detail.localChapters.entries) {
      if (entry.value['is_downloaded'] == true && entry.key.isNotEmpty) {
        urls.add(entry.key);
      }
    }
    for (final ch in detail.chapters) {
      final url = ch['url'] as String? ?? '';
      if (url.isEmpty) continue;
      if (ch['is_downloaded'] == true) urls.add(url);
    }
    return urls.toList();
  }

  Future<void> _clearLocalDownloadFlags(List<String> chapterUrls) async {
    if (_mangaId == null || chapterUrls.isEmpty) return;
    final repos = ref.read(repositoriesProvider);
    for (final url in chapterUrls) {
      final existing = await repos.manga.getMangaChapterByUrl(_mangaId!, url);
      if (existing != null) {
        await repos.manga.markMangaChapterDownloaded(existing.id, false);
      }
    }
  }

  void _applyDeletedInUi(List<String> chapterUrls) {
    final notifier = ref.read(mangaDetailProvider.notifier);
    final progress = Map<String, String>.from(
      ref.read(mangaDetailProvider).downloadProgress,
    );
    final localChapters = Map<String, Map<String, dynamic>>.from(
      ref.read(mangaDetailProvider).localChapters,
    );
    final chapters = ref
        .read(mangaDetailProvider)
        .chapters
        .map((ch) {
          final url = ch['url'] as String? ?? '';
          if (!chapterUrls.contains(url)) return ch;
          return {...ch, 'is_downloaded': false};
        })
        .toList();
    for (final url in chapterUrls) {
      progress.remove(url);
      if (localChapters.containsKey(url)) {
        localChapters[url] = {
          ...localChapters[url]!,
          'is_downloaded': false,
        };
      }
    }
    notifier
      ..setDownloadProgress(progress)
      ..setLocalChapters(localChapters)
      ..setChapters(chapters);
  }

  Future<void> _deleteDownloadedChapterUrls(
    List<String> chapterUrls, {
    required String successMessage,
  }) async {
    if (chapterUrls.isEmpty) return;
    try {
      await _service.deleteChapters(
        sourceId: widget.sourceId,
        mangaUrl: widget.url,
        chapterUrls: chapterUrls,
      );
      if (!mounted) return;
      await _clearLocalDownloadFlags(chapterUrls);
      if (!mounted) return;
      _applyDeletedInUi(chapterUrls);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _confirmDeleteSingleChapter(Map<String, dynamic> ch) async {
    final name = (ch['name'] as String?)?.trim();
    final label = (name == null || name.isEmpty) ? 'this chapter' : name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete download'),
        content: Text('Delete download for $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final url = ch['url'] as String? ?? '';
    if (url.isEmpty) return;
    await _deleteDownloadedChapterUrls(
      [url],
      successMessage: 'Deleted download for $label',
    );
  }

  Future<void> _confirmDeleteAllDownloads() async {
    final urls = _downloadedChapterUrls();
    if (urls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No downloaded chapters')),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete downloads'),
        content: Text(
          'Delete all downloaded chapters for this title?\n'
          '(${urls.length} chapter${urls.length == 1 ? '' : 's'})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _deleteDownloadedChapterUrls(
      urls,
      successMessage:
          'Deleted ${urls.length} download${urls.length == 1 ? '' : 's'}',
    );
  }

  bool _chapterMatchesFilter(
    Map<String, dynamic> ch,
    Map<ChapterFilter, FilterMode> modes,
    Map<String, Map<String, dynamic>> localChapters,
  ) {
    if (modes.values.every((m) => m == FilterMode.ignore)) return true;

    final url = ch['url'] as String? ?? '';
    final local = localChapters[url];
    final isRead = local?['is_read'] as bool? ?? false;
    // Presence in the DB ≠ downloaded; use the persisted download flag.
    final isDownloaded = local?['is_downloaded'] as bool? ?? false;

    final downloadedMatch =
        modes[ChapterFilter.downloaded] == FilterMode.ignore ||
        (modes[ChapterFilter.downloaded] == FilterMode.include) == isDownloaded;
    if (!downloadedMatch) return false;

    final readMatch =
        modes[ChapterFilter.read] == FilterMode.ignore ||
        (modes[ChapterFilter.read] == FilterMode.include) == isRead;
    if (!readMatch) return false;

    final unreadMatch =
        modes[ChapterFilter.unread] == FilterMode.ignore ||
        (modes[ChapterFilter.unread] == FilterMode.include) == !isRead;
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

    // Prefer the screen-local id. Never fall back to a stale provider mangaId
    // from a previously opened title (Discover A → B bug).
    final mangaId = _mangaId;
    if (_sessionReady && mangaId != null && _isCurrentBinding) {
      // Side effects belong in listen, not whenData-during-build (which
      // writes mangaDetailProvider and trips Riverpod's build-phase guard).
      ref.listen<AsyncValue<Manga?>>(mangaDetailStreamProvider(mangaId), (
        _,
        next,
      ) {
        next.whenData(_applyManga);
      });
      ref.listen<AsyncValue<List<MangaChapter>>>(
        mangaChaptersStreamProvider(mangaId),
        (_, next) {
          next.whenData(_applyChapters);
        },
      );
    }

    if (!_sessionReady) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final detail = ref.watch(mangaDetailProvider);
    final filteredChapters = _sortedChapters(
      detail.chapters
          .where(
            (ch) => _chapterMatchesFilter(
              ch,
              detail.filterModes,
              detail.localChapters,
            ),
          )
          .toList(),
    );

    String lastChapterDate = '';
    int latestDate = 0;
    for (final ch in detail.chapters) {
      final date = ch['date_upload'] as int? ?? 0;
      if (date > latestDate) latestDate = date;
    }
    if (latestDate > 0) {
      lastChapterDate = DateFormat.yMMMd().format(
        DateTime.fromMillisecondsSinceEpoch(latestDate),
      );
    }

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
            onPressed: detail.offlineMode ? null : _showDownloadDialog,
          ),
          if (_downloadedChapterUrls().isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: c.textPrimary),
              tooltip: 'Delete downloads',
              onPressed: _confirmDeleteAllDownloads,
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
            ),
          ),
        ),
      ),
      body: detail.details != null
          ? CustomScrollView(
              slivers: [
                if (detail.loading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (detail.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        detail.error!,
                        style: TextStyle(color: c.accent, fontSize: 13),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                    child: _Header(
                      details: detail.details!,
                      c: c,
                      inLibrary: _inLibrary,
                      onAddToLibrary: _addToLibrary,
                      onRemoveFromLibrary: _removeFromLibrary,
                      appBarHeight: appBarHeight,
                      localThumbnail: _localThumbnail,
                      sourceId: widget.sourceId,
                      url: widget.url,
                      sourceName: detail.sourceName,
                      lastChapterDate: lastChapterDate,
                      expanded: detail.expanded,
                      onExpandedChanged: (v) =>
                          ref.read(mangaDetailProvider.notifier).setExpanded(v),
                      fallbackTitle: widget.title,
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 24)),
                  // Chapter header
                  SliverToBoxAdapter(
                    child: Padding(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.surfaceMuted,
                                    borderRadius: AppSpacing.brPill,
                                  ),
                                  child: Text(
                                    '${filteredChapters.length}',
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (detail.offlineMode) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(30),
                                      borderRadius: AppSpacing.brPill,
                                      border: Border.all(
                                        color: Colors.orange.withAlpha(80),
                                      ),
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
                              switch (detail.sortMode) {
                                SortMode.nameAsc => Icons.sort_by_alpha,
                                SortMode.nameDesc => Icons.sort_by_alpha,
                                SortMode.dateAsc => Icons.sort,
                                SortMode.dateDesc => Icons.sort,
                                SortMode.chapterAsc => Icons.swap_vert,
                                SortMode.chapterDesc => Icons.swap_vert,
                              },
                              size: 20,
                              color: c.textSecondary,
                            ),
                            tooltip: 'Sort chapters',
                            onPressed: _showSortSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Chapter items
                  filteredChapters.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              detail.offlineMode
                                  ? 'No downloaded chapters'
                                  : 'No chapters',
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: filteredChapters.length,
                          itemBuilder: (context, index) {
                            final ch = filteredChapters[index];
                            return _buildChapterItem(
                              ch: ch,
                              c: c,
                              downloadProgress: detail.downloadProgress,
                              offlineMode: detail.offlineMode,
                              onChapterTap: (ch) async {
                                final url = ch['url'] as String? ?? '';
                                if (detail.mangaId != null &&
                                    url.isNotEmpty &&
                                    mounted) {
                                  final repos = ref.read(repositoriesProvider);
                                  final existing = await repos.manga
                                      .getMangaChapterByUrl(
                                        detail.mangaId!,
                                        url,
                                      );
                                  if (existing != null) {
                                    await repos.manga.markMangaChapterOpened(
                                      existing.id,
                                    );
                                  }
                                }
                                await context.pushNamed(
                                  Routes.mangaReader,
                                  extra:
                                      (
                                            mangaId: detail.mangaId,
                                            sourceId: widget.sourceId,
                                            mangaUrl: widget.url,
                                            chapterUrl:
                                                ch['url'] as String? ?? '',
                                            chapterName:
                                                ch['name'] as String? ?? '',
                                            pageNumber: null,
                                          )
                                          as MangaReaderArgs,
                                );
                                if (detail.mangaId != null && mounted) {
                                  final repos = ref.read(repositoriesProvider);
                                  final localChs = await repos.manga
                                      .getMangaChapters(detail.mangaId!);
                                  final chMap =
                                      <String, Map<String, dynamic>>{};
                                  for (final lc in localChs) {
                                    chMap[lc.url] = {
                                      'is_read': lc.isRead,
                                      'last_page_read': lc.lastPageRead,
                                      'is_downloaded': lc.isDownloaded,
                                      'is_opened': lc.isOpened,
                                    };
                                  }
                                  final chMapNorm =
                                      <String, Map<String, dynamic>>{};
                                  for (final lc in localChs) {
                                    chMapNorm[_normalizeUrl(lc.url)] = {
                                      'is_read': lc.isRead,
                                      'last_page_read': lc.lastPageRead,
                                      'is_downloaded': lc.isDownloaded,
                                      'is_opened': lc.isOpened,
                                    };
                                  }
                                  final merged = detail.chapters.map((ch) {
                                    final url = _normalizeUrl(
                                      ch['url'] as String? ?? '',
                                    );
                                    final local = chMapNorm[url];
                                    final cleaned =
                                        Map<String, dynamic>.from(ch)
                                          ..remove('is_read')
                                          ..remove('last_page_read')
                                          ..remove('is_downloaded')
                                          ..remove('is_opened')
                                          ..remove('read_at');
                                    if (local != null) cleaned.addAll(local);
                                    return cleaned;
                                  }).toList();
                                  final chMapRebuilt =
                                      <String, Map<String, dynamic>>{};
                                  for (final lc in localChs) {
                                    chMapRebuilt[lc.url] =
                                        chMapNorm[_normalizeUrl(lc.url)]!;
                                  }
                                  final notifier = ref.read(
                                    mangaDetailProvider.notifier,
                                  );
                                  notifier
                                    ..setChapters(merged)
                                    ..setLocalChapters(chMapRebuilt);
                                }
                              },
                              onDownloadTap: (ch) => _downloadSingleChapter(ch),
                              onDeleteTap: (ch) =>
                                  _confirmDeleteSingleChapter(ch),
                            );
                          },
                        ),
              ],
            )
          : detail.loading
          ? const Center(child: CircularProgressIndicator())
          : detail.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(detail.error!, style: TextStyle(color: c.accent)),
              ),
            )
          : const Center(child: Text('Failed to load manga details')),
    );
  }

  Widget _buildChapterItem({
    required Map<String, dynamic> ch,
    required KomaColors c,
    required Map<String, String> downloadProgress,
    required bool offlineMode,
    required void Function(Map<String, dynamic> ch) onChapterTap,
    required void Function(Map<String, dynamic> ch)? onDownloadTap,
    required void Function(Map<String, dynamic> ch)? onDeleteTap,
  }) {
    final url = ch['url'] as String? ?? '';
    final isRead = ch['is_read'] as bool? ?? false;
    final lastPageRead = ch['last_page_read'] as int? ?? 0;
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
            Container(
              width: 2,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isRead ? c.textTertiary.withAlpha(77) : c.accent,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
                  if (!isRead && lastPageRead > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Page ${lastPageRead + 1}',
                        style: TextStyle(color: c.textTertiary, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chNum != null)
                        Text(
                          'Ch. ${chNum.toStringAsFixed(chNum == chNum.truncateToDouble() ? 0 : 1)}',
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
                        ),
                      if (chNum != null && dateStr.isNotEmpty)
                        Text(
                          ' · ',
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
                        ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
                        ),
                      if (dateStr.isNotEmpty && scanlator != null)
                        Text(
                          ' · ',
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
                        ),
                      if (scanlator != null)
                        Text(
                          scanlator,
                          style: TextStyle(color: c.textTertiary, fontSize: 12),
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
            if (downloadProgress[url] == 'done' ||
                ch['is_downloaded'] == true)
              IconButtonRound(
                icon: Icons.delete_outline,
                size: 32,
                iconColor: c.textSecondary,
                onPressed: onDeleteTap == null
                    ? null
                    : () => onDeleteTap(ch),
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
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!offlineMode)
              IconButtonRound(
                icon: Icons.download_rounded,
                size: 32,
                onPressed: onDownloadTap == null
                    ? null
                    : () => onDownloadTap(ch),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final Map<String, dynamic> details;
  final KomaColors c;
  final bool inLibrary;
  final VoidCallback onAddToLibrary;
  final VoidCallback onRemoveFromLibrary;
  final double appBarHeight;
  final String? localThumbnail;
  final String sourceId;
  final String url;
  final String sourceName;
  final String lastChapterDate;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  /// Catalog/nav title used when remote details omit or blank the title.
  final String fallbackTitle;

  const _Header({
    required this.details,
    required this.c,
    required this.inLibrary,
    required this.onAddToLibrary,
    required this.onRemoveFromLibrary,
    this.appBarHeight = 0,
    this.localThumbnail,
    required this.sourceId,
    required this.url,
    this.sourceName = '',
    this.lastChapterDate = '',
    required this.expanded,
    required this.onExpandedChanged,
    this.fallbackTitle = '',
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  Widget _buildStatusChip(int status, String label) {
    final (icon, chipColor) = switch (status) {
      1 => (Icons.auto_awesome_mosaic, widget.c.accent), // Ongoing
      2 => (Icons.check_circle, const Color(0xFF4CAF50)), // Completed
      5 => (Icons.cancel, const Color(0xFFC44C4C)), // Cancelled
      6 => (Icons.pause_circle, Colors.orange), // On hiatus
      _ => (Icons.help_outline, widget.c.textTertiary), // Unknown
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: AppSpacing.brXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawTitle = widget.details['title'] as String? ?? '';
    final title = rawTitle.trim().isNotEmpty
        ? rawTitle
        : widget.fallbackTitle;
    final thumb = widget.details['thumbnail_url'] as String?;
    final author = widget.details['author'] as String?;
    final artist = widget.details['artist'] as String?;
    final description = widget.details['description'] as String?;
    final genre = widget.details['genre'] as String?;
    final status = widget.details['status'] as int? ?? 0;
    final statusLabel =
        _MangaDetailScreenState._statusLabels[status] ?? 'Unknown';
    final sourceName = widget.sourceName;

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
            sourceName: sourceName,
            lastChapterDate: widget.lastChapterDate,
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
                Row(
                  children: [
                    _buildStatusChip(status, statusLabel),
                    if (sourceName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: widget.c.surfaceMuted,
                          borderRadius: AppSpacing.brXs,
                        ),
                        child: Text(
                          sourceName,
                          style: TextStyle(
                            color: widget.c.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    if (widget.lastChapterDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AppIcon(
                        data: AppIcons.calendar,
                        size: 11,
                        color: widget.c.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.lastChapterDate,
                        style: TextStyle(
                          color: widget.c.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
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
                      style: AppType.labelCaps(
                        fontSize: 12,
                        color: widget.c.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.onExpandedChanged(!widget.expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        widget.expanded ? 'READ LESS' : 'READ MORE',
                        style: AppType.labelCaps(
                          fontSize: 12,
                          color: widget.c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: widget.expanded ? null : 4,
                  overflow: widget.expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
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
                  style: AppType.labelCaps(
                    fontSize: 12,
                    color: widget.c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: genre
                        .split(',')
                        .map((g) => g.trim())
                        .where((g) => g.isNotEmpty)
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
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
                          ),
                        )
                        .toList(),
                  ),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: OutlinedButton.icon(
                onPressed: widget.inLibrary
                    ? widget.onRemoveFromLibrary
                    : widget.onAddToLibrary,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: widget.inLibrary
                        ? widget.c.accent.withValues(alpha: 0.5)
                        : widget.c.accent,
                  ),
                ),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.inLibrary
                      ? const Icon(
                          Icons.favorite,
                          size: 18,
                          key: ValueKey('lib-true'),
                        )
                      : const Icon(
                          Icons.favorite_border_rounded,
                          size: 18,
                          key: ValueKey('lib-false'),
                        ),
                ),
                label: Text(
                  widget.inLibrary ? 'Remove from library' : 'Add to library',
                ),
              ),
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

Widget _detailInfoRow(KomaColors c, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: AppType.labelCaps(fontSize: 12, color: c.textTertiary),
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

class ChapterFilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final FilterMode mode;
  final VoidCallback onTap;

  const ChapterFilterOption({
    super.key,
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
        FilterMode.ignore => 'not applied',
        FilterMode.include => 'included',
        FilterMode.exclude => 'excluded',
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
  final FilterMode mode;

  const _TriStateGlyph({required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, glyph) = switch (mode) {
      FilterMode.ignore => (c.textTertiary, null),
      FilterMode.include => (c.accent, Icons.check_rounded),
      FilterMode.exclude => (const Color(0xFFC44C4C), Icons.close_rounded),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: mode == FilterMode.ignore ? Colors.transparent : color,
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
            if (selected) Icon(Icons.check_rounded, size: 20, color: c.accent),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends ConsumerWidget {
  final String title;
  final String thumb;
  final String? author;
  final String? artist;
  final String statusLabel;
  final KomaColors c;
  final double appBarHeight;
  final String? localThumbnail;
  final String sourceId;
  final String url;
  final String sourceName;
  final String lastChapterDate;

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
    this.sourceName = '',
    this.lastChapterDate = '',
  });

  Widget _buildImage(
    BuildContext context,
    WidgetRef ref, {
    required BoxFit fit,
    double? width,
    double? height,
  }) {
    if (localThumbnail != null) {
      return Image.file(
        File(localThumbnail!),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, exception, stackTrace) =>
            Container(width: width, height: height, color: c.surfaceMuted),
      );
    }
    final headers = ref.watch(sourceImageHeadersProvider(sourceId)).value;
    return Image(
      image: cachedCover(
        thumb,
        headers: headers,
        width: width?.toInt(),
        height: height?.toInt(),
      ),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, exception, stackTrace) =>
          Container(width: width, height: height, color: c.surfaceMuted),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = appBarHeight + 24 + 240 + 24;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: _buildImage(context, ref, fit: BoxFit.cover)),
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
                    child: _buildImage(
                      context,
                      ref,
                      width: 160,
                      height: 240,
                      fit: BoxFit.cover,
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
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
                          if (sourceName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.surfaceMuted.withValues(alpha: 0.5),
                                borderRadius: AppSpacing.brXs,
                              ),
                              child: Text(
                                sourceName,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (lastChapterDate.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  data: AppIcons.calendar,
                                  size: 11,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lastChapterDate,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
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
