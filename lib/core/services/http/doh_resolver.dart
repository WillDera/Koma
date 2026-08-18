import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_prefs.dart';

/// DNS-over-HTTPS lookup (Cloudflare/Google JSON API).
class DohResolver {
  DohResolver._();

  static final _cache = <String, InternetAddress>{};

  static Future<InternetAddress> resolve(String host) async {
    final cached = _cache[host];
    if (cached != null) return cached;

    final enabled = await HttpPrefs.dohEnabled();
    if (!enabled) return InternetAddress(host);

    final base = await HttpPrefs.dohUrl();
    if (base.isEmpty) return InternetAddress(host);

    try {
      final uri = Uri.parse(base).replace(
        queryParameters: {'name': host, 'type': 'A'},
      );
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/dns-json'},
      );
      if (response.statusCode != 200) return InternetAddress(host);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final answers = json['Answer'] as List<dynamic>? ?? const [];
      for (final raw in answers) {
        if (raw is! Map) continue;
        if (raw['type'] != 1) continue;
        final data = raw['data'] as String?;
        if (data == null || data.isEmpty) continue;
        final addr = InternetAddress.tryParse(data);
        if (addr != null) {
          _cache[host] = addr;
          return addr;
        }
      }
    } catch (_) {}
    return InternetAddress(host);
  }

  static void clearCache() => _cache.clear();
}
