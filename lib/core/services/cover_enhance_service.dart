import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Ebook cover post-process: optional 2× upscale for small covers, then a mild
/// unsharp mask so Discover → library covers look crisper without AI models.
class CoverEnhanceService {
  CoverEnhanceService._();

  /// Upscale when the shortest side is below this many pixels.
  static const int upscaleBelowShortSide = 400;

  /// Cap longest side after upscale so we don't blow memory on odd inputs.
  static const int maxLongSide = 1600;

  /// Enhance encoded image bytes. Returns JPEG bytes on success, or the
  /// original [bytes] if decode/enhance fails (never throws to callers).
  static Future<Uint8List> enhance(Uint8List bytes) async {
    if (bytes.isEmpty) return bytes;
    try {
      return await compute(_enhanceSync, bytes);
    } catch (e, st) {
      debugPrint('cover enhance failed: $e\n$st');
      return bytes;
    }
  }

  /// Sync path for [compute] and tests.
  static Uint8List enhanceSync(Uint8List bytes) => _enhanceSync(bytes);
}

Uint8List _enhanceSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  var image = decoded.numChannels == 4
      ? decoded.convert(numChannels: 3)
      : decoded;

  final shortSide = image.width < image.height ? image.width : image.height;
  final longSide = image.width > image.height ? image.width : image.height;

  if (shortSide > 0 &&
      shortSide < CoverEnhanceService.upscaleBelowShortSide &&
      longSide < CoverEnhanceService.maxLongSide) {
    final scale = 2;
    var targetW = image.width * scale;
    var targetH = image.height * scale;
    final targetLong = targetW > targetH ? targetW : targetH;
    if (targetLong > CoverEnhanceService.maxLongSide) {
      final factor = CoverEnhanceService.maxLongSide / targetLong;
      targetW = (targetW * factor).round().clamp(1, CoverEnhanceService.maxLongSide);
      targetH = (targetH * factor).round().clamp(1, CoverEnhanceService.maxLongSide);
    }
    image = img.copyResize(
      image,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );
  }

  image = _unsharpMask(image, radius: 1, amount: 1.35);

  // Mild edge boost without heavy halos (Pillow "Sharpness 1.15" analogue).
  image = img.convolution(
    image,
    filter: const <num>[0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
    div: 1,
    amount: 0.55,
  );

  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

/// Unsharp mask: `out = original + amount * (original - blur)`.
img.Image _unsharpMask(img.Image src, {required int radius, required double amount}) {
  final blurred = img.gaussianBlur(img.Image.from(src), radius: radius);
  final out = img.Image.from(src);
  for (final p in out) {
    final b = blurred.getPixel(p.x, p.y);
    p
      ..r = (p.r + amount * (p.r - b.r)).clamp(0, 255).round()
      ..g = (p.g + amount * (p.g - b.g)).clamp(0, 255).round()
      ..b = (p.b + amount * (p.b - b.b)).clamp(0, 255).round();
  }
  return out;
}
