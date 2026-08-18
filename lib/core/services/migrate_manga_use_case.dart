import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/manga_repository.dart';
import '../repositories/repositories.dart';
import '../utils/chapter_recognition.dart';
import '../../eval/dispatch_service.dart';
import 'extension_source_resolve.dart';
import 'keiyoushi_service.dart';

/// Mihon-shaped migration flags supported by Koma.
class MigrationFlags {
  const MigrationFlags({
    this.chapters = true,
    this.removeDownloads = true,
    this.categories = true,
    this.notes = true,
    this.customCover = true,
  });

  final bool chapters;
  final bool removeDownloads;
  final bool categories;
  final bool notes;
  final bool customCover;
}

/// Port of Mihon's [MigrateMangaUseCase] for the flags Koma supports today.
class MigrateMangaUseCase {
  MigrateMangaUseCase({
    required Repositories repositories,
    required this._dispatch,
    required this._keiyoushi,
  }) : _repos = repositories,
       _manga = repositories.manga;

  final Repositories _repos;
  final MangaRepository _manga;
  final ExtensionDispatchService _dispatch;
  final KeiyoushiService _keiyoushi;

  /// Migrates [current] library entry to a catalogue hit on another source.
  /// Returns the target manga row (now in library).
  Future<Manga> invoke({
    required Manga current,
    required String targetSourceId,
    required String targetUrl,
    String? targetTitle,
    String? targetMemo,
    required bool replace,
    MigrationFlags flags = const MigrationFlags(),
  }) async {
    if (targetSourceId == current.sourceId &&
        targetUrl.trim() == current.url.trim()) {
      throw StateError('Cannot migrate a title onto itself');
    }

    await _backfillChapterNumbers(current);

    final source = await resolveExtensionMSource(
      _repos,
      targetSourceId,
      name: targetTitle ?? current.name,
    );
    final detail = await _dispatch.getMangaDetail(
      source,
      targetUrl,
      memo: targetMemo,
      title: targetTitle ?? current.name,
    );

    final remote = detail.manga;
    final remoteTitle = (remote?.title.trim().isNotEmpty == true)
        ? remote!.title.trim()
        : (targetTitle?.trim().isNotEmpty == true
              ? targetTitle!.trim()
              : current.name);

    var target = await _manga.getMangaByKey(targetSourceId, targetUrl);
    if (target == null) {
      final id = await _manga.insertManga(
        Manga(
          id: 0,
          name: remoteTitle,
          url: targetUrl,
          imageUrl: remote?.thumbnailUrl,
          author: remote?.author,
          artist: remote?.artist,
          description: remote?.description,
          status: remote?.status ?? 0,
          genres: remote?.genres ?? const [],
          sourceId: targetSourceId,
          inLibrary: false,
          memo: (remote?.memo != null && remote!.memo!.isNotEmpty)
              ? remote.memo
              : targetMemo,
        ),
      );
      target = (await _manga.getMangaById(id))!;
    } else if (remote != null) {
      final remoteTitleNonEmpty = remote.title.trim();
      target = target.copyWith(
        name: remoteTitleNonEmpty.isNotEmpty ? remoteTitleNonEmpty : target.name,
        imageUrl: remote.thumbnailUrl ?? target.imageUrl,
        author: remote.author ?? target.author,
        artist: remote.artist ?? target.artist,
        description: remote.description ?? target.description,
        status: remote.status,
        genres: remote.genres.isNotEmpty ? remote.genres : target.genres,
        memo: (remote.memo != null && remote.memo!.isNotEmpty)
            ? remote.memo
            : (targetMemo ?? target.memo),
        updatedAt: DateTime.now(),
      );
      await _manga.updateManga(target);
    }

    final existingTargetChapters = await _manga.getMangaChapters(target.id);
    final existingByUrl = <String, MangaChapter>{
      for (final c in existingTargetChapters)
        if (c.url.isNotEmpty) c.url.trim(): c,
    };

    final networkChapters = detail.chapters;
    final merged = <MangaChapter>[];
    for (var i = 0; i < networkChapters.length; i++) {
      final ch = networkChapters[i];
      final url = ch.url.trim();
      if (url.isEmpty) continue;
      final recognized = ChapterRecognition.parseChapterNumber(
        remoteTitle,
        ch.name,
        ch.chapterNumber.toDouble(),
      );
      final existing = existingByUrl[url];
      if (existing != null) {
        merged.add(
          existing.copyWith(
            name: ch.name,
            scanlator: ch.scanlator ?? existing.scanlator,
            dateUpload: ch.dateUpload,
            index: i,
            chapterNumber: recognized,
            memo: ch.memo ?? existing.memo,
          ),
        );
      } else {
        merged.add(
          MangaChapter(
            id: 0,
            mangaId: target.id,
            name: ch.name,
            url: url,
            scanlator: ch.scanlator,
            dateUpload: ch.dateUpload,
            index: i,
            chapterNumber: recognized,
            memo: ch.memo,
          ),
        );
      }
    }

    if (merged.isNotEmpty) {
      await _manga.deleteMangaChapters(target.id);
      await _manga.insertMangaChapters(target.id, merged);
    }

    if (flags.chapters) {
      await _transferChapters(current: current, targetId: target.id);
    }

    await _transferExtras(
      current: current,
      targetId: target.id,
      flags: flags,
    );

    if (flags.removeDownloads) {
      await _removeDownloads(current);
    }

    if (replace) {
      await _manga.setMangaInLibrary(current.id, false);
    }
    await _manga.setMangaInLibrary(target.id, true);

    final refreshed = await _manga.getMangaById(target.id);
    return refreshed ?? target.copyWith(inLibrary: true);
  }

