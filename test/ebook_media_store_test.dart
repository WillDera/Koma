import 'package:koma/core/services/ebook_media_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EbookMediaStore.matchContentKey', () {
    const keys = ['OEBPS/Images/Graph1.PNG', 'cover.jpg'];

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

    test('leaves http urls alone', () {
      expect(
        EbookMediaStore.matchContentKey('https://example.com/a.png', keys),
        isNull,
      );
    });
  });
}
