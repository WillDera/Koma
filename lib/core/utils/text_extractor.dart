import 'dart:collection';

import 'package:koma/features/reader/html/html_to_document.dart';
import 'package:koma/features/reader/html/kir_model.dart';
import 'package:koma/features/reader/html/kir_to_document.dart';
import 'package:koma/features/reader/html/reading_document.dart';

/// Chapter HTML → plain text (and rich [ReadingDocument]) with an LRU cache.
///
/// Highlight / TTS / resume offsets are into [ReadingDocument.plainText]. Prefer
/// [documentCached] when painting rich spans; [extractCached] remains the
/// plain-text convenience used across the reader.
class TextExtractor {
  /// How many chapters' documents to keep. A handful covers the current
  /// chapter plus the neighbours a reader is likely to reach next.
  static const int _cacheCapacity = 12;

  static final LinkedHashMap<int, ReadingDocument> _docs =
      LinkedHashMap<int, ReadingDocument>();

  /// Memoised [ReadingDocument] per chapter id.
  ///
  /// When [kir] is set (Level 1 `.koma` path), KIR is mapped every call and
  /// not mixed into the HTML LRU — a chapter must not switch coordinate
  /// spaces mid-session.
  static ReadingDocument documentCached(
    int chapterId,
    String html, {
    KirChapter? kir,
  }) {
    if (kir != null) {
      return KirToDocument.parse(
        kir,
        imagePaths: KirToDocument.imagePathsFromHtml(html),
      );
    }
    final hit = _docs.remove(chapterId);
    if (hit != null) {
      _docs[chapterId] = hit;
      return hit;
    }
    final doc = HtmlToDocument.parse(html);
    if (_docs.length >= _cacheCapacity) {
      _docs.remove(_docs.keys.first);
    }
    _docs[chapterId] = doc;
    return doc;
  }

  /// [ReadingDocument.plainText] memoised per chapter.
  static String extractCached(int chapterId, String html, {KirChapter? kir}) {
    return documentCached(chapterId, html, kir: kir).plainText;
  }

  /// Drops cached documents. Pass a [chapterId] to evict one entry, or omit it
  /// to clear everything (e.g. when a book is deleted or re-imported).
  static void invalidate([int? chapterId]) {
    if (chapterId == null) {
      _docs.clear();
    } else {
      _docs.remove(chapterId);
    }
  }

  /// Stateless HTML → plain text (no cache). Prefer [extractCached] in the UI.
  static String extractFromHtml(String html) {
    return HtmlToDocument.parse(html).plainText;
  }
}
