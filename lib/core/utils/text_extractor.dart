import 'dart:collection';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class TextExtractor {
  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'pre',
  };

  /// How many chapters' extracted text to keep. A handful covers the current
  /// chapter plus the neighbours a reader is likely to reach next.
  static const int _cacheCapacity = 12;

  /// LRU of chapter id -> extracted plain text.
  ///
  /// Insertion-ordered, so the oldest key is always first; re-inserting on hit
  /// moves an entry to the back.
  static final LinkedHashMap<int, String> _cache = LinkedHashMap<int, String>();

  /// [extractFromHtml] memoised per chapter.
  ///
  /// Extraction is a full HTML parse plus five regex passes, and the reader
  /// calls it several times per frame with the same input. Chapter content is
  /// immutable once stored, so the chapter id is a sound cache key.
  static String extractCached(int chapterId, String html) {
    final hit = _cache.remove(chapterId);
    if (hit != null) {
      _cache[chapterId] = hit; // reinsert: most-recently-used
      return hit;
    }
    final text = extractFromHtml(html);
    if (_cache.length >= _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[chapterId] = text;
    return text;
  }

  /// Drops cached text. Pass a [chapterId] to evict one entry, or omit it to
  /// clear everything (e.g. when a book is deleted or re-imported).
  static void invalidate([int? chapterId]) {
    if (chapterId == null) {
      _cache.clear();
    } else {
      _cache.remove(chapterId);
    }
  }

  static String extractFromHtml(String html) {
    if (html.isEmpty) return '';
    final doc = html_parser.parse(html);
    final buffer = StringBuffer();
    _collectText(doc.body!, buffer);
    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' \n'), '\n')
        .replaceAll(RegExp(r'\n '), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static void _collectText(dom.Element element, StringBuffer buffer) {
    for (final node in element.nodes) {
      if (node is dom.Text) {
        final text = node.text;
        if (text.trim().isEmpty) continue;
        buffer.write(text);
      } else if (node is dom.Element) {
        final tag = node.localName!.toLowerCase();
        if (tag == 'br') {
          buffer.write('\n');
        } else if (_blockTags.contains(tag)) {
          if (buffer.isNotEmpty && !_endsWithNewline(buffer)) {
            buffer.write('\n\n');
          }
          _collectText(node, buffer);
          if (buffer.isNotEmpty && !_endsWithNewline(buffer)) {
            buffer.write('\n\n');
          }
        } else {
          _collectText(node, buffer);
        }
      }
    }
  }

  static bool _endsWithNewline(StringBuffer buffer) {
    if (buffer.isEmpty) return false;
    final s = buffer.toString();
    return s.endsWith('\n');
  }
}
