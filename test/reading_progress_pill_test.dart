import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/text_progress_pill_prefs.dart';
import 'package:koma/theme/app_theme.dart';
import 'package:koma/widgets/reading_progress_pill.dart';

ScrollMetrics _metrics({required double pixels, required double max}) {
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: max,
    pixels: pixels,
    viewportDimension: 800,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );
}

void main() {
  group('readingProgressFromScroll', () {
    test('is empty at the start', () {
      expect(readingProgressFromScroll(_metrics(pixels: 0, max: 1000)), 0);
    });

    test('is full at the end', () {
      expect(readingProgressFromScroll(_metrics(pixels: 1000, max: 1000)), 1);
    });

    test('is full when content does not scroll', () {
      expect(readingProgressFromScroll(_metrics(pixels: 0, max: 0)), 1);
    });

    test('clamps mid progress', () {
      expect(readingProgressFromScroll(_metrics(pixels: 250, max: 1000)), 0.25);
    });
  });

  group('readingProgressFromPage', () {
    test('single page is full', () {
      expect(readingProgressFromPage(0, 1), 1);
    });

    test('maps first and last pages', () {
      expect(readingProgressFromPage(0, 5), 0);
      expect(readingProgressFromPage(4, 5), 1);
    });
  });

  testWidgets('progress pill appears when enabled with activity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(
          body: ReadingProgressPillOverlay(
            progress: 0.4,
            enabled: false,
            placement: TextProgressPillPlacement.bottom,
            activityTick: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(
          body: ReadingProgressPillOverlay(
            progress: 0.4,
            enabled: true,
            placement: TextProgressPillPlacement.bottom,
            activityTick: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    final opacityFinder = find.byType(AnimatedOpacity);
    expect(opacityFinder, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1.0);
  });

  testWidgets('progress pill fades out after 3s of inactivity', (tester) async {
    Widget host(int tick) => MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: ReadingProgressPillOverlay(
              progress: 0.4,
              enabled: true,
              placement: TextProgressPillPlacement.bottom,
              activityTick: tick,
            ),
          ),
        );

    await tester.pumpWidget(host(1));
    await tester.pumpWidget(host(2));
    await tester.pump();

    final opacityFinder = find.byType(AnimatedOpacity);
    expect(opacityFinder, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1.0);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.0);
  });
}
