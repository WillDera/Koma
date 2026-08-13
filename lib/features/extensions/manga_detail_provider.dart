import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  MangaDetailState copyWith({
    bool? loading,
    String? error,
    bool? inLibrary,
    int? mangaId,
    String? sourceName,
    SortMode? sortMode,
    Map<ChapterFilter, FilterMode>? filterModes,
    bool? offlineMode,
    Map<String, dynamic>? details,
    List<Map<String, dynamic>>? chapters,
    Map<String, Map<String, dynamic>>? localChapters,
    String? localThumbnail,
  }) {
    return MangaDetailState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      inLibrary: inLibrary ?? this.inLibrary,
      mangaId: mangaId ?? this.mangaId,
      sourceName: sourceName ?? this.sourceName,
      sortMode: sortMode ?? this.sortMode,
      filterModes: filterModes ?? this.filterModes,
      offlineMode: offlineMode ?? this.offlineMode,
      details: details ?? this.details,
      chapters: chapters ?? this.chapters,
      localChapters: localChapters ?? this.localChapters,
      localThumbnail: localThumbnail ?? this.localThumbnail,
    );
  }
}

class MangaDetailNotifier extends Notifier<MangaDetailState> {
  static const _keySortMode = 'manga_chapter_sort_mode';
  static const _keyFilterModes = 'manga_chapter_filter_modes';

  @override
  MangaDetailState build() {
    return const MangaDetailState();
  }

  Future<void> init({
    required String sourceId,
    required String url,
    Map<String, dynamic>? manga,
  }) async {
    state = state.copyWith(loading: true, error: null);
    final prefs = await SharedPreferences.getInstance();
    final sortIdx = prefs.getInt(_keySortMode) ?? SortMode.chapterAsc.index;
    state = state.copyWith(sortMode: SortMode.values[sortIdx]);
    final filterRaw = prefs.getString(_keyFilterModes);
    if (filterRaw != null) {
      try {
        final json = jsonDecode(filterRaw) as Map<String, dynamic>;
        final modes = <ChapterFilter, FilterMode>{};
        for (final e in json.entries) {
          final key = ChapterFilter.values.firstWhereOrNull(
            (v) => v.name == e.key,
          );
          if (key != null) {
            modes[key] = FilterMode.values[e.value as int? ?? 0];
          }
        }
        state = state.copyWith(filterModes: modes);
      } catch (_) {}
    }
  }

  void setLoading(bool v) => state = state.copyWith(loading: v);
  void setError(String? e) => state = state.copyWith(error: e);
  void setInLibrary(bool v, int? id) =>
      state = state.copyWith(inLibrary: v, mangaId: id);
  void setSourceName(String n) => state = state.copyWith(sourceName: n);
  void setSortMode(SortMode m) async {
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
