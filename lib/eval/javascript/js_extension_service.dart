import 'dart:async';
import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import '../extension_service.dart';
import '../models/m_source.dart';
import '../models/m_manga.dart';
import '../models/m_chapter.dart';
import '../models/m_pages.dart';
import '../models/filter_list.dart';
import '../models/source_preference.dart';
import 'bridges/crypto_bridge.dart';
import 'bridges/dom_bridge.dart';
import 'bridges/http_bridge.dart';
import 'bridges/m_provider_bridge.dart';
import 'bridges/prefs_bridge.dart';
import 'bridges/utils_bridge.dart';

/// Mangayomi-compatible JS extension host.
///
/// Architecture mirrors `mangayomi/lib/eval/javascript/service.dart`:
/// - Fresh [getJavascriptRuntime] per bound source (no shared dirty engine)
/// - Init order: Http → Dom → Utils → Crypto → SharedPreferences → MProvider
/// - Calls via `jsonStringify(() => extention.$call)` + [handlePromise]
class JsExtensionService implements ExtensionService {
  JavascriptRuntime? _runtime;
  String? _boundSourceKey;

  /// Serialize calls on the active runtime (QuickJS is not re-entrant).
  Future<void> _chain = Future.value();

  @override
  String get type => 'js';

  Future<T> _serialized<T>(Future<T> Function() run) {
    final done = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        done.complete(await run());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> _init(MSource source) async {
    final code = source.sourceCode ?? '';
    if (code.trim().isEmpty) {
      throw StateError(
        'JS extension ${source.name} has empty sourceCode — reinstall it',
      );
    }
    final key = '${source.id}|${source.sourceId}|${code.hashCode}';
    if (_boundSourceKey == key && _runtime != null) return;

    // Tear down previous source's engine (mangayomi: one runtime per Source).
    try {
      _runtime?.dispose();
    } catch (_) {}
    _runtime = null;
    _boundSourceKey = null;

    await hydrateJsPrefsCache();

    // Same factory mangayomi uses for JS manga extensions.
    final runtime = getJavascriptRuntime();
    await injectHttpBridge(runtime);
    await injectDomBridge(runtime);
    await injectUtilsBridge(runtime);
    await injectCryptoBridge(runtime);
    injectPrefsBridge(runtime, sourceId: source.sourceId);

    final sourceJson = jsonEncode(_sourceToJsJson(source));
    runtime.evaluate(buildMProviderStub(sourceJson));
    runtime.evaluate('''
$code
var extention = new DefaultExtension();
''');

    _runtime = runtime;
    _boundSourceKey = key;
  }

  Map<String, dynamic> _sourceToJsJson(MSource source) {
    final id = int.tryParse(source.id) ?? int.tryParse(source.sourceId);
    return {
      'id': id ?? source.id,
      'name': source.name,
      'lang': source.lang,
      'baseUrl': source.baseUrl,
      'apiUrl': '',
      'dateFormat': '',
      'dateFormatLocale': '',
      'hasCloudflare': false,
      'isFullData': false,
      'additionalParams': '',
      'notes': '',
    };
  }

  Future<T> _extensionCallAsync<T>(MSource source, String call) {
    return _serialized(() async {
      await _init(source);
      final runtime = _runtime!;
      final evaled = await runtime.evaluateAsync(
        'jsonStringify(() => extention.$call)',
      );
      final promised = await runtime
          .handlePromise(evaled)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'JS call timed out: $call (${source.name})',
            ),
          );
      if (promised.isError) {
        throw StateError('JS error in $call: ${promised.stringResult}');
      }
      final raw = promised.stringResult;
      if (raw.isEmpty) {
        throw StateError('JS call returned empty: $call (${source.name})');
      }
      return jsonDecode(raw) as T;
    });
  }

  T _extensionCallSync<T>(String call, T def) {
    final runtime = _runtime;
    if (runtime == null) return def;
    try {
      final res = runtime.evaluate('JSON.stringify(extention.$call)');
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
  Future<FilterList> getFilterList(MSource source) {
    return _serialized(() async {
      await _init(source);
      try {
        final raw = _extensionCallSync<List>('getFilterList()', <dynamic>[]);
        return FilterList.fromJson(raw);
      } catch (_) {
        return const FilterList();
      }
    });
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
    // Mangayomi passes filter objects with type_name/state/values — extensions
    // (e.g. Webtoons) look up filters by `type` id and read `.state`/`.values`.
    // Keiyoushi-shaped `toJson()` breaks that; use mangayomi shape.
    var effective = filters;
    if (effective == null || effective.filters.isEmpty) {
      effective = await getFilterList(source);
    }
    final filtersJson = jsonEncode(effective.toJsJson());
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
    // Mangayomi JS has no getChapterList — chapters come from getDetail only.
    final raw = await _extensionCallAsync(
      source,
      'getDetail(${jsonEncode(url)})',
    );
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    return _parseChapters(map['chapters'] ?? map['episodes']);
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
    return (manga: manga, chapters: chapters);
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
      _runtime?.evaluate(
        'extention.saveSourcePreference(${jsonEncode(pref.key)}, ${jsonEncode(pref.defaultValue)})',
      );
    } catch (_) {}
  }
}
