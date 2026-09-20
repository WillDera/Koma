import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/widgets/color_filter_widget.dart';

void main() {
  testWidgets('ColorFilterWidget applies invert matrix when invertColors',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ColorFilterWidget(
          brightness: 1,
          contrast: 1,
          saturation: 1,
          invertColors: true,
          child: const SizedBox(
            key: Key('page'),
            width: 40,
            height: 40,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('page')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsWidgets);
  });

  testWidgets('ColorFilterWidget applies matrix for grayscale saturation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ColorFilterWidget(
          brightness: 1,
          contrast: 1,
          saturation: 0,
          invertColors: false,
          child: const SizedBox(
            key: Key('page'),
            width: 40,
            height: 40,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('page')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('identity settings skip ColorFiltered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColorFilterWidget(
          brightness: 1,
          contrast: 1,
          saturation: 1,
          child: SizedBox(key: Key('page'), width: 10, height: 10),
        ),
      ),
    );

    expect(find.byType(ColorFiltered), findsNothing);
  });
}
