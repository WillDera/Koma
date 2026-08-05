import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Normalize source `SManga.memo` to a JSON string for round-trip to Dalvik.
/// Accepts an already-encoded string, a nested Map, or empty/null.
String? coerceMemoJson(dynamic memo) {
  if (memo == null) return null;
  if (memo is String) {
    final t = memo.trim();
    return t.isEmpty ? null : t;
  }
  if (memo is Map) {
    try {
      return jsonEncode(Map<String, dynamic>.from(memo));
    } catch (_) {
      return null;
    }
  }
  final s = memo.toString().trim();
  return s.isEmpty ? null : s;
}

/// Thrown when the client aborts an in-flight [KeiyoushiService.downloadChapters]
/// by closing the HTTP connection (pause / cancel).
class DownloadAbortedException implements Exception {
  const DownloadAbortedException();

  @override
  String toString() => 'DownloadAbortedException';
}

Map<String, dynamic> _normalizeMangaMap(Map<String, dynamic> manga) {
  final memo = coerceMemoJson(manga['memo']);
  if (memo == null) {
    if (!manga.containsKey('memo')) return manga;
    final copy = Map<String, dynamic>.from(manga);
    copy.remove('memo');
    return copy;
  }
  if (identical(manga['memo'], memo)) return manga;
  return {...manga, 'memo': memo};
}

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

  Future<dynamic> _post(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!_initialized) await init();
    final res = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);
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
    String? title,
    String? thumbnailUrl,
    String? author,
    String? artist,
    String? description,
    String? genre,
    int? status,
  }) async {
    final res = await _post({
      'method': 'getMangaUpdate',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
      'title': ?title,
      'thumbnail_url': ?thumbnailUrl,
      'author': ?author,
      'artist': ?artist,
      'description': ?description,
      'genre': ?genre,
      'status': ?status,
    });
    if (res is Map && res.containsKey('error')) {
      throw Exception(res['error']);
    }
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
    String? title,
  }) async {
    final res = await _post({
      'method': 'getMangaDetails',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
      'title': ?title,
    });
    if (res is! Map) return {};
    if (res.containsKey('error')) {
      throw Exception(res['error']);
    }
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getChapterList({
    required String sourceId,
    required String url,
    String? memo,
    String? title,
  }) async {
    final res = await _post({
      'method': 'getChapterList',
      'sourceId': sourceId,
      'url': url,
      'memo': ?memo,
      'title': ?title,
    });
    if (res is Map && res.containsKey('error')) {
      throw Exception(res['error']);
    }
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
        return res.whereType<Map>().map((e) {
          final entry = Map<String, dynamic>.from(e);
          final mangas = (entry['mangas'] as List? ?? const [])
              .whereType<Map>()
              .map((m) => _normalizeMangaMap(Map<String, dynamic>.from(m)))
              .toList(growable: false);
          entry['mangas'] = mangas;
          return entry;
        }).toList(growable: false);
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
    void Function(String chapterUrl, int done, int total)? onProgress,
    /// When aborted (client closed), the NDJSON stream ends and this throws
    /// [DownloadAbortedException] so the queue can re-queue the chapter.
    Object? abort,
  }) async {
    if (!_initialized) await init();
    final urls = chapters.map((ch) => ch['url'] as String? ?? '').toList();
    final names = chapters.map((ch) => ch['name'] as String? ?? '').toList();
    final memos = chapters
        .map((ch) => coerceMemoJson(ch['memo']) ?? '')
        .toList();
    // Chapter downloads (esp. Cloudflare-challenged sources) commonly exceed
    // the default 60s request timeout — that surfaced as "Future not completed".
    final timeout = Duration(minutes: 2 + chapters.length.clamp(1, 20));
    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'method': 'downloadChapters',
        'sourceId': sourceId,
        'mangaUrl': mangaUrl,
        'chapterUrls': urls,
        'chapterNames': names,
        'chapterMemos': memos,
      });
    final client = http.Client();
    // DownloadAbortController.attach — duck-typed to avoid a hard cycle.
    try {
      (abort as dynamic)?.attach(client);
    } catch (_) {}
    try {
      final streamed = await client.send(request).timeout(timeout);
      if (streamed.statusCode != 200) {
        throw Exception('Dalvik server returned ${streamed.statusCode}');
      }
      Map<String, List<String>>? result;
      // Overall timeout for the whole download — not per-line idle
      // (individual pages can stall under Cloudflare for a long time).
      await Future(() async {
        await for (final line in streamed.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final dynamic decoded;
          try {
            decoded = jsonDecode(trimmed);
          } catch (_) {
            throw Exception('Invalid download progress line');
          }
          if (decoded is! Map) continue;
          final map = Map<String, dynamic>.from(decoded);
          final type = map['type']?.toString();
          if (type == 'progress') {
            final chapterUrl = map['chapterUrl']?.toString() ?? '';
            final done = (map['done'] as num?)?.toInt() ?? 0;
            final total = (map['total'] as num?)?.toInt() ?? 0;
            if (chapterUrl.isNotEmpty && total > 0) {
              onProgress?.call(chapterUrl, done, total);
            }
          } else if (type == 'result') {
            final chaptersRaw = map['chapters'];
            final out = <String, List<String>>{};
            if (chaptersRaw is Map) {
              for (final entry in chaptersRaw.entries) {
                final v = entry.value;
                if (v is List) {
                  out[entry.key.toString()] =
                      v.map((e) => e.toString()).toList();
                }
              }
            }
            result = out;
          } else if (type == 'error') {
            throw Exception(map['message']?.toString() ?? 'Download failed');
          } else if (map.containsKey('error')) {
            // Legacy single-JSON error shape.
            throw Exception(map['error']?.toString() ?? 'Download failed');
          }
        }
      }).timeout(timeout);
      final aborted = () {
        try {
          return (abort as dynamic)?.isAborted == true;
        } catch (_) {
          return false;
        }
      }();
      if (aborted) {
        throw const DownloadAbortedException();
      }
      final chapters = result;
      if (chapters == null) {
        throw Exception('Download ended without result');
      }
      return chapters;
    } on DownloadAbortedException {
      rethrow;
    } catch (e) {
      final aborted = () {
        try {
          return (abort as dynamic)?.isAborted == true;
        } catch (_) {
          return false;
        }
      }();
      if (aborted) throw const DownloadAbortedException();
      rethrow;
    } finally {
      client.close();
    }
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

  /// Deletes on-disk page dirs for [chapterUrls] under
  /// `filesDir/manga/{sourceId}/{mangaKey}/{chKey}/`. Returns the chapter
  /// URLs that were removed (missing dirs still count as deleted).
  Future<List<String>> deleteChapters({
    required String sourceId,
    required String mangaUrl,
    required List<String> chapterUrls,
  }) async {
    final res = await _post({
      'method': 'deleteChapters',
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrls': chapterUrls,
    });
    if (res is! Map) {
      throw Exception('Unexpected delete response');
    }
    final map = Map<String, dynamic>.from(res);
    if (map.containsKey('error')) {
      throw Exception(map['error']?.toString() ?? 'Delete failed');
    }
    final deleted = map['deleted'];
    if (deleted is! List) return [];
    return deleted.map((e) => e.toString()).toList();
  }

  ({List<Map<String, dynamic>> mangas, bool hasNextPage}) _parseMangasPage(
    Map<String, dynamic> raw,
  ) {
    if (raw.containsKey('error')) {
      throw Exception(raw['error']?.toString() ?? 'Dalvik search failed');
    }
    final mangas = ((raw['mangas'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => _normalizeMangaMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final hasNext = (raw['hasNextPage'] as bool?) ?? false;
    return (mangas: mangas, hasNextPage: hasNext);
  }
}