  Future<void> _transferExtras({
    required Manga current,
    required int targetId,
    required MigrationFlags flags,
  }) async {
    if (!flags.categories && !flags.notes && !flags.customCover) return;

    final target = await _manga.getMangaById(targetId);
    if (target == null) return;

    var categoryIds = target.categoryIds;
    var notes = target.notes;
    var customCoverPath = target.customCoverPath;

    if (flags.categories && current.categoryIds.isNotEmpty) {
      categoryIds = current.categoryIds;
    }
    if (flags.notes &&
        current.notes != null &&
        current.notes!.trim().isNotEmpty) {
      notes = current.notes;
    }
    if (flags.customCover && current.customCoverPath != null) {
      customCoverPath = await _copyCustomCover(
        current.customCoverPath!,
        targetId,
      );
    }

    await _manga.updateMangaExtras(
      targetId,
      categoryIds: categoryIds,
      notes: notes,
      customCoverPath: customCoverPath,
    );
  }

  Future<String?> _copyCustomCover(String fromPath, int targetMangaId) async {
    final src = File(fromPath);
    if (!await src.exists()) return null;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'manga_covers'));
    await dir.create(recursive: true);
    final ext = p.extension(fromPath);
    final dest = File(p.join(dir.path, '$targetMangaId${ext.isEmpty ? '.jpg' : ext}'));
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> _backfillChapterNumbers(Manga manga) async {
    final chapters = await _manga.getMangaChapters(manga.id);
    final updated = <MangaChapter>[];
    for (final c in chapters) {
      if (c.isRecognizedNumber) continue;
      final n = ChapterRecognition.parseChapterNumber(manga.name, c.name);
      if (n == c.chapterNumber) continue;
      updated.add(c.copyWith(chapterNumber: n));
    }
    if (updated.isNotEmpty) {
      await _manga.insertMangaChapters(manga.id, updated);
    }
  }

  Future<void> _transferChapters({
    required Manga current,
    required int targetId,
  }) async {
    final prev = await _manga.getMangaChapters(current.id);
    final next = await _manga.getMangaChapters(targetId);

    double? maxChapterRead;
    for (final c in prev) {
      if (!c.isRead || !c.isRecognizedNumber) continue;
      if (maxChapterRead == null || c.chapterNumber > maxChapterRead) {
        maxChapterRead = c.chapterNumber;
      }
    }

    final updates = <MangaChapter>[];
    for (var mangaChapter in next) {
      if (!mangaChapter.isRecognizedNumber) {
        updates.add(mangaChapter);
        continue;
      }

      MangaChapter? prevChapter;
      for (final c in prev) {
        if (c.isRecognizedNumber &&
            c.chapterNumber == mangaChapter.chapterNumber) {
          prevChapter = c;
          break;
        }
      }

      if (prevChapter != null) {
        mangaChapter = mangaChapter.copyWith(
          isBookmarked: prevChapter.isBookmarked,
          lastPageRead: prevChapter.lastPageRead,
          scrollPosition: prevChapter.scrollPosition,
          isOpened: prevChapter.isOpened || mangaChapter.isOpened,
          readAt: prevChapter.readAt ?? mangaChapter.readAt,
        );
      }

      if (maxChapterRead != null &&
          mangaChapter.chapterNumber <= maxChapterRead) {
        mangaChapter = mangaChapter.copyWith(
          isRead: true,
          readAt: mangaChapter.readAt ?? DateTime.now(),
        );
      }
      updates.add(mangaChapter);
    }

    if (updates.isNotEmpty) {
      await _manga.insertMangaChapters(targetId, updates);
    }
  }

  Future<void> _removeDownloads(Manga current) async {
    final chapters = await _manga.getMangaChapters(current.id);
    final urls = [
      for (final c in chapters)
        if (c.isDownloaded && c.url.isNotEmpty) c.url,
    ];
    if (urls.isEmpty) return;

    final ext = await findInstalledExtension(_repos, current.sourceId);
    if (ext == null || !ext.isJs) {
      try {
        await _keiyoushi.deleteChapters(
          sourceId: current.sourceId,
          mangaUrl: current.url,
          chapterUrls: urls,
        );
      } catch (_) {
        // Native delete can fail for missing dirs — still clear flags.
      }
    }

    final cleared = [
      for (final c in chapters)
        if (c.isDownloaded) c.copyWith(isDownloaded: false),
    ];
    if (cleared.isNotEmpty) {
      await _manga.insertMangaChapters(current.id, cleared);
    }
  }
}
