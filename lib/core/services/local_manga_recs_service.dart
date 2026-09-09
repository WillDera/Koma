import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';

class BecauseYouReadRec {
  const BecauseYouReadRec({
    required this.seed,
    required this.suggestions,
  });

  final Manga seed;
  final List<Manga> suggestions;
}

/// Local “because you read X” suggestions from shared genres / authors.
class LocalMangaRecsService {
  LocalMangaRecsService(this._repos);

  final Repositories _repos;

  Future<BecauseYouReadRec?> load({int limit = 12}) async {
    final library = await _repos.manga.getMangasInLibrary();
    if (library.length < 2) return null;

    Manga? seed;
    DateTime? seedReadAt;
    for (final manga in library) {
      final chapters = await _repos.manga.getMangaChapters(manga.id);
      final latest = _latestReadAt(chapters);
      if (latest == null) continue;
      if (seedReadAt == null || latest.isAfter(seedReadAt)) {
        seed = manga;
        seedReadAt = latest;
      }
    }
    seed ??= library.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );

    final seedGenres = seed.genres
        .map((g) => g.trim().toLowerCase())
        .where((g) => g.isNotEmpty)
        .toSet();
    final seedAuthor = (seed.author ?? '').trim().toLowerCase();

    final scored = <({Manga manga, int score})>[];
    for (final manga in library) {
      if (manga.id == seed.id) continue;
      var score = 0;
      final genres = manga.genres
          .map((g) => g.trim().toLowerCase())
          .where((g) => g.isNotEmpty)
          .toSet();
      score += genres.intersection(seedGenres).length * 3;
      final author = (manga.author ?? '').trim().toLowerCase();
      if (seedAuthor.isNotEmpty && author == seedAuthor) score += 4;
      if (manga.sourceId == seed.sourceId) score += 1;
      // Prefer titles with unread / unopened chapters.
      final chapters = await _repos.manga.getMangaChapters(manga.id);
      final hasUnread = chapters.any((c) => !c.isRead);
      if (hasUnread) score += 2;
      if (score > 0) scored.add((manga: manga, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final suggestions = scored.take(limit).map((e) => e.manga).toList();
    if (suggestions.isEmpty) return null;
    return BecauseYouReadRec(seed: seed, suggestions: suggestions);
  }

  static DateTime? _latestReadAt(List<MangaChapter> chapters) {
    DateTime? latest;
    for (final c in chapters) {
      final at = c.readAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }
}
