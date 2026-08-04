import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/utils/text_extractor.dart';
import 'package:koma/features/reader/html/html_to_document.dart';
import 'package:koma/features/reader/html/reading_document.dart';

void main() {
  group('HtmlToDocument', () {
    test('preserves italics and bold as style runs', () {
      final doc = HtmlToDocument.parse(
        '<p>Hello <em>world</em> and <strong>more</strong>.</p>',
      );
      expect(doc.plainText.contains('Hello'), isTrue);
      expect(doc.plainText.contains('world'), isTrue);
      expect(doc.styleRuns, isNotEmpty);
      expect(doc.styleRuns.any((r) => r.flags.italic), isTrue);
      expect(doc.styleRuns.any((r) => r.flags.bold), isTrue);
    });

    test('captures link href on style run', () {
      final doc = HtmlToDocument.parse(
        '<p>See <a href="https://example.com">here</a>.</p>',
      );
      final link = doc.styleRuns.where((r) => r.flags.linkHref != null);
      expect(link, isNotEmpty);
      expect(link.first.flags.linkHref, 'https://example.com');
    });

    test('builds list items with markers', () {
      final doc = HtmlToDocument.parse(
        '<ul><li>One</li><li>Two</li></ul>',
      );
      final items =
          doc.blocks.where((b) => b.kind == ReadingBlockKind.listItem);
      expect(items.length, 2);
      expect(items.first.listMarker, '•');
    });

    test('records image embeds with zero text contribution', () {
      final doc = HtmlToDocument.parse(
        '<p>Before</p><img src="file:///tmp/cover.png"/><p>After</p>',
      );
      expect(doc.embeds, isNotEmpty);
      expect(doc.embeds.first.path, contains('cover.png'));
      expect(doc.plainText.contains('Before'), isTrue);
      expect(doc.plainText.contains('After'), isTrue);
      // Image must not inject characters into the TTS/highlight space.
      expect(doc.plainText.contains('\uFFFC'), isFalse);
    });

    test('ignores script and style tags', () {
      final doc = HtmlToDocument.parse(
        '<p>Hi</p><script>alert(1)</script><style>p{}</style>',
      );
      expect(doc.plainText, 'Hi');
    });

    test('heading blocks are marked', () {
      final doc = HtmlToDocument.parse('<h1>Title</h1><p>Body</p>');
      expect(
        doc.blocks.any((b) => b.kind == ReadingBlockKind.heading1),
        isTrue,
      );
    });
  });

  group('TextExtractor compat', () {
    test('documentCached.plainText matches extractCached', () {
      const html = '<p>Alpha <em>beta</em> gamma</p>';
      TextExtractor.invalidate();
      final plain = TextExtractor.extractCached(42, html);
      final doc = TextExtractor.documentCached(42, html);
      expect(doc.plainText, plain);
    });

    test('text-only paragraphs stay close to classic extractor shape', () {
      const html = '<p>First paragraph.</p><p>Second paragraph.</p>';
      final plain = TextExtractor.extractFromHtml(html);
      expect(plain.contains('First paragraph.'), isTrue);
      expect(plain.contains('Second paragraph.'), isTrue);
    });
  });
}
