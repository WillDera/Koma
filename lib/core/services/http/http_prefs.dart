import 'package:shared_preferences/shared_preferences.dart';

/// Network overrides for extension HTTP ([MClient]).
class HttpPrefs {
  HttpPrefs._();

  static const _dohEnabled = 'http_doh_enabled';
  static const _dohUrl = 'http_doh_url';
  static const _cfProxyUrl = 'http_cf_proxy_url';

  static const defaultDohUrl = 'https://cloudflare-dns.com/dns-query';

  static Future<bool> dohEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dohEnabled) ?? false;
  }

  static Future<void> setDohEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dohEnabled, value);
  }

  static Future<String> dohUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dohUrl)?.trim() ?? defaultDohUrl;
  }

  static Future<void> setDohUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dohUrl, value.trim());
  }

  static Future<String> cfProxyUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cfProxyUrl)?.trim() ?? '';
  }

  static Future<void> setCfProxyUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cfProxyUrl, value.trim());
  }
}
