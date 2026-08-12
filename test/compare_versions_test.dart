import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/utils/language.dart';

void main() {
  group('compareVersions', () {
    test('0.2.20 is newer than 0.1.25', () {
      expect(compareVersions('0.2.20', '0.1.25'), greaterThan(0));
      expect(compareVersions('0.1.25', '0.2.20'), lessThan(0));
    });

    test('0.10.0 is newer than 0.9.0 (no padRight bug)', () {
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
      expect(compareVersions('0.9.0', '0.10.0'), lessThan(0));
    });

    test('equal versions', () {
      expect(compareVersions('0.2.20', '0.2.20'), 0);
      expect(compareVersions('v1.2.3', '1.2.3'), 0);
    });
  });
}
