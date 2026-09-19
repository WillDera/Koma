import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/migrate_suggestion_service.dart';

final migrateSuggestionServiceProvider = Provider<MigrateSuggestionService>((
  ref,
) {
  return MigrateSuggestionService(
    repositories: ref.watch(repositoriesProvider),
    dispatch: ref.watch(extensionServiceProvider),
  );
});

/// Best-effort "more chapters elsewhere" hint for a library manga id.
///
/// Pass a bump via [MigrateSuggestionQuery.force] / invalidate to rescan.
final migrateSuggestionProvider = FutureProvider.autoDispose
    .family<MigrateSuggestion?, MigrateSuggestionQuery>((ref, query) async {
      final repos = ref.watch(repositoriesProvider);
      final manga = await repos.manga.getMangaById(query.mangaId);
      if (manga == null || !manga.inLibrary) return null;
      final service = ref.watch(migrateSuggestionServiceProvider);
      return service.findBetterSource(manga, force: query.force);
    });

class MigrateSuggestionQuery {
  const MigrateSuggestionQuery(this.mangaId, {this.force = false});

  final int mangaId;
  final bool force;

  @override
  bool operator ==(Object other) =>
      other is MigrateSuggestionQuery &&
      other.mangaId == mangaId &&
      other.force == force;

  @override
  int get hashCode => Object.hash(mangaId, force);
}
