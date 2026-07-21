import 'package:flutter/services.dart';

/// Single method-channel client to the native Keiyoushi bridge.
///
/// All extension work (loading APKs, calling into Source subclasses,
/// unloading) goes through this class — the rest of the app never
/// touches the binary messenger directly.
class KeiyoushiService {
  static const _channel = MethodChannel('eu.kanade.tachiyomi/keiyoushi');

  /// Load a Source class from an APK. If [className] is null, the
  /// native side reads it from the APK's
  /// `<meta-data android:name="tachiyomi.extension.class">` tag.
  ///
  /// Returns a map: `{ id, name, lang, apkPath, className }`.
  Future<Map<String, dynamic>> loadExtension({
    required String apkPath,
    String? className,
  }) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'loadExtension',
      {'apkPath': apkPath, if (className != null) 'className': className},
    );
    return Map<String, dynamic>.from(res ?? const {});
  }

  /// Unload a previously loaded Source by its stable id.
  Future<void> unloadExtension(String sourceId) =>
      _channel.invokeMethod('unloadExtension', {'sourceId': sourceId});

  /// List every currently loaded Source, as descriptors.
  Future<List<Map<String, dynamic>>> listLoadedExtensions() async {
    final res = await _channel.invokeListMethod<dynamic>('listLoadedExtensions');
    return (res ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Fetch a page of popular manga from a loaded source.
  ///
  /// Returns `{ mangas: List<Map>, hasNextPage: bool }`.
  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
      getPopularManga({required String sourceId, int page = 1}) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'getPopularManga',
      {'sourceId': sourceId, 'page': page},
    );
    return _parseMangasPage(res);
  }

  /// Search a loaded source.
  Future<({List<Map<String, dynamic>> mangas, bool hasNextPage})>
      searchManga({required String sourceId, String query = '', int page = 1}) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'searchManga',
      {'sourceId': sourceId, 'query': query, 'page': page},
    );
    return _parseMangasPage(res);
  }

  /// Fetch full manga metadata (description, author, genre, etc.).
  Future<Map<String, dynamic>> getMangaDetails({
    required String sourceId,
    required String url,
  }) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'getMangaDetails',
      {'sourceId': sourceId, 'url': url},
    );
    return Map<String, dynamic>.from(res ?? const {});
  }

  /// Fetch chapter list for a manga URL.
  Future<List<Map<String, dynamic>>> getChapterList({
    required String sourceId,
    required String url,
  }) async {
    final res = await _channel.invokeListMethod<dynamic>(
      'getChapterList',
      {'sourceId': sourceId, 'url': url},
    );
    return (res ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Search ALL loaded sources for [query]. Returns one entry per source
  /// that has results: `[{ sourceId, sourceName, mangas, hasNextPage }]`.
  Future<List<Map<String, dynamic>>> searchAllInstalled({
    String query = '',
    int page = 1,
  }) async {
    final res = await _channel.invokeListMethod<dynamic>(
      'searchAllInstalled',
      {'query': query, 'page': page},
    );
    return (res ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Fetch page list (image URLs) for a chapter.
  Future<List<Map<String, dynamic>>> getPageList({
    required String sourceId,
    required String url,
  }) async {
    final res = await _channel.invokeListMethod<dynamic>(
      'getPageList',
      {'sourceId': sourceId, 'url': url},
    );
    return (res ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// Download one or more chapters to local storage.
  ///
  /// Returns a map of chapterUrl → list of local file URIs.
  Future<Map<String, List<String>>> downloadChapters({
    required String sourceId,
    required String mangaUrl,
    required List<Map<String, dynamic>> chapters,
  }) async {
    final urls = chapters.map((ch) => ch['url'] as String? ?? '').toList();
    final names = chapters.map((ch) => ch['name'] as String? ?? '').toList();
    final res = await _channel.invokeMapMethod<String, dynamic>('downloadChapters', {
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrls': urls,
      'chapterNames': names,
    });
    return (res ?? const {}).map((k, v) =>
        MapEntry(k, (v as List).cast<String>()));
  }

  /// Check for locally downloaded page files for a chapter.
  /// Returns a list of file URIs sorted by page index, or empty list.
  Future<List<String>> getLocalPages({
    required String sourceId,
    required String mangaUrl,
    required String chapterUrl,
  }) async {
    final res = await _channel.invokeListMethod<String>('getLocalPages', {
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
      'chapterUrl': chapterUrl,
    });
    return res ?? const [];
  }

  /// Return the set of chapter key hashes that have downloaded files on disk.
  Future<Set<String>> getDownloadedChapterKeys({
    required String sourceId,
    required String mangaUrl,
  }) async {
    final res = await _channel.invokeListMethod<String>('getDownloadedChapterKeys', {
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
    });
    return (res ?? const []).toSet();
  }

  ({List<Map<String, dynamic>> mangas, bool hasNextPage}) _parseMangasPage(
    Map<String, dynamic>? raw,
  ) {
    final mangas = ((raw?['mangas'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final hasNext = (raw?['hasNextPage'] as bool?) ?? false;
    return (mangas: mangas, hasNextPage: hasNext);
  }
}
