import 'dart:io';

import 'package:flutter/services.dart';

/// Saves manga panels to the system gallery and shares image bytes via the
/// platform chooser — Mihon ImageSaver / share parity for Android.
class MediaExportService {
  static const _channel = MethodChannel('com.koma.koma/media');

  /// Writes [bytes] into `Pictures/Koma/[optionalFolder]/ returns a content URI
  /// string when available.
  Future<String?> saveToGallery({
    required Uint8List bytes,
    required String displayName,
    String? albumSubfolder,
    String mimeType = 'image/jpeg',
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Gallery save is only implemented on Android');
    }
    final result = await _channel.invokeMethod<String>('saveToGallery', {
      'bytes': bytes,
      'displayName': displayName,
      'albumSubfolder': albumSubfolder,
      'mimeType': mimeType,
    });
    return result;
  }

  /// Opens the system share sheet for [bytes] as an image.
  Future<void> shareImage({
    required Uint8List bytes,
    required String displayName,
    String mimeType = 'image/jpeg',
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Image share is only implemented on Android');
    }
    await _channel.invokeMethod<void>('shareImage', {
      'bytes': bytes,
      'displayName': displayName,
      'mimeType': mimeType,
    });
  }
}
