import 'package:d4rt/d4rt.dart';
import 'package:flutter/foundation.dart';
import 'package:koma/eval/dart/bridge/registrer.dart';
import 'package:koma/eval/extension_service.dart';
import 'package:koma/eval/javascript/bridges/prefs_bridge.dart';
import 'package:koma/eval/model/filter.dart' as dart_filter;
import 'package:koma/eval/model/m_chapter.dart' as dart_chapter;
import 'package:koma/eval/model/m_manga.dart' as dart_manga;
import 'package:koma/eval/model/m_pages.dart' as dart_pages;
import 'package:koma/eval/model/m_source.dart' as dart_source;
import 'package:koma/eval/model/page_url.dart';
import 'package:koma/eval/model/status.dart';
import 'package:koma/eval/models/filter_list.dart';
import 'package:koma/eval/models/m_chapter.dart';
import 'package:koma/eval/models/m_manga.dart';
import 'package:koma/eval/models/m_pages.dart';
import 'package:koma/eval/models/m_source.dart';
import 'package:koma/eval/models/manga_browse_page.dart';
import 'package:koma/eval/models/source_preference.dart';
import 'package:koma/eval/javascript/js_source_meta.dart';

/// Mangayomi-faithful d4rt Dart extension host.
///
/// Architecture mirrors `mangayomi/lib/eval/dart/service.dart`:
/// - Fresh [D4rt] interpreter per bound source
/// - [RegistrerBridge.registerBridge] + execute with `MSource` positional arg
/// - Bridge URI remains `package:mangayomi/bridge_lib.dart`
///
/// Implements LNStash [ExtensionService] and converts mangayomi-shaped
/// interpreter models to LNStash API models at the boundary.
class DartExtensionService implements ExtensionService {
  D4rt? _interpreter;
  String? _boundSourceKey;
  dart_source.MSource? _boundDartSource;

  @override
  String get type => 'dart';

  Future<void> _init(MSource source) async {
    final code = source.sourceCode ?? '';
    if (code.trim().isEmpty) {
      throw StateError(
        'Dart extension ${source.name} has empty sourceCode — reinstall it',
      );
    }
    final key = '${source.id}|${source.sourceId}|${code.hashCode}';
    if (_boundSourceKey == key && _interpreter != null) return;

    _interpreter = null;
    _boundSourceKey = null;
    _boundDartSource = null;

    await hydrateJsPrefsCache();

    final dartSrc = _toDartMSource(source);
    final interpreter = D4rt();
    RegistrerBridge.registerBridge(interpreter);
    interpreter.execute(
      source: code.replaceAll('Client(source)', 'Client()'),
      positionalArgs: [dartSrc],
    );

    _interpreter = interpreter;
    _boundSourceKey = key;
    _boundDartSource = dartSrc;
    _seedPreferenceDefaults(dartSrc);
  }

  /// Seed PrefsCache from `getSourcePreferences()` like mangayomi / JS path.
  void _seedPreferenceDefaults(dart_source.MSource dartSrc) {
    final sid = '${dartSrc.id ?? ''}';
    if (sid.isEmpty) return;
    try {
      final result = _interpreter!.invoke('getSourcePreferences', []);
      final prefs = (result as List).whereType<SourcePreference>();
      for (final pref in prefs) {
        final key = pref.key;
        if (key == null || key.isEmpty) continue;
        final fullKey = 'js_src_pref:$sid:$key';
        if (PrefsCache.instance.contains(fullKey)) continue;
        final def = pref.typedValue;
        if (def == null) continue;
        PrefsCache.instance.putJson(fullKey, def);
      }
    } catch (_) {}
  }

