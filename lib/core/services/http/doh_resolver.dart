import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_prefs.dart';

/// DNS-over-HTTPS lookup (Cloudflare/Google JSON API).
///
/// Returns a numeric IPv4 string when DoH succeeds; null to fall back to
/// system DNS via [Socket.startConnect] with the hostname.
class DohResolver {
  DohResolver._();

  static final _cache = <String, String>{};

  /// Resolves [host] to an IPv4 string when DoH is enabled and succeeds.
  static Future<String?> resolveIp(String host) async {
    final enabled = await HttpPrefs.dohEnabled();
    if (!enabled) return null;
    return lookupA(host);
  }

  /// DoH A-record lookup (no enabled check — only call when transport uses DoH).
  static Future<String?> lookupA(String host) async {
    final cached = _cache[host];
    if (cached != null) return cached;

    final base = await HttpPrefs.dohUrl();
    if (base.isEmpty) return null;

    try {
      final uri = Uri.parse(base).replace(
        queryParameters: {'name': host, 'type': 'A'},
      );
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/dns-json'},
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final answers = json['Answer'] as List<dynamic>? ?? const [];
      for (final raw in answers) {
        if (raw is! Map) continue;
        if (raw['type'] != 1) continue;
        final data = raw['data'] as String?;
        if (data == null || data.isEmpty) continue;
        if (InternetAddress.tryParse(data) != null) {
          _cache[host] = data;
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  static void clearCache() => _cache.clear();
}
