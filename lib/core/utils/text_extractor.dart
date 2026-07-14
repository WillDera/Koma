import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class TextExtractor {
  static const _blockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'li', 'blockquote', 'pre',
  };

  static String extractFromHtml(String html) {
    if (html.isEmpty) return '';
    final doc = html_parser.parse(html);
    final buffer = StringBuffer();
    _collectText(doc.body!, buffer);
    return buffer.toString()
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