  dart_source.MSource _toDartMSource(MSource source) {
    final meta = parseMangayomiSourcesHeader(source.sourceCode);
    final id = int.tryParse(source.id) ?? int.tryParse(source.sourceId);
    final baseUrl = source.baseUrl.isNotEmpty
        ? source.baseUrl
        : (meta['baseUrl'] ?? '');
    final apiUrl = (source.apiUrl != null && source.apiUrl!.isNotEmpty)
        ? source.apiUrl
        : (meta['apiUrl']?.isNotEmpty == true ? meta['apiUrl'] : null);
    final dateFormat = (source.dateFormat != null && source.dateFormat!.isNotEmpty)
        ? source.dateFormat
        : (meta['dateFormat']?.isNotEmpty == true ? meta['dateFormat'] : null);
    final dateFormatLocale =
        (source.dateFormatLocale != null && source.dateFormatLocale!.isNotEmpty)
            ? source.dateFormatLocale
            : (meta['dateFormatLocale']?.isNotEmpty == true
                ? meta['dateFormatLocale']
                : null);
    return dart_source.MSource(
      id: id,
      name: source.name,
      baseUrl: baseUrl,
      lang: source.lang,
      isFullData: false,
      hasCloudflare: source.hasCloudflare || meta['hasCloudflare'] == 'true',
      dateFormat: dateFormat,
      dateFormatLocale: dateFormatLocale,
      apiUrl: apiUrl,
      additionalParams: '',
      notes: '',
    );
  }

  MangaBrowsePage _toBrowsePage(dart_pages.MPages pages) {
    return MangaBrowsePage(
      list: pages.list.map(_toApiManga).toList(),
      hasNextPage: pages.hasNextPage,
    );
  }

  MManga _toApiManga(dart_manga.MManga m) {
    return MManga(
      url: m.link ?? '',
      title: m.name ?? '',
      thumbnailUrl: m.imageUrl,
      author: m.author,
      artist: m.artist,
      description: m.description,
      status: _statusToInt(m.status),
      genres: m.genre ?? const [],
    );
  }

  int _statusToInt(Status? status) {
    return switch (status) {
      Status.ongoing => 0,
      Status.completed => 1,
      Status.onHiatus => 2,
      Status.canceled => 3,
      Status.publishingFinished => 4,
      Status.unknown || null => 0,
    };
  }

  MChapter _toApiChapter(dart_chapter.MChapter c) {
    final raw = c.dateUpload;
    final dateUpload = raw == null
        ? 0
        : (int.tryParse(raw) ?? DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0);
    return MChapter(
      url: c.url ?? '',
      name: c.name ?? '',
      scanlator: c.scanlator,
      dateUpload: dateUpload,
    );
  }

  List<MPage> _pageUrlsToMPages(List<PageUrl> urls) {
    return [
      for (var i = 0; i < urls.length; i++)
        MPage(index: i, url: urls[i].url.trim(), headers: urls[i].headers),
    ];
  }

  /// Convert LNStash [FilterList] into mangayomi-shaped filter instances for
  /// `search(query, page, FilterList)`.
  dart_filter.FilterList _toDartFilterList(FilterList? filters) {
    if (filters == null || filters.filters.isEmpty) {
      return dart_filter.FilterList([]);
    }
    final list = <dynamic>[];
    for (final f in filters.filters) {
      list.add(_toDartFilter(f));
    }
    return dart_filter.FilterList(list);
  }

  dynamic _toDartFilter(Filter f) {
    final typeName = f.typeName;
    final typeId = f.filterTypeId ?? f.key;
    switch (f.type) {
      case FilterType.select:
        return dart_filter.SelectFilter(
          typeId,
          f.name,
          f.value is int
              ? f.value as int
              : (f.value is num ? (f.value as num).toInt() : 0),
          (f.options ?? [])
              .map(
                (o) => dart_filter.SelectFilterOption(o.name, o.value, 'SelectOption'),
              )
              .toList(),
          typeName ?? 'SelectFilter',
        );
      case FilterType.text:
        return dart_filter.TextFilter(
          typeId,
          f.name,
          typeName ?? 'TextFilter',
          state: f.value as String? ?? '',
        );
      case FilterType.check:
        return dart_filter.CheckBoxFilter(
          typeId,
          f.name,
          f.options?.isNotEmpty == true ? f.options!.first.value : f.name,
          typeName ?? 'CheckBox',
          state: f.value as bool? ?? false,
        );
      case FilterType.triState:
        return dart_filter.TriStateFilter(
          typeId,
          f.name,
          f.options?.isNotEmpty == true ? f.options!.first.value : f.name,
          typeName ?? 'TriState',
          state: f.value is int
              ? f.value as int
              : (f.value is num ? (f.value as num).toInt() : 0),
        );
      case FilterType.sort:
        final raw = f.value;
        var index = 0;
        var ascending = false;
        if (raw is Map) {
          index = (raw['index'] as num?)?.toInt() ?? 0;
          ascending = raw['ascending'] == true;
        }
        return dart_filter.SortFilter(
          typeId,
          f.name,
          dart_filter.SortState(index, ascending, 'SortState'),
          (f.options ?? [])
              .map(
                (o) => dart_filter.SelectFilterOption(o.name, o.value, 'SelectOption'),
              )
              .toList(),
          typeName ?? 'SortFilter',
        );
      case FilterType.group:
        return dart_filter.GroupFilter(
          typeId,
          f.name,
          (f.subFilters ?? []).map(_toDartFilter).toList(),
          typeName ?? 'GroupFilter',
        );
      case FilterType.header:
        return dart_filter.HeaderFilter(f.name, typeName ?? 'HeaderFilter', type: typeId);
      case FilterType.separator:
        return dart_filter.SeparatorFilter(typeName ?? 'SeparatorFilter', type: typeId);
    }
  }

