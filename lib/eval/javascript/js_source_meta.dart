/// Pull metadata fields from a mangayomi JS extension's `mangayomiSources`
/// header object (e.g. MangaDex `apiUrl`).
///
/// Installed sources historically only persisted [baseUrl] from the index;
/// many extensions still need [apiUrl] at runtime. Parsing the onboarded
/// script avoids an Isar schema bump and works for already-installed sources.
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
  ]) {
    final m = RegExp(
      '"$key"\\s*:\\s*"([^"]*)"',
    ).firstMatch(objectBody);
    if (m != null) out[key] = m.group(1)!;
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
