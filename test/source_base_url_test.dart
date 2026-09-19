import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/utils/source_base_url.dart';

void main() {
  test('normalizeSourceBaseUrl adds https and trims slash', () {
    expect(normalizeSourceBaseUrl(' readcomiconline.xyz/ '), 'https://readcomiconline.xyz');
    expect(
      normalizeSourceBaseUrl('https://readcomiconline.xyz'),
      'https://readcomiconline.xyz',
    );
  });

  test('normalizeSourceBaseUrl repairs https// typo', () {
    expect(
      normalizeSourceBaseUrl('https//readcomiconline.xyz'),
      'https://readcomiconline.xyz',
    );
  });

  test('normalizeSourceBaseUrl empty → null', () {
    expect(normalizeSourceBaseUrl('  '), isNull);
    expect(normalizeSourceBaseUrl(null), isNull);
  });
}
