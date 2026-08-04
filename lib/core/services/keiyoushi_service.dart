import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class KeiyoushiService {
  static const _channel = MethodChannel('eu.kanade.tachiyomi/keiyoushi');

  late String _baseUrl;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Primary path: the MainActivity engine exposes getDalvikPort. Background
    // isolates (WorkManager) run on a separate engine with no such handler,
    // so we fall back to the port persisted by DalvikRuntimeManager into
    // Flutter's shared_preferences store.
    int port = 0;
    try {
      port = await _channel.invokeMethod<int>('getDalvikPort') ?? 0;
    } catch (_) {
      port = 0;
    }
    if (port <= 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Kotlin writes flutter.dalvik_port into the native store after the
        // Dart cache may already have been loaded — reload before reading.
        await prefs.reload();
        // Logical key; SharedPreferences strips/adds the "flutter." prefix.
        port = prefs.getInt('dalvik_port') ?? 0;
      } catch (_) {
        port = 0;
      }
    }
    if (port <= 0) {
      throw Exception('Failed to get Dalvik server port');
    }
    _baseUrl = 'http://127.0.0.1:$port/dalvik';
    _initialized = true;
  }

  Future<dynamic> _post(Map<String, dynamic> body) async {
    if (!_initialized) await init();
    final res = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('Dalvik server returned ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  /// Like [_post] but throws if the response isn't a Map or contains an
  /// `error` field. Use for operations where failure must be reported
  /// (install, reload).
  Future<Map<String, dynamic>> _postChecked(Map<String, dynamic> body) async {
    final result = await _post(body);
    if (result is! Map) {
      throw Exception('Expected Map response, got ${result.runtimeType}');
    }
    final map = Map<String, dynamic>.from(result);
    if (map.containsKey('error')) {
      throw Exception(map['error']);
    }
    return map;
  }

  Future<List<dynamic>> _postList(Map<String, dynamic> body) async {
    final result = await _post(body);
    if (result is List) return result;
    return [];
  }

  Future<Map<String, dynamic>> loadExtension({
    required String apkPath,
    String? className,
  }) async {
    final body = <String, dynamic>{
      'method': 'loadExtension',
      'apkPath': apkPath,
      'className': ?className,
    };
    return _postChecked(body);
  }

  Future<void> unloadExtension(String sourceId) async {
    await _post({'method': 'unloadExtension', 'sourceId': sourceId});
  }

  Future<List<Map<String, dynamic>>> listLoadedExtensions() async {
    final result = await _postList({'method': 'listLoadedExtensions'});
    return result.cast<Map<String, dynamic>>();
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
  getPopularManga({required String sourceId, int page = 1}) async {
    final res = await _post({
      'method': 'getPopularManga',
      'sourceId': sourceId,
      'page': page,
    });
    return _parseMangasPage(
      res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{},
    );
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
  getLatestUpdates({required String sourceId, int page = 1}) async {
    final res = await _post({
      'method': 'getLatestUpdates',
      'sourceId': sourceId,
      'page': page,
    });
    return _parseMangasPage(
      res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{},
    );
  }

  Future<List<Map<String, dynamic>>> getFilters({
    required String sourceId,
  }) async {
    final res = await _post({'method': 'filtersManga', 'sourceId': sourceId});
    if (res is! List) return [];
    return res.cast<Map<String, dynamic>>();
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})> searchManga({
    required String sourceId,
    String query = '',
    int page = 1,
    List<Map<String, dynamic>>? filters,
  }) async {
    final body = <String, dynamic>{
      // DalvikServer handler is getSearchManga (alias searchManga also accepted).
      'method': 'getSearchManga',
      'sourceId': sourceId,
      'query': query,
      'page': page,
    };
    if (filters != null) body['filters'] = filters;
    final res = await _post(body);
    return _parseMangasPage(
      res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{},
    );
  }

  Future<({Map<String, dynamic> details, List<Map<String, dynamic>> chapters})>
  getMangaUpdate({
    required String sourceId,
    required String url,
    String? memo,
  }) async {
    final res = await _post({
      'method': 'getMangaUpdate',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
    });
    final Map<String, dynamic> raw = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final details = Map<String, dynamic>.from(raw['manga'] ?? {});
    final chapters = (raw['chapters'] as List? ?? [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    return (details: details, chapters: chapters);
  }

  Future<Map<String, dynamic>> getMangaDetails({
    required String sourceId,
    required String url,
    String? memo,
  }) async {
    final res = await _post({
      'method': 'getMangaDetails',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
    });
    if (res is! Map) return {};
    if (res.containsKey('error')) return {};
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getChapterList({
    required String sourceId,
    required String url,
    String? memo,
  }) async {
    final res = await _post({
      'method': 'getChapterList',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
    });
    if (res is! List) return [];
    return res
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Search every extension currently loaded in the Dalvik cache.
  ///
  /// Prefer the native `searchAllInstalled` fan-out. If the server doesn't
  /// know that method (older builds) or returns an error map, fall back to
  /// calling [searchManga] per loaded source so Discover still works.
  Future<List<Map<String, dynamic>>> searchAllInstalled({
    String query = '',
    int page = 1,
  }) async {
    try {
      final res = await _post({
        'method': 'searchAllInstalled',
        'query': query,
        'page': page,
      });
      if (res is List) {
        return res
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      // Unknown-method / error payload → Dart fan-out below.
    } catch (_) {
      // Dalvik unreachable or timed out → try per-source path.
    }

    final loaded = await listLoadedExtensions();
    if (loaded.isEmpty) return const [];

    final results = await Future.wait(
      loaded.map((ext) async {
        final sourceId = ext['sourceId'] as String? ?? '';
        if (sourceId.isEmpty) return null;
        try {
          final pageResult = await searchManga(
            sourceId: sourceId,
            query: query,
            page: page,
          );
          if (pageResult.mangas.isEmpty) return null;
          return <String, dynamic>{
            'sourceId': sourceId,
            'sourceName': ext['name'] as String? ?? '',
            'baseUrl': ext['baseUrl'] as String? ?? '',
            'mangas': pageResult.mangas,
            'hasNextPage': pageResult.hasNextPage,
          };
        } catch (_) {
          return null;
        }
      }),
    );
    return results.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getPageList({
    required String sourceId,
    required String url,
    String? memo,
  }) async {
    final res = await _post({
      'method': 'getPageList',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
    });
    if (res is! List) return [];
    return res.cast<Map<String, dynamic>>();
  }

  Future<Map<String, List<String>>> downloadChapters({
    required String sourceId,
    required String mangaUrl,
    required List<Map<String, dynamic>> chapters,
  }) async {
    final urls = chapters.map((ch) => ch['url'] as String? ?? '').toList();
    final names = chapters.map((ch) => ch['name'] as String? ?? '').toList();
    final memos = chapters.map((ch) => ch['memo'] as String? ?? '').toList();
    final res = await _post({
      'method': 'downloadChapters',
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrls': urls,
      'chapterNames': names,
      'chapterMemos': memos,
    });
    if (res is! Map) return {};
    return res.map((k, v) => MapEntry(k, (v as List).cast<String>()));
  }

  Future<List<String>> getLocalPages({
    required String sourceId,
    required String mangaUrl,
    required String chapterUrl,
  }) async {
    final res = await _postList({
      'method': 'getLocalPages',
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrl': chapterUrl,
    });
    return res.cast<String>();
  }

  ({List<Map<String, dynamic>> mangas, bool hasNextPage}) _parseMangasPage(
    Map<String, dynamic> raw,
  ) {
    if (raw.containsKey('error')) {
      throw Exception(raw['error']?.toString() ?? 'Dalvik search failed');
    }
    final mangas = ((raw['mangas'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final hasNext = (raw['hasNextPage'] as bool?) ?? false;
    return (mangas: mangas, hasNextPage: hasNext);
  }
}
