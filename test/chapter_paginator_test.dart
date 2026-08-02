import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/pagination/chapter_paginator.dart';
import 'package:koma/theme/theme_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 14, height: 1.5);

  PaginationKey keyFor(Size viewport) => PaginationKey(
    viewport: viewport,
    fontSize: 14,
    lineHeight: 1.5,
    textAlign: TextAlign.left,
    fontFamily: null,
    useDeviceFont: true,
    bionicReading: false,
  );

  /// A paginator that renders plain uniform spans — enough to measure.
  ChapterPaginator paginatorFor(String text, {double firstPageInset = 0}) {
    return ChapterPaginator(
      spanBuilder: (start, end) => [
        TextSpan(text: text.substring(start, end), style: style),
      ],
      firstPageInset: firstPageInset,
    );
  }

  PaginatedChapter run(
    String text, {
    Size viewport = const Size(300, 200),
    double firstPageInset = 0,
  }) {
    return paginatorFor(
      text,
      firstPageInset: firstPageInset,
    ).paginate(chapterId: 1, text: text, key: keyFor(viewport));
  }

  /// Long enough to need many pages at the viewport sizes used below.
  final longText = List.generate(
    400,
    (i) => 'Sentence number $i in a reasonably long paragraph of prose.',
  ).join(' ');

  group('ChapterPaginator — structural invariants', () {
    test('pages are contiguous, ascending and non-overlapping', () {
      final result = run(longText);
      expect(result.pages, isNotEmpty);
      for (var i = 0; i < result.pages.length; i++) {
        final p = result.pages[i];
        expect(p.start, lessThan(p.end), reason: 'page $i is empty');
        if (i > 0) {
          expect(
            p.start,
            result.pages[i - 1].end,
            reason: 'gap or overlap before page $i',
          );
        }
      }
    });

    test('the pages cover the whole text exactly once', () {
      final result = run(longText);
      expect(result.pages.first.start, 0);
      expect(result.pages.last.end, longText.length);

      final rebuilt = result.pages
          .map((p) => longText.substring(p.start, p.end))
          .join();
      expect(rebuilt, longText);
    });

    test('a long chapter splits into more than one page', () {
      final result = run(longText);
      expect(result.pageCount, greaterThan(1));
    });

    test('a taller viewport yields fewer pages', () {
      final short = run(longText, viewport: const Size(300, 200));
      final tall = run(longText, viewport: const Size(300, 600));
      expect(tall.pageCount, lessThan(short.pageCount));
    });

    test('a narrower viewport yields more pages', () {
      final wide = run(longText, viewport: const Size(600, 300));
      final narrow = run(longText, viewport: const Size(200, 300));
      expect(narrow.pageCount, greaterThan(wide.pageCount));
    });

    test('the title inset costs space on the first page only', () {
      final without = run(longText, viewport: const Size(300, 300));
      final with_ = run(
        longText,
        viewport: const Size(300, 300),
        firstPageInset: 120,
      );
      // The first page holds less text; later pages are unaffected.
      expect(with_.pages.first.end, lessThan(without.pages.first.end));
    });
  });

  group('ChapterPaginator — offset mapping', () {
    test('pageIndexForOffset round-trips every page start', () {
      final result = run(longText);
      for (var i = 0; i < result.pageCount; i++) {
        expect(
          result.pageIndexForOffset(result.pages[i].start),
          i,
          reason: 'page $i start did not map back to $i',
        );
      }
    });

    test('pageIndexForOffset finds the page for interior offsets', () {
      final result = run(longText);
      for (var i = 0; i < result.pageCount; i++) {
        final p = result.pages[i];
        final mid = p.start + (p.length ~/ 2);
        expect(result.pageIndexForOffset(mid), i);
      }
    });

    test('offsetForPageIndex is the inverse of pageIndexForOffset', () {
      final result = run(longText);
      for (var i = 0; i < result.pageCount; i++) {
        expect(result.pageIndexForOffset(result.offsetForPageIndex(i)), i);
      }
    });

    test('out-of-range offsets clamp to the first and last page', () {
      final result = run(longText);
      expect(result.pageIndexForOffset(-500), 0);
      expect(
        result.pageIndexForOffset(longText.length + 500),
        result.pageCount - 1,
      );
    });

    test('out-of-range page indices clamp', () {
      final result = run(longText);
      expect(result.offsetForPageIndex(-3), result.pages.first.start);
      expect(result.offsetForPageIndex(9999), result.pages.last.start);
      expect(result.pageAt(9999), result.pages.last);
    });
  });

  group('ChapterPaginator — degenerate input', () {
    test('empty text yields a single empty page', () {
      final result = run('');
      expect(result.pageCount, 1);
      expect(result.pages.single.isEmpty, isTrue);
      expect(result.pageIndexForOffset(0), 0);
    });

    test('text shorter than one page stays on one page', () {
      const short = 'Just a few words.';
      final result = run(short, viewport: const Size(400, 400));
      expect(result.pageCount, 1);
      expect(result.pages.single, const PageBreak(0, short.length));
    });

    test('a zero-height viewport does not hang or throw', () {
      final result = run(longText, viewport: const Size(300, 0));
      expect(result.pageCount, 1);
      expect(result.pages.single.end, longText.length);
    });

    test('a zero-width viewport does not hang or throw', () {
      final result = run(longText, viewport: const Size(0, 300));
      expect(result.pageCount, 1);
    });

    test('a single unbreakable word taller than the viewport terminates', () {
      // No spaces, so the line cannot be broken to fit.
      final wall = 'x' * 4000;
      final result = run(wall, viewport: const Size(50, 20));
      expect(result.pages, isNotEmpty);
      expect(result.pages.last.end, wall.length);
      // Every page must advance, or the reader would be stuck.
      for (final p in result.pages) {
        expect(p.length, greaterThan(0));
      }
    });

    test('an inset larger than the viewport still terminates', () {
      final result = run(
        longText,
        viewport: const Size(300, 100),
        firstPageInset: 500,
      );
      expect(result.pages, isNotEmpty);
      expect(result.pages.last.end, longText.length);
    });

    test('text that is only newlines is handled', () {
      final result = run('\n\n\n\n', viewport: const Size(300, 300));
      expect(result.pages, isNotEmpty);
      expect(result.pages.last.end, 4);
    });
  });

  group('PaginationKey', () {
    const viewport = Size(320, 480);
    final base = keyFor(viewport);

    test('identical inputs compare equal and hash alike', () {
      expect(keyFor(viewport), base);
      expect(keyFor(viewport).hashCode, base.hashCode);
    });

    test('any layout-affecting field change breaks equality', () {
      expect(keyFor(const Size(321, 480)), isNot(base));

      PaginationKey vary({
        double? fontSize,
        double? lineHeight,
        TextAlign? textAlign,
        String? fontFamily,
        bool? useDeviceFont,
        bool? bionicReading,
      }) {
        return PaginationKey(
          viewport: viewport,
          fontSize: fontSize ?? 14,
          lineHeight: lineHeight ?? 1.5,
          textAlign: textAlign ?? TextAlign.left,
          fontFamily: fontFamily,
          useDeviceFont: useDeviceFont ?? true,
          bionicReading: bionicReading ?? false,
        );
      }

      expect(vary(fontSize: 15), isNot(base));
      expect(vary(lineHeight: 1.6), isNot(base));
      expect(vary(textAlign: TextAlign.justify), isNot(base));
      expect(vary(fontFamily: 'Literata'), isNot(base));
      expect(vary(useDeviceFont: false), isNot(base));
      expect(vary(bionicReading: true), isNot(base));
    });

    test('PaginationKey.from mirrors the theme state', () {
      const prov = ThemeState(fontSize: 18, lineHeight: 1.8);
      final key = PaginationKey.from(prov, viewport);
      expect(key.fontSize, 18);
      expect(key.lineHeight, 1.8);
      expect(key.viewport, viewport);
    });

    test('useDeviceFont drops the family so measurement matches rendering', () {
      const device = ThemeState(useDeviceFont: true);
      expect(PaginationKey.from(device, viewport).fontFamily, isNull);
    });
  });

  group('PageBreak', () {
    test('value equality', () {
      expect(const PageBreak(0, 10), const PageBreak(0, 10));
      expect(const PageBreak(0, 10).hashCode, const PageBreak(0, 10).hashCode);
      expect(const PageBreak(0, 10), isNot(const PageBreak(0, 11)));
    });

    test('contains is half-open', () {
      const p = PageBreak(5, 10);
      expect(p.contains(5), isTrue);
      expect(p.contains(9), isTrue);
      expect(p.contains(10), isFalse);
      expect(p.contains(4), isFalse);
    });

    test('length and isEmpty', () {
      expect(const PageBreak(5, 10).length, 5);
      expect(const PageBreak(5, 5).isEmpty, isTrue);
    });
  });
}
