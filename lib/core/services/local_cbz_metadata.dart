import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/manga.dart';
import 'android_storage_access.dart';
import 'local_cbz_source.dart';

/// Series-level metadata written next to chapter CBZs on export and read on scan.
///
/// Layout (normal — a folder of CBZs, not one zip):
/// ```text
/// Series Title/
///   series.json      (Koma)
///   ComicInfo.xml    (ComicRack / Komga compatible)
///   cover.jpg
///   Chapter 001.cbz
///   Chapter 002.cbz
/// ```
class LocalCbzMetadata {
  LocalCbzMetadata({
    required this.title,
    this.author,
    this.artist,
    this.description,
    this.status = 0,
    this.genres = const [],
    this.coverFileName,
    this.sourceId,
    this.sourceUrl,
  });

  final String title;
  final String? author;
  final String? artist;
  final String? description;
  final int status;
  final List<String> genres;
  final String? coverFileName;
  final String? sourceId;
  final String? sourceUrl;

  static const seriesJsonName = 'series.json';
  static const comicInfoName = 'ComicInfo.xml';

  Map<String, dynamic> toJson() => {
        'version': 1,
        'title': title,
        if (author != null && author!.trim().isNotEmpty) 'author': author,
        if (artist != null && artist!.trim().isNotEmpty) 'artist': artist,
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
        'status': status,
        'genres': genres,
        // Alias for tools / humans that look for "tags".
        if (genres.isNotEmpty) 'tags': genres,
        if (coverFileName != null) 'cover': coverFileName,
        if (sourceId != null) 'source_id': sourceId,
        if (sourceUrl != null) 'source_url': sourceUrl,
      };

  factory LocalCbzMetadata.fromManga(Manga manga, {String? coverFileName}) {
    final desc = manga.description?.trim();
    final author = manga.author?.trim();
    final artist = manga.artist?.trim();
    return LocalCbzMetadata(
      title: manga.name.trim().isNotEmpty ? manga.name.trim() : 'Untitled',
      author: author != null && author.isNotEmpty ? author : null,
      artist: artist != null && artist.isNotEmpty ? artist : null,
      description: desc != null && desc.isNotEmpty ? desc : null,
      status: manga.status,
      genres: [
        for (final g in manga.genres)
          if (g.trim().isNotEmpty) g.trim(),
      ],
      coverFileName: coverFileName,
      sourceId: manga.sourceId,
      sourceUrl: manga.url,
    );
  }

