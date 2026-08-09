/// Pull metadata fields from a mangayomi JS extension's `mangayomiSources`
/// header object (e.g. MangaDex `apiUrl`).
///
/// Installed sources may only persist [baseUrl] from the index; many
/// extensions still need [apiUrl] / Cloudflare / itemType at runtime.
/// Parsing the onboarded script fills blanks.
Map<String, String> parseMangayomiSourcesHeader(String? sourceCode) {
  if (sourceCode == null || sourceCode.isEmpty) return const {};
  final start = sourceCode.indexOf('mangayomiSources');
  if (start < 0) return const {};
  final brace = sourceCode.indexOf('{', start);
  if (brace < 0) return const {};
  // End at the first `}];` / `},` that closes the first source object.
  final endObj = _findMatchingBrace(sourceCode, brace);
  if (endObj < 0) return const {};
  final objectBody = sourceCode.substring(brace, endObj + 1);
  final out = <String, String>{};
  for (final key in const [
    'apiUrl',
    'baseUrl',
    'dateFormat',
    'dateFormatLocale',
    'iconUrl',
    'itemType',
  ]) {
    final m = RegExp(
      '"$key"\\s*:\\s*"([^"]*)"',
    ).firstMatch(objectBody);
    if (m != null) out[key] = m.group(1)!;
  }
  // Booleans / bare identifiers (hasCloudflare: true, itemType: 0).
  final cf = RegExp(
    '"hasCloudflare"\\s*:\\s*(true|false)',
  ).firstMatch(objectBody);
  if (cf != null) out['hasCloudflare'] = cf.group(1)!;
  if (!out.containsKey('itemType')) {
    final itemIdx = RegExp(
      '"itemType"\\s*:\\s*([0-2])',
    ).firstMatch(objectBody);
    if (itemIdx != null) {
      out['itemType'] = const ['manga', 'anime', 'novel'][int.parse(
        itemIdx.group(1)!,
      )];
    }
  }
  return out;
}

int _findMatchingBrace(String s, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < s.length; i++) {
    final c = s[i];
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
