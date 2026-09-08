import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:koni_archive/io.dart';
import 'package:path/path.dart' as p;

import '../models/manga.dart';
import '../models/manga_chapter.dart';
import 'android_storage_access.dart';
import 'app_storage.dart';
import 'keiyoushi_service.dart';
import 'local_cbz_metadata.dart';
import 'local_cbz_source.dart';

class CbzExportResult {
  const CbzExportResult({
    required this.exported,
    required this.skipped,
    required this.failed,
  });

  final int exported;
  final int skipped;
  final int failed;
}

/// Zips on-disk manga chapter images into CBZ archives.
class CbzExportService {
  CbzExportService._();

  /// Export [chapters] for [manga] into `{dest}/{Series}/{Chapter}.cbz`.
  ///
  /// Local-source chapters whose URL already points at a CBZ are copied.
  /// Extension chapters are resolved from the JS support layout and/or Dalvik
  /// `filesDir` via [keiyoushi] (Mihon downloads).
  static Future<CbzExportResult> exportChapters({
    required Manga manga,
    required List<MangaChapter> chapters,
    required String destinationDir,
    KeiyoushiService? keiyoushi,
    Future<String> Function(String sourceId)? resolveSourceId,
  }) async {
    final seriesDir = Directory(
      p.join(destinationDir, _safeName(manga.name)),
    );
    if (!await seriesDir.exists()) {
      await seriesDir.create(recursive: true);
    }

    var exported = 0;
    var skipped = 0;
    var failed = 0;
    final used = <String>{};

    await for (final entity in seriesDir.list(followLinks: false)) {
      if (entity is File) {
        used.add(p.basename(entity.path).toLowerCase());
      }
    }

    // Optional cover + series metadata (series.json / ComicInfo.xml).
    // Export is a folder of chapter CBZs (Mihon-style), not one zip.
    final coverName = await LocalCbzMetadata.exportCover(
      seriesDir: seriesDir,
      imageUrl: manga.imageUrl ?? manga.customCoverPath,
    );
    if (coverName != null) used.add(coverName.toLowerCase());
    try {
      await LocalCbzMetadata.fromManga(
        manga,
        coverFileName: coverName,
      ).writeToDirectory(seriesDir);
      used.add(LocalCbzMetadata.seriesJsonName.toLowerCase());
      used.add(LocalCbzMetadata.comicInfoName.toLowerCase());
    } catch (_) {}

    // Legacy: also copy a local cover path if exportCover missed it.
    final cover = manga.imageUrl?.trim();
    if (coverName == null &&
        cover != null &&
        cover.isNotEmpty &&
        !cover.startsWith('http') &&
        await File(cover).exists()) {
      final legacyName = 'cover${p.extension(cover).toLowerCase()}';
      try {
        await _copyFile(cover, p.join(seriesDir.path, legacyName));
        used.add(legacyName.toLowerCase());
      } catch (_) {}
    }

    final sourceIds = <String>{manga.sourceId};
    if (resolveSourceId != null) {
      try {
        final resolved = await resolveSourceId(manga.sourceId);
        if (resolved.isNotEmpty) sourceIds.add(resolved);
      } catch (_) {}
    }

    for (final chapter in chapters) {
      try {
        final fileName = _uniqueName(
          preferred: '${_safeName(chapter.name)}.cbz',
          used: used,
        );
        used.add(fileName.toLowerCase());
        final outPath = p.join(seriesDir.path, fileName);

        if (LocalCbzSource.isLocal(manga.sourceId)) {
          if (LocalCbzSource.isArchivePath(chapter.url) &&
              await File(chapter.url).exists()) {
            await _copyFile(chapter.url, outPath);
            exported++;
            continue;
          }
          final entityType = await FileSystemEntity.type(chapter.url);
          if (entityType == FileSystemEntityType.directory) {
            final pages = await _listImageDir(chapter.url);
            if (pages.isEmpty) {
              skipped++;
              continue;
            }
            await _writeCbz(outPath, pages);
            exported++;
            continue;
          }
        }

        final pages = await listDownloadedPageFiles(
          sourceIds: sourceIds.toList(),
          mangaUrl: manga.url,
          chapterUrl: chapter.url,
          keiyoushi: keiyoushi,
        );
        if (pages.isEmpty) {
          skipped++;
          continue;
        }

        await _writeCbz(outPath, pages);
        exported++;
      } catch (_) {
        failed++;
      }
    }

    return CbzExportResult(
      exported: exported,
      skipped: skipped,
      failed: failed,
    );
  }

  /// Lists page image files for a downloaded chapter.
  ///
  /// Tries the JS/AppStorage layout first, then Dalvik [KeiyoushiService.getLocalPages]
  /// (filesDir). [sourceIds] should include both the stored id and any hex
  /// bridge resolution of it.
  static Future<List<String>> listDownloadedPageFiles({
    required List<String> sourceIds,
    required String mangaUrl,
    required String chapterUrl,
    KeiyoushiService? keiyoushi,
  }) async {
    final ids = sourceIds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];

