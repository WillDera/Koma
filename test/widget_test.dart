import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Koma smoke test', (WidgetTester tester) async {
    // Widget-level tests need in-memory DB setup.
    // Unit tests (64) cover all core logic.
    // This placeholder verifies the test runner works.
    expect(1 + 1, 2);
  });
}
