import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_prefs.dart';

/// FlareSolverr / Byparr-style challenge solver tried before the WebView path.
class CfProxyClient {
  CfProxyClient._();

  /// Returns cookie header + user-agent from the proxy, or null on failure.
  static Future<({String cookie, String userAgent})?> solve(String url) async {
    final base = await HttpPrefs.cfProxyUrl();
    if (base.isEmpty) return null;

    final endpoint = base.endsWith('/')
        ? '${base}v1'
        : '$base/v1';

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({
          'cmd': 'request.get',
          'url': url,
          'maxTimeout': 60000,
        }),
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'ok') return null;
      final solution = body['solution'] as Map<String, dynamic>?;
      if (solution == null) return null;

      final ua = solution['userAgent'] as String? ?? '';
      final cookies = solution['cookies'] as List<dynamic>? ?? const [];
      final parts = <String>[];
      for (final raw in cookies) {
        if (raw is! Map) continue;
        final name = raw['name'] as String?;
        final value = raw['value'] as String?;
        if (name == null || value == null) continue;
        parts.add('$name=$value');
      }
      if (parts.isEmpty && ua.isEmpty) return null;
      return (cookie: parts.join('; '), userAgent: ua);
    } catch (_) {
      return null;
    }
  }
}
