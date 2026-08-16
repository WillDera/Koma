import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:html/parser.dart' as html_parser;

import 'package:path_provider/path_provider.dart';
import '../models/source.dart';
import '../repositories/repositories.dart';
import 'ebook_service.dart';
import 'ebook_media_store.dart';
import 'koma_package_store.dart';

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
  final Repositories _repos;
  final EbookService _ebook;

  SourceService(this._repos, this._ebook);

  http_io.IOClient _client() {
    return http_io.IOClient(HttpClient());
  }

  Future<http.Response> _get(String url) async {
    final client = _client();
    try {
      return await client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Koma/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return http.Response('', 500);
    } finally {
      client.close();
    }
  }

  Future<List<SourceSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    var sources = await _repos.stats.getSources();
    if (sources.isEmpty) {
      for (final s in defaultSources()) {
        await _repos.stats.insertSource(s);
      }
      sources = await _repos.stats.getSources();
    }
    final active = sources.where((s) => s.enabled).toList();
    if (active.isEmpty) return [];
    final batches = await Future.wait(
      active.map((s) async {
        try {
          return await _searchSource(s, query);
        } catch (_) {
          return <SourceSearchResult>[];
        }
      }),
    );
    return batches.expand((e) => e).toList(growable: false);
  }

  Future<List<SourceSearchResult>> _searchSource(
    Source source,
    String query,
  ) async {
    switch (source.tag) {
      case 'libgen':
        return _searchLibGen(source, query);
      default:
        return [];
    }
  }

  Future<List<SourceSearchResult>> _searchLibGen(
    Source source,
    String query,
  ) async {
    final url =
        '${source.baseUrl}?req=${Uri.encodeQueryComponent(query)}&columns%5B%5D=t&columns%5B%5D=a&topics%5B%5D=l&topics%5B%5D=f&res=100&covers=on';
    final response = await _get(url);
    if (response.statusCode != 200) return [];

    final doc = html_parser.parse(response.body);
    // Mirrors rotate markup: prefer the classic striped table, then known
    // libgen ids, then any table that looks like a result grid.
    var table = doc.querySelector('table.table.table-striped') ??
        doc.querySelector('table#tablelibgen') ??
        doc.querySelector('table.c');
    if (table == null) {
      for (final candidate in doc.querySelectorAll('table')) {
        final candidateRows = candidate.querySelectorAll('tr');
        if (candidateRows.length > 1 &&
            candidateRows.first.querySelectorAll('td,th').length >= 5) {
          table = candidate;
          break;
        }
      }
    }
    if (table == null) return [];

    final tbody = table.querySelector('tbody') ?? table;
    final rows = tbody.querySelectorAll('tr');
    var results = <SourceSearchResult>[];

    for (final row in rows) {
      try {
        final cols = row.querySelectorAll('td');
        if (cols.length < 5) continue;
        // Skip header-like rows.
        if (row.querySelectorAll('th').isNotEmpty) continue;

        final imgTag = cols[0].querySelector('img');
        final imgSrc = imgTag?.attributes['src'];

        final titleTag =
            cols[1].querySelector('a[title]') ?? cols[1].querySelector('a');
        final titleRaw = (titleTag?.attributes['title'] ?? '').trim();
        var title = titleRaw.contains('<br>')
            ? titleRaw.split('<br>').last.trim()
            : titleRaw;
        if (title.isEmpty) {
          title = (titleTag?.text ?? cols[1].text).trim();
        }

        final author = cols.length > 2 ? cols[2].text.trim() : '';

        String? year;
        if (cols.length > 4) {
          final nobr = cols[4].querySelector('nobr');
          year = (nobr?.text ?? cols[4].text).trim();
          if (year.isEmpty) year = null;
        }

        final language = cols.length > 5 ? cols[5].text.trim() : '';
        final size = cols.length > 7 ? cols[7].text.trim() : '';
        final ext = cols.length > 8 ? cols[8].text.trim() : '';

        String? downloadUrl;
        downloadUrl = row
            .querySelector('a[title="libgen.is"]')
            ?.attributes['href'];
        if (downloadUrl == null || downloadUrl.isEmpty) {
          final lastCol = cols.last;
          downloadUrl = lastCol.querySelector('a')?.attributes['href'];
        }
        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadUrl = row
              .querySelector('a[href*="libgen"]')
              ?.attributes['href'];
        }
        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadUrl = row.querySelector('a')?.attributes['href'];
        }
        if (downloadUrl != null && !downloadUrl.startsWith('http')) {
          downloadUrl = _resolveUrl(url, downloadUrl);
        }

        if (title.isNotEmpty) {
          results.add(
            SourceSearchResult(
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
            ),
          );
        }
      } catch (_) {}
    }
    if (source.language != null && source.language!.isNotEmpty) {
      results = results
          .where(
            (r) =>
                r.language?.toLowerCase().contains(
                  source.language!.toLowerCase(),
                ) ==
                true,
          )
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
    SourceSearchResult result,
  ) async {
    if (result.downloadUrl == null || result.downloadUrl!.isEmpty) return {};
    return getDownloadLinks(result.downloadUrl!);
  }

  /// Downloads [url], imports the ebook, and returns the new library book id.
  Future<int?> downloadFromLink(
    String url,
    String title,
    String ext, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Koma/1.0';
        final response = await client.send(request);

        if (response.statusCode != 200) return null;

        final total = response.contentLength;
        var received = 0;
        final chunks = <List<int>>[];
        await for (final chunk in response.stream) {
          chunks.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call(received / total);
          }
        }
        onProgress?.call(1.0);

        final bytes = Uint8List(received);
        var offset = 0;
        for (final chunk in chunks) {
          bytes.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/downloads/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);

        final result = await _ebook.parse(file.path);
        if (result == null) return null;

        final bookId = await _repos.books.insertBook(result.book);
        final chapters = await EbookMediaStore.promote(
          sessionId: result.mediaSessionId,
          bookId: bookId,
          chapters: result.chapters,
        );
        for (final ch in chapters) {
          await _repos.books.insertChapter(ch);
        }
        if (ext == 'epub') {
          await KomaPackageStore.compileEpub(
            bookId: bookId,
            epubPath: file.path,
          );
        }
        return bookId;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
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
