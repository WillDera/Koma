import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/models/manga.dart';
import '../../core/models/manga_chapter.dart';
import '../../core/services/extension_source_resolve.dart';
import '../../core/utils/chapter_recognition.dart';

/// Stream of [Manga?] for a given manga ID. Backed by Isar's watchObject —
/// re-emits every time the manga row is written via put(). fireImmediately=true
/// returns the current value on first listen so there is never a loading gap.
final mangaDetailStreamProvider = StreamProvider.family<Manga?, int>((
  ref,
  mangaId,
) {
  return ref.watch(repositoriesProvider).manga.watchManga(mangaId);
});

/// Stream of [List<MangaChapter>] for a given manga ID. Backed by Isar's
/// filtered watch — re-emits when any chapter row matching this mangaId is
/// added/updated/deleted. Sorted by index.
final mangaChaptersStreamProvider =
    StreamProvider.family<List<MangaChapter>, int>((ref, mangaId) {
      return ref.watch(repositoriesProvider).manga.watchMangaChapters(mangaId);
    });

/// Fetches fresh manga detail + chapters from the extension source and persists
/// to Isar. After the write, [mangaDetailStreamProvider] and
/// [mangaChaptersStreamProvider] re-emit automatically — no manual invalidation
/// needed. Mirrors mangayomi's updateMangaDetail pattern.
///
/// When [isInit] is true and chapters already exist, the fetch is skipped
/// (manga was already cached with chapters — no need to re-fetch on first open).
final updateMangaDetailProvider =
    FutureProvider.family<void, ({int mangaId, bool isInit})>((
      ref,
      params,
    ) async {
      final repos = ref.watch(repositoriesProvider);
      final service = ref.watch(extensionServiceProvider);

      final manga = await repos.manga.getMangaById(params.mangaId);
      if (manga == null) return;

      // IsInit + chapters already populated → no network fetch needed
      final existingChapters = await repos.manga.getMangaChapters(
        params.mangaId,
      );
      if (params.isInit && existingChapters.isNotEmpty) return;

      final source = await resolveExtensionMSource(repos, manga.sourceId);
      final result = await service.getMangaDetail(
        source,
        manga.url,
        memo: manga.memo,
        title: manga.name.isNotEmpty ? manga.name : null,
      );

      final mmanga = result.manga;
      final chapters = result.chapters;

      // Update manga metadata from network response. This triggers the
      // watchObject stream for this manga.
      if (mmanga != null) {
        final remoteTitle = mmanga.title.trim();
        final updatedManga = manga.copyWith(
          name: remoteTitle.isNotEmpty ? remoteTitle : manga.name,
          imageUrl: mmanga.thumbnailUrl ?? manga.imageUrl,
          author: mmanga.author ?? manga.author,
          artist: mmanga.artist ?? manga.artist,
          description: mmanga.description ?? manga.description,
          status: mmanga.status,
          genres: mmanga.genres.isNotEmpty ? mmanga.genres : manga.genres,
          memo: (mmanga.memo != null && mmanga.memo!.isNotEmpty)
              ? mmanga.memo
              : manga.memo,
          updatedAt: DateTime.now(),
        );
        await repos.manga.updateManga(updatedManga);
      }

      // Merge network chapters with existing — preserve read/download progress
      // for already-known chapters (matched by url), insert new ones only.
      if (chapters.isNotEmpty) {
        final existingByUrl = <String, MangaChapter>{
          for (final c in existingChapters)
            if (c.url.isNotEmpty) c.url.trim(): c,
        };

        final merged = <MangaChapter>[];
        for (var i = 0; i < chapters.length; i++) {
          final ch = chapters[i];
          final url = ch.url.trim();
          if (url.isEmpty) continue;

          final existing = existingByUrl[url];
          final recognized = ChapterRecognition.parseChapterNumber(
            manga.name,
            ch.name,
            ch.chapterNumber.toDouble(),
          );
          if (existing != null) {
            // Update metadata on existing row, preserve read/download state
            merged.add(
              existing.copyWith(
                name: ch.name,
                scanlator: ch.scanlator ?? existing.scanlator,
                dateUpload: ch.dateUpload,
                index: i,
                chapterNumber: recognized,
                memo: ch.memo ?? existing.memo,
              ),
            );
          } else {
            // New chapter — insert fresh (id: 0 = auto-increment)
            merged.add(
              MangaChapter(
                id: 0,
                mangaId: params.mangaId,
                name: ch.name,
                url: url,
                scanlator: ch.scanlator,
                dateUpload: ch.dateUpload,
                index: i,
                chapterNumber: recognized,
                memo: ch.memo,
              ),
            );
          }
        }

        // Replace all chapters for this manga (the merge above preserved
        // progress for known ones). This triggers the chapters watch stream.
        await repos.manga.deleteMangaChapters(params.mangaId);
        await repos.manga.insertMangaChapters(params.mangaId, merged);
      }
    });

