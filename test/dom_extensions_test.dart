import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:koma/eval/utils/dom_extensions.dart';

void main() {
  test(':contains selects elements by text (mangayomi / Cheerio)', () {
    final doc = html_parser.parse('''
      <html><body>
        <a href="/c1">Chapter 1</a>
        <a href="/c2">Chapter 2</a>
        <span>Other</span>
      </body></html>
    ''');
    final hits = doc.select('a:contains(Chapter)') ?? [];
    expect(hits.length, 2);
    expect(hits.first.attr('href'), '/c1');
  });

  test(':contains is case-insensitive', () {
    final doc = html_parser.parse('<div><p>Hello World</p></div>');
    final hit = doc.selectFirst('p:contains(hello)');
    expect(hit, isNotNull);
    expect(hit!.text, 'Hello World');
  });

  test('unsupported package:html selectors no longer throw via select()', () {
    final doc = html_parser.parse('<div><p>x</p></div>');
    expect(() => doc.select('p:contains(x)'), returnsNormally);
  });
}
