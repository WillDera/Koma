import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:koma/core/services/cover_enhance_service.dart';

void main() {
  test('enhance upscales small covers and returns jpeg', () {
    final tiny = img.Image(width: 120, height: 180);
    img.fill(tiny, color: img.ColorRgb8(40, 80, 160));
    // Soft edge so sharpen has something to work with.
    for (var x = 50; x < 70; x++) {
      for (var y = 0; y < tiny.height; y++) {
        tiny.setPixelRgb(x, y, 220, 220, 220);
      }
    }
    final raw = Uint8List.fromList(img.encodeJpg(tiny, quality: 85));
    final out = CoverEnhanceService.enhanceSync(raw);
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, greaterThanOrEqualTo(240));
    expect(decoded.height, greaterThanOrEqualTo(360));
  });

  test('enhance leaves large covers without forced 2x', () {
    final big = img.Image(width: 800, height: 1200);
    img.fill(big, color: img.ColorRgb8(10, 10, 10));
    final raw = Uint8List.fromList(img.encodeJpg(big, quality: 85));
    final out = CoverEnhanceService.enhanceSync(raw);
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, 800);
    expect(decoded.height, 1200);
  });
}
