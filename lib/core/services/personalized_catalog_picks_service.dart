import '../repositories/repositories.dart';
import '../repositories/track_repository.dart';
import 'trackers/anilist.dart';
import 'trackers/base_tracker.dart';
import 'trackers/myanimelist.dart';

class PersonalizedCatalogPicks {
  const PersonalizedCatalogPicks({
    required this.sourceName,
    required this.syncId,
    required this.items,
    this.hasMore = false,
    this.nextPage = 2,
  });

  final String sourceName;
  final int syncId;
  final List<TrackSearchResult> items;
  final bool hasMore;

  /// Next API page cursor for [PersonalizedCatalogPicksService.loadMore].
  final int nextPage;

  PersonalizedCatalogPicks copyWith({
    List<TrackSearchResult>? items,
    bool? hasMore,
    int? nextPage,
  }) {
    return PersonalizedCatalogPicks(
      sourceName: sourceName,
      syncId: syncId,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
    );
  }
}

/// Tracker-backed catalog picks (AniList recommendation graph / MAL suggestions).
class PersonalizedCatalogPicksService {
  PersonalizedCatalogPicksService(this._repos);

  static const int defaultPageSize = 10;

  final Repositories _repos;

  Future<PersonalizedCatalogPicks?> load({
    int limit = defaultPageSize,
  }) async {
    final al = AnilistTracker(_repos);
    final mal = MyAnimeListTracker(_repos);

    if (await al.isLoggedIn()) {
      final page = await _collect(
        syncId: TrackIds.anilist,
        want: limit,
        startPage: 1,
        excludeMediaIds: <int>{},
        fetch: (page, perPage) =>
            al.recommendations(limit: perPage, page: page),
      );
      if (page.items.isNotEmpty) {
        return PersonalizedCatalogPicks(
          sourceName: al.name,
          syncId: TrackIds.anilist,
          items: page.items,
          hasMore: page.hasMore,
          nextPage: page.nextPage,
        );
      }
    }

    if (await mal.isLoggedIn()) {
      final page = await _collect(
        syncId: TrackIds.mal,
        want: limit,
        startPage: 1,
        excludeMediaIds: <int>{},
        fetch: (page, perPage) => mal.recommendations(
          limit: perPage,
          offset: (page - 1) * perPage,
        ),
      );
      if (page.items.isNotEmpty) {
        return PersonalizedCatalogPicks(
          sourceName: mal.name,
          syncId: TrackIds.mal,
          items: page.items,
          hasMore: page.hasMore,
          nextPage: page.nextPage,
        );
      }
    }

    return null;
  }

  Future<PersonalizedCatalogPicks> loadMore(
    PersonalizedCatalogPicks current, {
    int limit = defaultPageSize,
  }) async {
    if (!current.hasMore) return current;

    final exclude = {for (final i in current.items) i.mediaId};
    late final Future<TrackerRecPage> Function(int, int) fetch;
    late final String sourceName;

    if (current.syncId == TrackIds.anilist) {
      final al = AnilistTracker(_repos);
      sourceName = al.name;
      fetch =
          (page, perPage) => al.recommendations(limit: perPage, page: page);
    } else if (current.syncId == TrackIds.mal) {
      final mal = MyAnimeListTracker(_repos);
      sourceName = mal.name;
      fetch = (page, perPage) => mal.recommendations(
            limit: perPage,
            offset: (page - 1) * perPage,
          );
    } else {
      return current.copyWith(hasMore: false);
    }

    final page = await _collect(
      syncId: current.syncId,
      want: limit,
      startPage: current.nextPage,
      excludeMediaIds: exclude,
      fetch: fetch,
    );
    if (page.items.isEmpty) {
      return current.copyWith(hasMore: false, nextPage: page.nextPage);
    }
    return PersonalizedCatalogPicks(
      sourceName: sourceName,
      syncId: current.syncId,
      items: [...current.items, ...page.items],
      hasMore: page.hasMore,
      nextPage: page.nextPage,
    );
  }

  Future<({List<TrackSearchResult> items, bool hasMore, int nextPage})>
      _collect({
    required int syncId,
    required int want,
    required int startPage,
    required Set<int> excludeMediaIds,
    required Future<TrackerRecPage> Function(int page, int perPage) fetch,
  }) async {
    final tracked = await _trackedMediaIds(syncId);
    final exclude = {...excludeMediaIds, ...tracked};
    final out = <TrackSearchResult>[];
    var page = startPage;
    // AniList pages are anime-heavy; pull large raw pages and keep going
    // until we fill [want] or the API reports the end.
    const perPage = 50;
    var reachedEnd = false;

    for (var attempt = 0; attempt < 12 && out.length < want; attempt++) {
      final batch = await fetch(page, perPage);
      page++;
      if (batch.reachedEnd) reachedEnd = true;

      var added = 0;
      for (final item in batch.items) {
        if (!exclude.add(item.mediaId)) continue;
        out.add(item);
        added++;
        if (out.length >= want) break;
      }

      if (reachedEnd) break;
      // All duplicates after exclude — still advance while API has pages.
      if (added == 0 && batch.items.isEmpty && !reachedEnd) {
        // Mixed anime page with zero manga: keep paging.
        continue;
      }
    }

    final items = out.take(want).toList();
    return (
      items: items,
      hasMore: !reachedEnd && items.length >= want,
      nextPage: page,
    );
  }

  Future<Set<int>> _trackedMediaIds(int syncId) async {
    final mangas = await _repos.manga.getMangasInLibrary();
    final trackedIds = <int>{};
    for (final manga in mangas) {
      final track = await _repos.tracks.getTrack(manga.id, syncId);
      final mediaId = track?.mediaId;
      if (mediaId != null && mediaId > 0) trackedIds.add(mediaId);
    }
    return trackedIds;
  }
}
