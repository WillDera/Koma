import 'package:flutter/services.dart';

/// Opens Mihon-style interactive WebView for CF / captcha (shared CookieManager).
class SourceWebViewBridge {
  SourceWebViewBridge._();
  static const _channel = MethodChannel('com.koma.koma/webview');

  /// [url] may be a relative manga url — native resolves via [HttpSource.getMangaUrl].
  static Future<void> open({
    required String url,
    required String sourceId,
    String? title,
    String? memo,
  }) async {
    await _channel.invokeMethod<void>('openWebView', {
      'url': url,
      'sourceId': sourceId,
      'title': ?title,
      'memo': ?memo,
    });
  }
}
