import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/models/chapter.dart';
import 'package:koma/theme/app_theme.dart';
import 'package:koma/widgets/chapter_nav_overlay.dart';

void main() {
  Chapter chapter(int index) => Chapter(
    id: index,
    bookId: 1,
    title: 'Title $index',
    content: '<p>body</p>',
    index: index,
  );

  testWidgets('next/previous move the chapter slider and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: ChapterNavOverlay(
            chapters: [chapter(0), chapter(1), chapter(2)],
            currentIndex: 0,
            onSelect: (_) {},
            onPrevious: () {},
            onNext: () {},
          ),
        ),
      ),
    );

    expect(find.text('Chapter 1 of 3'), findsOneWidget);
    expect(find.text('Title 0'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();

    expect(find.text('Chapter 2 of 3'), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.5, 0.001));

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();

    expect(find.text('Chapter 3 of 3'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
  });
}
