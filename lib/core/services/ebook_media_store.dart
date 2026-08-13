import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Creates a unique pending session key for an in-flight import.
  static String newSessionId() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'pending_$stamp$rand';
  }

  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
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

  /// Rewrites `src` attributes in [html] whose paths resolve via [resolver].
  ///
  /// [resolver] receives the raw src (may be relative) and returns an absolute
  /// file path, or null to leave the attribute unchanged.
  static String rewriteImgSrcs(
    String html,
    String? Function(String src) resolver,
  ) {
    return html.replaceAllMapped(
      RegExp(
        r'''(<img\b[^>]*?\bsrc\s*=\s*)(["'])([^"']+)\2''',
        caseSensitive: false,
      ),
      (m) {
        final prefix = m.group(1)!;
        final quote = m.group(2)!;
        final src = m.group(3)!;
        final resolved = resolver(src);
        if (resolved == null || resolved.isEmpty) return m.group(0)!;
        final fileUri = resolved.startsWith('file:')
            ? resolved
            : Uri.file(resolved).toString();
        return '$prefix$quote$fileUri$quote';
      },
    );
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
    if (cleaned == 'jpeg') return 'jpg';
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
  static String? matchContentKey(String src, Iterable<String> keys) {
    var cleaned = src.trim();
    if (cleaned.startsWith('file:')) return null;
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return null;
    }
    cleaned = cleaned.split('#').first.split('?').first;
    cleaned = cleaned.replaceAll('\\', '/');
    while (cleaned.startsWith('./')) {
      cleaned = cleaned.substring(2);
    }
    // Try exact, basename, and suffix match.
    for (final key in keys) {
      if (key == cleaned) return key;
    }
    final base = cleaned.split('/').last;
    for (final key in keys) {
      if (key == base || key.endsWith('/$base') || key.endsWith(base)) {
        return key;
      }
    }
    // Percent-decode once.
    try {
      final decoded = Uri.decodeComponent(cleaned);
      if (decoded != cleaned) return matchContentKey(decoded, keys);
    } catch (_) {}
    return null;
  }
}
