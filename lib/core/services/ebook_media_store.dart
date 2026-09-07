import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'app_storage.dart';

import '../models/chapter.dart';

/// On-disk home for inline ebook images extracted at import.
///
/// Layout: `{documents}/ebook_media/{bookOrSessionId}/{hash}.{ext}`
///
/// Parsers write into a pending [sessionId] while [bookId] is still unknown;
/// callers [promote] the session to the real Isar id and rewrite chapter HTML.
class EbookMediaStore {
  EbookMediaStore._();

  static const _rootName = 'ebook_media';

  static final _imageExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.svg',
    '.jfif',
    '.jpe',
  };

  /// Creates a unique pending session key for an in-flight import.
  static String newSessionId() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'pending_$stamp$rand';
  }

  static Future<Directory> _root() async {
    final docs = await AppStorage.documents();
    final dir = Directory('${docs.path}/$_rootName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> dirFor(String bookOrSessionId) async {
    final root = await _root();
    final dir = Directory('${root.path}/$bookOrSessionId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] under [bookOrSessionId], deduped by content hash.
  /// Returns an absolute filesystem path suitable for `Image.file` / `file://`.
  static Future<String> storeBytes({
    required String bookOrSessionId,
    required List<int> bytes,
    String? preferredExt,
    String? logicalName,
  }) async {
    final dir = await dirFor(bookOrSessionId);
    final digest = sha256.convert(bytes).toString().substring(0, 16);
    final ext = _sanitizeExt(
      preferredExt ?? _extFromName(logicalName) ?? _sniffExt(bytes) ?? 'bin',
    );
    final file = File('${dir.path}/$digest.$ext');
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  /// Moves `ebook_media/[sessionId]` → `ebook_media/[bookId]` and rewrites
  /// every chapter's HTML so `file://` (and bare) paths point at the new dir.
  ///
  /// Safe no-op when [sessionId] is null or already equals [bookId]'s folder.
  static Future<List<Chapter>> promote({
    required String? sessionId,
    required int bookId,
    required List<Chapter> chapters,
  }) async {
    if (sessionId == null || sessionId.isEmpty) {
      return chapters
          .map((c) => c.copyWith(bookId: bookId))
          .toList(growable: false);
    }

    final root = await _root();
    final from = Directory('${root.path}/$sessionId');
    final to = Directory('${root.path}/$bookId');
    final fromPrefix = from.path;
    final toPrefix = to.path;

    if (await from.exists()) {
      if (await to.exists()) {
        // Merge: move files that aren't already present.
        await for (final entity in from.list(recursive: false)) {
          if (entity is! File) continue;
          final dest = File('${to.path}/${entity.uri.pathSegments.last}');
          if (!await dest.exists()) {
            await entity.rename(dest.path);
          } else {
            await entity.delete();
          }
        }
        try {
          await from.delete(recursive: true);
        } catch (_) {}
      } else {
        await from.rename(to.path);
      }
    }

    return chapters
        .map(
          (c) => c.copyWith(
            bookId: bookId,
            content: _rewritePaths(c.content, fromPrefix, toPrefix),
          ),
        )
        .toList(growable: false);
  }

  /// Deletes all media for a book (call from book delete).
  static Future<void> deleteBookMedia(int bookId) async {
    final root = await _root();
    final dir = Directory('${root.path}/$bookId');
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// True when [href] / [mime] looks like an image resource publishers put in
  /// EPUBs — including nonstandard MIME types (`image/jpg`, `image/webp`) that
  /// `epub_pro` leaves out of [EpubContent.images].
  static bool looksLikeImage({String? href, String? mime}) {
    final m = (mime ?? '').trim().toLowerCase();
    if (m.startsWith('image/')) return true;
    final name = (href ?? '').split('#').first.split('?').first;
    final ext = p.extension(name.replaceAll('\\', '/')).toLowerCase();
    return _imageExts.contains(ext);
  }

  /// Rewrites image references in [html] whose paths resolve via [resolver].
  ///
  /// Handles `<img src>`, SVG `<image href>` / `xlink:href`.
  static String rewriteImgSrcs(
    String html,
    String? Function(String src) resolver,
  ) {
    var out = html.replaceAllMapped(
      RegExp(
        r'''(<img\b[^>]*?\bsrc\s*=\s*)(["'])([^"']+)\2''',
        caseSensitive: false,
      ),
      (m) => _replaceAttr(m, resolver),
    );
    // EPUB / SVG wrappers often use <image href="…"> instead of <img>.
    out = out.replaceAllMapped(
      RegExp(
        r'''(<image\b[^>]*?\b(?:xlink:)?href\s*=\s*)(["'])([^"']+)\2''',
        caseSensitive: false,
      ),
      (m) => _replaceAttr(m, resolver),
    );
    return out;
  }

  static String _replaceAttr(
    Match m,
    String? Function(String src) resolver,
  ) {
    final prefix = m.group(1)!;
    final quote = m.group(2)!;
    final src = _decodeHtmlEntities(m.group(3)!);
    final resolved = resolver(src);
    if (resolved == null || resolved.isEmpty) return m.group(0)!;
    final fileUri = resolved.startsWith('file:')
        ? resolved
        : Uri.file(resolved).toString();
    return '$prefix$quote$fileUri$quote';
  }

  static String _decodeHtmlEntities(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String _rewritePaths(String html, String fromPrefix, String toPrefix) {
    if (fromPrefix == toPrefix) return html;
    // Absolute paths and file:// URIs that contain the old directory.
    var out = html.replaceAll(fromPrefix, toPrefix);
    final fromUri = Uri.file(fromPrefix).toString();
    final toUri = Uri.file(toPrefix).toString();
    if (fromUri != fromPrefix) {
      out = out.replaceAll(fromUri, toUri);
    }
    return out;
  }

  static String _sanitizeExt(String ext) {
    final cleaned = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (cleaned.isEmpty) return 'bin';
    if (cleaned == 'jpeg' || cleaned == 'jpe' || cleaned == 'jfif') {
      return 'jpg';
    }
    return cleaned.length > 5 ? cleaned.substring(0, 5) : cleaned;
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i + 1);
  }

  static String? _sniffExt(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  /// Resolve a relative EPUB image href against content image map keys.
  ///
  /// Matching order:
  /// 1. Exact / case-insensitive on the cleaned href
  /// 2. Path resolved against [baseHref] (chapter file location)
  /// 3. Basename / suffix (case-insensitive)
  /// 4. One percent-decode pass, then retry
  ///
  /// [baseHref] is the chapter's content file path in the EPUB (e.g.
  /// `OEBPS/Text/ch1.xhtml`), so `../Images/fig.png` resolves correctly.
  static String? matchContentKey(
    String src,
    Iterable<String> keys, {
    String? baseHref,
  }) {
    var cleaned = _decodeHtmlEntities(src.trim());
    if (cleaned.startsWith('file:')) return null;
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return null;
    }
    cleaned = cleaned.split('#').first.split('?').first;
    cleaned = cleaned.replaceAll('\\', '/');
    while (cleaned.startsWith('./')) {
      cleaned = cleaned.substring(2);
    }

    final hit = _matchAgainstKeys(cleaned, keys, baseHref: baseHref);
    if (hit != null) return hit;

    // Percent-decode once.
    try {
      final decoded = Uri.decodeComponent(cleaned);
      if (decoded != cleaned) {
        return matchContentKey(decoded, keys, baseHref: baseHref);
      }
    } catch (_) {}
    return null;
  }

  static String? _matchAgainstKeys(
    String cleaned,
    Iterable<String> keys, {
    String? baseHref,
  }) {
    final exact = _matchContentKeyNormalized(
      cleaned,
      keys,
      caseSensitive: true,
    );
    if (exact != null) return exact;
    final ci = _matchContentKeyNormalized(
      cleaned,
      keys,
      caseSensitive: false,
    );
    if (ci != null) return ci;

    final resolved = resolveAgainstBase(cleaned, baseHref);
    if (resolved != null && resolved != cleaned) {
      final rExact = _matchContentKeyNormalized(
        resolved,
        keys,
        caseSensitive: true,
      );
      if (rExact != null) return rExact;
      final rCi = _matchContentKeyNormalized(
        resolved,
        keys,
        caseSensitive: false,
      );
      if (rCi != null) return rCi;
    }

    return _matchContentKeyNormalized(
          cleaned,
          keys,
          caseSensitive: true,
          basenameOnly: true,
        ) ??
        _matchContentKeyNormalized(
          cleaned,
          keys,
          caseSensitive: false,
          basenameOnly: true,
        );
  }

  /// Joins [href] to the directory of [baseHref] and normalizes `..` segments.
  static String? resolveAgainstBase(String href, String? baseHref) {
    if (baseHref == null || baseHref.isEmpty) return null;
    var base = baseHref.replaceAll('\\', '/');
    if (base.startsWith('/')) base = base.substring(1);
    final dir = p.posix.dirname(base);
    if (dir.isEmpty || dir == '.') {
      return p.posix.normalize(href);
    }
    return p.posix.normalize(p.posix.join(dir, href));
  }

  static String? _matchContentKeyNormalized(
    String cleaned,
    Iterable<String> keys, {
    required bool caseSensitive,
    bool basenameOnly = false,
  }) {
    String norm(String s) {
      var v = s;
      try {
        v = Uri.decodeFull(v);
      } catch (_) {}
      return caseSensitive ? v : v.toLowerCase();
    }

    final want = norm(cleaned);
    if (!basenameOnly) {
      for (final key in keys) {
        if (norm(key) == want) return key;
      }
    }
    final base = cleaned.split('/').last;
    if (base.isEmpty) return null;
    final wantBase = norm(base);
    for (final key in keys) {
      final k = norm(key);
      final keyBase = k.split('/').last;
      if (k == wantBase || keyBase == wantBase || k.endsWith('/$wantBase')) {
        return key;
      }
    }
    return null;
  }

  /// Registers [path] under common aliases of [logicalKey] so later matching
  /// succeeds whether the HTML used encoded, decoded, or basename-only hrefs.
  static void indexImagePath(
    Map<String, String> imagePaths, {
    required String logicalKey,
    required String path,
  }) {
    for (final alias in _keyAliases(logicalKey)) {
      imagePaths.putIfAbsent(alias, () => path);
    }
  }

  static Iterable<String> _keyAliases(String key) sync* {
    final raw = key.trim().replaceAll('\\', '/');
    if (raw.isEmpty) return;
    yield raw;
    try {
      final decoded = Uri.decodeFull(raw);
      if (decoded != raw) yield decoded;
    } catch (_) {}
    final base = raw.split('/').last;
    if (base.isNotEmpty && base != raw) yield base;
  }
}