enum ChapterFilter { downloaded, read, unread }

enum FilterMode { ignore, include, exclude }

enum SortMode { nameAsc, nameDesc, dateAsc, dateDesc, chapterAsc, chapterDesc }

class MangaDetailState {
  final bool loading;
  final String? error;
  final bool inLibrary;
  final int? mangaId;
  final String sourceName;
  final SortMode sortMode;
  final Map<ChapterFilter, FilterMode> filterModes;
  final bool offlineMode;
  final Map<String, dynamic>? details;
  final List<Map<String, dynamic>> chapters;
  final Map<String, Map<String, dynamic>> localChapters;
  final String? localThumbnail;
  final Map<String, String> downloadProgress;
  final bool expanded;

  const MangaDetailState({
    this.loading = true,
    this.error,
    this.inLibrary = false,
    this.mangaId,
    this.sourceName = '',
    this.sortMode = SortMode.chapterAsc,
    this.filterModes = const {},
    this.offlineMode = false,
    this.details,
    this.chapters = const [],
    this.localChapters = const {},
    this.localThumbnail,
    this.downloadProgress = const {},
    this.expanded = false,
  });

  /// Sentinel so nullable fields can be explicitly cleared (plain `??` cannot
  /// distinguish "omitted" from "set to null").
  static const Object _unset = Object();

  MangaDetailState copyWith({
    bool? loading,
    Object? error = _unset,
    bool? inLibrary,
    Object? mangaId = _unset,
    String? sourceName,
    SortMode? sortMode,
    Map<ChapterFilter, FilterMode>? filterModes,
    bool? offlineMode,
    Object? details = _unset,
    List<Map<String, dynamic>>? chapters,
    Map<String, Map<String, dynamic>>? localChapters,
    Object? localThumbnail = _unset,
    Map<String, String>? downloadProgress,
    bool? expanded,
  }) {
    return MangaDetailState(
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      inLibrary: inLibrary ?? this.inLibrary,
      mangaId: identical(mangaId, _unset) ? this.mangaId : mangaId as int?,
      sourceName: sourceName ?? this.sourceName,
      sortMode: sortMode ?? this.sortMode,
      filterModes: filterModes ?? this.filterModes,
      offlineMode: offlineMode ?? this.offlineMode,
      details: identical(details, _unset)
          ? this.details
          : details as Map<String, dynamic>?,
      chapters: chapters ?? this.chapters,
      localChapters: localChapters ?? this.localChapters,
      localThumbnail: identical(localThumbnail, _unset)
          ? this.localThumbnail
          : localThumbnail as String?,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      expanded: expanded ?? this.expanded,
    );
  }
}

class MangaDetailNotifier extends Notifier<MangaDetailState> {
  static const _keySortMode = 'manga_chapter_sort_mode';
  static const _keyFilterModes = 'manga_chapter_filter_modes';

  /// Tracks which manga the global state currently belongs to so a late
  /// async response from a previous detail screen cannot overwrite the next.
  String? _boundSourceId;
  String? _boundUrl;

  @override
  MangaDetailState build() {
    return const MangaDetailState();
  }

