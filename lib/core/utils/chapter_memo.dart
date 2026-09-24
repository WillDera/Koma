import 'dart:convert';

import '../services/keiyoushi_service.dart' show coerceMemoJson;

/// Pull a catalogue `mangaId` out of a manga or chapter URL.
///
/// Covers common Mihon / host layouts (`/manga/{id}`, `/title/{id}`, …) and
/// bare ids (no slash) used by some catalogue memos.
String? mangaIdFromUrl(String? url) {
  if (url == null) return null;
  final t = url.trim();
  if (t.isEmpty) return null;
  if (!t.contains('/')) return t;
  for (final re in [
    RegExp(r'/manga/([^/?#]+)'),
    RegExp(r'/title/([^/?#]+)'),
    RegExp(r'/series/([^/?#]+)'),
    RegExp(r'/comic/([^/?#]+)'),
  ]) {
    final m = re.firstMatch(t);
    final id = m?.group(1)?.trim();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

String? mangaIdFromMemo(String? memo) {
  final c = coerceMemoJson(memo);
  if (c == null) return null;
  try {
    final decoded = jsonDecode(c);
    if (decoded is Map) {
      final id = decoded['mangaId']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
  } catch (_) {}
  return null;
}

/// Ensures chapter memo JSON includes `mangaId` when a source needs it for
/// `getPageList` (AllManga / mkissa and similar). Derives from [mangaUrl],
/// [mangaMemo], or [chapterUrl] path segments — never source-specific.
String? enrichChapterMemo({
  String? chapterMemo,
  String? mangaUrl,
  String? mangaMemo,
  String? chapterUrl,
}) {
  final existing = coerceMemoJson(chapterMemo);
  Map<String, dynamic> map = {};
  if (existing != null) {
    try {
      final decoded = jsonDecode(existing);
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      } else {
        // Opaque non-object memo — leave untouched.
        return existing;
      }
    } catch (_) {
      // Non-JSON opaque memo — leave untouched.
      return existing;
    }
  }

  final current = map['mangaId']?.toString().trim();
  if (current != null && current.isNotEmpty) {
    return jsonEncode(map);
  }

  final derived = mangaIdFromUrl(mangaUrl) ??
      mangaIdFromMemo(mangaMemo) ??
      mangaIdFromUrl(chapterUrl);
  if (derived == null) {
    return existing;
  }
  map['mangaId'] = derived;
  return jsonEncode(map);
}
