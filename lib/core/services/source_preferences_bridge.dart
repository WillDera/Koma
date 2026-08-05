import 'package:flutter/services.dart';

/// Bridge to native Mihon-style [ConfigurableSource] preferences Activity.
class SourcePreferencesBridge {
  static const _channel = MethodChannel('com.koma.koma/source_prefs');

  /// Ensures the APK is loaded into Dalvik, then reports whether the source
  /// implements ConfigurableSource.
  static Future<bool> isConfigurable({
    required String sourceId,
    required String apkPath,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('isConfigurable', {
        'sourceId': sourceId,
        'apkPath': apkPath,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Loads the extension if needed and opens [SourcePreferencesActivity].
  static Future<void> open({
    required String sourceId,
    required String apkPath,
    String? title,
  }) async {
    await _channel.invokeMethod<void>('openSourcePreferences', {
      'sourceId': sourceId,
      'apkPath': apkPath,
      if (title != null && title.isNotEmpty) 'title': title,
    });
  }
}