  bool isBoundTo({required String sourceId, required String url}) =>
      _boundSourceId == sourceId && _boundUrl == url;

  /// Wipe per-manga fields before opening another title. Keeps sort/filter
  /// prefs. Must run synchronously at the start of detail [_init] so build()
  /// does not keep watching the previous manga's Isar streams.
  void prepareFor({
    required String sourceId,
    required String url,
    String? title,
    String? memo,
  }) {
    _boundSourceId = sourceId;
    _boundUrl = url;
    final seed = <String, dynamic>{
      if (title != null && title.isNotEmpty) 'title': title,
      if (memo != null && memo.isNotEmpty) 'memo': memo,
    };
    state = MangaDetailState(
      loading: true,
      sortMode: state.sortMode,
      filterModes: state.filterModes,
      details: seed.isNotEmpty ? seed : null,
    );
  }

  Future<void> init({
    required String sourceId,
    required String url,
    Map<String, dynamic>? manga,
  }) async {
    prepareFor(sourceId: sourceId, url: url);
    final prefs = await SharedPreferences.getInstance();
    if (!isBoundTo(sourceId: sourceId, url: url)) return;
    final sortIdx = prefs.getInt(_keySortMode) ?? SortMode.chapterAsc.index;
    state = state.copyWith(sortMode: SortMode.values[sortIdx]);
    final filterRaw = prefs.getString(_keyFilterModes);
    if (filterRaw != null) {
      try {
        final json = jsonDecode(filterRaw) as Map<String, dynamic>;
        final modes = <ChapterFilter, FilterMode>{};
        for (final e in json.entries) {
          final key = ChapterFilter.values.firstWhere(
            (v) => v.name == e.key,
            orElse: () => ChapterFilter.values.first,
          );
          modes[key] = FilterMode.values[e.value as int? ?? 0];
        }
        state = state.copyWith(filterModes: modes);
      } catch (_) {}
    }
  }

  void setLoading(bool v) => state = state.copyWith(loading: v);
  void setError(String? e) => state = state.copyWith(error: e);
  void setInLibrary(bool v, int? id) =>
      state = state.copyWith(inLibrary: v, mangaId: id);
  void setMangaId(int? id) => state = state.copyWith(mangaId: id);
  void setSourceName(String n) => state = state.copyWith(sourceName: n);
  Future<void> setSortMode(SortMode m) async {
    state = state.copyWith(sortMode: m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySortMode, m.index);
  }

  void setFilterMode(ChapterFilter f, FilterMode m) {
    final modes = Map<ChapterFilter, FilterMode>.from(state.filterModes)
      ..[f] = m;
    state = state.copyWith(filterModes: modes);
  }

  void setDetails(Map<String, dynamic>? d) =>
      state = state.copyWith(details: d);
  void setChapters(List<Map<String, dynamic>> c) =>
      state = state.copyWith(chapters: c);
  void setLocalChapters(Map<String, Map<String, dynamic>> c) =>
      state = state.copyWith(localChapters: c);
  void setOfflineMode(bool v) => state = state.copyWith(offlineMode: v);
  void setLocalThumbnail(String? p) =>
      state = state.copyWith(localThumbnail: p);
  void setDownloadProgress(Map<String, String> p) =>
      state = state.copyWith(downloadProgress: p);
  void setExpanded(bool e) => state = state.copyWith(expanded: e);

  void applyChapters(List<Map<String, dynamic>> chapters) {
    final merged = chapters.map((ch) {
      final url = ch['url'] as String? ?? '';
      final local = state.localChapters[url];
      final cleaned = Map<String, dynamic>.from(ch)
        ..remove('is_read')
        ..remove('last_page_read')
        ..remove('is_downloaded')
        ..remove('is_opened')
        ..remove('read_at');
      if (local != null) cleaned.addAll(local);
      return cleaned;
    }).toList();
    state = state.copyWith(chapters: merged);
  }
}

final mangaDetailProvider =
    NotifierProvider<MangaDetailNotifier, MangaDetailState>(
      MangaDetailNotifier.new,
    );
