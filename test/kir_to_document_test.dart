import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/html/kir_model.dart';
import 'package:koma/features/reader/html/kir_to_document.dart';
import 'package:koma/features/reader/html/reading_document.dart';

void main() {
  test('paragraphs, headings, style runs, no chapter title in plainText', () {
    const chapter = KirChapter(
      id: 'c1',
      title: 'Should Not Appear',
      blocks: [
        KirBlock(
          kind: 'heading1',
          spans: [KirSpan(text: 'Title')],
        ),
        KirBlock(
          kind: 'paragraph',
          spans: [
            KirSpan(text: 'Hello '),
            KirSpan(text: 'world', italic: true),
            KirSpan(text: ' and '),
            KirSpan(text: 'more', bold: true),
          ],
        ),
      ],
    );
    final doc = KirToDocument.parse(chapter);
    expect(doc.plainText.contains('Should Not Appear'), isFalse);
    expect(doc.plainText.contains('Title'), isTrue);
    expect(doc.plainText.contains('Hello'), isTrue);
    expect(doc.styleRuns.any((r) => r.flags.italic), isTrue);
    expect(doc.styleRuns.any((r) => r.flags.bold), isTrue);
    expect(doc.blocks.any((b) => b.kind == ReadingBlockKind.heading1), isTrue);
  });

  test('images contribute zero characters and consume html paths in order', () {
    const chapter = KirChapter(
      id: 'c1',
      blocks: [
        KirBlock(kind: 'paragraph', spans: [KirSpan(text: 'Before')]),
        KirBlock(kind: 'image', mediaId: 'pic'),
        KirBlock(kind: 'paragraph', spans: [KirSpan(text: 'After')]),
      ],
    );
    final doc = KirToDocument.parse(
      chapter,
      imagePaths: ['/tmp/cover.png'],
    );
    expect(doc.embeds, isNotEmpty);
    expect(doc.embeds.first.path, '/tmp/cover.png');
    expect(doc.plainText.contains('Before'), isTrue);
    expect(doc.plainText.contains('After'), isTrue);
    expect(doc.plainText.contains('\uFFFC'), isFalse);
    expect(
      doc.blocks.any((b) => b.kind == ReadingBlockKind.image),
      isTrue,
    );
  });

  test('unordered list items get bullet markers', () {
    const chapter = KirChapter(
      id: 'c1',
      blocks: [
        KirBlock(
          kind: 'list',
          children: [
            KirBlock(kind: 'paragraph', spans: [KirSpan(text: 'One')]),
            KirBlock(kind: 'paragraph', spans: [KirSpan(text: 'Two')]),
          ],
        ),
      ],
    );
    final doc = KirToDocument.parse(chapter);
    final items =
        doc.blocks.where((b) => b.kind == ReadingBlockKind.listItem).toList();
    expect(items.length, 2);
    expect(items.first.listMarker, '•');
    expect(doc.plainText.contains('One'), isTrue);
    expect(doc.plainText.contains('Two'), isTrue);
  });

  test('quote children become blockquote blocks', () {
    const chapter = KirChapter(
      id: 'c1',
      blocks: [
        KirBlock(
          kind: 'quote',
          children: [
            KirBlock(kind: 'paragraph', spans: [KirSpan(text: 'Cited')]),
          ],
        ),
      ],
    );
    final doc = KirToDocument.parse(chapter);
    expect(
      doc.blocks.any((b) => b.kind == ReadingBlockKind.blockquote),
      isTrue,
    );
    expect(doc.plainText.contains('Cited'), isTrue);
  });

  test('imagePathsFromHtml extracts file uris in order', () {
    const html =
        '<p>x</p><img src="file:///tmp/a.png"/><img src="https://x/y.png"/><img src="file:///tmp/b.png"/>';
    expect(KirToDocument.imagePathsFromHtml(html), [
      '/tmp/a.png',
      '/tmp/b.png',
    ]);
  });
}
