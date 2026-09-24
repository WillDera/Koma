const Set<String> kGenericGenreDenyList = {
  'fiction',
  'book',
  'books',
  'manga',
  'comic',
  'comics',
  'novel',
  'novels',
  'ebook',
  'ebooks',
  'literature',
  'general',
};

const Map<String, String> kGenreSynonyms = {
  'sci-fi': 'science fiction',
  'scifi': 'science fiction',
  'science-fiction': 'science fiction',
  'ya': 'young adult',
  'young-adult': 'young adult',
};

String normalizeGenre(String raw) {
  var g = raw.trim().toLowerCase();
  g = g.replaceAll(RegExp(r'\s+'), ' ');
  g = g.replaceAll('_', ' ');
  return kGenreSynonyms[g] ?? g;
}

List<String> normalizeGenres(Iterable<String> raw) {
  final out = <String>[];
  final seen = <String>{};
  for (final r in raw) {
    final g = normalizeGenre(r);
    if (g.isEmpty || seen.contains(g)) continue;
    seen.add(g);
    out.add(g);
  }
  return out;
}

bool isGenericGenre(String normalized) =>
    kGenericGenreDenyList.contains(normalized);
