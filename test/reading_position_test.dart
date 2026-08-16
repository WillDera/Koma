import 'package:flutter_test/flutter_test.dart';
import 'package:koma/features/reader/pagination/reading_position.dart';

void main() {
  group('charOffsetFromScroll', () {
    test('maps the top and bottom of the chapter', () {
      expect(
        charOffsetFromScroll(textLength: 100, pixels: 0, maxExtent: 500),
        0,
      );
      expect(
        charOffsetFromScroll(textLength: 100, pixels: 500, maxExtent: 500),
        100,
      );
    });

    test('maps the midpoint', () {
      expect(
        charOffsetFromScroll(textLength: 100, pixels: 250, maxExtent: 500),
        50,
      );
    });

    test('returns 0 when there is no text or no scroll range', () {
      expect(
        charOffsetFromScroll(textLength: 0, pixels: 10, maxExtent: 500),
        0,
      );
      expect(
        charOffsetFromScroll(textLength: 100, pixels: 10, maxExtent: 0),
        0,
      );
    });

    test('clamps overscroll', () {
      expect(
        charOffsetFromScroll(textLength: 100, pixels: -20, maxExtent: 500),
        0,
      );
      expect(
        charOffsetFromScroll(textLength: 100, pixels: 800, maxExtent: 500),
        100,
      );
    });
  });

  group('scrollPixelsFromChar', () {
    test('is the inverse of charOffsetFromScroll at stable points', () {
      const length = 200;
      const extent = 800.0;
      for (final pixels in [0.0, 200.0, 400.0, 800.0]) {
        final char = charOffsetFromScroll(
          textLength: length,
          pixels: pixels,
          maxExtent: extent,
        );
        expect(
          scrollPixelsFromChar(
            charOffset: char,
            textLength: length,
            maxExtent: extent,
          ),
          closeTo(pixels, 0.6),
        );
      }
    });

    test('returns 0 when there is no text or no scroll range', () {
      expect(
        scrollPixelsFromChar(charOffset: 10, textLength: 0, maxExtent: 500),
        0,
      );
      expect(
        scrollPixelsFromChar(charOffset: 10, textLength: 100, maxExtent: 0),
        0,
      );
    });
  });
}
