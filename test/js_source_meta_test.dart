import 'package:flutter_test/flutter_test.dart';
import 'package:koma/eval/javascript/js_source_meta.dart';

void main() {
  test('parseMangayomiSourcesHeader extracts apiUrl and baseUrl', () {
    const code = '''
const mangayomiSources = [{
    "name": "MangaDex",
    "baseUrl": "https://mangadex.org",
    "apiUrl": "https://api.mangadex.org",
    "iconUrl": "https://example.com/icon.png",
    "version": "0.1.4"
}];

class DefaultExtension extends MProvider {}
''';
    final meta = parseMangayomiSourcesHeader(code);
    expect(meta['apiUrl'], 'https://api.mangadex.org');
    expect(meta['baseUrl'], 'https://mangadex.org');
    expect(meta['iconUrl'], 'https://example.com/icon.png');
  });

  test('parseMangayomiSourcesHeader returns empty for missing header', () {
    expect(parseMangayomiSourcesHeader('class Foo {}'), isEmpty);
    expect(parseMangayomiSourcesHeader(null), isEmpty);
  });
}
