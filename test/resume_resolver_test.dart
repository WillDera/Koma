import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/utils/text_extractor.dart';
import 'package:koma/features/reader/pagination/book_page_cursor.dart';
import 'package:koma/features/reader/pagination/chapter_paginator.dart';
import 'package:koma/features/reader/pagination/resume_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 14, height: 1.5);

  Chapter chapter(int id, int index, int sentences) {
    final body = List.generate(
      sentences,
      (i) => 'Chapter $index sentence $i with some words in it.',
    ).join(' ');
    return Chapter(
      id: id,
      bookId: 1,
      title: 'Chapter $index',
      content: '<p>$body</p>',
      index: index,
    );
  }

  late BookPageCursor cursor;
  late List<Chapter> chapters;

  setUp(() {
    TextExtractor.invalidate();
    chapters = [chapter(1, 0, 200), chapter(2, 1, 200)];
    cursor = BookPageCursor(
      chapters: chapters,
      paginatorFor: (i) {
        final text = TextExtractor.extractCached(
          chapters[i].id,
          chapters[i].content,
        );
        return ChapterPaginator(
          spanBuilder: (s, e) => [
            TextSpan(text: text.substring(s, e), style: style),
          ],
        );
      },
    );
    cursor.updateKey(
      const PaginationKey(
        viewport: Size(300, 200),
        fontSize: 14,
        lineHeight: 1.5,
        textAlign: TextAlign.left,
        fontFamily: null,
        useDeviceFont: true,
        bionicReading: false,
      ),
    );
  });

  ResumeResolver resolverWith({
    int? Function(int)? charOffset,
    double Function(int)? pixels,
    double? Function(int)? height,
  }) {
    return ResumeResolver(
      cursor: cursor,
      charOffsetFor: charOffset ?? (_) => null,
      pixelOffsetFor: pixels ?? (_) => 0,
      contentHeightFor: height ?? (_) => null,
    );
  }

  group('ResumeResolver — stored character offset wins', () {
    test('an exact offset resolves to its page and is marked exact', () {
      final pages = cursor.pagesFor(0)!;
      final target = pages.offsetForPageIndex(4);
      final r = resolverWith(charOffset: (_) => target).resolve(0);
      expect(r.position, const BookPosition(0, 4));
      expect(r.exact, isTrue);
    });

    test('a character offset beats a competing pixel offset', () {
      final pages = cursor.pagesFor(0)!;
      final target = pages.offsetForPageIndex(3);
      final r = resolverWith(
        charOffset: (_) => target,
        pixels: (_) => 9999,
        height: (_) => 10000,
      ).resolve(0);
      // Not the last page, which is where the pixel fraction would have landed.
      expect(r.position, const BookPosition(0, 3));
      expect(r.exact, isTrue);
    });

    test('offset 0 is honoured rather than treated as absent', () {
      final r = resolverWith(
        charOffset: (_) => 0,
        pixels: (_) => 5000,
        height: (_) => 10000,
      ).resolve(0);
      expect(r.position, const BookPosition(0, 0));
      expect(r.exact, isTrue);
    });

    test('an out-of-range stored offset clamps to a real page', () {
      final r = resolverWith(charOffset: (_) => 1 << 30).resolve(0);
      expect(r.position.pageIndex, cursor.pageCountOf(0) - 1);
      expect(r.exact, isTrue);
    });
  });

  group('ResumeResolver — legacy pixel migration', () {
    test('a mid-content pixel offset lands mid-chapter and is inexact', () {
      final r = resolverWith(
        pixels: (_) => 5000,
        height: (_) => 10000,
      ).resolve(0);
      expect(r.exact, isFalse);
      expect(r.position.pageIndex, greaterThan(0));
      expect(r.position.pageIndex, lessThan(cursor.pageCountOf(0) - 1));
    });

    test('a pixel offset at the end lands on the last page', () {
      final r = resolverWith(
        pixels: (_) => 10000,
        height: (_) => 10000,
      ).resolve(0);
      expect(r.position.pageIndex, cursor.pageCountOf(0) - 1);
      expect(r.exact, isFalse);
    });

    test('zero pixels means the start of the chapter, treated as exact', () {
      final r = resolverWith(pixels: (_) => 0, height: (_) => 10000).resolve(0);
      expect(r.position, const BookPosition(0, 0));
      expect(r.exact, isTrue);
    });

    test('an unknown content height falls back to the chapter start', () {
      final r = resolverWith(
        pixels: (_) => 5000,
        height: (_) => null,
      ).resolve(0);
      expect(r.position, const BookPosition(0, 0));
      expect(r.exact, isTrue);
    });

    test('a zero content height does not divide by zero', () {
      final r = resolverWith(pixels: (_) => 5000, height: (_) => 0).resolve(0);
      expect(r.position, const BookPosition(0, 0));
      expect(r.exact, isTrue);
    });

    test('pixels beyond the content height clamp to the last page', () {
      final r = resolverWith(
        pixels: (_) => 999999,
        height: (_) => 1000,
      ).resolve(0);
      expect(r.position.pageIndex, cursor.pageCountOf(0) - 1);
    });

    test('the approximation is monotonic in the stored pixel offset', () {
      var last = -1;
      for (var px = 0.0; px <= 10000; px += 500) {
        final r = resolverWith(
          pixels: (_) => px,
          height: (_) => 10000,
        ).resolve(0);
        expect(r.position.pageIndex, greaterThanOrEqualTo(last));
        last = r.position.pageIndex;
      }
    });
  });

  group('ResumeResolver — nothing stored', () {
    test('opens at the start of the chapter', () {
      final r = resolverWith().resolve(0);
      expect(r.position, const BookPosition(0, 0));
      expect(r.exact, isTrue);
    });

    test('resolves per chapter, not globally', () {
      final pages1 = cursor.pagesFor(1)!;
      final r = resolverWith(
        charOffset: (i) => i == 1 ? pages1.offsetForPageIndex(2) : null,
      );
      expect(
        r.resolve(0),
        isA<ResumeTarget>().having(
          (t) => t.position,
          'position',
          const BookPosition(0, 0),
        ),
      );
      expect(r.resolve(1).position, const BookPosition(1, 2));
    });
  });
}
