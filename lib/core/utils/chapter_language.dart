import '../models/manga_chapter.dart';

/// Detects a reading-language tag on a chapter and keeps next/prev navigation
/// on that language when a series publishes parallel translations.
class ChapterLanguage {
  ChapterLanguage._();

  /// Canonical language codes keyed by lowercase alias (name or short code).
  /// Longer aliases are matched first so "spanish" wins over "es" inside noise.
  static final Map<String, String> _aliases = () {
    const pairs = <String, String>{
      'english': 'en',
      'eng': 'en',
      'en': 'en',
      'en-us': 'en',
      'en-gb': 'en',
      'spanish': 'es',
      'español': 'es',
      'espanol': 'es',
      'spa': 'es',
      'es': 'es',
      'es-la': 'es',
      'es-419': 'es',
      'castellano': 'es',
      'french': 'fr',
      'français': 'fr',
      'francais': 'fr',
      'fre': 'fr',
      'fr': 'fr',
      'portuguese': 'pt',
      'português': 'pt',
      'portugues': 'pt',
      'por': 'pt',
      'pt': 'pt',
      'pt-br': 'pt',
      'brazilian': 'pt',
      'italian': 'it',
      'italiano': 'it',
      'ita': 'it',
      'it': 'it',
      'german': 'de',
      'deutsch': 'de',
      'ger': 'de',
      'de': 'de',
      'russian': 'ru',
      'русский': 'ru',
      'rus': 'ru',
      'ru': 'ru',
      'japanese': 'ja',
      '日本語': 'ja',
      'jap': 'ja',
      'jp': 'ja',
      'ja': 'ja',
      'korean': 'ko',
      '한국어': 'ko',
      'kor': 'ko',
      'ko': 'ko',
      'chinese': 'zh',
      '中文': 'zh',
      'zh': 'zh',
      'zh-cn': 'zh',
      'zh-tw': 'zh',
      'zh-hk': 'zh',
      'arabic': 'ar',
      'العربية': 'ar',
      'ara': 'ar',
      'ar': 'ar',
      'turkish': 'tr',
      'türkçe': 'tr',
      'turkce': 'tr',
      'tur': 'tr',
      'tr': 'tr',
      'polish': 'pl',
      'polski': 'pl',
      'pol': 'pl',
      'pl': 'pl',
      'dutch': 'nl',
      'nederlands': 'nl',
      'nl': 'nl',
      'indonesian': 'id',
      'indonesia': 'id',
      'ind': 'id',
      'id': 'id',
      'vietnamese': 'vi',
      'tiếng việt': 'vi',
      'tieng viet': 'vi',
      'vie': 'vi',
      'vi': 'vi',
      'thai': 'th',
      'ไทย': 'th',
      'th': 'th',
      'hindi': 'hi',
      'हिन्दी': 'hi',
      'hi': 'hi',
    };
    final entries = pairs.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    return {for (final e in entries) e.key: e.value};
  }();

  /// Bracket / paren code: `[EN]`, `(es)`, `{fr}`.
  static final _bracketLang = RegExp(
    r'[\[\(\{]\s*([a-z]{2,3}(?:-[a-z0-9]+)?)\s*[\]\)\}]',
    caseSensitive: false,
  );

  /// Trailing / separated short code: `- EN`, `/es`, `_fr`, `| pt-br`.
  static final _sepLang = RegExp(
    r'(?:^|[\s\-–—_/|:])([a-z]{2,3}(?:-[a-z0-9]+)?)(?:\s*$|(?=[]\s\-–—_/|:]))',
    caseSensitive: false,
  );

  /// Canonical language for [chapter], or null when none is detectable.
  static String? detect(MangaChapter chapter) {
    final fromScanlator = detectInText(chapter.scanlator);
    if (fromScanlator != null) return fromScanlator;
    return detectInText(chapter.name);
  }

  /// Canonical language code found in free text, or null.
  static String? detectInText(String? text) {
    if (text == null) return null;
    final raw = text.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();

    // Full language names (longest first).
    for (final e in _aliases.entries) {
      if (e.key.length < 3) continue; // skip short codes here
      final re = RegExp(
        r'(?:^|[^\w])' + RegExp.escape(e.key) + r'(?:$|[^\w])',
        caseSensitive: false,
      );
      if (re.hasMatch(lower)) return e.value;
    }

    final bracket = _bracketLang.firstMatch(lower);
    if (bracket != null) {
      final code = _aliases[bracket.group(1)!.toLowerCase()];
      if (code != null) return code;
    }

    // Prefer a trailing separator match so "Chapter 10" does not yield "ch".
    final seps = _sepLang.allMatches(lower).toList();
    for (final m in seps.reversed) {
      final token = m.group(1)!.toLowerCase();
      final code = _aliases[token];
      if (code != null) return code;
    }
    return null;
  }

  /// Next chapter in [readingOrder] after [current], staying on the same
  /// language when [current] has a detectable language tag.
  static MangaChapter? next(
    List<MangaChapter> readingOrder,
    MangaChapter current,
  ) {
    return _step(readingOrder, current, forward: true);
  }

  /// Previous chapter in [readingOrder] before [current], same-language aware.
  static MangaChapter? previous(
    List<MangaChapter> readingOrder,
    MangaChapter current,
  ) {
    return _step(readingOrder, current, forward: false);
  }

  static MangaChapter? _step(
    List<MangaChapter> readingOrder,
    MangaChapter current, {
    required bool forward,
  }) {
    final i = readingOrder.indexWhere((c) => c.url == current.url);
    if (i < 0) return null;

    final lang = detect(current);
    if (lang == null) {
      final j = forward ? i + 1 : i - 1;
      if (j < 0 || j >= readingOrder.length) return null;
      return readingOrder[j];
    }

    if (forward) {
      for (var j = i + 1; j < readingOrder.length; j++) {
        if (_compatible(lang, readingOrder[j])) return readingOrder[j];
      }
    } else {
      for (var j = i - 1; j >= 0; j--) {
        if (_compatible(lang, readingOrder[j])) return readingOrder[j];
      }
    }
    return null;
  }

  /// Same language, or no language tag (unlabeled chapters stay in the path).
  static bool _compatible(String currentLang, MangaChapter other) {
    final otherLang = detect(other);
    return otherLang == null || otherLang == currentLang;
  }
}
