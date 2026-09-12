import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/extension_manager.dart';

void main() {
  test('resolveExtensionSourceCodeUrl keeps absolute URLs', () {
    expect(
      resolveExtensionSourceCodeUrl(
        'https://example.com/a.js',
        'https://willdera.github.io/Koma/extensions/index.json',
      ),
      'https://example.com/a.js',
    );
  });

  test('resolveExtensionSourceCodeUrl joins relative next to index', () {
    expect(
      resolveExtensionSourceCodeUrl(
        'novelbuddy.js',
        'https://willdera.github.io/Koma/extensions/index.json',
      ),
      'https://willdera.github.io/Koma/extensions/novelbuddy.js',
    );
  });
}
