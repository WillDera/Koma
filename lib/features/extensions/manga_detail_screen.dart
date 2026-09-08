import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/services/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/providers.dart';
import '../../core/services/chapter_auto_delete.dart';
import '../../core/services/download/chapter_download.dart';
import '../../core/services/download/download_manager.dart';
import '../../core/services/extension_source_resolve.dart';
import '../../core/services/keiyoushi_service.dart';
import '../../eval/dispatch_service.dart';
import '../../eval/models/m_chapter.dart';
import '../../core/services/source_webview_bridge.dart';
import '../../core/utils/chapter_recognition.dart';
import '../../core/utils/image_cache.dart';
import '../../core/utils/image_headers.dart';
import '../../core/utils/json_coerce.dart';
import '../../router/router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_spacing.dart';
import '../../theme/tokens/app_type.dart';
import '../../widgets/animated_press.dart';
import '../../widgets/dialog_sheet.dart';
import '../../widgets/icon_button_round.dart';
import '../../widgets/page_transitions.dart';
import '../../widgets/screen_chrome.dart';
import 'manga_detail_providers.dart';
import 'migrate_search_screen.dart';

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
  /// Shared process-scoped services — never construct a fresh KeiyoushiService
  /// (its init path hits getDalvikPort / a TCP probe).
  KeiyoushiService get _keiyoushi => ref.read(keiyoushiServiceProvider);
  ExtensionDispatchService get _dispatch =>
      ref.read(extensionServiceProvider);
  int? _mangaId;
  String? _localThumbnail;
  bool _inLibrary = false;
  bool _chapterSelectMode = false;
  final Set<String> _selectedChapterUrls = {};
  String? _notes;

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
          (a, b) => asIntOr(a['date_upload']).compareTo(
            asIntOr(b['date_upload']),
          ),
        );
      case SortMode.dateDesc:
        sorted.sort(
          (a, b) => asIntOr(b['date_upload']).compareTo(
            asIntOr(a['date_upload']),
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
  /// Prefers persisted/source [chapter_number], else title-aware recognition.
  Map<Map<String, dynamic>, double> _chapterNumberMap(
    List<Map<String, dynamic>> chapters,
  ) {
    final map = <Map<String, dynamic>, double>{};
    final title = ref.read(mangaDetailProvider).details?['title'] as String? ??
        widget.title;
    for (final ch in chapters) {
      final raw = ch['chapter_number'] as num?;
      map[ch] = ChapterRecognition.parseChapterNumber(
        title,
        ch['name'] as String? ?? '',
        raw?.toDouble(),
      );
    }
    return map;
  }

  void _showSortSheet() {
    final current = ref.read(mangaDetailProvider).sortMode;
    StashSheet.show<SortMode>(
      context,
      title: 'Sort chapters',
      initialChildSize: 0.5,
      maxChildSize: 0.7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
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
        // Keep loading true — refresh will clear it when finished/skipped.
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
    _notes = m.notes;
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
      ..setInLibrary(m.inLibrary, m.id);
    // Do not clear loading here — [_refreshFromSource] clears it after fetch
    // or when cached chapters mean the network refresh is skipped.

    final chapters = await repos.manga.getMangaChapters(mangaId);
    if (chapters.isNotEmpty && mounted && _isCurrentBinding) {
      final chList = chapters
          .map(
            (c) => <String, dynamic>{
              'url': c.url,
              'name': c.name,
              'chapter_number': c.chapterNumber,
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
      final appDir = await AppStorage.documents();
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
      if (existing.isNotEmpty) {
        if (mounted && expectedGen == _loadGen && _isCurrentBinding) {
          ref.read(mangaDetailProvider.notifier).setLoading(false);
        }
        return;
      }
    }
    if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;
    // Ensure the fetch banner is visible for the whole network round-trip
    // (seed paths previously cleared loading before this awaited).
    ref.read(mangaDetailProvider.notifier).setLoading(true);
    try {
      final repos = ref.read(repositoriesProvider);
      final mSource = await resolveExtensionMSource(
        repos,
        widget.sourceId,
        name: widget.title,
      );
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;

      final detail = await _dispatch.getMangaDetail(
        mSource,
        widget.url,
        memo: widget.memo ?? widget.manga?.memo,
        title: widget.title.isNotEmpty
            ? widget.title
            : (ref.read(mangaDetailProvider).details?['title'] as String?),
      );
      if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) return;

      final mmanga = detail.manga;
      var details = <String, dynamic>{
        if (mmanga != null) ...mmanga.toJson(),
      };
      var chapters = detail.chapters
          .map((MChapter ch) => ch.toJson())
          .toList();

      if (chapters.isEmpty && !mSource.isJs) {
        try {
          final fallback = await _keiyoushi.getChapterList(
            sourceId: widget.sourceId,
            url: widget.url,
            memo: widget.memo ?? widget.manga?.memo,
            title: widget.title,
          );
          if (!mounted || expectedGen != _loadGen || !_isCurrentBinding) {
            return;
          }
          if (fallback.isNotEmpty) {
            chapters = fallback
                .map((m) => MChapter.fromMap(Map<String, dynamic>.from(m)).toJson())
                .toList();
          }
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
          status: asInt(details['status']) ?? manga.status,
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
    final mangaTitle = manga.name;
    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      final url = (ch['url'] as String? ?? '').trim();
      if (url.isEmpty) continue;
      final name = ch['name'] as String? ?? '';
      final sourceNum = (ch['chapter_number'] as num?)?.toDouble();
      final recognized = ChapterRecognition.parseChapterNumber(
        mangaTitle,
        name.isNotEmpty ? name : (existingByUrl[url]?.name ?? ''),
        sourceNum,
      );
      final existing = existingByUrl[url];
      if (existing != null) {
        merged.add(
          existing.copyWith(
            name: name.isNotEmpty ? name : existing.name,
            scanlator: ch['scanlator'] as String? ?? existing.scanlator,
            dateUpload: asInt(ch['date_upload']) ?? existing.dateUpload,
            index: i,
            chapterNumber: recognized,
            memo: ch['memo'] as String? ?? existing.memo,
          ),
        );
      } else {
        merged.add(
          MangaChapter.withRecognition(
            id: 0,
            mangaId: mangaId,
            mangaTitle: mangaTitle,
            name: name,
            url: url,
            scanlator: ch['scanlator'] as String?,
            dateUpload: asIntOr(ch['date_upload']),
            index: i,
            sourceChapterNumber: sourceNum,
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
      ..setError(null);
    // Do not touch loading — Isar stream updates must not hide the fetch banner.
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
              'chapter_number': c.chapterNumber,
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
            final name = e.value['name'] as String? ?? '';
            return MangaChapter.withRecognition(
              id: 0,
              mangaId: _mangaId!,
              mangaTitle: _preferTitle(
                detail.details?['title'] as String?,
                widget.title,
              ),
              name: name,
              url: url,
              scanlator: e.value['scanlator'] as String?,
              dateUpload: asIntOr(e.value['date_upload']),
              index: e.key,
              isRead: local?['is_read'] as bool? ?? false,
              lastPageRead: asIntOr(local?['last_page_read']),
              sourceChapterNumber: e.value['chapter_number'] as num?,
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
            status: asIntOr(d?['status']),
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
        status: asIntOr(d['status']),
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
        return MangaChapter.withRecognition(
          id: 0,
          mangaId: id,
          mangaTitle: _preferTitle(d['title'] as String?, widget.title),
          name: e.value['name'] as String? ?? '',
          url: url,
          scanlator: e.value['scanlator'] as String?,
          dateUpload: asIntOr(e.value['date_upload']),
          index: e.key,
          isRead: local?['is_read'] as bool? ?? false,
          lastPageRead: asIntOr(local?['last_page_read']),
          sourceChapterNumber: e.value['chapter_number'] as num?,
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
                      color: context.colors.textPrimary,
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

    final confirmed = await StashSheet.show<_DownloadMode>(
      context,
      title: 'Download chapters',
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isRange = selectedMode == _DownloadMode.range;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
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
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedMode == null
                        ? null
                        : () {
                            if (selectedMode == _DownloadMode.range) {
                              final startText = startController.text.trim();
                              final endText = endController.text.trim();
                              if (startText.isEmpty || endText.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
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
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter valid chapter numbers',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (end < start) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('End must be >= start'),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(sheetContext, _DownloadMode.range);
                              _downloadChapters(
                                _DownloadMode.range,
                                rangeStart: start,
                                rangeEnd: end,
                              );
                              return;
                            }
                            Navigator.pop(sheetContext, selectedMode);
                          },
                    child: const Text('Download'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    startController.dispose();
    endController.dispose();

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

    // Skip chapters already downloaded.
    targets = targets.where((t) {
      final url = t['url'] as String? ?? '';
      final status = detail.downloadProgress[url];
      if (status == 'done') return false;
      final local = detail.localChapters[url];
      return local?['is_downloaded'] != true;
    }).toList();
    if (targets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected chapters are already downloaded')),
        );
      }
      return;
    }

    final mgr = ref.read(downloadManagerProvider.notifier);
    final mangaMemo = widget.memo ??
        ref.read(mangaDetailProvider).details?['memo'] as String?;
    await mgr.downloadChapters(
      sourceId: widget.sourceId,
      mangaUrl: widget.url,
      mangaTitle: widget.title,
      chapters: targets,
      mangaId: _mangaId,
      mangaMemo: mangaMemo,
    );
    _syncDownloadProgressFromQueue(mgr.manager);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Queued ${targets.length} chapter${targets.length == 1 ? '' : 's'}',
          ),
          action: SnackBarAction(
            label: 'Queue',
            onPressed: () => context.pushNamed(Routes.downloadQueue),
          ),
        ),
      );
    }
  }

  Future<void> _editNotes() async {
    final mangaId = _mangaId;
    if (mangaId == null) return;
    final ctrl = TextEditingController(text: _notes ?? '');
    final saved = await StashDialog.show<String?>(
      context,
      title: 'Notes',
      contentWidget: TextField(
        controller: ctrl,
        maxLines: 6,
        decoration: const InputDecoration(hintText: 'Personal notes…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
    ctrl.dispose();
    if (saved == null || !mounted) return;
    final repos = ref.read(repositoriesProvider);
    await repos.manga.setMangaNotes(mangaId, saved.isEmpty ? null : saved);
    setState(() => _notes = saved.isEmpty ? null : saved);
  }

  List<Map<String, dynamic>> _selectedChapters() {
    final detail = ref.read(mangaDetailProvider);
    return detail.chapters
        .where((ch) => _selectedChapterUrls.contains(ch['url'] as String? ?? ''))
        .toList();
  }

  Future<void> _bulkMarkSelectedRead() async {
    final detail = ref.read(mangaDetailProvider);
    final mangaId = detail.mangaId;
    if (mangaId == null) return;
    final repos = ref.read(repositoriesProvider);
    for (final ch in _selectedChapters()) {
      final url = ch['url'] as String? ?? '';
      if (url.isEmpty) continue;
      final row = await repos.manga.getMangaChapterByUrl(mangaId, url);
      if (row != null) await repos.manga.markMangaChapterRead(row.id);
    }
    setState(() {
      _selectedChapterUrls.clear();
      _chapterSelectMode = false;
    });
  }

  Future<void> _bulkDownloadSelected() async {
    final detail = ref.read(mangaDetailProvider);
    final selected = _selectedChapters();
    if (selected.isEmpty) return;
    final mgr = ref.read(downloadManagerProvider.notifier);
    await mgr.downloadChapters(
      sourceId: widget.sourceId,
      mangaUrl: widget.url,
      mangaTitle: _preferTitle(detail.details?['title'] as String?, widget.title),
      chapters: selected,
      mangaId: detail.mangaId,
      mangaMemo: detail.details?['memo'] as String?,
    );
    setState(() {
      _selectedChapterUrls.clear();
      _chapterSelectMode = false;
    });
  }

  Future<void> _bulkDeleteSelectedDownloads() async {
    final urls = _selectedChapterUrls.toList();
    if (urls.isEmpty) return;
    await _deleteDownloadedChapterUrls(
      urls,
      successMessage: 'Deleted ${urls.length} download(s)',
    );
    setState(() {
      _selectedChapterUrls.clear();
      _chapterSelectMode = false;
    });
  }

  Future<void> _downloadSingleChapter(Map<String, dynamic> ch) async {
    final url = ch['url'] as String? ?? '';
    final notifier = ref.read(downloadManagerProvider.notifier);
    final mgr = notifier.manager;
    final existing = mgr.getQueuedByChapterUrl(widget.sourceId, url);
    if (existing != null) {
      if (existing.status == DownloadState.error) {
        existing.status = DownloadState.queue;
        await notifier.startDownloads();
      }
      _syncDownloadProgressFromQueue(mgr);
      return;
    }
    await notifier.downloadChapters(
      sourceId: widget.sourceId,
      mangaUrl: widget.url,
      mangaTitle: widget.title,
      chapters: [ch],
      mangaId: _mangaId,
      mangaMemo: widget.memo ??
          ref.read(mangaDetailProvider).details?['memo'] as String?,
    );
    _syncDownloadProgressFromQueue(mgr);
  }

  void _syncDownloadProgressFromQueue(DownloadManager mgr) {
    if (!mounted) return;
    final notifier = ref.read(mangaDetailProvider.notifier);
    final progress = Map<String, String>.from(
      ref.read(mangaDetailProvider).downloadProgress,
    );
    final localChapters = Map<String, Map<String, dynamic>>.from(
      ref.read(mangaDetailProvider).localChapters,
    );
    var localChanged = false;
    final activeUrls = <String>{};
    for (final d in mgr.queue) {
      if (d.sourceId != widget.sourceId || d.mangaUrl != widget.url) continue;
      activeUrls.add(d.chapterUrl);
      final label = downloadProgressLabel(d);
      if (label != null) progress[d.chapterUrl] = label;
      if (d.status == DownloadState.downloaded) {
        progress[d.chapterUrl] = 'done';
        if (localChapters.containsKey(d.chapterUrl)) {
          localChapters[d.chapterUrl] = {
            ...localChapters[d.chapterUrl]!,
            'is_downloaded': true,
          };
          localChanged = true;
        }
      }
    }
    // Drop transient active statuses for chapters that left the queue.
    final stale = <String>[];
    for (final entry in progress.entries) {
      if (activeUrls.contains(entry.key)) continue;
      if (_isActiveDownload(entry.value)) {
        stale.add(entry.key);
      }
    }
    for (final url in stale) {
      if (localChapters[url]?['is_downloaded'] == true) {
        progress[url] = 'done';
      } else if (progress[url] != 'done' && progress[url] != 'error') {
        progress.remove(url);
      }
    }
    notifier.setDownloadProgress(progress);
    if (localChanged) {
      notifier.setLocalChapters(localChapters);
    }
  }

  /// Parses `"7/24"` style page progress from [downloadProgress] values.
  static (int done, int total)? _parsePageProgress(String? status) {
    if (status == null) return null;
    final m = RegExp(r'^(\d+)/(\d+)$').firstMatch(status);
    if (m == null) return null;
    final done = int.tryParse(m.group(1)!);
    final total = int.tryParse(m.group(2)!);
    if (done == null || total == null || total <= 0) return null;
    return (done, total);
  }

  static bool _isActiveDownload(String? status) =>
      status == 'queued' || _parsePageProgress(status) != null;

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
      final repos = ref.read(repositoriesProvider);
      await ChapterAutoDelete.deleteChapterFiles(
        keiyoushi: _keiyoushi,
        repos: repos,
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
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Delete download',
      content: 'Delete download for $label?',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFC44C4C)),
          ),
        ),
      ],
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
    final confirmed = await StashDialog.show<bool>(
      context,
      title: 'Delete downloads',
      content:
          'Delete all downloaded chapters for this title?\n'
          '(${urls.length} chapter${urls.length == 1 ? '' : 's'})',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFC44C4C)),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _deleteDownloadedChapterUrls(
      urls,
      successMessage:
          'Deleted ${urls.length} download${urls.length == 1 ? '' : 's'}',
    );
  }

  /// First in-progress chapter, else first unread, else first in list.
  Map<String, dynamic>? _continueChapter(
    List<Map<String, dynamic>> chapters,
  ) {
    if (chapters.isEmpty) return null;
    Map<String, dynamic>? inProgress;
    Map<String, dynamic>? firstUnread;
    for (final ch in chapters) {
      final isRead = ch['is_read'] as bool? ?? false;
      final lastPage = asIntOr(ch['last_page_read']);
      if (!isRead && lastPage > 0) {
        inProgress ??= ch;
      }
      if (!isRead) {
        firstUnread ??= ch;
      }
    }
    return inProgress ?? firstUnread ?? chapters.first;
  }

  bool _hasContinueProgress(List<Map<String, dynamic>> chapters) {
    for (final ch in chapters) {
      if (asIntOr(ch['last_page_read']) > 0) return true;
      if (ch['is_read'] as bool? ?? false) return true;
    }
    return false;
  }

  Future<void> _openChapter(Map<String, dynamic> ch) async {
    final detail = ref.read(mangaDetailProvider);
    final url = ch['url'] as String? ?? '';
    if (detail.mangaId != null && url.isNotEmpty && mounted) {
      final repos = ref.read(repositoriesProvider);
      final existing = await repos.manga.getMangaChapterByUrl(
        detail.mangaId!,
        url,
      );
      if (existing != null) {
        await repos.manga.markMangaChapterOpened(existing.id);
      }
    }
    if (!mounted) return;
    await context.pushNamed(
      Routes.mangaReader,
      extra:
          (
                mangaId: detail.mangaId,
                sourceId: widget.sourceId,
                mangaUrl: widget.url,
                chapterUrl: url,
                chapterName: ch['name'] as String? ?? '',
                pageNumber: null,
              )
              as MangaReaderArgs,
    );
    if (detail.mangaId != null && mounted) {
      final repos = ref.read(repositoriesProvider);
      final localChs = await repos.manga.getMangaChapters(detail.mangaId!);
      final chMapNorm = <String, Map<String, dynamic>>{};
      for (final lc in localChs) {
        chMapNorm[_normalizeUrl(lc.url)] = {
          'is_read': lc.isRead,
          'last_page_read': lc.lastPageRead,
          'is_downloaded': lc.isDownloaded,
          'is_opened': lc.isOpened,
        };
      }
      final merged = detail.chapters.map((row) {
        final u = _normalizeUrl(row['url'] as String? ?? '');
        final local = chMapNorm[u];
        final cleaned = Map<String, dynamic>.from(row)
          ..remove('is_read')
          ..remove('last_page_read')
          ..remove('is_downloaded')
          ..remove('is_opened')
          ..remove('read_at');
        if (local != null) cleaned.addAll(local);
        return cleaned;
      }).toList();
      final chMapRebuilt = <String, Map<String, dynamic>>{};
      for (final lc in localChs) {
        chMapRebuilt[lc.url] = chMapNorm[_normalizeUrl(lc.url)]!;
      }
      final notifier = ref.read(mangaDetailProvider.notifier);
      notifier
        ..setChapters(merged)
        ..setLocalChapters(chMapRebuilt);
    }
  }

  Future<void> _onOverflowSelected(String value) async {
    final detail = ref.read(mangaDetailProvider);
    switch (value) {
      case 'select':
        setState(() {
          _chapterSelectMode = !_chapterSelectMode;
          if (!_chapterSelectMode) _selectedChapterUrls.clear();
        });
      case 'filter':
        _showFilterSheet();
      case 'sort':
        _showSortSheet();
      case 'download':
        if (!detail.offlineMode) await _showDownloadDialog();
      case 'delete_downloads':
        await _confirmDeleteAllDownloads();
      case 'webview':
        try {
          await SourceWebViewBridge.open(
            url: widget.url,
            sourceId: widget.sourceId,
            title: widget.title,
            memo: widget.memo ?? detail.details?['memo'] as String?,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('WebView failed: $e')),
          );
        }
      case 'notes':
        await _editNotes();
      case 'migrate':
        final mangaId = _mangaId;
        if (mangaId == null) return;
        final title = _preferTitle(
          detail.details?['title'] as String?,
          widget.title,
        );
        if (!mounted) return;
        final target = await Navigator.of(context).push<Manga>(
          scaleFadeRoute(
            MigrateSearchScreen(
              currentMangaId: mangaId,
              currentTitle: title,
              excludeSourceId: widget.sourceId,
            ),
          ),
        );
        if (target == null || !mounted) return;
        context.pushReplacementNamed(
          Routes.mangaDetail,
          extra: (
            sourceId: target.sourceId,
            url: target.url,
            title: target.name,
            manga: target,
            memo: target.memo,
          ),
        );
    }
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

  /// Mode of weekday from recent chapter uploads; N/A when signal is weak.
  static String _releaseCycleFromChapters(List<Map<String, dynamic>> chapters) {
    const names = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    final counts = <int, int>{};
    for (final ch in chapters) {
      final date = asIntOr(ch['date_upload']);
      if (date <= 0) continue;
      final wd = DateTime.fromMillisecondsSinceEpoch(date).weekday;
      counts[wd] = (counts[wd] ?? 0) + 1;
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total < 3) return 'N/A';
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value / total < 0.4) return 'N/A';
    return 'Every ${names[best.key]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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

    // Mirror global download queue progress into this title's chapter rows.
    ref.listen(downloadManagerProvider, (_, snap) {
      _syncDownloadProgressFromQueue(
        ref.read(downloadManagerProvider.notifier).manager,
      );
    });

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
      final date = asIntOr(ch['date_upload']);
      if (date > latestDate) latestDate = date;
    }
    if (latestDate > 0) {
      lastChapterDate = DateFormat.yMMMd().format(
        DateTime.fromMillisecondsSinceEpoch(latestDate),
      );
    }
    final releaseCycle = _releaseCycleFromChapters(detail.chapters);
    final continueCh = _continueChapter(filteredChapters);
    final readLabel =
        _hasContinueProgress(filteredChapters) ? 'Continue' : 'Read';
    final showBulkBar =
        _chapterSelectMode && _selectedChapterUrls.isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _KenjiDetailButtonGroup(
        c: c,
        bulkMode: showBulkBar,
        readLabel: readLabel,
        inLibrary: _inLibrary,
        onRead: continueCh == null ? null : () => _openChapter(continueCh),
        onLibrary: _inLibrary ? _removeFromLibrary : _addToLibrary,
        onDownload: detail.offlineMode ? null : _showDownloadDialog,
        onBulkMarkRead: _bulkMarkSelectedRead,
        onBulkDownload: detail.offlineMode ? null : _bulkDownloadSelected,
        onBulkDelete: _bulkDeleteSelectedDownloads,
      ),
      body: detail.details != null
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    details: detail.details!,
                    c: c,
                    localThumbnail: _localThumbnail,
                    sourceId: widget.sourceId,
                    url: widget.url,
                    sourceName: detail.sourceName,
                    lastChapterDate: lastChapterDate,
                    releaseCycle: releaseCycle,
                    expanded: detail.expanded,
                    onExpandedChanged: (v) =>
                        ref.read(mangaDetailProvider.notifier).setExpanded(v),
                    fallbackTitle: widget.title,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
                    overflowButton: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                      ),
                      color: c.surface,
                      onSelected: _onOverflowSelected,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'select',
                          child: Text(
                            _chapterSelectMode
                                ? 'Cancel selection'
                                : 'Select chapters',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'filter',
                          child: Text('Filter chapters'),
                        ),
                        const PopupMenuItem(
                          value: 'sort',
                          child: Text('Sort chapters'),
                        ),
                        if (!detail.offlineMode)
                          const PopupMenuItem(
                            value: 'download',
                            child: Text('Download chapters'),
                          ),
                        if (_downloadedChapterUrls().isNotEmpty)
                          const PopupMenuItem(
                            value: 'delete_downloads',
                            child: Text('Delete downloads'),
                          ),
                        const PopupMenuItem(
                          value: 'webview',
                          child: Text('Open in WebView'),
                        ),
                        if (_inLibrary && _mangaId != null)
                          const PopupMenuItem(
                            value: 'notes',
                            child: Text('Notes'),
                          ),
                        if (_inLibrary && _mangaId != null)
                          const PopupMenuItem(
                            value: 'migrate',
                            child: Text('Migrate'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (detail.loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Material(
                        color: c.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  detail.chapters.isEmpty
                                      ? 'Fetching manga details and chapters…'
                                      : 'Refreshing manga metadata…',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (detail.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        detail.error!,
                        style: TextStyle(color: c.accent, fontSize: 13),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          'CHAPTERS',
                          style: AppType.labelCaps(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.surfaceMuted,
                            borderRadius: AppSpacing.brPill,
                          ),
                          child: Text(
                            '${filteredChapters.length} '
                            '${filteredChapters.length == 1 ? 'Chapter' : 'Chapters'}',
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
                        const Spacer(),
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
                filteredChapters.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
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
                    : SliverPadding(
                        padding: const EdgeInsets.only(bottom: 24),
                        sliver: SliverList.builder(
                          itemCount: filteredChapters.length,
                          itemBuilder: (context, index) {
                            final ch = filteredChapters[index];
                            final url = ch['url'] as String? ?? '';
                            return StaggeredFadeScale(
                              index: index.clamp(
                                0,
                                StaggeredFadeScale.maxStaggerIndex,
                              ),
                              child: _buildChapterItem(
                                ch: ch,
                                c: c,
                                downloadProgress: detail.downloadProgress,
                                offlineMode: detail.offlineMode,
                                selectMode: _chapterSelectMode,
                                selected: _selectedChapterUrls.contains(url),
                                onChapterTap: (ch) async {
                                  final chapterUrl =
                                      ch['url'] as String? ?? '';
                                  if (_chapterSelectMode) {
                                    setState(() {
                                      if (chapterUrl.isEmpty) return;
                                      if (_selectedChapterUrls.contains(
                                        chapterUrl,
                                      )) {
                                        _selectedChapterUrls.remove(
                                          chapterUrl,
                                        );
                                      } else {
                                        _selectedChapterUrls.add(chapterUrl);
                                      }
                                    });
                                    return;
                                  }
                                  await _openChapter(ch);
                                },
                                onChapterLongPress: (ch) {
                                  final chapterUrl =
                                      ch['url'] as String? ?? '';
                                  if (chapterUrl.isEmpty) return;
                                  setState(() {
                                    if (!_chapterSelectMode) {
                                      _chapterSelectMode = true;
                                      _selectedChapterUrls
                                        ..clear()
                                        ..add(chapterUrl);
                                    } else if (_selectedChapterUrls.contains(
                                      chapterUrl,
                                    )) {
                                      _selectedChapterUrls.remove(chapterUrl);
                                    } else {
                                      _selectedChapterUrls.add(chapterUrl);
                                    }
                                  });
                                },
                                onDownloadTap: (ch) =>
                                    _downloadSingleChapter(ch),
                                onDeleteTap: (ch) =>
                                    _confirmDeleteSingleChapter(ch),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            )
          : detail.loading
          ? const Center(child: CircularProgressIndicator())
          : detail.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  detail.error!,
                  style: TextStyle(color: c.accent),
                ),
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
    void Function(Map<String, dynamic> ch)? onChapterLongPress,
    required void Function(Map<String, dynamic> ch)? onDownloadTap,
    required void Function(Map<String, dynamic> ch)? onDeleteTap,
    bool selectMode = false,
    bool selected = false,
  }) {
    final url = ch['url'] as String? ?? '';
    final isRead = ch['is_read'] as bool? ?? false;
    final lastPageRead = asIntOr(ch['last_page_read']);
    final name = ch['name'] as String? ?? '';
    final scanlator = (ch['scanlator'] as String?)?.trim();
    final dateUpload = asIntOr(ch['date_upload']);
    final dlStatus = downloadProgress[url];
    final pageProg = _parsePageProgress(dlStatus);
    final unread = !isRead;

    final dateStr = dateUpload > 0
        ? DateFormat.yMMMd().format(
            DateTime.fromMillisecondsSinceEpoch(dateUpload),
          )
        : '';
    final subtitleParts = <String>[
      if (dateStr.isNotEmpty) dateStr,
      if (scanlator != null && scanlator.isNotEmpty) scanlator,
      if (!isRead && lastPageRead > 0) 'Page ${lastPageRead + 1}',
    ];
    final subtitle = subtitleParts.join(' · ');

    return AnimatedPress(
      onTap: () => onChapterTap(ch),
      onLongPress: onChapterLongPress == null
          ? null
          : () => onChapterLongPress(ch),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border, width: 0.3)),
        ),
        child: Row(
          children: [
            if (selectMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? c.accent : c.textTertiary,
                  size: 22,
                ),
              )
            else if (unread)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const SizedBox(width: 16),
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
                      fontSize: 15,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      height: 20 / 15,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                  if (pageProg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: pageProg.$1 / pageProg.$2,
                              backgroundColor: c.surfaceMuted,
                              color: c.accent,
                              minHeight: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${pageProg.$1}/${pageProg.$2}',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (dlStatus == 'queued')
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
            if (dlStatus == 'done' || ch['is_downloaded'] == true)
              IconButtonRound(
                icon: Icons.delete_outline,
                size: 32,
                iconColor: c.textSecondary,
                onPressed: onDeleteTap == null
                    ? null
                    : () => onDeleteTap(ch),
              )
            else if (dlStatus == 'error')
              IconButtonRound(
                icon: Icons.error_outline,
                size: 32,
                iconColor: Colors.redAccent,
                onPressed: () => onDownloadTap?.call(ch),
              )
            else if (_isActiveDownload(dlStatus))
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
  final String? localThumbnail;
  final String sourceId;
  final String url;
  final String sourceName;
  final String lastChapterDate;
  final String releaseCycle;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  /// Catalog/nav title used when remote details omit or blank the title.
  final String fallbackTitle;
  final VoidCallback onBack;
  final Widget overflowButton;

  const _Header({
    required this.details,
    required this.c,
    this.localThumbnail,
    required this.sourceId,
    required this.url,
    this.sourceName = '',
    this.lastChapterDate = '',
    this.releaseCycle = 'N/A',
    required this.expanded,
    required this.onExpandedChanged,
    this.fallbackTitle = '',
    required this.onBack,
    required this.overflowButton,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  Widget _buildStatusChip(int status, String label) {
    final (icon, chipColor) = switch (status) {
      1 => (Icons.auto_awesome_mosaic, widget.c.accent),
      2 => (Icons.check_circle, const Color(0xFF4CAF50)),
      5 => (Icons.cancel, const Color(0xFFC44C4C)),
      6 => (Icons.pause_circle, Colors.orange),
      _ => (Icons.help_outline, widget.c.textTertiary),
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

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: AppType.labelCaps(
        fontSize: 12,
        color: widget.c.textTertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawTitle = widget.details['title'] as String? ?? '';
    final title = rawTitle.trim().isNotEmpty ? rawTitle : widget.fallbackTitle;
    final thumb = widget.details['thumbnail_url'] as String?;
    final author = widget.details['author'] as String?;
    final artist = widget.details['artist'] as String?;
    final description = widget.details['description'] as String?;
    final genre = widget.details['genre'] as String?;
    final status = asIntOr(widget.details['status']);
    final statusLabel =
        _MangaDetailScreenState._statusLabels[status] ?? 'Unknown';
    final sourceName = widget.sourceName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroSection(
          title: title,
          thumb: thumb,
          statusChip: _buildStatusChip(status, statusLabel),
          c: widget.c,
          localThumbnail: widget.localThumbnail,
          sourceId: widget.sourceId,
          url: widget.url,
          sourceName: sourceName,
          lastChapterDate: widget.lastChapterDate,
          onBack: widget.onBack,
          overflowButton: widget.overflowButton,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((author != null && author.isNotEmpty) ||
                  (artist != null && artist.isNotEmpty)) ...[
                _sectionLabel('AUTHOR'),
                const SizedBox(height: 8),
                if (author != null && author.isNotEmpty)
                  Text(
                    author,
                    style: TextStyle(
                      color: widget.c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (artist != null &&
                    artist.isNotEmpty &&
                    artist != author) ...[
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    style: TextStyle(
                      color: widget.c.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              if (description != null && description.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(child: _sectionLabel('DESCRIPTION')),
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
                const SizedBox(height: 8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: Text(
                    description,
                    key: ValueKey(widget.expanded),
                    maxLines: widget.expanded ? null : 4,
                    overflow: widget.expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.c.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (genre != null && genre.isNotEmpty) ...[
                _sectionLabel('TAGS'),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: widget.expanded
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: genre
                              .split(',')
                              .map((g) => g.trim())
                              .where((g) => g.isNotEmpty)
                              .map(_tagChip)
                              .toList(),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: genre
                                .split(',')
                                .map((g) => g.trim())
                                .where((g) => g.isNotEmpty)
                                .map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _tagChip(g),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.releaseCycle.isNotEmpty &&
                  widget.releaseCycle != 'N/A')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Release cycle · ${widget.releaseCycle}',
                    style: TextStyle(
                      color: widget.c.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagChip(String g) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.c.surfaceMuted,
        borderRadius: AppSpacing.brPill,
      ),
      // widthFactor keeps the chip intrinsic — Container.alignment would
      // expand to the Wrap's max width (full row).
      child: Center(
        widthFactor: 1,
        child: Text(
          '${_genreEmoji(g)}$g',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.c.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
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
  final String? thumb;
  final Widget statusChip;
  final KomaColors c;
  final String? localThumbnail;
  final String sourceId;
  final String url;
  final String sourceName;
  final String lastChapterDate;
  final VoidCallback onBack;
  final Widget overflowButton;

  const _HeroSection({
    required this.title,
    this.thumb,
    required this.statusChip,
    required this.c,
    this.localThumbnail,
    required this.sourceId,
    required this.url,
    this.sourceName = '',
    this.lastChapterDate = '',
    required this.onBack,
    required this.overflowButton,
  });

  static const double _headerHeight = 242;

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
    if (thumb == null || thumb!.isEmpty) {
      return Container(width: width, height: height, color: c.surfaceMuted);
    }
    final headers = ref.watch(sourceImageHeadersProvider(sourceId)).value;
    return Image(
      image: cachedCover(thumb!, headers: headers),
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.topCenter,
      errorBuilder: (context, exception, stackTrace) =>
          Container(width: width, height: height, color: c.surfaceMuted),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: topInset + _headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(context, ref, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.75),
                  c.bg,
                ],
                stops: const [0.0, 0.35, 0.75, 1.0],
              ),
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButtonRound(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  variant: IconButtonVariant.filled,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  iconColor: Colors.white,
                  tooltip: 'Back',
                  onPressed: onBack,
                ),
                const Spacer(),
                overflowButton,
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'manga-thumbnail-$sourceId-$url',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    statusChip,
                    if (sourceName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.brXs,
                        ),
                        child: Text(
                          sourceName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (lastChapterDate.isNotEmpty)
                      Text(
                        lastChapterDate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kenji sticky bottom trio — Read / Library / Download (or bulk actions).
class _KenjiDetailButtonGroup extends StatelessWidget {
  final KomaColors c;
  final bool bulkMode;
  final String readLabel;
  final bool inLibrary;
  final VoidCallback? onRead;
  final VoidCallback onLibrary;
  final VoidCallback? onDownload;
  final VoidCallback onBulkMarkRead;
  final VoidCallback? onBulkDownload;
  final VoidCallback onBulkDelete;

  const _KenjiDetailButtonGroup({
    required this.c,
    required this.bulkMode,
    required this.readLabel,
    required this.inLibrary,
    required this.onRead,
    required this.onLibrary,
    required this.onDownload,
    required this.onBulkMarkRead,
    required this.onBulkDownload,
    required this.onBulkDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Material(
      color: c.bg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
        child: SizedBox(
          height: 56,
          child: Row(
            children: bulkMode
                ? [
                    Expanded(
                      child: _KenjiBarButton(
                        label: 'Mark read',
                        icon: Icons.done_all_rounded,
                        filled: true,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        onPressed: onBulkMarkRead,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KenjiBarButton(
                        label: 'Download',
                        icon: Icons.download_rounded,
                        filled: false,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        muted: c.surfaceMuted,
                        fg: c.textPrimary,
                        onPressed: onBulkDownload,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KenjiBarButton(
                        label: 'Delete DL',
                        icon: Icons.delete_outline_rounded,
                        filled: false,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        muted: c.surfaceMuted,
                        fg: c.textPrimary,
                        onPressed: onBulkDelete,
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: _KenjiBarButton(
                        label: readLabel,
                        icon: Icons.menu_book_rounded,
                        filled: true,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        onPressed: onRead,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KenjiBarButton(
                        label: inLibrary ? 'In Library' : 'Add',
                        icon: inLibrary
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        filled: inLibrary,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        muted: c.surfaceMuted,
                        fg: c.textPrimary,
                        onPressed: onLibrary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KenjiBarButton(
                        label: 'Download',
                        icon: Icons.download_rounded,
                        filled: false,
                        accent: c.accent,
                        onAccent: c.onAccent,
                        muted: c.surfaceMuted,
                        fg: c.textPrimary,
                        onPressed: onDownload,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _KenjiBarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color accent;
  final Color onAccent;
  final Color? muted;
  final Color? fg;
  final VoidCallback? onPressed;

  const _KenjiBarButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.accent,
    required this.onAccent,
    this.muted,
    this.fg,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.colors;
    final bg = filled ? accent : (muted ?? theme.surfaceMuted);
    final color = filled ? onAccent : (fg ?? theme.textPrimary);
    final child = Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) {
      return Opacity(opacity: 0.4, child: child);
    }
    return AnimatedPress(
      onTap: onPressed,
      scaleDown: 0.97,
      child: child,
    );
  }
}
