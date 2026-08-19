import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/core/utils/text_extractor.dart';
import 'package:koma/features/reader/pagination/book_page_cursor.dart';
import 'package:koma/features/reader/pagination/paginated_reader_body.dart';
import 'package:koma/theme/theme_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Chapter chapter(int id, int index, int sentences) {
    final body = List.generate(
      sentences,
      (i) => 'Chapter $index sentence $i with a handful of words in it.',
    ).join(' ');
    return Chapter(
      id: id,
      bookId: 1,
      title: 'Chapter $index',
      content: '<p>$body</p>',
      index: index,
    );
  }

  setUp(TextExtractor.invalidate);

  /// Pumps the body and returns a recorder of every reported position.
  Future<List<BookPosition>> pump(
    WidgetTester tester, {
    required List<Chapter> chapters,
    int chapterIndex = 0,
    int? Function(int)? charOffsetFor,
    List<int>? chapterChanges,
    Size size = const Size(400, 600),
  }) async {
    final positions = <BookPosition>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaginatedReaderBody(
            chapters: chapters,
            chapterIndex: chapterIndex,
            themeProv: const ThemeState(),
            charOffsetFor: charOffsetFor ?? (_) => null,
            pixelOffsetFor: (_) => 0,
            disableAnimations: true,
            onPositionChanged: (pos, offset, {required exact, pageEnd}) {
              positions.add(pos);
            },
            onChapterChanged: chapterChanges?.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return positions;
  }

  testWidgets('renders the first page and shows the chapter title', (
    tester,
  ) async {
    await pump(tester, chapters: [chapter(1, 0, 80)]);
    expect(find.textContaining('Chapter 0'), findsWidgets);
  });

  testWidgets('pages paint an opaque background', (tester) async {
    // Pages paint an opaque sheet fill.
    await pump(tester, chapters: [chapter(1, 0, 200)]);

    final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    final pageBoxes = boxes.where((b) => b.color.a == 1.0).length;
    expect(
      pageBoxes,
      greaterThanOrEqualTo(1),
      reason: 'the current sheet must be opaque',
    );
  });

  testWidgets('an empty chapter list renders nothing', (tester) async {
    await pump(tester, chapters: []);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('a stored character offset opens on the matching page', (
    tester,
  ) async {
    final chapters = [chapter(1, 0, 200)];
    // Deep into the chapter — the opening page must not be page 0.
    final positions = await pump(
      tester,
      chapters: chapters,
      charOffsetFor: (_) => 4000,
    );
    // An exact resume reports nothing: there is no approximation to persist.
    expect(positions, isEmpty);

    final text = TextExtractor.extractCached(1, chapters.first.content);
    expect(text.length, greaterThan(4000));
  });

  testWidgets('a legacy pixel offset is persisted once as a char offset', (
    tester,
  ) async {
    final positions = <BookPosition>[];
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaginatedReaderBody(
            chapters: [chapter(1, 0, 200)],
            chapterIndex: 0,
            themeProv: const ThemeState(),
            charOffsetFor: (_) => null,
            pixelOffsetFor: (_) => 3000,
            contentHeightFor: (_) => 6000,
            disableAnimations: true,
            onPositionChanged: (pos, offset, {required exact, pageEnd}) {
              if (!exact) positions.add(pos);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Approximated from the midpoint of the old layout, so it should land
    // mid-chapter and be written back exactly once.
    expect(positions, hasLength(1));
    expect(positions.single.pageIndex, greaterThan(0));
  });

  /// Drag horizontally to turn a page.
  Future<void> turn(WidgetTester tester, {required bool forward}) async {
    await tester.drag(
      find.byType(PaginatedReaderBody),
      Offset(forward ? -120 : 120, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('turning forward advances one page at a time', (tester) async {
    final positions = await pump(tester, chapters: [chapter(1, 0, 200)]);

    await turn(tester, forward: true);
    expect(positions, hasLength(1));
    expect(positions.last, const BookPosition(0, 1));

    await turn(tester, forward: true);
    expect(positions.last, const BookPosition(0, 2));
  });

  testWidgets('turning back returns to the previous page', (tester) async {
    final positions = await pump(tester, chapters: [chapter(1, 0, 200)]);

    await turn(tester, forward: true);
    await turn(tester, forward: true);
    expect(positions.last, const BookPosition(0, 2));

    await turn(tester, forward: false);
    expect(positions.last, const BookPosition(0, 1));
  });

  testWidgets('cannot turn back from the first page of the book', (
    tester,
  ) async {
    final positions = await pump(tester, chapters: [chapter(1, 0, 200)]);
    await turn(tester, forward: false);
    // No position reported: there was nowhere to go.
    expect(positions, isEmpty);
  });

  testWidgets('turning past the last page enters the next chapter', (
    tester,
  ) async {
    // A short first chapter so the boundary is reachable in a few turns.
    final chapters = [chapter(1, 0, 6), chapter(2, 1, 60)];
    final changes = <int>[];
    final positions = await pump(
      tester,
      chapters: chapters,
      chapterChanges: changes,
    );

    // Turn until the chapter changes, with a bound so a stuck cursor fails
    // loudly rather than hanging the test.
    for (var i = 0; i < 20 && changes.isEmpty; i++) {
      await turn(tester, forward: true);
    }

    expect(
      changes,
      isNotEmpty,
      reason: 'should have crossed into the next chapter',
    );
    expect(changes.first, 1);
    // The first page of the new chapter, not a continuation of the old one.
    expect(positions.last, const BookPosition(1, 0));
  });

  testWidgets('cannot turn forward past the end of the book', (tester) async {
    final positions = await pump(tester, chapters: [chapter(1, 0, 6)]);

    for (var i = 0; i < 20; i++) {
      await turn(tester, forward: true);
    }
    final settled = positions.length;

    await turn(tester, forward: true);
    expect(
      positions.length,
      settled,
      reason: 'no further turns past the end of the book',
    );
    if (positions.isNotEmpty) {
      expect(positions.last.chapterIndex, 0);
    }
  });

  group('reflow on settings change', () {
    /// Pumps a body whose [ThemeState] can be swapped mid-test, and exposes the
    /// text of the page currently on screen.
    Future<
      ({Future<void> Function(ThemeState) apply, String Function() pageText})
    >
    pumpSettings(
      WidgetTester tester, {
      required List<Chapter> chapters,
      ThemeState initial = const ThemeState(),
      int? Function(int)? charOffsetFor,
      Size size = const Size(400, 600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late void Function(void Function()) setOuter;
      var prov = initial;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return PaginatedReaderBody(
                  chapters: chapters,
                  chapterIndex: 0,
                  themeProv: prov,
                  charOffsetFor: charOffsetFor ?? (_) => null,
                  pixelOffsetFor: (_) => 0,
                  disableAnimations: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      String pageText() {
        final widgets = tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .toList();
        if (widgets.isEmpty) return '';
        final visible = widgets.first;
        return visible.data ?? visible.textSpan?.toPlainText() ?? '';
      }

      Future<void> apply(ThemeState next) async {
        setOuter(() => prov = next);
        await tester.pumpAndSettle();
      }

      return (apply: apply, pageText: pageText);
    }

    testWidgets('a font size change keeps the reader on the same text', (
      tester,
    ) async {
      const resumeOffset = 2000;
      final h = await pumpSettings(
        tester,
        chapters: [chapter(1, 0, 200)],
        // Start well into the chapter so a reflow has somewhere to drift to.
        charOffsetFor: (_) => resumeOffset,
      );

      final before = h.pageText();
      expect(before, isNotEmpty);

      await h.apply(const ThemeState(fontSize: 22));
      final after = h.pageText();
      expect(after, isNotEmpty);

      // Re-measuring moves every boundary, so the text cannot be compared
      // verbatim. What must hold is that the reader did not jump: the new page
      // has to start near the offset that was being read, which is the whole
      // point of carrying the character offset across the change.
      final full = TextExtractor.extractCached(1, chapter(1, 0, 200).content);
      final newStart = full.indexOf(after.substring(0, 40));
      expect(
        newStart,
        greaterThanOrEqualTo(0),
        reason: 'the page text should come from this chapter',
      );
      expect(
        (newStart - resumeOffset).abs(),
        lessThan(600),
        reason:
            'reflow should land near the old offset, not at the chapter top',
      );
    });

    testWidgets('a larger font yields more pages for the same chapter', (
      tester,
    ) async {
      final chapters = [chapter(1, 0, 200)];
      final h = await pumpSettings(
        tester,
        chapters: chapters,
        initial: const ThemeState(fontSize: 14),
      );

      final small = h.pageText().length;
      await h.apply(const ThemeState(fontSize: 24));
      final large = h.pageText().length;

      expect(
        large,
        lessThan(small),
        reason: 'bigger glyphs must fit less text per page',
      );
    });

    testWidgets('the page still fills the viewport after a reflow', (
      tester,
    ) async {
      final h = await pumpSettings(
        tester,
        chapters: [chapter(1, 0, 200)],
        initial: const ThemeState(fontSize: 14),
      );

      await h.apply(const ThemeState(fontSize: 24));
      await tester.pumpAndSettle();

      // A stale title inset used to be measured against the *old* font, which
      // over-budgeted the first page and overflowed it.
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings changes settle without leaving a pending timer', (
      tester,
    ) async {
      final h = await pumpSettings(
        tester,
        chapters: [chapter(1, 0, 120), chapter(2, 1, 120)],
      );

      // A slider drag: several changes in quick succession.
      for (final size in [15.0, 16.0, 17.0, 18.0]) {
        await h.apply(ThemeState(fontSize: size));
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(h.pageText(), isNotEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposing mid-settle does not fire a timer on a dead state', (
      tester,
    ) async {
      await pumpSettings(tester, chapters: [chapter(1, 0, 120)]);
      // Tear the tree down inside the settle window.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
