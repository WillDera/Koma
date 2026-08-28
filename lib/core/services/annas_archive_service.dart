import 'dart:convert';

import 'package:annas_archive_api/annas_archive_api.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/source.dart';
import 'annas_archive_prefs.dart';

const _kAnnaFastDownload = "Anna's Archive (fast)";

/// Search + download helpers for Anna's Archive (RapidAPI primary, package fallback).
class AnnasArchiveService {
  AnnasArchiveService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final AnnaApi _annaApi = AnnaApi();

  static final _defaultCategories = [
    Category.fiction,
    Category.nonfiction,
    Category.comic,
    Category.magazine,
    Category.musicalScore,
    Category.other,
    Category.unknown,
  ];

  static const _languageCodes = {
    'english': 'en',
    'french': 'fr',
    'german': 'de',
    'spanish': 'es',
    'italian': 'it',
    'portuguese': 'pt',
    'russian': 'ru',
    'chinese': 'zh',
    'japanese': 'ja',
    'korean': 'ko',
    'dutch': 'nl',
    'polish': 'pl',
    'arabic': 'ar',
    'hindi': 'hi',
  };

  /// Search enabled Anna's Archive sources. Uses RapidAPI when a key is set,
  /// otherwise [AnnaApi] HTML scraping; falls back to the package on RapidAPI errors.
  Future<List<AnnasSearchHit>> search(Source source, String query) async {
    final prefs = await SharedPreferences.getInstance();
    final rapidKey = await readAnnasArchiveRapidApiKey(prefs);

    if (rapidKey != null) {
      try {
        return await _searchRapidApi(
          query: query,
          source: source,
          rapidKey: rapidKey,
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AnnasArchive RapidAPI search failed: $e\n$st');
        }
      }
    }

    return _searchPackage(query: query, source: source);
  }

  /// Resolves download mirrors for an Anna's Archive md5 hash.
  Future<Map<String, String>> downloadOptions(String md5) async {
    final normalized = md5.trim().toLowerCase();
    if (normalized.length != 32) return {};

    final prefs = await SharedPreferences.getInstance();
    final rapidKey = await readAnnasArchiveRapidApiKey(prefs);
    final secretKey = await readAnnasArchiveSecretKey(prefs);
    final options = <String, String>{};

    if (secretKey != null) {
      final fast = await _resolveFastDownload(
        md5: normalized,
        secretKey: secretKey,
        rapidKey: rapidKey,
      );
      if (fast != null) {
        options[_kAnnaFastDownload] = fast;
      }
    }

    Map<String, String> mirrorLinks = const {};
    if (rapidKey != null) {
      try {
        mirrorLinks = await _downloadLinksRapidApi(
          md5: normalized,
          rapidKey: rapidKey,
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AnnasArchive RapidAPI download links failed: $e\n$st');
        }
      }
    }

    if (mirrorLinks.isEmpty) {
      mirrorLinks = await _downloadLinksPackage(normalized);
    }

    for (final entry in mirrorLinks.entries) {
      options.putIfAbsent(entry.key, () => entry.value);
    }

    return options;
  }

  Future<List<AnnasSearchHit>> _searchRapidApi({
    required String query,
    required Source source,
    required String rapidKey,
  }) async {
    final params = <String, String>{
      'q': query.trim(),
      'page': '1',
      'sort': 'mostRelevant',
      'cat':
          'fiction, nonfiction, comic, magazine, musicalscore, other, unknown',
      'source': 'libgenLi, libgenRs, zLibrary, internetArchive',
    };

    final lang = _languageCode(source.language);
    if (lang != null) {
      params['lang'] = lang;
    } else {
      params['lang'] = 'en';
    }

    final exts = source.fileExtensions;
    if (exts.isNotEmpty) {
      params['ext'] = exts.join(', ');
    } else {
      params['ext'] = 'pdf, epub, mobi, azw3';
    }

    final uri = Uri.https(annasArchiveRapidApiHost, '/search', params);
    final response = await _client
        .get(uri, headers: _rapidHeaders(rapidKey))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('RapidAPI search HTTP ${response.statusCode}');
    }

    final body = _decodeJsonMap(response.body);
    if (body == null) return [];

    final booksRaw = body['books'];
    if (booksRaw is! List) return [];

    return booksRaw
        .whereType<Map>()
        .map((raw) => _hitFromRapidJson(Map<String, dynamic>.from(raw)))
        .where((h) => h.md5.length == 32 && h.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<AnnasSearchHit>> _searchPackage({
    required String query,
    required Source source,
  }) async {
    final formats = _formatsFromExtensions(source.fileExtensions);
    final language = _languageEnum(source.language);

    final response = await _annaApi.find(
      SearchRequest(
        query: query.trim(),
        formats: formats,
        language: language,
        categories: _defaultCategories,
        sources: const [
          AnnaSource.libgenLi,
          AnnaSource.libgenRs,
          AnnaSource.zLibrary,
          AnnaSource.internetArchive,
        ],
      ),
    );

    return response.books
        .map(
          (b) => AnnasSearchHit(
            title: b.title,
            author: b.author,
            md5: b.md5.toLowerCase(),
            format: b.format.extension,
            size: b.size,
            year: b.year,
            poster: b.imgUrl.isNotEmpty ? b.imgUrl : null,
          ),
        )
        .where((h) => h.md5.length == 32 && h.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, String>> _downloadLinksRapidApi({
    required String md5,
    required String rapidKey,
  }) async {
    final uri = Uri.https(
      annasArchiveRapidApiHost,
      '/download',
      {'md5': md5},
    );
    final response = await _client
        .get(uri, headers: _rapidHeaders(rapidKey))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('RapidAPI download HTTP ${response.statusCode}');
    }

    final body = _decodeJsonMap(response.body);
    if (body == null) return {};

    final out = <String, String>{};
    for (final entry in body.entries) {
      final label = entry.key.toString().trim();
      if (label.isEmpty) continue;
      final urls = _stringList(entry.value);
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i].trim();
        if (url.isEmpty) continue;
        final key = urls.length == 1 ? label : '$label ${i + 1}';
        out[key] = url;
      }
    }
    return out;
  }

