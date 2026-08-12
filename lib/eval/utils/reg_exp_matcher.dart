/// Mangayomi-faithful HTML attribute extractors used by JS Element getters
/// (`getSrc`, `getImg`, `getHref`, `getDataSrc`).
String regHrefMatcher(String input) {
  final matches = RegExp(r'href="([^"]+)"').allMatches(input);
  if (matches.isEmpty) return '';
  return matches.first.group(1) ?? '';
}

String regDataSrcMatcher(String input) {
  final matches = RegExp(r'data-src="([^"]+)"').allMatches(input);
  if (matches.isEmpty) return '';
  return matches.first.group(1) ?? '';
}

String regSrcMatcher(String input) {
  final matches = RegExp(r'src="([^"]+)"').allMatches(input);
  if (matches.isEmpty) return '';
  return matches.first.group(1) ?? '';
}

String regImgMatcher(String input) {
  final matches = RegExp(r'img="([^"]+)"').allMatches(input);
  if (matches.isEmpty) return '';
  return matches.first.group(1) ?? '';
}

String regCustomMatcher(String input, String source, int group) {
  try {
    final matches = RegExp(source).allMatches(input);
    return matches.first.group(group)!;
  } catch (_) {
    return input;
  }
}
