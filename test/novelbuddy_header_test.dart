import 'package:flutter_test/flutter_test.dart';
import 'package:koma/eval/javascript/js_source_meta.dart';

void main() {
  test('NovelBuddy asset header parses as novel JS source', () async {
    // Mirror the critical mangayomiSources fields from
    // assets/extensions/novelbuddy.js (kept inline so the test does not
    // depend on Flutter asset bundling).
    const source = r'''
const mangayomiSources = [
  {
    "name": "NovelBuddy",
    "lang": "en",
    "baseUrl": "https://novelbuddy.me",
    "apiUrl": "https://api.novelbuddy.me",
    "version": "1.0.2",
    "itemType": 2,
    "sourceCodeLanguage": 1,
    "hasCloudflare": false,
  },
];
''';
    final meta = parseMangayomiSourcesHeader(source);
    expect(meta['itemType'], 'novel');
    expect(meta['apiUrl'], 'https://api.novelbuddy.me');
    expect(meta['baseUrl'], 'https://novelbuddy.me');
    expect(meta['hasCloudflare'], 'false');
    expect(meta['name'], 'NovelBuddy');
    expect(meta['version'], '1.0.2');
  });
}
