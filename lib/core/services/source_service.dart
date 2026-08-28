import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:html/parser.dart' as html_parser;

import 'annas_archive_service.dart';
import 'app_storage.dart';
import '../models/source.dart';
import '../repositories/repositories.dart';
import 'ebook_service.dart';
import 'ebook_media_store.dart';
import 'http/m_client.dart';
import 'koma_package_store.dart';

/// LibGen HTML uses relative cover paths like
/// `/fictionruscovers/221000/<hash>_small.jpg` or `/fictioncovers/...`.
/// Those assets are served from [libgen.li](https://libgen.li), not from
/// search mirrors such as libgen.gs.
String? resolveLibgenCoverUrl(String searchPageUrl, String? imgSrc) {
  if (imgSrc == null || imgSrc.trim().isEmpty) return null;
  final raw = imgSrc.trim();
  final resolved = raw.startsWith('http')
      ? raw
      : _resolveRelativeUrl(searchPageUrl, raw);
  final uri = Uri.tryParse(resolved);
  if (uri == null) return resolved;

  final path = uri.path;
  final lower = path.toLowerCase();
  final isCoverPath = lower.contains('fictionruscovers') ||
      lower.contains('fictioncovers') ||
      lower.contains('comicscovers') ||
      lower.contains('/covers/');
  if (!isCoverPath) return resolved;

  var coverPath = path;
  if (coverPath.endsWith('_small.jpg')) {
    coverPath =
        '${coverPath.substring(0, coverPath.length - '_small.jpg'.length)}.jpg';
  } else if (coverPath.endsWith('_small.png')) {
    coverPath =
        '${coverPath.substring(0, coverPath.length - '_small.png'.length)}.png';
  } else if (coverPath.endsWith('_small.webp')) {
    coverPath =
        '${coverPath.substring(0, coverPath.length - '_small.webp'.length)}.webp';
  }
  return 'https://libgen.li$coverPath';
}

String _resolveRelativeUrl(String base, String relative) {
  final uri = Uri.tryParse(relative);
  if (uri == null || uri.hasScheme) return relative;
  return Uri.parse(base).resolve(relative).toString();
}

const _kDirectDownload = 'Direct download';
const _kCloudflare = 'Cloudflare';
const _kIpfsIo = 'IPFS.io';
const _kInfura = 'Infura';
const _kPinata = 'Pinata';

const _kMirrorOrder = [
  _kDirectDownload,
  _kCloudflare,
  _kIpfsIo,
  _kInfura,
  _kPinata,
];

final _ipfsCidRe = RegExp(r'/ipfs/([a-zA-Z0-9]+)', caseSensitive: false);
final _md5Re = RegExp(r'[a-fA-F0-9]{32}');

/// Stock Chrome UA for ebook file fetches. `kBrowserUserAgent` includes
/// `Koma/1.0`, which Cloudflare CDN edges (booksdl.lc) often 503.
const _kChromeMobileUa =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

String? _md5FromUrl(String url) {
  final q = Uri.tryParse(url)?.queryParameters['md5'];
  if (q != null && q.length == 32) return q.toLowerCase();
  return _md5Re.firstMatch(url)?.group(0)?.toLowerCase();
}

bool _isNonFileLibgenMirror(Uri uri) {
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final raw = uri.toString().toLowerCase();
  if (uri.scheme == 'magnet' || uri.scheme == 'ed2k') return true;
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host.endsWith('.onion')) return true;
  if (raw.contains('.torrent') || raw.contains('oftorrent')) return true;
  if (host.contains('annas-archive') || host.contains('anna-archive')) {
    return true;
  }
  if (host.contains('randombook')) return true;
  if (host.contains('libgen.pw') || host.contains('libgen.me')) return true;
  if (host.contains('bookfi') || host.contains('b-ok') || host.contains('3lib')) {
    return true;
  }
  if (path.contains('ads.php')) return true;
  return false;
}

String? _ipfsCidFromUri(Uri uri) {
  return _ipfsCidRe.firstMatch(uri.path)?.group(1);
}

String _ipfsGatewayUrl(String origin, String cid, String? filename) {
  final uri = Uri.parse('$origin/ipfs/$cid');
  if (filename != null && filename.isNotEmpty) {
    return uri.replace(queryParameters: {'filename': filename}).toString();
  }
  return uri.toString();
}

/// Labels a LibGen ads-page href as a file-host option, or null to skip.
String? _labelForLibgenHref(String resolved, String linkText) {
  final uri = Uri.tryParse(resolved);
  if (uri == null || uri.scheme == 'javascript') return null;
  if (_isNonFileLibgenMirror(uri)) return null;

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final text = linkText.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  if (_ipfsCidFromUri(uri) != null) {
    if (host.contains('cloudflare')) return _kCloudflare;
    if (host.contains('ipfs.io')) return _kIpfsIo;
    if (host.contains('infura')) return _kInfura;
    if (host.contains('pinata')) return _kPinata;
  }

  if (path.contains('get.php') ||
      host.contains('download.library.lol') ||
      host.contains('download.books.ms')) {
    return _kDirectDownload;
  }

  if (text == 'get') return _kDirectDownload;
  if (text.contains('cloudflare')) return _kCloudflare;
  if (text.contains('ipfs.io')) return _kIpfsIo;
  if (text.contains('infura')) return _kInfura;
  if (text.contains('pinata')) return _kPinata;
  return null;
}

