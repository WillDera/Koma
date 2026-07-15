import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:html/parser.dart' as html_parser;

import 'package:path_provider/path_provider.dart';
import '../models/source.dart';
import 'database_service.dart';
import 'epub_service.dart';

class SourceSearchResult {
  final String title;
  final String? author;
  final String? year;
  final String? size;
  final String? extension;
  final String? language;
  final String? poster;
  final String? pages;
  final String? downloadUrl;
  final String sourceName;
  final String tag;

  const SourceSearchResult({
    required this.title,
    this.author,
    this.year,
    this.size,
    this.extension,
    this.language,
    this.poster,
    this.pages,
    this.downloadUrl,
    required this.sourceName,
    this.tag = '',
  });
}

class SourceService {
  final DatabaseService _db;
  final EpubService _epub;

  SourceService(this._db, this._epub);

  http_io.IOClient _client() {
    return http_io.IOClient(HttpClient());
  }

  Future<http.Response> _get(String url) async {
    final client = _client();
    try {
      return await client
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 StashReader/1.0'
          })
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return http.Response('', 500);
    } finally {
      client.close();
    }
  }

  Future<List<SourceSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    var sources = await _db.getSources();
    if (sources.isEmpty) {
      for (final s in defaultSources()) {
        await _db.insertSource(s);
      }
      sources = await _db.getSources();
    }
    final active = sources.where((s) => s.enabled).toList();
    final all = <SourceSearchResult>[];
    for (final s in active) {
      try {
        final results = await _searchSource(s, query);
        all.addAll(results);
      } catch (_) {}
    }
    return all;
  }

  Future<List<SourceSearchResult>> _searchSource(
      Source source, String query) async {
    switch (source.tag) {
      case 'libgen':
        return _searchLibGen(source, query);
      default:
        return [];
    }
  }

  Future<List<SourceSearchResult>> _searchLibGen(
      Source source, String query) async {
    final url =
        '${source.baseUrl}?req=${Uri.encodeQueryComponent(query)}&columns%5B%5D=t&columns%5B%5D=a&topics%5B%5D=l&topics%5B%5D=f&res=100&covers=on';
    final response = await _get(url);
    if (response.statusCode != 200) return [];

    final doc = html_parser.parse(response.body);
    final table = doc.querySelector('table.table.table-striped');
    if (table == null) return [];

    final tbody = table.querySelector('tbody');
    if (tbody == null) return [];

    final rows = tbody.querySelectorAll('tr');
    var results = <SourceSearchResult>[];

    for (final row in rows) {
      try {
        final cols = row.querySelectorAll('td');
        if (cols.length < 9) continue;

        final imgTag = cols[0].querySelector('img');
        final imgSrc = imgTag?.attributes['src'];

        final titleTag = cols[1].querySelector('a[title]');
        final titleRaw = titleTag?.attributes['title'] ?? '';
        final title = titleRaw.contains('<br>')
            ? titleRaw.split('<br>')[1]
            : titleRaw;

        final author = cols.length > 2 ? cols[2].text.trim() : '';

        String? year;
        if (cols.length > 4) {
          final nobr = cols[4].querySelector('nobr');
          year = nobr?.text.trim();
        }

        final language = cols.length > 5 ? cols[5].text.trim() : '';
        final size = cols.length > 7 ? cols[7].text.trim() : '';
        final ext = cols.length > 8 ? cols[8].text.trim() : '';

        // Find download URL: try multiple selectors in order of specificity
        String? downloadUrl;
        downloadUrl = row.querySelector('a[title="libgen.is"]')?.attributes['href'];
        if (downloadUrl == null || downloadUrl.isEmpty) {
          final lastCol = cols.last;
          downloadUrl = lastCol.querySelector('a')?.attributes['href'];
        }
        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadUrl = row.querySelector('a[href*="libgen"]')?.attributes['href'];
        }
        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadUrl = row.querySelector('a')?.attributes['href'];
        }
        if (downloadUrl != null && !downloadUrl.startsWith('http')) {
          downloadUrl = _resolveUrl(url, downloadUrl);
        }

        if (title.isNotEmpty) {
          results.add(SourceSearchResult(
            title: title,
            author: author,
            year: year,
            size: size,
            extension: ext,
            language: language,
            poster: imgSrc != null ? '${_base(source.baseUrl)}$imgSrc' : null,
            downloadUrl: downloadUrl,
            sourceName: source.name,
            tag: 'libgen',
          ));
        }
      } catch (_) {}
    }
    if (source.language != null && source.language!.isNotEmpty) {
      results = results
          .where((r) =>
              r.language?.toLowerCase().contains(source.language!.toLowerCase()) == true)
          .toList();
    }
    return results;
  }

  Future<Map<String, String>> getDownloadLinks(String mirrorUrl) async {
    final response = await _get(mirrorUrl);
    if (response.statusCode != 200) return {};

    final doc = html_parser.parse(response.body);
    const targets = ['GET', 'Cloudflare', 'IPFS.io', 'Infura'];
    final links = <String, String>{};
    for (final a in doc.querySelectorAll('a')) {
      if (targets.contains(a.text.trim())) {
        final href = a.attributes['href'] ?? '';
        links[a.text.trim()] = _resolveUrl(mirrorUrl, href);
      }
    }
    return links;
  }

  Future<Map<String, String>> showDownloadOptions(
      SourceSearchResult result) async {
    if (result.downloadUrl == null || result.downloadUrl!.isEmpty) return {};
    return getDownloadLinks(result.downloadUrl!);
  }

  Future<bool> downloadFromLink(
      String url, String title, String ext) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 StashReader/1.0'
          })
          .timeout(const Duration(minutes: 2));

      if (response.statusCode != 200) return false;

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/downloads/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      final result = await _epub.parseEpub(file.path);
      if (result == null) return false;

      final bookId = await _db.insertBook(result.book);
      for (final ch in result.chapters) {
        await _db.insertChapter(ch.copyWith(bookId: bookId));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String _base(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    return '${uri.scheme}://${uri.host}';
  }

  String _resolveUrl(String base, String relative) {
    final uri = Uri.tryParse(relative);
    if (uri == null || uri.hasScheme) return relative;
    final baseUri = Uri.parse(base);
    return baseUri.resolve(relative).toString();
  }

  static List<Source> defaultSources() => [
        Source(
          name: 'Library Genesis',
          tag: 'libgen',
          baseUrl: 'https://libgen.gs/index.php',
        ),
      ];
}
