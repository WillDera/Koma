import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/layout/kre_layout.dart';

void main() {
  test('hitTestLayoutPage returns glyph offset and misses empty space', () {
    const page = LayoutPage(
      charStart: 0,
      charEnd: 4,
      lines: [
        LayoutLine(
          y: 10,
          height: 20,
          charStart: 0,
          charEnd: 4,
          glyphs: [
            LayoutGlyph(
              x: 48,
              y: 10,
              width: 10,
              height: 20,
              charStart: 2,
              charEnd: 3,
            ),
          ],
        ),
      ],
    );
    expect(hitTestLayoutPage(page, const Offset(50, 15)), 2);
    expect(hitTestLayoutPage(page, Offset.zero), isNull);
  });

  test('pageCharRanges are half-open and ordered', () {
    const layout = LayoutResult(
      plainText: 'Hello\n\nWorld',
      pages: [
        LayoutPage(charStart: 0, charEnd: 5),
        LayoutPage(charStart: 7, charEnd: 12),
      ],
    );
    expect(pageCharRanges(layout), [(0, 5), (7, 12)]);
  });
}
