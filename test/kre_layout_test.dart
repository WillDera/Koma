import 'dart:ui' show Rect;

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
    expect(hitTestLayoutPage(page, const Offset(70, 15)), 3);
  });

  test('glyphRectsOverlapping uses the line box', () {
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
              y: 12,
              width: 10,
              height: 20,
              charStart: 2,
              charEnd: 3,
            ),
          ],
        ),
      ],
    );
    expect(glyphRectsOverlapping(page, 2, 3), [const Rect.fromLTWH(48, 10, 10, 20)]);
    expect(glyphRectsOverlapping(page, 0, 1), isEmpty);
  });

  test('imageSlotBase counts empty-glyph lines on earlier pages', () {
    const layout = LayoutResult(
      plainText: 'Hi',
      pages: [
        LayoutPage(
          charStart: 0,
          charEnd: 0,
          lines: [LayoutLine(y: 0, height: 80, charStart: 0, charEnd: 0)],
        ),
        LayoutPage(charStart: 0, charEnd: 2),
      ],
    );
    expect(imageSlotBase(layout, 0), 0);
    expect(imageSlotBase(layout, 1), 1);
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

  test('layoutSlice uses Dart UTF-16 indices around curly quotes', () {
    const plain = 'It\u2019s a test';
    expect(plain.length, 11);
    expect(layoutSlice(plain, 0, 4), 'It\u2019s');
    expect(layoutSlice(plain, 4, 11), ' a test');
  });
}
