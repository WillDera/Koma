/// Port of Mihon's [ChapterRecognition.parseChapterNumber].
///
/// Used when persisting [MangaChapter.chapterNumber] and for migrate matching.
class ChapterRecognition {
  ChapterRecognition._();

  static final _number = RegExp(r'([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?');
  static final _basic = RegExp(r'(?<=ch\.) *([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?');
  static final _unwanted = RegExp(
    r'\b(?:v|ver|vol|version|volume|season|s)[^a-z]?[0-9]+',
  );
  static final _unwantedWhiteSpace = RegExp(r'\s(?=extra|special|omake)');

  /// Returns a recognized chapter number, or `-1` when unknown.
  /// Source-provided values of `-2` or `> -1` are trusted as-is (Mihon).
  static double parseChapterNumber(
    String mangaTitle,
    String chapterName, [
    double? chapterNumber,
  ]) {
    if (chapterNumber != null &&
        (chapterNumber == -2.0 || chapterNumber > -1.0)) {
      return chapterNumber;
    }

    var clean = chapterName.toLowerCase();
    final title = mangaTitle.toLowerCase().trim();
    if (title.isNotEmpty) {
      clean = clean.replaceAll(title, '').trim();
    }
    clean = clean
        .replaceAll(',', '.')
        .replaceAll('-', '.')
        .replaceAll(_unwantedWhiteSpace, '');

    final matches = _number.allMatches(clean).toList();
    if (matches.isEmpty) return chapterNumber ?? -1.0;

    if (matches.length > 1) {
      final stripped = clean.replaceAll(_unwanted, '');
      final basicMatch = _basic.firstMatch(stripped);
      if (basicMatch != null) return _fromMatch(basicMatch);
      final fallback = _number.firstMatch(stripped);
      if (fallback != null) return _fromMatch(fallback);
    }

    return _fromMatch(matches.first);
  }

  static bool isRecognized(double chapterNumber) => chapterNumber >= 0;

  static double _fromMatch(RegExpMatch match) {
    final initial = double.parse(match.group(1)!);
    return initial + _decimal(match.group(2), match.group(3));
  }

  static double _decimal(String? decimal, String? alpha) {
    if (decimal != null && decimal.isNotEmpty) {
      return double.parse(decimal);
    }
    if (alpha == null || alpha.isEmpty) return 0.0;
    if (alpha.contains('extra')) return 0.99;
    if (alpha.contains('omake')) return 0.98;
    if (alpha.contains('special')) return 0.97;
    final trimmed = alpha.startsWith('.') ? alpha.substring(1) : alpha;
    if (trimmed.length == 1) {
      final n = trimmed.codeUnitAt(0) - ('a'.codeUnitAt(0) - 1);
      if (n >= 10) return 0.0;
      return n / 10.0;
    }
    return 0.0;
  }
}