  Future<Map<String, String>> _downloadLinksPackage(String md5) async {
    final links = await _annaApi.getLibgenDownloadLinks(md5.toUpperCase());
    final out = <String, String>{};
    for (var i = 0; i < links.length; i++) {
      final url = links[i].trim();
      if (url.isEmpty) continue;
      out[links.length == 1 ? 'Libgen' : 'Libgen ${i + 1}'] = url;
    }
    return out;
  }

  Future<String?> _resolveFastDownload({
    required String md5,
    required String secretKey,
    String? rapidKey,
  }) async {
    if (rapidKey != null) {
      try {
        final fromRapid = await _fastDownloadRapidApi(
          md5: md5,
          secretKey: secretKey,
          rapidKey: rapidKey,
        );
        if (fromRapid != null) return fromRapid;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('AnnasArchive RapidAPI fast download failed: $e\n$st');
        }
      }
    }
    return _fastDownloadDirect(md5: md5, secretKey: secretKey);
  }

  Future<String?> _fastDownloadRapidApi({
    required String md5,
    required String secretKey,
    required String rapidKey,
  }) async {
    final uri = Uri.https(
      annasArchiveRapidApiHost,
      '/download/member',
      {'md5': md5, 'mk': secretKey},
    );
    final response = await _client
        .get(uri, headers: _rapidHeaders(rapidKey))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;

    final body = _decodeJsonMap(response.body);
    if (body == null) return null;

    return _firstUrl(body) ??
        _readString(body, 'download_url') ??
        _readString(body, 'fast') ??
        _readString(body, 'url');
  }

  Future<String?> _fastDownloadDirect({
    required String md5,
    required String secretKey,
  }) async {
    final mirrors = [
      'https://annas-archive.gl',
      'https://annas-archive.pk',
      'https://annas-archive.gd',
    ];

    for (final base in mirrors) {
      try {
        final uri = Uri.parse(
          '$base/dyn/api/fast_download.json?md5=$md5&key=${Uri.encodeComponent(secretKey)}',
        );
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 && response.statusCode != 204) {
          continue;
        }
        final body = _decodeJsonMap(response.body);
        if (body == null) continue;
        final url = _readString(body, 'download_url');
        if (url != null && url.isNotEmpty) return url;
      } catch (_) {}
    }

    try {
      final member = await _annaApi.getMemberDownloadLinks(
        md5: md5,
        membershipKey: secretKey,
      );
      final fast = member?.fast.trim();
      if (fast != null && fast.isNotEmpty) return fast;
    } catch (_) {}

    return null;
  }

  Map<String, String> _rapidHeaders(String rapidKey) => {
    'Content-Type': 'application/json',
    'x-rapidapi-host': annasArchiveRapidApiHost,
    'x-rapidapi-key': rapidKey,
  };

  AnnasSearchHit _hitFromRapidJson(Map<String, dynamic> raw) {
    return AnnasSearchHit(
      title: _readString(raw, 'title') ?? '',
      author: _readString(raw, 'author'),
      md5: (_readString(raw, 'md5') ?? '').toLowerCase(),
      format: _readString(raw, 'format'),
      size: _readString(raw, 'size'),
      year: _readString(raw, 'year'),
      poster: _readString(raw, 'imgUrl'),
    );
  }

  List<Format> _formatsFromExtensions(List<String> extensions) {
    if (extensions.isEmpty) {
      return const [Format.epub, Format.pdf, Format.mobi, Format.azw3];
    }
    final mapped = extensions
        .map((e) => Format.fromString(e.toLowerCase().replaceAll('.', '')))
        .where((f) => f != Format.unknown)
        .toList(growable: false);
    if (mapped.isEmpty) {
      return const [Format.epub, Format.pdf, Format.mobi, Format.azw3];
    }
    return mapped;
  }

  Map<String, dynamic>? _decodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (kDebugMode) debugPrint('AnnasArchive JSON decode failed: $e');
    }
    return null;
  }

  Language _languageEnum(String? language) {
    final code = _languageCode(language);
    if (code == null) return Language.english;
    for (final lang in Language.values) {
      if (lang.code == code) return lang;
    }
    return Language.english;
  }

  String? _languageCode(String? language) {
    if (language == null || language.trim().isEmpty) return null;
    final lower = language.trim().toLowerCase();
    if (lower.length == 2) return lower;
    return _languageCodes[lower];
  }

  String? _readString(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  String? _firstUrl(Map<String, dynamic> map) {
    for (final value in map.values) {
      if (value is String && value.startsWith('http')) return value;
      if (value is List) {
        for (final item in value) {
          final s = item.toString();
          if (s.startsWith('http')) return s;
        }
      }
    }
    return null;
  }
}

class AnnasSearchHit {
  final String title;
  final String? author;
  final String md5;
  final String? format;
  final String? size;
  final String? year;
  final String? poster;

  const AnnasSearchHit({
    required this.title,
    this.author,
    required this.md5,
    this.format,
    this.size,
    this.year,
    this.poster,
  });

  String get detailPageUrl => 'https://annas-archive.gl/md5/$md5';
}
