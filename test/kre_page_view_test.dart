import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/layout/kre_layout.dart';
import 'package:koma/features/reader/layout/kre_page_view.dart';
import 'package:koma/features/reader/pagination/chapter_paginator.dart';
import 'package:koma/theme/theme_state.dart';

void main() {
  testWidgets('KrePageView paints laid-out text', (tester) async {
    const page = LayoutPage(
      charStart: 0,
      charEnd: 5,
      lines: [
        LayoutLine(
          y: 0,
          height: 24,
          charStart: 0,
          charEnd: 5,
          glyphs: [
            LayoutGlyph(
              x: 0,
              y: 0,
              width: 40,
              height: 24,
              charStart: 0,
              charEnd: 5,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: KrePageView(
              page: page,
              plainText: 'Hello',
              themeProv: ThemeState(),
              chapterTitle: 'Chapter',
              showTitle: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Chapter'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('PaginatedChapter.fromLayout maps half-open ranges', () {
    const layout = LayoutResult(
      plainText: 'Hello\n\nWorld',
      pages: [
        LayoutPage(charStart: 0, charEnd: 5),
        LayoutPage(charStart: 7, charEnd: 12),
      ],
    );
    final chapter = PaginatedChapter.fromLayout(
      chapterId: 1,
      layout: layout,
      key: PaginationKey.from(const ThemeState(), const Size(400, 600)),
    );
    expect(chapter.pageCount, 2);
    expect(chapter.pageAt(0), const PageBreak(0, 5));
    expect(chapter.pageAt(1), const PageBreak(7, 12));
    expect(chapter.pageIndexForOffset(8), 1);
  });
}
