import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/sheet/sheet_switcher.dart';

void main() {
  testWidgets('forward keeps the incoming sheet at origin and slides outgoing left', (
    tester,
  ) async {
    var index = 0;
    var direction = SheetTurnDirection.none;
    late void Function(void Function()) setOuter;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SheetSwitcher(
                index: index,
                direction: direction,
                sheetColor: const Color(0xFFFFFFFF),
                duration: const Duration(milliseconds: 300),
                child: Text('page-$index', key: ValueKey(index)),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('page-0'), findsOneWidget);

    setOuter(() {
      index = 1;
      direction = SheetTurnDirection.forward;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('page-0'), findsOneWidget);
    expect(find.text('page-1'), findsOneWidget);

    final transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(transforms, isNotEmpty);
    final dx = transforms.first.transform.getTranslation().x;
    expect(dx, lessThan(0));

    expect(find.descendant(
      of: find.byType(SheetSwitcher),
      matching: find.byType(FadeTransition),
    ), findsNothing);
    expect(find.descendant(
      of: find.byType(SheetSwitcher),
      matching: find.byType(ScaleTransition),
    ), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('page-0'), findsNothing);
    expect(find.text('page-1'), findsOneWidget);
  });

  testWidgets('back slides the incoming sheet from the left over a static current', (
    tester,
  ) async {
    var index = 1;
    var direction = SheetTurnDirection.none;
    late void Function(void Function()) setOuter;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SheetSwitcher(
                index: index,
                direction: direction,
                sheetColor: const Color(0xFFFFFFFF),
                duration: const Duration(milliseconds: 300),
                child: Text('page-$index', key: ValueKey(index)),
              );
            },
          ),
        ),
      ),
    );

    setOuter(() {
      index = 0;
      direction = SheetTurnDirection.back;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('page-0'), findsOneWidget);
    expect(find.text('page-1'), findsOneWidget);

    final transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(transforms, isNotEmpty);
    final dx = transforms.first.transform.getTranslation().x;
    expect(dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(find.text('page-0'), findsOneWidget);
    expect(find.text('page-1'), findsNothing);
  });
}
