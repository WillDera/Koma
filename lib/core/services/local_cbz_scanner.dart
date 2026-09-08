import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/manga.dart';
import '../models/manga_chapter.dart';
import '../repositories/repositories.dart';
import 'local_cbz_metadata.dart';
import 'local_cbz_prefs.dart';
import 'local_cbz_source.dart';

class LocalCbzScanResult {
  const LocalCbzScanResult({
    required this.seriesUpserted,
    required this.chaptersAdded,
    this.error,
  });

  final int seriesUpserted;
  final int chaptersAdded;
  final String? error;

  bool get ok => error == null;
}

/// Walks the user-chosen local manga folder and upserts library entries.
///
/// Expected layout (Mihon / Komga style — a **folder of CBZs**, not one zip):
/// ```text
/// {folder}/
///   Series Title/
///     series.json / ComicInfo.xml / cover.jpg   (optional)
///     Chapter 001.cbz
///     Chapter 002.cbz
///   Another Series/
///     ...
/// ```
///
/// If [folder] itself contains CBZ files (no series subfolders), those archives
/// become **chapters of one manga** named after the folder — not one manga each.
class LocalCbzScanner {
  LocalCbzScanner(this._repos);

  final Repositories _repos;

  Future<LocalCbzScanResult> scanConfiguredFolder({
    bool forceInLibrary = false,
  }) async {
    final root = await LocalCbzPrefs.folderPath();
    if (root == null) {
      return const LocalCbzScanResult(
        seriesUpserted: 0,
        chaptersAdded: 0,
        error: 'No local manga folder set',
      );
    }
    return scanFolder(root, forceInLibrary: forceInLibrary);
  }

  /// Walks [rootPath] and upserts series.
  ///
  /// When [forceInLibrary] is false (quiet library refresh), series the user
  /// deleted/removed are skipped and existing rows are not forced back into
  /// the library. Explicit imports should pass `forceInLibrary: true`.
  Future<LocalCbzScanResult> scanFolder(
    String rootPath, {
    bool forceInLibrary = false,
  }) async {
    final root = Directory(rootPath.trim());
    if (!await root.exists()) {
      return LocalCbzScanResult(
        seriesUpserted: 0,
        chaptersAdded: 0,
        error: 'Folder not found: ${root.path}',
      );
    }

    var seriesUpserted = 0;
    var chaptersAdded = 0;

    try {
      final entities = await root.list(followLinks: false).toList();
      final seriesDirs = <Directory>[];
      final looseArchives = <File>[];

      for (final entity in entities) {
        if (entity is Directory) {
          if (await _directoryLooksLikeSeries(entity)) {
            seriesDirs.add(entity);
          }
        } else if (entity is File && LocalCbzSource.isArchivePath(entity.path)) {
          looseArchives.add(entity);
        }
      }

      seriesDirs.sort(
        (a, b) => p.basename(a.path).toLowerCase().compareTo(
              p.basename(b.path).toLowerCase(),
            ),
      );
      looseArchives.sort(
        (a, b) => _naturalCompare(p.basename(a.path), p.basename(b.path)),
      );

      for (final dir in seriesDirs) {
        final r = await _upsertSeriesDirectory(
          dir,
          forceInLibrary: forceInLibrary,
        );
        seriesUpserted += r.seriesUpserted;
        chaptersAdded += r.chaptersAdded;
      }

      // Pack every loose CBZ at the scan root into ONE manga (folder name).
      if (looseArchives.isNotEmpty) {
        final r = await _upsertLooseArchivesAsSeries(
          root: root,
          archives: looseArchives,
          forceInLibrary: forceInLibrary,
        );
        seriesUpserted += r.seriesUpserted;
        chaptersAdded += r.chaptersAdded;
      }

      // Empty root that is itself an image folder → single-chapter series.
      if (seriesDirs.isEmpty &&
          looseArchives.isEmpty &&
          await _directoryHasImages(root)) {
        final r = await _upsertSeriesDirectory(
          root,
          forceInLibrary: forceInLibrary,
        );
        seriesUpserted += r.seriesUpserted;
        chaptersAdded += r.chaptersAdded;
      }

      return LocalCbzScanResult(
        seriesUpserted: seriesUpserted,
        chaptersAdded: chaptersAdded,
      );
    } catch (e) {
      return LocalCbzScanResult(
        seriesUpserted: seriesUpserted,
        chaptersAdded: chaptersAdded,
        error: '$e',
      );
    }
  }

