import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/router/book_navigation_policy.dart';

void main() {
  group('saved chapter target', () {
    final chapters = [
      Chapter(id: 10, bookId: 1, title: 'One', content: '', index: 0),
      Chapter(id: 20, bookId: 1, title: 'Two', content: '', index: 1),
    ];

    test('uses the persisted current chapter position', () {
      expect(savedChapterId(chapters, 1), 20);
    });

    test('clamps stale positions and handles no rows', () {
      expect(savedChapterId(chapters, 99), 20);
      expect(savedChapterId(const [], 0), isNull);
    });
  });
}
