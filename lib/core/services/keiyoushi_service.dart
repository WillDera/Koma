import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class KeiyoushiService {
  static const _channel = MethodChannel('eu.kanade.tachiyomi/keiyoushi');

  late String _baseUrl;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final port = await _channel.invokeMethod<int>('getDalvikPort');
    if (port == null || port <= 0) {
      throw Exception('Failed to get Dalvik server port');
    }
    _baseUrl = 'http://127.0.0.1:$port/dalvik';
    _initialized = true;
  }

  Future<dynamic> _post(Map<String, dynamic> body) async {
    if (!_initialized) await init();
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
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
      if (className != null) 'className': className,
    };
    return _postChecked(body);
  }

  Future<void> unloadExtension(String sourceId) async {
    await _post({
      'method': 'unloadExtension',
      'sourceId': sourceId,
    });
  }

  Future<List<Map<String, dynamic>>> listLoadedExtensions() async {
    final result = await _postList({
      'method': 'listLoadedExtensions',
    });
    return result.cast<Map<String, dynamic>>();
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
      getPopularManga({required String sourceId, int page = 1}) async {
    final res = await _post({
      'method': 'getPopularManga',
      'sourceId': sourceId,
      'page': page,
    });
    return _parseMangasPage(res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
      getLatestUpdates({required String sourceId, int page = 1}) async {
    final res = await _post({
      'method': 'getLatestUpdates',
      'sourceId': sourceId,
      'page': page,
    });
    return _parseMangasPage(res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
  }

  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
      searchManga({required String sourceId, String query = '', int page = 1}) async {
    final res = await _post({
      'method': 'getSearchManga',
      'sourceId': sourceId,
      'query': query,
      'page': page,
    });
    return _parseMangasPage(res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{});
  }

  Future<({Map<String, dynamic> details, List<Map<String, dynamic>> chapters})>
      getMangaUpdate({required String sourceId, required String url}) async {
    final res = await _post({
      'method': 'getMangaUpdate',
      'sourceId': sourceId,
      'url': url,
    });
    final Map<String, dynamic> raw = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
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
  }) async {
    final res = await _post({
      'method': 'getMangaDetails',
      'sourceId': sourceId,
      'url': url,
    });
    if (res is! Map) return {};
    if (res.containsKey('error')) return {};
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getChapterList({
    required String sourceId,
    required String url,
  }) async {
    final res = await _post({
      'method': 'getChapterList',
      'sourceId': sourceId,
      'url': url,
    });
    if (res is! List) return [];
    return res
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchAllInstalled({
    String query = '',
    int page = 1,
  }) async {
    final res = await _post({
      'method': 'searchAllInstalled',
      'query': query,
      'page': page,
    });
    if (res is! List) return [];
    return res.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPageList({
    required String sourceId,
    required String url,
  }) async {
    final res = await _post({
      'method': 'getPageList',
      'sourceId': sourceId,
      'url': url,
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
    final res = await _post({
      'method': 'downloadChapters',
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrls': urls,
      'chapterNames': names,
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
    final mangas = ((raw['mangas'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final hasNext = (raw['hasNextPage'] as bool?) ?? false;
    return (mangas: mangas, hasNextPage: hasNext);
  }
}