bool _isHtmlPayload(Uint8List bytes, String? contentType) {
  final ct = (contentType ?? '').toLowerCase();
  if (ct.contains('text/html') || ct.contains('application/xhtml')) {
    return true;
  }
  if (bytes.length < 15) return false;
  final head = String.fromCharCodes(
    bytes.take(64),
  ).trimLeft().toLowerCase();
  return head.startsWith('<!doctype html') || head.startsWith('<html');
}

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
  /// Anna's Archive file hash (32-char md5) when [tag] is `annas-archive`.
  final String? md5;
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
    this.md5,
    required this.sourceName,
    this.tag = '',
  });
}

class SourceService {
  final Repositories _repos;
  final EbookService _ebook;
  final AnnasArchiveService _annas;

  SourceService(this._repos, this._ebook, [AnnasArchiveService? annas])
      : _annas = annas ?? AnnasArchiveService();

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
    final sources = await _repos.stats.getSources();
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
      case 'annas-archive':
        return _searchAnnasArchive(source, query);
      default:
        return [];
    }
  }

  Future<List<SourceSearchResult>> _searchAnnasArchive(
    Source source,
    String query,
  ) async {
    final hits = await _annas.search(source, query);
    var results = hits
        .map(
          (h) => SourceSearchResult(
            title: h.title,
            author: h.author,
            year: h.year,
            size: h.size,
            extension: h.format,
            poster: h.poster,
            downloadUrl: h.detailPageUrl,
            md5: h.md5,
            sourceName: source.name,
            tag: 'annas-archive',
          ),
        )
        .toList(growable: false);

    if (source.fileExtensions.isNotEmpty) {
      final allowed = source.fileExtensions.map((e) => e.toLowerCase()).toSet();
      results = results.where((r) {
        final ext = (r.extension ?? '').toLowerCase().replaceAll('.', '');
        return ext.isNotEmpty && allowed.contains(ext);
      }).toList();
    }
    return results;
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
              poster: resolveLibgenCoverUrl(url, imgSrc),
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
    if (source.fileExtensions.isNotEmpty) {
      final allowed = source.fileExtensions.map((e) => e.toLowerCase()).toSet();
      results = results.where((r) {
        final ext = (r.extension ?? '').toLowerCase().replaceAll('.', '');
        return ext.isNotEmpty && allowed.contains(ext);
      }).toList();
    }
    return results;
  }

  Future<Map<String, String>> getDownloadLinks(String mirrorUrl) async {
    final found = await _scrapeFileMirrors(mirrorUrl);
    final hasIpfs = found.containsKey(_kCloudflare) ||
        found.containsKey(_kIpfsIo) ||
        found.containsKey(_kPinata);
    if (!hasIpfs) {
      final md5 = _md5FromUrl(mirrorUrl) ??
          _md5FromUrl(found[_kDirectDownload] ?? '');
      if (md5 != null) {
        for (final ads in [
          'https://library.lol/main/$md5',
          'https://library.lol/fiction/$md5',
        ]) {
          final extra = await _scrapeFileMirrors(ads);
          extra.forEach((k, v) => found.putIfAbsent(k, () => v));
          if (found.containsKey(_kIpfsIo) || found.containsKey(_kCloudflare)) {
            break;
          }
        }
      }
    }

    final ordered = <String, String>{};
    for (final key in _kMirrorOrder) {
      final url = found[key];
      if (url != null) ordered[key] = url;
    }
    return ordered;
  }

  Future<Map<String, String>> _scrapeFileMirrors(String mirrorUrl) async {
    final response = await _get(mirrorUrl);
    if (response.statusCode != 200) return {};

    final found = <String, String>{};
    String? cid;
    String? filename;
    final doc = html_parser.parse(response.body);

    for (final a in doc.querySelectorAll('a')) {
      final href = (a.attributes['href'] ?? '').trim();
      if (href.isEmpty) continue;
      final resolved = _resolveUrl(mirrorUrl, href);
      final uri = Uri.tryParse(resolved);
      if (uri != null) {
        final extracted = _ipfsCidFromUri(uri);
        if (extracted != null) {
          cid ??= extracted;
          filename ??= uri.queryParameters['filename'];
        }
      }
      final label = _labelForLibgenHref(resolved, a.text);
      if (label != null) {
        found.putIfAbsent(label, () => resolved);
      }
    }

    cid ??= _ipfsCidRe.firstMatch(response.body)?.group(1);
    final resolvedCid = cid;
    if (resolvedCid != null) {
      found.putIfAbsent(
        _kCloudflare,
        () => _ipfsGatewayUrl(
          'https://cloudflare-ipfs.com',
          resolvedCid,
          filename,
        ),
      );
      found.putIfAbsent(
        _kIpfsIo,
        () => _ipfsGatewayUrl('https://gateway.ipfs.io', resolvedCid, filename),
      );
      found.putIfAbsent(
        _kInfura,
        () => _ipfsGatewayUrl('https://ipfs.infura.io', resolvedCid, filename),
      );
      found.putIfAbsent(
        _kPinata,
        () => _ipfsGatewayUrl(
          'https://gateway.pinata.cloud',
          resolvedCid,
          filename,
        ),
      );
    }
    return found;
  }

  Future<Map<String, String>> showDownloadOptions(
    SourceSearchResult result,
  ) async {
    if (result.tag == 'annas-archive') {
      final md5 =
          result.md5 ?? _md5FromUrl(result.downloadUrl ?? '');
      if (md5 == null || md5.length != 32) return {};
      final options = await _annas.downloadOptions(md5);
      return _expandLibgenMirrorOptions(options);
    }
    if (result.downloadUrl == null || result.downloadUrl!.isEmpty) return {};
    return getDownloadLinks(result.downloadUrl!);
  }

  Future<Map<String, String>> _expandLibgenMirrorOptions(
    Map<String, String> options,
  ) async {
    if (options.isEmpty) return options;

    final expanded = <String, String>{};
    for (final entry in options.entries) {
      if (_looksLikeLibgenAdsPage(entry.value)) {
        final mirrors = await getDownloadLinks(entry.value);
        if (mirrors.isNotEmpty) {
          for (final mirror in mirrors.entries) {
            expanded['${entry.key} · ${mirror.key}'] = mirror.value;
          }
          continue;
        }
      }
      expanded[entry.key] = entry.value;
    }
    return expanded;
  }

  bool _looksLikeLibgenAdsPage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('ads.php') ||
        lower.contains('/main/') ||
        lower.contains('/fiction/');
  }

  /// Downloads [url] (then [fallbackUrls]), imports the ebook, and returns
  /// the new library book id.
  ///
  /// Uses a raw [HttpClient] (not [MClient] / `http.Request`). `http.Request`
  /// always sends `Content-Type: text/plain` on GET, which Cloudflare file
  /// CDNs 503 while a browser does not.
  Future<int?> downloadFromLink(
    String url,
    String title,
    String ext, {
    void Function(double progress)? onProgress,
    List<String> fallbackUrls = const [],
  }) async {
    final urls = <String>[
      url,
      ...fallbackUrls.where((u) => u.isNotEmpty && u != url),
    ];

    for (final attempt in urls) {
      try {
        final bytes = await _fetchEbookBytes(attempt, onProgress);
        if (bytes == null) continue;

        final dir = await AppStorage.documents();
        final filePath =
            '${dir.path}/downloads/${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);

        final result = await _ebook.parse(file.path);
        if (result == null) {
          if (kDebugMode) {
            debugPrint('downloadFromLink parse failed: $filePath');
          }
          continue;
        }

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
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('downloadFromLink failed ($attempt): $e\n$st');
        }
      }
    }
    return null;
  }

  Future<Uint8List?> _fetchEbookBytes(
    String url,
    void Function(double progress)? onProgress,
  ) async {
    final httpClient = HttpClient();
    httpClient.userAgent = _kChromeMobileUa;
    httpClient.autoUncompress = true;
    httpClient.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.removeAll(HttpHeaders.contentTypeHeader);
      for (final entry in hostAwareHeaders(url).entries) {
        if (entry.key.toLowerCase() == 'user-agent') continue;
        request.headers.set(entry.key, entry.value);
      }
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      request.headers.set(
        HttpHeaders.acceptLanguageHeader,
        'en-US,en;q=0.9',
      );

      if (kDebugMode) {
        debugPrint('downloadFromLink GET $url');
      }

      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          final loc = response.redirects.isEmpty
              ? url
              : response.redirects.last.location.toString();
          debugPrint(
            'downloadFromLink HTTP ${response.statusCode} → $loc',
          );
        }
        await response.drain<void>();
        return null;
      }

      final total = response.contentLength;
      var received = 0;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }

      final bytes = builder.takeBytes();
      if (bytes.isEmpty ||
          _isHtmlPayload(bytes, response.headers.contentType?.mimeType)) {
        if (kDebugMode) {
          debugPrint('downloadFromLink got HTML/empty body: $url');
        }
        return null;
      }
      onProgress?.call(1.0);
      return bytes;
    } finally {
      httpClient.close(force: true);
    }
  }

  String _resolveUrl(String base, String relative) {
    return _resolveRelativeUrl(base, relative);
  }

  static List<Source> defaultSources() => [];
}
