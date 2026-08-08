import 'dart:convert';

import '../extension_service.dart';
import '../models/m_source.dart';
import '../models/m_manga.dart';
import '../models/m_chapter.dart';
import '../models/m_pages.dart';
import '../models/filter_list.dart';
import '../models/source_preference.dart';
import 'bridges/m_provider_bridge.dart';
import 'js_runtime.dart';

/// Mangayomi-compatible JS extension host: injects MProvider + evaluates
/// `source.sourceCode`, then `var extention = new DefaultExtension();`,
/// calling methods via `jsonStringify(() => extention.$call)` + handlePromise.
class JsExtensionService implements ExtensionService {
  final JsRuntime _runtime;
  String? _boundSourceKey;

  JsExtensionService({JsRuntime? runtime}) : _runtime = runtime ?? JsRuntime();

  @override
  String get type => 'js';

  Future<void> _init(MSource source) async {
    await _runtime.init();
    final key =
        '${source.id}|${source.sourceId}|${source.sourceCode?.hashCode ?? 0}';
    if (_boundSourceKey == key) return;

    final sourceJson = jsonEncode(_sourceToJsJson(source));
    _runtime.evaluate(buildMProviderStub(sourceJson));
    _runtime.evaluate('''
${source.sourceCode ?? ''}
var extention = new DefaultExtension();
''');
    _boundSourceKey = key;
  }

  Map<String, dynamic> _sourceToJsJson(MSource source) => {
    'id': source.id,
    'name': source.name,
    'lang': source.lang,
    'baseUrl': source.baseUrl,
    'version': source.version,
    'apiUrl': '',
    'dateFormat': '',
    'dateFormatLocale': '',
    'hasCloudflare': false,
    'isFullData': false,
    'additionalParams': '',
    'notes': '',
  };

  Future<T> _extensionCallAsync<T>(MSource source, String call) async {
    await _init(source);
    final promised = await _runtime.handlePromise(
      await _runtime.evaluateAsync('jsonStringify(() => extention.$call)'),
    );
    return jsonDecode(promised.stringResult) as T;
  }

  T _extensionCallSync<T>(String call, T def) {
    try {
      final res = _runtime.evaluateRaw('JSON.stringify(extention.$call)');
      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      return def;
    }
  }

  List<MManga> _parseMangaList(dynamic raw) {
    final List<dynamic> list;
    if (raw is Map && raw['list'] is List) {
      list = raw['list'] as List;
    } else if (raw is List) {
      list = raw;
    } else {
      return [];
    }
    return list
        .whereType<Map>()
        .map((e) => MManga.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<MChapter> _parseChapters(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => MChapter.fromDynamic(e)).toList();
  }

  List<MPage> _parsePageImages(List raw) {
    final pages = <MPage>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e == null) continue;
      if (e is String) {
        final url = e.trim();
        if (url.isEmpty) continue;
        pages.add(MPage(index: i, url: url));
        continue;
      }
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        final url = (map['url'] as String? ?? '').trim();
        if (url.isEmpty) continue;
        pages.add(
          MPage(
            index: map['index'] as int? ?? i,
            url: url,
            headers: map['headers'] != null
                ? Map<String, String>.from(
                    (map['headers'] as Map).map(
                      (k, v) => MapEntry(k.toString(), v.toString()),
                    ),
                  )
                : null,
          ),
        );
      }
    }
    return pages;
  }

  @override
  Future<FilterList> getFilterList(MSource source) async {
    await _init(source);
    try {
      final raw = _extensionCallSync<List>('getFilterList()', <dynamic>[]);
      return FilterList.fromJson(raw);
    } catch (_) {
      return const FilterList();
    }
  }

  @override
  Future<List<MManga>> getPopular(int page, {required MSource source}) async {
    final raw = await _extensionCallAsync(source, 'getPopular($page)');
    return _parseMangaList(raw);
  }

  @override
  Future<List<MManga>> getLatestUpdates(
    int page, {
    required MSource source,
  }) async {
    final raw = await _extensionCallAsync(source, 'getLatestUpdates($page)');
    return _parseMangaList(raw);
  }

  @override
  Future<List<MManga>> search(
    MSource source,
    int page,
    String query, {
    FilterList? filters,
  }) async {
    final filtersJson = jsonEncode(
      filters?.filters.map((f) => f.toJson()).toList() ?? <dynamic>[],
    );
    final raw = await _extensionCallAsync(
      source,
      'search(${jsonEncode(query)},$page,$filtersJson)',
    );
    return _parseMangaList(raw);
  }

  @override
  Future<MManga?> getDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final raw = await _extensionCallAsync(
      source,
      'getDetail(${jsonEncode(url)})',
    );
    if (raw is! Map) return null;
    return MManga.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<List<MChapter>> getChapterList(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    // Prefer mangayomi shape: chapters embedded in getDetail.
    try {
      final detail = await _extensionCallAsync(
        source,
        'getDetail(${jsonEncode(url)})',
      );
      if (detail is Map) {
        final chapters = detail['chapters'] ?? detail['episodes'];
        if (chapters is List && chapters.isNotEmpty) {
          return _parseChapters(chapters);
        }
      }
    } catch (_) {}

    // Fallback: dedicated getChapterList if the extension implements it.
    try {
      final raw = await _extensionCallAsync(
        source,
        'getChapterList(${jsonEncode(url)})',
      );
      return _parseChapters(raw);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<({MManga? manga, List<MChapter> chapters})> getMangaDetail(
    MSource source,
    String url, {
    String? memo,
    String? title,
  }) async {
    final raw = await _extensionCallAsync(
      source,
      'getDetail(${jsonEncode(url)})',
    );
    if (raw is! Map) {
      return (manga: null, chapters: <MChapter>[]);
    }
    final map = Map<String, dynamic>.from(raw);
    final manga = MManga.fromJson(map);
    final chapters = _parseChapters(map['chapters'] ?? map['episodes']);
    if (chapters.isNotEmpty) {
      return (manga: manga, chapters: chapters);
    }
    final viaList = await getChapterList(
      source,
      url,
      memo: memo,
      title: title,
    );
    return (manga: manga, chapters: viaList);
  }

  @override
  Future<List<MPages>> getPageList(MSource source, MChapter chapter) async {
    final raw = await _extensionCallAsync<List>(
      source,
      'getPageList(${jsonEncode(chapter.url)})',
    );
    final pages = _parsePageImages(raw);
    return [MPages(pages: pages)];
  }

  @override
  Future<List<SourcePreference>> getSourcePreferences(MSource source) async {
    await _init(source);
    try {
      final raw =
          _extensionCallSync<List>('getSourcePreferences()', <dynamic>[]);
      return raw.map((e) => SourcePreference.fromDynamic(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveSourcePreference(
    MSource source,
    SourcePreference pref,
  ) async {
    await _init(source);
    try {
      _runtime.evaluate(
        'extention.saveSourcePreference(${jsonEncode(pref.key)}, ${jsonEncode(pref.defaultValue)})',
      );
    } catch (_) {}
  }
}
