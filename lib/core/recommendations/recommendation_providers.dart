import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recommendation_engine/recommendation_engine.dart';

import '../providers.dart';
import 'koma_catalog_source.dart';
import 'koma_metadata_enricher.dart';

/// Real engine when `pubspec_overrides.yaml` points at the private package;
/// stub otherwise (always empty results).
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  final repos = ref.watch(repositoriesProvider);
  return RecommendationService(
    KomaCatalogSource(
      repos,
      extensions: ref.watch(extensionManagerProvider),
      dispatch: ref.watch(extensionServiceProvider),
    ),
    enricher: KomaMetadataEnricher(),
  );
});

/// Stable family key (package [RecommendationSeed] has no == / hashCode).
class RecommendationSeedKey {
  const RecommendationSeedKey({
    required this.title,
    this.author,
    this.id,
    this.kind = RecommendationContentKind.ebook,
    this.progress,
    this.finished,
  });

  final String title;
  final String? author;
  final String? id;
  final RecommendationContentKind kind;
  final double? progress;
  final bool? finished;

  RecommendationSeed toSeed() => RecommendationSeed(
        title: title,
        author: author,
        kind: kind,
        id: id,
        signals: ReadingSignals(progress: progress, finished: finished),
      );

  @override
  bool operator ==(Object other) =>
      other is RecommendationSeedKey &&
      other.title == title &&
      other.author == author &&
      other.id == id &&
      other.kind == kind &&
      other.progress == progress &&
      other.finished == finished;

  @override
  int get hashCode => Object.hash(title, author, id, kind, progress, finished);
}

/// Library home: seed from in-progress / recent titles; include Discover hits.
final libraryRecommendationsProvider =
    FutureProvider.autoDispose<RecommendationResult>((ref) async {
  final engine = ref.watch(recommendationServiceProvider);
  final repos = ref.watch(repositoriesProvider);

  final seeds = <RecommendationSeed>[];

  final inProgressBooks = await repos.books.getInProgressBooks();
  for (final b in inProgressBooks.take(5)) {
    seeds.add(
      RecommendationSeed(
        title: b.title,
        author: b.author,
        kind: RecommendationContentKind.ebook,
        id: 'book:${b.id}',
        signals: ReadingSignals(
          progress: b.progress,
          finished: b.progress >= 0.98,
        ),
      ),
    );
  }

  final inProgressManga = await repos.manga.getInProgressManga();
  for (final row in inProgressManga.take(5)) {
    final m = row.manga;
    seeds.add(
      RecommendationSeed(
        title: m.name,
        author: m.author,
        kind: RecommendationContentKind.manga,
        id: 'manga:${m.id}',
        signals: ReadingSignals(
          progress: row.progress,
          finished: m.readingStatus == 2,
        ),
      ),
    );
  }

  if (seeds.isEmpty) {
    final books = await repos.books.getBooks();
    for (final b in books.take(3)) {
      seeds.add(
        RecommendationSeed(
          title: b.title,
          author: b.author,
          kind: RecommendationContentKind.ebook,
          id: 'book:${b.id}',
          signals: ReadingSignals(progress: b.progress),
        ),
      );
    }
    final mangas = await repos.manga.getMangasInLibrary();
    for (final m in mangas.take(3)) {
      seeds.add(
        RecommendationSeed(
          title: m.name,
          author: m.author,
          kind: RecommendationContentKind.manga,
          id: 'manga:${m.id}',
          signals: ReadingSignals(
            finished: m.readingStatus == 2,
          ),
        ),
      );
    }
  }

  if (seeds.isEmpty) return RecommendationResult.empty;

  return engine.recommend(
    RecommendationRequest(
      seeds: seeds,
      limit: 8,
      scope: RecommendationCandidateScope.libraryAndDiscover,
    ),
  );
});

/// Single-title “More like this” for book or manga detail.
final recommendationsForSeedProvider = FutureProvider.autoDispose
    .family<RecommendationResult, RecommendationSeedKey>((ref, key) async {
  final engine = ref.watch(recommendationServiceProvider);
  return engine.recommend(
    RecommendationRequest(
      seeds: [key.toSeed()],
      limit: 6,
      scope: RecommendationCandidateScope.libraryAndDiscover,
    ),
  );
});
