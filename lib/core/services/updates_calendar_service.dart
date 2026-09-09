import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';
import '../utils/fetch_interval.dart';

class UpcomingRelease {
  const UpcomingRelease({
    required this.manga,
    required this.expectedDate,
    required this.intervalDays,
  });

  final Manga manga;
  final DateTime expectedDate;
  final int intervalDays;
}

/// Builds Mangayomi-style upcoming release dates from local chapter cadence.
class UpdatesCalendarService {
  UpdatesCalendarService(this._repos);

  final Repositories _repos;

  Future<List<UpcomingRelease>> loadUpcoming({DateTime? now}) async {
    final library = await _repos.manga.getMangasInLibrary();
    final results = <UpcomingRelease>[];

    for (final manga in library) {
      // Skip fully completed titles (Mihon status 2 = completed).
      if (manga.status == 2) continue;

      final chapters = await _repos.manga.getMangaChapters(manga.id);
      if (chapters.isEmpty) continue;

      final interval = FetchInterval.calculateInterval(chapters);
      final lastUpload = _latestMs(chapters, (c) => c.dateUpload);
      final lastFetch = _latestMs(chapters, (c) => c.dateFetch);
      final expected = FetchInterval.computeExpectedDate(
        lastChapterDateMs: lastUpload,
        lastUpdateMs: lastFetch > 0
            ? lastFetch
            : manga.updatedAt.millisecondsSinceEpoch,
        interval: interval,
        now: now,
      );
      if (expected == null) continue;

      results.add(
        UpcomingRelease(
          manga: manga,
          expectedDate: DateTime(
            expected.year,
            expected.month,
            expected.day,
          ),
          intervalDays: interval,
        ),
      );
    }

    results.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    return results;
  }

  static int _latestMs(
    List<MangaChapter> chapters,
    int Function(MangaChapter) pick,
  ) {
    var max = 0;
    for (final c in chapters) {
      final v = pick(c);
      if (v > max) max = v;
    }
    return max;
  }
}
