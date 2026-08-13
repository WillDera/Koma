import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/utils/text_extractor.dart';
import 'package:koma/features/reader/pagination/book_page_cursor.dart';
import 'package:koma/features/reader/pagination/chapter_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 14, height: 1.5);
  const viewport = Size(300, 200);

  PaginationKey keyFor([Size vp = viewport]) => PaginationKey(
    viewport: vp,
    fontSize: 14,
    lineHeight: 1.5,
    textAlign: TextAlign.left,
    fontFamily: null,
    bionicReading: false,
  );

  /// Chapter bodies as HTML, since the cursor extracts through TextExtractor.
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

  late int paginatorCalls;

  BookPageCursor cursorFor(
    List<Chapter> chapters, {
    Size vp = viewport,
    bool applyKey = true,
  }) {
    paginatorCalls = 0;
    final c = BookPageCursor(
      chapters: chapters,
      paginatorFor: (i) {
        paginatorCalls++;
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
    if (applyKey) c.updateKey(keyFor(vp));
    return c;
  }

  setUp(TextExtractor.invalidate);

  group('BookPageCursor — lazy measurement', () {
    test('no chapter is measured until it is asked for', () {
      cursorFor([chapter(1, 0, 60), chapter(2, 1, 60)]);
      expect(paginatorCalls, 0);
    });

    test('asking for a chapter measures only that chapter', () {
      final c = cursorFor([chapter(1, 0, 60), chapter(2, 1, 60)]);
      c.pagesFor(0);
      expect(paginatorCalls, 1);
      expect(c.isPaginated(0), isTrue);
      expect(c.isPaginated(1), isFalse);
    });

    test('repeat access is cached, not re-measured', () {
      final c = cursorFor([chapter(1, 0, 60)]);
      c.pagesFor(0);
      c.pagesFor(0);
      c.pagesFor(0);
      expect(paginatorCalls, 1);
    });

    test('without a key nothing can be measured', () {
      final c = cursorFor([chapter(1, 0, 60)], applyKey: false);
      expect(c.pagesFor(0), isNull);
      expect(paginatorCalls, 0);
    });

    test('out-of-range chapters return null', () {
      final c = cursorFor([chapter(1, 0, 60)]);
      expect(c.pagesFor(-1), isNull);
      expect(c.pagesFor(5), isNull);
    });
  });

  group('BookPageCursor — key invalidation', () {
    test('the same key does not invalidate', () {
      final c = cursorFor([chapter(1, 0, 60)]);
      c.pagesFor(0);
      expect(c.updateKey(keyFor()), isFalse);
      c.pagesFor(0);
      expect(paginatorCalls, 1);
    });

    test('a changed key clears the cache and forces re-measure', () {
      final c = cursorFor([chapter(1, 0, 60)]);
      c.pagesFor(0);
      expect(c.updateKey(keyFor(const Size(300, 400))), isTrue);
      expect(c.isPaginated(0), isFalse);
      c.pagesFor(0);
      expect(paginatorCalls, 2);
    });

    test('re-measuring at a taller viewport yields fewer pages', () {
      final c = cursorFor([chapter(1, 0, 200)]);
      final short = c.pageCountOf(0);
      c.updateKey(keyFor(const Size(300, 600)));
      expect(c.pageCountOf(0), lessThan(short));
    });
  });

  group('BookPageCursor — navigation', () {
    late BookPageCursor c;
    late int ch0Pages;
    late int ch1Pages;

    setUp(() {
      c = cursorFor([
        chapter(1, 0, 120),
        chapter(2, 1, 120),
        chapter(3, 2, 120),
      ]);
      ch0Pages = c.pageCountOf(0);
      ch1Pages = c.pageCountOf(1);
      // The fixtures must be multi-page for boundary tests to mean anything.
      expect(ch0Pages, greaterThan(1));
      expect(ch1Pages, greaterThan(1));
    });

    test('next advances within a chapter', () {
      expect(c.next(const BookPosition(0, 0)), const BookPosition(0, 1));
    });

    test('next crosses into the next chapter at the last page', () {
      final last = BookPosition(0, ch0Pages - 1);
      expect(c.next(last), const BookPosition(1, 0));
    });

    test('next returns null at the end of the book', () {
      final lastPage = c.pageCountOf(2) - 1;
      expect(c.next(BookPosition(2, lastPage)), isNull);
    });

    test('previous steps back within a chapter', () {
      expect(c.previous(const BookPosition(0, 2)), const BookPosition(0, 1));
    });

    test('previous crosses to the previous chapter last page', () {
      expect(
        c.previous(const BookPosition(1, 0)),
        BookPosition(0, ch0Pages - 1),
      );
    });

    test('previous returns null at the start of the book', () {
      expect(c.previous(const BookPosition(0, 0)), isNull);
    });

    test('next and previous are inverse across a chapter boundary', () {
      const atBoundary = BookPosition(1, 0);
      final back = c.previous(atBoundary)!;
      expect(c.next(back), atBoundary);
    });

    test('walking the whole book forward visits every page once', () {
      final total = c.pageCountOf(0) + c.pageCountOf(1) + c.pageCountOf(2);
      var pos = const BookPosition(0, 0);
      final seen = <BookPosition>{pos};
      while (true) {
        final n = c.next(pos);
        if (n == null) break;
        expect(seen.add(n), isTrue, reason: 'revisited $n');
        pos = n;
      }
      expect(seen.length, total);
      expect(pos.chapterIndex, 2);
    });

    test('walking back from the end returns to the start', () {
      var pos = BookPosition(2, c.pageCountOf(2) - 1);
      var steps = 0;
      while (true) {
        final p = c.previous(pos);
        if (p == null) break;
        pos = p;
        steps++;
      }
      expect(pos, const BookPosition(0, 0));
      expect(steps, greaterThan(0));
    });
  });

  group('BookPageCursor — offsets and clamping', () {
    test('positionForOffset and offsetAt round-trip', () {
      final c = cursorFor([chapter(1, 0, 150)]);
      final count = c.pageCountOf(0);
      for (var i = 0; i < count; i++) {
        final pos = BookPosition(0, i);
        expect(c.positionForOffset(0, c.offsetAt(pos)), pos);
      }
    });

    test('clamp pins an out-of-range page and chapter', () {
      final c = cursorFor([chapter(1, 0, 60), chapter(2, 1, 60)]);
      final last = c.pageCountOf(1) - 1;
      // Chapter 9 does not exist, and neither does page 999.
      expect(c.clamp(const BookPosition(9, 999)), BookPosition(1, last));
      expect(c.clamp(const BookPosition(-4, -4)), const BookPosition(0, 0));
    });

    test('clamp leaves an in-range position untouched', () {
      final c = cursorFor([chapter(1, 0, 60), chapter(2, 1, 60)]);
      expect(c.pageCountOf(1), greaterThan(3));
      expect(c.clamp(const BookPosition(1, 3)), const BookPosition(1, 3));
    });

    test('clamp on an empty book is safe', () {
      final c = cursorFor(const <Chapter>[]);
      expect(c.clamp(const BookPosition(3, 3)), const BookPosition(0, 0));
    });

    test('pageAt returns the character range of the position', () {
      final c = cursorFor([chapter(1, 0, 120)]);
      final page = c.pageAt(const BookPosition(0, 1));
      expect(page.start, lessThan(page.end));
      expect(page.start, c.offsetAt(const BookPosition(0, 1)));
    });
  });

  group('BookPageCursor — legacy pixel-offset migration', () {
    test('fraction 0 lands on the first page', () {
      final c = cursorFor([chapter(1, 0, 150)]);
      expect(c.approximateFromScrollFraction(0, 0), const BookPosition(0, 0));
    });

    test('fraction 1 lands on the last page', () {
      final c = cursorFor([chapter(1, 0, 150)]);
      final last = c.pageCountOf(0) - 1;
      expect(c.approximateFromScrollFraction(0, 1.0), BookPosition(0, last));
    });

    test('a mid fraction lands somewhere in the middle', () {
      final c = cursorFor([chapter(1, 0, 200)]);
      final count = c.pageCountOf(0);
      final mid = c.approximateFromScrollFraction(0, 0.5).pageIndex;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(count - 1));
    });

    test('the fraction is monotonic in the page index', () {
      final c = cursorFor([chapter(1, 0, 200)]);
      var last = -1;
      for (var f = 0.0; f <= 1.0; f += 0.05) {
        final p = c.approximateFromScrollFraction(0, f).pageIndex;
        expect(p, greaterThanOrEqualTo(last));
        last = p;
      }
    });

    test('out-of-range and non-finite fractions are handled', () {
      final c = cursorFor([chapter(1, 0, 150)]);
      final last = c.pageCountOf(0) - 1;
      expect(c.approximateFromScrollFraction(0, -3), const BookPosition(0, 0));
      expect(c.approximateFromScrollFraction(0, 9), BookPosition(0, last));
      expect(
        c.approximateFromScrollFraction(0, double.nan),
        const BookPosition(0, 0),
      );
      expect(
        c.approximateFromScrollFraction(0, double.infinity),
        const BookPosition(0, 0),
      );
    });
  });
}
