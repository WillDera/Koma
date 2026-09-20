import 'package:flutter/foundation.dart';

import 'merge_manga_use_case.dart';

/// Cross-source (or same-source re-add) duplicate detection for library titles.
class LibraryDuplicateDetector {
  LibraryDuplicateDetector._();

  /// Lowercase, strip punctuation / brackets, collapse spaces, strip trailing
  /// volume/chapter noise.
  static String normTitle(String s) {
    var t = s.trim().toLowerCase();
    // Drop bracketed / parenthetical noise: (Official), [Color], etc.
    t = t.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');
    t = t
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    t = t
        .replaceFirst(
          RegExp(r'\s+(?:vol|volume|ch|chapter|v|part|pt)\s*\d+\s*$'),
          '',
        )
        .trim();
    return t;
  }

  /// Title-only key (author is ignored — catalogue copies rarely match).
  static String fingerprint(String title, [String? author]) => normTitle(title);

  /// True when [a] and [b] look like the same series on different library rows.
  static bool isLikelyDuplicate(
    LibraryDuplicateCandidate a,
    LibraryDuplicateCandidate b,
  ) {
    if (a.id == b.id) return false;
    // Identical catalogue row.
    if (a.sourceId == b.sourceId && a.url == b.url) return false;
    return titlesMatch(a, b);
  }

  /// Title match using primary name + alternate titles.
  ///
  /// Requires a full case-insensitive match (after light normalize). Shared
  /// tokens alone are not enough.
  static bool titlesMatch(
    LibraryDuplicateCandidate a,
    LibraryDuplicateCandidate b,
  ) {
    final aTitles = a.allTitles;
    final bTitles = b.allTitles;
    for (final at in aTitles) {
      for (final bt in bTitles) {
        if (MergeMangaUseCase.titlesLookCompatible(at, bt)) return true;
        final na = normTitle(at);
        final nb = normTitle(bt);
        if (na.isEmpty || nb.isEmpty) continue;
        if (na == nb) return true;
      }
    }
    return false;
  }

  /// Groups of 2+ likely-duplicate library rows.
  static List<LibraryDuplicateGroup> findGroups(
    List<LibraryDuplicateCandidate> items,
  ) {
    if (items.length < 2) return const [];

    final parent = List<int>.generate(items.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        if (isLikelyDuplicate(items[i], items[j])) union(i, j);
      }
    }

    final buckets = <int, List<LibraryDuplicateCandidate>>{};
    for (var i = 0; i < items.length; i++) {
      (buckets[find(i)] ??= []).add(items[i]);
    }

    final groups = <LibraryDuplicateGroup>[];
    for (final list in buckets.values) {
      if (list.length < 2) continue;
      // Prefer groups that span sources; still allow same-source re-adds
      // (different urls) so library doubles surface a hint.
      final fp = fingerprint(list.first.name);
      if (fp.isEmpty) continue;
      groups.add(LibraryDuplicateGroup(
        fingerprint: fp,
        items: List.unmodifiable(list),
      ));
    }
    return groups;
  }
}

class LibraryDuplicateCandidate {
  const LibraryDuplicateCandidate({
    required this.id,
    required this.name,
    this.author,
    required this.sourceId,
    this.url = '',
    this.alternateTitles = const [],
  });

  final int id;
  final String name;
  final String? author;
  final String sourceId;
  final String url;
  final List<String> alternateTitles;

  List<String> get allTitles => [
        name,
        ...alternateTitles.where((t) => t.trim().isNotEmpty),
      ];
}

class LibraryDuplicateGroup {
  const LibraryDuplicateGroup({
    required this.fingerprint,
    required this.items,
  });

  final String fingerprint;
  final List<LibraryDuplicateCandidate> items;
}

/// Debug helper — never throws.
void debugLogLibraryDuplicates(
  LibraryDuplicateCandidate keep,
  List<LibraryDuplicateCandidate> library,
) {
  if (!kDebugMode) return;
  final hits = [
    for (final c in library)
      if (LibraryDuplicateDetector.isLikelyDuplicate(keep, c)) c,
  ];
  debugPrint(
    '[dup-hint] keep="${keep.name}" src=${keep.sourceId} '
    'library=${library.length} hits=${hits.length} '
    '${hits.map((h) => '${h.id}:${h.name}/${h.sourceId}').join(', ')}',
  );
}
