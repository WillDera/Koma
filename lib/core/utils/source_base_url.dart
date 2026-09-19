/// Normalize a user-entered Source URL for storage and WebView.
///
/// Returns null for empty input. Adds `https://` when the scheme is missing
/// and repairs common typos like `https//example.com`.
String? normalizeSourceBaseUrl(String? raw) {
  var u = (raw ?? '').trim();
  if (u.isEmpty) return null;
  // https//host or http//host (missing colon)
  u = u.replaceFirstMapped(
    RegExp(r'^(https?)[/\\]+', caseSensitive: false),
    (m) => '${m[1]!.toLowerCase()}://',
  );
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
    u = 'https://$u';
  }
  // Drop a single trailing slash — Mihon baseUrls are usually bare origins.
  if (u.length > 'https://x'.length && u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}
