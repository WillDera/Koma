import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

final downloadedChapterIdsProvider =
    StreamProvider.family<Set<int>, int>((ref, mangaId) {
  final mangaRepo = ref.watch(repositoriesProvider).manga;
  return mangaRepo
      .watchMangaChapters(mangaId)
      .map((chapters) =>
          chapters.where((c) => c.isDownloaded).map((c) => c.id).toSet());
});