    for (final sourceId in ids) {
      final fromSupport = await _listSupportPages(
        sourceId: sourceId,
        mangaUrl: mangaUrl,
        chapterUrl: chapterUrl,
      );
      if (fromSupport.isNotEmpty) return fromSupport;
    }

    if (keiyoushi != null) {
      for (final sourceId in ids) {
        try {
          final fromDalvik = await keiyoushi.getLocalPages(
            sourceId: sourceId,
            mangaUrl: mangaUrl,
            chapterUrl: chapterUrl,
          );
          final existing = <String>[];
          for (final raw in fromDalvik) {
            final path = _normalizeLocalPath(raw.trim());
            if (path.isEmpty) continue;
            if (await File(path).exists()) existing.add(path);
          }
          if (existing.isNotEmpty) return existing;
        } catch (_) {
          // Try next source id.
        }
      }
    }

    return const [];
  }

  static Future<List<String>> _listSupportPages({
    required String sourceId,
    required String mangaUrl,
    required String chapterUrl,
  }) async {
    final supportDir = await AppStorage.support();
    final mangaKey =
        sha256.convert(utf8.encode(mangaUrl)).toString().substring(0, 16);
    final chKey =
        sha256.convert(utf8.encode(chapterUrl)).toString().substring(0, 16);
    final dir = Directory(
      '${supportDir.path}/manga/$sourceId/$mangaKey/$chKey',
    );
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp')) {
        files.add(entity);
      }
    }
    files.sort((a, b) {
      int idx(File f) =>
          int.tryParse(p.basenameWithoutExtension(f.path)) ?? 1 << 30;
      return idx(a).compareTo(idx(b));
    });
    return [for (final f in files) f.path];
  }

  static String _normalizeLocalPath(String path) {
    if (path.startsWith('file:')) {
      try {
        return Uri.parse(path).toFilePath();
      } catch (_) {
        return path.replaceFirst(RegExp(r'^file://'), '');
      }
    }
    return path;
  }

  static Future<List<String>> _listImageDir(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (LocalCbzSource.isImagePath(entity.path) &&
          !LocalCbzSource.coverNames.contains(
            p.basename(entity.path).toLowerCase(),
          )) {
        files.add(entity);
      }
    }
    files.sort(
      (a, b) => p.basename(a.path).toLowerCase().compareTo(
            p.basename(b.path).toLowerCase(),
          ),
    );
    return [for (final f in files) f.path];
  }

  static Future<void> _writeCbz(String outPath, List<String> pagePaths) async {
    final needsShared = AndroidStorageAccess.needsAllFilesAccess(outPath);
    final writePath = needsShared
        ? p.join(
            (await AppStorage.cache()).path,
            'cbz_export_${DateTime.now().microsecondsSinceEpoch}.cbz',
          )
        : '$outPath.partial';

    final writer = await createArchiveFile(
      writePath,
      format: const ZipWriteFormat(),
    );
    try {
      for (var i = 0; i < pagePaths.length; i++) {
        final src = File(pagePaths[i]);
        final bytes = Uint8List.fromList(await src.readAsBytes());
        final ext = p.extension(src.path).toLowerCase();
        final safeExt = ext.isEmpty ? '.jpg' : ext;
        final name = '${(i + 1).toString().padLeft(4, '0')}$safeExt';
        await writer.addBytes(ArchiveEntrySpec(path: name), bytes);
      }
    } finally {
      await writer.close();
    }

    if (needsShared) {
      await AndroidStorageAccess.copyFile(writePath, outPath);
      await File(writePath).delete();
    } else {
      final out = File(outPath);
      if (await out.exists()) await out.delete();
      await File(writePath).rename(outPath);
    }
  }

  static Future<void> _copyFile(String from, String to) async {
    if (AndroidStorageAccess.needsAllFilesAccess(to) ||
        AndroidStorageAccess.needsAllFilesAccess(from)) {
      await AndroidStorageAccess.copyFile(from, to);
    } else {
      await File(from).copy(to);
    }
  }

  static String _safeName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'untitled';
    return cleaned.length > 120 ? cleaned.substring(0, 120).trim() : cleaned;
  }

  static String _uniqueName({
    required String preferred,
    required Set<String> used,
  }) {
    if (!used.contains(preferred.toLowerCase())) return preferred;
    final base = p.basenameWithoutExtension(preferred);
    final ext = p.extension(preferred);
    for (var i = 2; i < 1000; i++) {
      final candidate = '$base ($i)$ext';
      if (!used.contains(candidate.toLowerCase())) return candidate;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}$ext';
  }
}