  Future<bool> _directoryLooksLikeSeries(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && LocalCbzSource.isArchivePath(entity.path)) {
        return true;
      }
      if (entity is Directory && await _directoryHasImages(entity)) {
        return true;
      }
      if (entity is File && LocalCbzSource.isImagePath(entity.path)) {
        return true;
      }
      final name = p.basename(entity.path);
      if (name == LocalCbzMetadata.seriesJsonName ||
          name == LocalCbzMetadata.comicInfoName) {
        return true;
      }
    }
    return false;
  }

  Future<LocalCbzScanResult> _upsertLooseArchivesAsSeries({
    required Directory root,
    required List<File> archives,
    bool forceInLibrary = false,
  }) async {
    final meta = await LocalCbzMetadata.readFromDirectory(root);
    final title = meta?.title.trim().isNotEmpty == true
        ? meta!.title.trim()
        : p.basename(root.path);
    final cover = await _findCover(root) ??
        (meta?.coverFileName != null
            ? p.join(root.path, meta!.coverFileName!)
            : null);
    final coverPath = cover != null && await File(cover).exists()
        ? p.normalize(File(cover).absolute.path)
        : null;

    return _upsertSeries(
      title: title,
      seriesUrl: p.normalize(root.absolute.path),
      coverPath: coverPath,
      chapterPaths: [
        for (final f in archives) p.normalize(f.absolute.path),
      ],
      chapterNames: [
        for (final f in archives) p.basenameWithoutExtension(f.path),
      ],
      metadata: meta,
      forceInLibrary: forceInLibrary,
    );
  }

  Future<LocalCbzScanResult> _upsertSeriesDirectory(
    Directory dir, {
    bool forceInLibrary = false,
  }) async {
    final seriesUrl = p.normalize(dir.absolute.path);
    final meta = await LocalCbzMetadata.readFromDirectory(dir);
    final title = meta?.title.trim().isNotEmpty == true
        ? meta!.title.trim()
        : p.basename(dir.path);
    final cover = await _findCover(dir) ??
        (meta?.coverFileName != null
            ? p.join(dir.path, meta!.coverFileName!)
            : null);
    final coverPath = cover != null && await File(cover).exists()
        ? p.normalize(File(cover).absolute.path)
        : null;

    final chapterFiles = <File>[];
    final imageDirs = <Directory>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && LocalCbzSource.isArchivePath(entity.path)) {
        chapterFiles.add(entity);
      } else if (entity is Directory) {
        if (await _directoryHasImages(entity)) {
          imageDirs.add(entity);
        }
      }
    }

    chapterFiles.sort(
      (a, b) => _naturalCompare(p.basename(a.path), p.basename(b.path)),
    );
    imageDirs.sort(
      (a, b) => _naturalCompare(p.basename(a.path), p.basename(b.path)),
    );

    if (chapterFiles.isEmpty && imageDirs.isEmpty) {
      if (await _directoryHasImages(dir)) {
        return _upsertSeries(
          title: title,
          seriesUrl: seriesUrl,
          coverPath: coverPath,
          chapterPaths: [seriesUrl],
          chapterNames: [title],
          metadata: meta,
          forceInLibrary: forceInLibrary,
        );
      }
      return const LocalCbzScanResult(seriesUpserted: 0, chaptersAdded: 0);
    }

    return _upsertSeries(
      title: title,
      seriesUrl: seriesUrl,
      coverPath: coverPath,
      chapterPaths: [
        ...chapterFiles.map((f) => p.normalize(f.absolute.path)),
        ...imageDirs.map((d) => p.normalize(d.absolute.path)),
      ],
      chapterNames: [
        ...chapterFiles.map((f) => p.basenameWithoutExtension(f.path)),
        ...imageDirs.map((d) => p.basename(d.path)),
      ],
      metadata: meta,
      forceInLibrary: forceInLibrary,
    );
  }

  Future<LocalCbzScanResult> _upsertSeries({
    required String title,
    required String seriesUrl,
    required String? coverPath,
    required List<String> chapterPaths,
    required List<String> chapterNames,
    LocalCbzMetadata? metadata,
    bool forceInLibrary = false,
  }) async {
    final normalizedUrl = LocalCbzPrefs.normalizeSeriesUrl(seriesUrl);
    if (!forceInLibrary && await LocalCbzPrefs.isSeriesExcluded(normalizedUrl)) {
      return const LocalCbzScanResult(seriesUpserted: 0, chaptersAdded: 0);
    }
    if (forceInLibrary) {
      await LocalCbzPrefs.includeSeriesUrl(normalizedUrl);
    }

    final existing = await _repos.manga.getMangaByKey(
      LocalCbzSource.sourceId,
      normalizedUrl,
    );

    final author = metadata?.author;
    final artist = metadata?.artist;
    final description = metadata?.description;
    final status = metadata?.status ?? 0;
    final genres = metadata?.genres ?? const <String>[];

    late final int mangaId;
    if (existing == null) {
      mangaId = await _repos.manga.insertManga(
        Manga(
          id: 0,
          name: title,
          url: normalizedUrl,
          imageUrl: coverPath,
          author: author,
          artist: artist,
          description: description,
          status: status,
          genres: genres,
          sourceId: LocalCbzSource.sourceId,
          inLibrary: true,
        ),
      );
    } else {
      mangaId = existing.id;
      // Quiet rescans must not undo a user "remove from library". Explicit
      // imports pass [forceInLibrary] to put the series back.
      if (forceInLibrary && !existing.inLibrary) {
        await _repos.manga.setMangaInLibrary(mangaId, true);
      }
      await _repos.manga.updateManga(
        existing.copyWith(
          name: title,
          imageUrl: coverPath ?? existing.imageUrl,
          author: author ?? existing.author,
          artist: artist ?? existing.artist,
          description: (description != null && description.isNotEmpty)
              ? description
              : existing.description,
          status: metadata != null ? status : existing.status,
          genres: genres.isNotEmpty ? genres : existing.genres,
        ),
      );
    }

    final incoming = <MangaChapter>[
      for (var i = 0; i < chapterPaths.length; i++)
        MangaChapter.withRecognition(
          id: 0,
          mangaId: mangaId,
          mangaTitle: title,
          name: chapterNames[i],
          url: chapterPaths[i],
          index: i,
          isDownloaded: true,
          dateFetch: DateTime.now().millisecondsSinceEpoch,
        ),
    ];

    final fresh = await _repos.manga.mergeNewChapters(mangaId, incoming);

    for (final path in chapterPaths) {
      final ch = await _repos.manga.getMangaChapterByUrl(mangaId, path);
      if (ch != null && !ch.isDownloaded) {
        await _repos.manga.markMangaChapterDownloaded(ch.id, true);
      }
    }

    return LocalCbzScanResult(
      seriesUpserted: 1,
      chaptersAdded: fresh.length,
    );
  }

  Future<String?> _findCover(Directory dir) async {
    for (final name in LocalCbzSource.coverNames) {
      final f = File(p.join(dir.path, name));
      if (await f.exists()) return p.normalize(f.absolute.path);
    }
    final images = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && LocalCbzSource.isImagePath(entity.path)) {
        images.add(entity);
      }
    }
    if (images.isEmpty) return null;
    images.sort(
      (a, b) => p.basename(a.path).toLowerCase().compareTo(
            p.basename(b.path).toLowerCase(),
          ),
    );
    return p.normalize(images.first.absolute.path);
  }

  Future<bool> _directoryHasImages(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && LocalCbzSource.isImagePath(entity.path)) {
        return true;
      }
    }
    return false;
  }
}

