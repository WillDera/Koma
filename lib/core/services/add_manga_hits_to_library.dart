import 'dart:async';

import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';
import '../../eval/dispatch_service.dart';
import '../../features/extensions/catalog_multi_select.dart';
import 'extension_source_resolve.dart';

class AddMangaHitsResult {
  const AddMangaHitsResult({
    required this.added,
    required this.alreadyInLibrary,
    required this.failed,
    this.timedOut = 0,
  });

  final int added;
  final int alreadyInLibrary;
  final int failed;

  /// Skipped because detail/chapters fetch exceeded [_detailTimeout].
  final int timedOut;
}

enum _HitOutcome { added, already, failed, timedOut }

/// Batch-add catalogue hits to the library (fetch detail + chapters when possible).
class AddMangaHitsToLibrary {
  AddMangaHitsToLibrary(this._repos, this._dispatch);

  final Repositories _repos;
  final ExtensionDispatchService _dispatch;

  /// Skip a title if its detail fetch takes longer than this.
  static const detailTimeout = Duration(seconds: 10);

  /// Bounded parallelism (same idea as global search).
  static const _concurrency = 5;

  Future<AddMangaHitsResult> call(List<CatalogHit> hits) async {
    if (hits.isEmpty) {
      return const AddMangaHitsResult(
        added: 0,
        alreadyInLibrary: 0,
        failed: 0,
      );
    }

    var next = 0;
    final outcomes = List<_HitOutcome?>.filled(hits.length, null);

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= hits.length) return;
        outcomes[i] = await _addOne(hits[i]);
      }
    }

    final n = _concurrency.clamp(1, hits.length);
    await Future.wait(List.generate(n, (_) => worker()));

    var added = 0;
    var already = 0;
    var failed = 0;
    var timedOut = 0;
    for (final o in outcomes) {
      switch (o) {
        case _HitOutcome.added:
          added++;
        case _HitOutcome.already:
          already++;
        case _HitOutcome.timedOut:
          timedOut++;
        case _HitOutcome.failed:
        case null:
          failed++;
      }
    }

    return AddMangaHitsResult(
      added: added,
      alreadyInLibrary: already,
      failed: failed,
      timedOut: timedOut,
    );
  }

  Future<_HitOutcome> _addOne(CatalogHit hit) async {
    if (hit.url.isEmpty) return _HitOutcome.failed;
    try {
      final existing =
          await _repos.manga.getMangaByKey(hit.sourceId, hit.url);
      if (existing != null && existing.inLibrary) {
        return _HitOutcome.already;
      }

      final source = await resolveExtensionMSource(
        _repos,
        hit.sourceId,
        name: hit.title,
      );
      final detail = await _dispatch.getMangaDetail(
        source,
        hit.url,
        memo: hit.memo,
        title: hit.title,
        timeout: detailTimeout,
      );

      final d = detail.manga;
      final name =
          (d != null && d.title.trim().isNotEmpty) ? d.title : hit.title;
      final imageUrl = d?.thumbnailUrl ?? hit.imageUrl;
      final author = d?.author ?? hit.author;
      final memo = d?.memo ?? hit.memo;

      late final int mangaId;
      if (existing != null) {
        mangaId = existing.id;
        await _repos.manga.updateManga(
          existing.copyWith(
            name: name,
            imageUrl: imageUrl,
            author: author,
            artist: d?.artist ?? existing.artist,
            description: d?.description ?? existing.description,
            status: d?.status ?? existing.status,
            genres:
                d != null && d.genres.isNotEmpty ? d.genres : existing.genres,
            inLibrary: true,
            memo: memo,
          ),
        );
        await _repos.manga.setMangaInLibrary(mangaId, true);
      } else {
        mangaId = await _repos.manga.insertManga(
          Manga(
            id: 0,
            name: name,
            url: hit.url,
            imageUrl: imageUrl,
            author: author,
            artist: d?.artist,
            description: d?.description,
            status: d?.status ?? 0,
            genres: d?.genres ?? const [],
            sourceId: hit.sourceId,
            inLibrary: true,
            memo: memo,
          ),
        );
      }

      final chapters = detail.chapters;
      if (chapters.isNotEmpty) {
        await _repos.manga.deleteMangaChapters(mangaId);
        final models = <MangaChapter>[];
        for (var i = 0; i < chapters.length; i++) {
          final ch = chapters[i];
          final url = ch.url.trim();
          if (url.isEmpty) continue;
          models.add(
            MangaChapter.withRecognition(
              id: 0,
              mangaId: mangaId,
              mangaTitle: name,
              name: ch.name,
              url: url,
              scanlator: ch.scanlator,
              dateUpload: ch.dateUpload,
              index: i,
              sourceChapterNumber: ch.chapterNumber,
              memo: ch.memo,
            ),
          );
        }
        if (models.isNotEmpty) {
          await _repos.manga.insertMangaChapters(mangaId, models);
        }
      }
      return _HitOutcome.added;
    } on TimeoutException {
      return _HitOutcome.timedOut;
    } catch (_) {
      return _HitOutcome.failed;
    }
  }
}
