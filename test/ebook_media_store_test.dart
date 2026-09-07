import 'package:koma/core/services/ebook_media_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EbookMediaStore.matchContentKey', () {
    const keys = [
      'OEBPS/Images/Graph1.PNG',
      'cover.jpg',
      'OEBPS/Images/photo%20one.jpg',
      'Text/../Images/dup.png',
    ];

    test('exact match', () {
      expect(
        EbookMediaStore.matchContentKey('../Images/Graph1.PNG', keys),
        'OEBPS/Images/Graph1.PNG',
      );
    });

    test('case-insensitive match on Android-style paths', () {
      expect(
        EbookMediaStore.matchContentKey('../Images/graph1.png', keys),
        'OEBPS/Images/Graph1.PNG',
      );
      expect(
        EbookMediaStore.matchContentKey('Cover.JPG', keys),
        'cover.jpg',
      );
    });

    test('basename match', () {
      expect(
        EbookMediaStore.matchContentKey('Graph1.PNG', keys),
        'OEBPS/Images/Graph1.PNG',
      );
    });

    test('resolves relative to chapter file', () {
      expect(
        EbookMediaStore.matchContentKey(
          '../Images/Graph1.PNG',
          const ['OEBPS/Images/Graph1.PNG'],
          baseHref: 'OEBPS/Text/chapter1.xhtml',
        ),
        'OEBPS/Images/Graph1.PNG',
      );
      expect(
        EbookMediaStore.matchContentKey(
          'Images/Graph1.PNG',
          const ['OEBPS/Images/Graph1.PNG'],
          baseHref: 'OEBPS/chapter1.xhtml',
        ),
        'OEBPS/Images/Graph1.PNG',
      );
    });

    test('percent-decoded href', () {
      expect(
        EbookMediaStore.matchContentKey(
          'OEBPS/Images/photo one.jpg',
          keys,
        ),
        'OEBPS/Images/photo%20one.jpg',
      );
    });

    test('html entity amp in src', () {
      expect(
        EbookMediaStore.matchContentKey(
          'OEBPS/Images/photo&amp;one.jpg',
          const ['OEBPS/Images/photo&one.jpg'],
        ),
        'OEBPS/Images/photo&one.jpg',
      );
    });

    test('leaves http urls alone', () {
      expect(
        EbookMediaStore.matchContentKey('https://example.com/a.png', keys),
        isNull,
      );
    });
  });

  group('EbookMediaStore.looksLikeImage', () {
    test('accepts nonstandard mime types', () {
      expect(
        EbookMediaStore.looksLikeImage(mime: 'image/jpg'),
        isTrue,
      );
      expect(
        EbookMediaStore.looksLikeImage(mime: 'image/webp'),
        isTrue,
      );
      expect(
        EbookMediaStore.looksLikeImage(href: 'foo/bar.WEBP'),
        isTrue,
      );
      expect(
        EbookMediaStore.looksLikeImage(mime: 'application/xhtml+xml'),
        isFalse,
      );
    });
  });

  group('EbookMediaStore.rewriteImgSrcs', () {
    test('rewrites img and svg image hrefs', () {
      const html = '''
<img src="../Images/a.png"/>
<image xlink:href="../Images/b.png"/>
<image href="../Images/c.png"/>
''';
      final out = EbookMediaStore.rewriteImgSrcs(html, (src) {
        if (src.contains('a.png')) return '/tmp/a.png';
        if (src.contains('b.png')) return '/tmp/b.png';
        if (src.contains('c.png')) return '/tmp/c.png';
        return null;
      });
      expect(out.contains('file:///tmp/a.png'), isTrue);
      expect(out.contains('file:///tmp/b.png'), isTrue);
      expect(out.contains('file:///tmp/c.png'), isTrue);
      expect(out.contains('../Images/'), isFalse);
    });
  });
}