  FilterList _fromDartFilters(List filters) {
    final out = <Filter>[];
    for (final e in filters) {
      final f = _fromDartFilter(e);
      if (f != null) out.add(f);
    }
    return FilterList(filters: out);
  }

  Filter? _fromDartFilter(dynamic e) {
    if (e is BridgedInstance) {
      e = e.nativeObject;
    }
    if (e is dart_filter.SelectFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.select,
        value: e.state,
        options: e.values.map((o) {
          if (o is BridgedInstance) o = o.nativeObject;
          if (o is dart_filter.SelectFilterOption) {
            return FilterOption(name: o.name, value: o.value);
          }
          return FilterOption(name: o.toString(), value: o.toString());
        }).toList(),
        filterTypeId: e.type,
        typeName: e.typeName ?? 'SelectFilter',
      );
    }
    if (e is dart_filter.TextFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.text,
        value: e.state,
        filterTypeId: e.type,
        typeName: e.typeName ?? 'TextFilter',
      );
    }
    if (e is dart_filter.CheckBoxFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.check,
        value: e.state,
        options: [FilterOption(name: e.name, value: e.value)],
        filterTypeId: e.type,
        typeName: e.typeName ?? 'CheckBox',
      );
    }
    if (e is dart_filter.TriStateFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.triState,
        value: e.state,
        options: [FilterOption(name: e.name, value: e.value)],
        filterTypeId: e.type,
        typeName: e.typeName ?? 'TriState',
      );
    }
    if (e is dart_filter.SortFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.sort,
        value: {'index': e.state.index, 'ascending': e.state.ascending},
        options: e.values.map((o) {
          if (o is BridgedInstance) o = o.nativeObject;
          if (o is dart_filter.SelectFilterOption) {
            return FilterOption(name: o.name, value: o.value);
          }
          return FilterOption(name: o.toString(), value: o.toString());
        }).toList(),
        filterTypeId: e.type,
        typeName: e.typeName ?? 'SortFilter',
      );
    }
    if (e is dart_filter.GroupFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.group,
        subFilters: e.state
            .map(_fromDartFilter)
            .whereType<Filter>()
            .toList(),
        filterTypeId: e.type,
        typeName: e.typeName ?? 'GroupFilter',
      );
    }
    if (e is dart_filter.HeaderFilter) {
      return Filter(
        key: e.type ?? e.name,
        name: e.name,
        type: FilterType.header,
        filterTypeId: e.type,
        typeName: e.typeName ?? 'HeaderFilter',
      );
    }
    if (e is dart_filter.SeparatorFilter) {
      return Filter(
        key: e.type ?? 'separator',
        name: e.type ?? 'separator',
        type: FilterType.separator,
        filterTypeId: e.type,
        typeName: e.typeName ?? 'SeparatorFilter',
      );
    }
    return null;
  }

  List _toValueList(List filters) {
    return filters.map((e) {
      if (e is BridgedInstance) {
        e = e.nativeObject;
      }
      if (e is dart_filter.SelectFilter) {
        return dart_filter.SelectFilter(
          e.type,
          e.name,
          e.state,
          _toValueList(e.values),
          e.typeName,
        );
      } else if (e is dart_filter.SortFilter) {
        return dart_filter.SortFilter(
          e.type,
          e.name,
          e.state,
          _toValueList(e.values),
          e.typeName,
        );
      } else if (e is dart_filter.GroupFilter) {
        return dart_filter.GroupFilter(
          e.type,
          e.name,
          _toValueList(e.state),
          e.typeName,
        );
      }
      return e;
    }).toList();
  }

  @override
  Future<FilterList> getFilterList(MSource source) async {
    await _init(source);
    List<dynamic> list = [];
    try {
      list = _interpreter!.invoke('getFilterList', []) as List;
    } catch (e, st) {
      if (kDebugMode) {
        print('[DartExtensionService] getFilterList failed: $e\n$st');
      }
    }
    return _fromDartFilters(_toValueList(list));
  }

  @override
  Future<MangaBrowsePage> getPopular(int page, {required MSource source}) async {
    await _init(source);
    final pages =
        await _interpreter!.invoke('getPopular', [page]) as dart_pages.MPages;
    return _toBrowsePage(pages);
  }

  @override
  Future<MangaBrowsePage> getLatestUpdates(
    int page, {
    required MSource source,
  }) async {
    await _init(source);
    final pages = await _interpreter!.invoke('getLatestUpdates', [page])
        as dart_pages.MPages;
    return _toBrowsePage(pages);
  }

  @override
  Future<MangaBrowsePage> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) async {
    await _init(source);
    var effective = filters;
    if (effective == null || effective.filters.isEmpty) {
      effective = await getFilterList(source);
    }
    final pages = await _interpreter!.invoke('search', [
          query,
          page,
          _toDartFilterList(effective),
        ])
        as dart_pages.MPages;
    return _toBrowsePage(pages);
  }

  @override
  Future<MManga?> getDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    await _init(source);
    final manga =
        await _interpreter!.invoke('getDetail', [url]) as dart_manga.MManga;
    return _toApiManga(manga);
  }

  @override
  Future<List<MChapter>> getChapterList(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    await _init(source);
    final manga =
        await _interpreter!.invoke('getDetail', [url]) as dart_manga.MManga;
    final chapters = manga.chapters ?? [];
    return chapters.map(_toApiChapter).toList();
  }

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    await _init(source);
    final manga =
        await _interpreter!.invoke('getDetail', [url]) as dart_manga.MManga;
    return (
      manga: _toApiManga(manga),
      chapters: (manga.chapters ?? []).map(_toApiChapter).toList(),
    );
  }

  @override
  Future<List<MPages>> getPageList(MSource source, MChapter chapter) async {
    await _init(source);
    final result =
        await _interpreter!.invoke('getPageList', [chapter.url]) as List;
    final urls = result.map((e) {
      if (e is String) return PageUrl(e.trim());
      if (e is PageUrl) return e;
      if (e is BridgedInstance) {
        final n = e.nativeObject;
        if (n is PageUrl) return n;
      }
      if (e is Map) {
        return PageUrl.fromJson(Map<String, dynamic>.from(e));
      }
      return PageUrl(e.toString().trim());
    }).toList();
    return [MPages(pages: _pageUrlsToMPages(urls))];
  }

  @override
  Future<List<SourcePreference>> getSourcePreferences(MSource source) async {
    await _init(source);
    try {
      final result = _interpreter!.invoke('getSourcePreferences', []);
      return (result as List).whereType<SourcePreference>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveSourcePreference(MSource source, SourcePreference pref) async {
    await _init(source);
    final sid = _boundDartSource?.id?.toString() ?? source.sourceId;
    final key = pref.key;
    if (key == null || key.isEmpty) return;
    final value = pref.typedValue;
    if (value != null) {
      setJsPreferenceValue(sid, key, value);
    }
  }

  void dispose() {
    _interpreter = null;
    _boundSourceKey = null;
    _boundDartSource = null;
  }
}