int _naturalCompare(String a, String b) {
  final ra = _parts(a.toLowerCase());
  final rb = _parts(b.toLowerCase());
  final n = ra.length < rb.length ? ra.length : rb.length;
  for (var i = 0; i < n; i++) {
    final pa = ra[i];
    final pb = rb[i];
    if (pa is int && pb is int) {
      final c = pa.compareTo(pb);
      if (c != 0) return c;
    } else {
      final c = '$pa'.compareTo('$pb');
      if (c != 0) return c;
    }
  }
  return ra.length.compareTo(rb.length);
}

List<Object> _parts(String s) {
  final parts = <Object>[];
  final buf = StringBuffer();
  var inDigit = false;
  for (final code in s.codeUnits) {
    final digit = code >= 48 && code <= 57;
    if (buf.isEmpty) {
      inDigit = digit;
      buf.writeCharCode(code);
      continue;
    }
    if (digit == inDigit) {
      buf.writeCharCode(code);
    } else {
      parts.add(inDigit ? int.parse(buf.toString()) : buf.toString());
      buf.clear();
      inDigit = digit;
      buf.writeCharCode(code);
    }
  }
  if (buf.isNotEmpty) {
    parts.add(inDigit ? int.parse(buf.toString()) : buf.toString());
  }
  return parts;
}