  factory LocalCbzMetadata.fromJson(Map<String, dynamic> json) {
    final genres = <String>[];
    void addGenres(dynamic raw) {
      if (raw is List) {
        for (final g in raw) {
          final s = g.toString().trim();
          if (s.isNotEmpty && !genres.contains(s)) genres.add(s);
        }
      } else if (raw is String) {
        for (final part in raw.split(',')) {
          final s = part.trim();
          if (s.isNotEmpty && !genres.contains(s)) genres.add(s);
        }
      }
    }

    addGenres(json['genres']);
    addGenres(json['tags']);
    addGenres(json['genre']);

    return LocalCbzMetadata(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Untitled',
      author: (json['author'] as String?)?.trim(),
      artist: (json['artist'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim() ??
          (json['summary'] as String?)?.trim(),
      status: (json['status'] as num?)?.toInt() ?? 0,
      genres: genres,
      coverFileName: (json['cover'] as String?)?.trim(),
      sourceId: (json['source_id'] as String?)?.trim(),
      sourceUrl: (json['source_url'] as String?)?.trim(),
    );
  }

  /// Reads [series.json], then [ComicInfo.xml], from [dir].
  static Future<LocalCbzMetadata?> readFromDirectory(Directory dir) async {
    final jsonFile = File(p.join(dir.path, seriesJsonName));
    if (await jsonFile.exists()) {
      try {
        final map = jsonDecode(await jsonFile.readAsString());
        if (map is Map<String, dynamic>) return LocalCbzMetadata.fromJson(map);
        if (map is Map) {
          return LocalCbzMetadata.fromJson(Map<String, dynamic>.from(map));
        }
      } catch (_) {}
    }

    final xmlFile = File(p.join(dir.path, comicInfoName));
    if (await xmlFile.exists()) {
      try {
        return _fromComicInfoXml(await xmlFile.readAsString());
      } catch (_) {}
    }
    return null;
  }

  static LocalCbzMetadata _fromComicInfoXml(String raw) {
    String? tag(String name) {
      final re = RegExp(
        '<$name(?:\\s[^>]*)?>([\\s\\S]*?)</$name>',
        caseSensitive: false,
      );
      final m = re.firstMatch(raw);
      if (m == null) return null;
      final t = _unescapeXml(m.group(1)!.trim());
      return t.isEmpty ? null : t;
    }

    final title = tag('Series') ?? tag('Title') ?? 'Untitled';
    final genres = <String>[];
    final genre = tag('Genre');
    if (genre != null) {
      genres.addAll(
        genre.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    final tags = tag('Tags');
    if (tags != null) {
      for (final t in tags.split(',').map((e) => e.trim())) {
        if (t.isNotEmpty && !genres.contains(t)) genres.add(t);
      }
    }

    return LocalCbzMetadata(
      title: title,
      author: tag('Writer') ?? tag('Penciller'),
      artist: tag('Penciller') ?? tag('Inker'),
      description: tag('Summary'),
      status: _statusFromComicInfo(tag('Status')),
      genres: genres,
    );
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static int _statusFromComicInfo(String? raw) {
    final s = raw?.trim().toLowerCase() ?? '';
    if (s.contains('end') || s.contains('complet') || s == 'finished') {
      return 2;
    }
    if (s.contains('ongoing') || s.contains('continu')) return 1;
    if (s.contains('hiatus')) return 6;
    if (s.contains('cancel')) return 5;
    return 0;
  }

  static String _statusToComicInfo(int status) {
    switch (status) {
      case 1:
        return 'Ongoing';
      case 2:
      case 4:
        return 'Ended';
      case 5:
        return 'Cancelled';
      case 6:
        return 'Hiatus';
      default:
        return 'Ongoing';
    }
  }

  String toComicInfoXml() {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<ComicInfo>')
      ..writeln('  <Title>${_escapeXml(title)}</Title>')
      ..writeln('  <Series>${_escapeXml(title)}</Series>');
    if (author != null && author!.isNotEmpty) {
      b.writeln('  <Writer>${_escapeXml(author!)}</Writer>');
    }
    if (artist != null && artist!.isNotEmpty) {
      b.writeln('  <Penciller>${_escapeXml(artist!)}</Penciller>');
    }
    if (description != null && description!.isNotEmpty) {
      b.writeln('  <Summary>${_escapeXml(description!)}</Summary>');
    }
    if (genres.isNotEmpty) {
      final joined = _escapeXml(genres.join(', '));
      b.writeln('  <Genre>$joined</Genre>');
      b.writeln('  <Tags>$joined</Tags>');
    }
    b
      ..writeln('  <Status>${_escapeXml(_statusToComicInfo(status))}</Status>')
      ..writeln('  <Manga>Yes</Manga>')
      ..writeln('</ComicInfo>');
    return b.toString();
  }

  /// Writes series.json + ComicInfo.xml into [seriesDir].
  Future<void> writeToDirectory(Directory seriesDir) async {
    if (!await seriesDir.exists()) {
      await seriesDir.create(recursive: true);
    }
    final jsonPath = p.join(seriesDir.path, seriesJsonName);
    final xmlPath = p.join(seriesDir.path, comicInfoName);
    final jsonBody = const JsonEncoder.withIndent('  ').convert(toJson());
    final xmlBody = toComicInfoXml();
    await _writeText(jsonPath, jsonBody);
    await _writeText(xmlPath, xmlBody);
  }

  static Future<void> _writeText(String path, String body) async {
    if (AndroidStorageAccess.needsAllFilesAccess(path)) {
      final tmp = File('$path.tmp');
      await tmp.writeAsString(body);
      await AndroidStorageAccess.copyFile(tmp.path, path);
      await tmp.delete();
    } else {
      await File(path).writeAsString(body);
    }
  }

  /// Copies or downloads a cover next to the series files. Returns the file name.
  static Future<String?> exportCover({
    required Directory seriesDir,
    required String? imageUrl,
  }) async {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;

    try {
      late final List<int> bytes;
      late final String ext;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final res = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 30),
            );
        if (res.statusCode < 200 || res.statusCode >= 300) return null;
        bytes = res.bodyBytes;
        final ct = res.headers['content-type'] ?? '';
        if (ct.contains('png')) {
          ext = '.png';
        } else if (ct.contains('webp')) {
          ext = '.webp';
        } else {
          ext = '.jpg';
        }
      } else {
        final path =
            url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
        final src = File(path);
        if (!await src.exists()) return null;
        bytes = await src.readAsBytes();
        final e = p.extension(path).toLowerCase();
        ext = LocalCbzSource.imageExtensions.contains(e) ? e : '.jpg';
      }

      final name = 'cover$ext';
      final dest = p.join(seriesDir.path, name);
      if (AndroidStorageAccess.needsAllFilesAccess(dest)) {
        final tmp = File('$dest.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await AndroidStorageAccess.copyFile(tmp.path, dest);
        await tmp.delete();
      } else {
        await File(dest).writeAsBytes(bytes, flush: true);
      }
      return name;
    } catch (_) {
      return null;
    }
  }
}
