import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../repositories/repositories.dart';
import 'app_storage.dart';
import 'download/download_manager.dart';
import 'extension_source_resolve.dart';
import 'keiyoushi_service.dart';

/// Deletes local chapter download files and clears the DB flag (Mihon parity).
class ChapterAutoDelete {
  ChapterAutoDelete({
    required Repositories repos,
    required KeiyoushiService keiyoushi,
    DownloadManager? downloadManager,
  })  : _repos = repos,
        _keiyoushi = keiyoushi,
        _downloadManager = downloadManager;

  final Repositories _repos;
  final KeiyoushiService _keiyoushi;
  final DownloadManager? _downloadManager;

  static const _channel = MethodChannel('com.koma.koma/system');

  /// Install an APK via Android PackageInstaller session API.
  static Future<void> installApkViaPackageInstaller(String apkPath) async {
    await _channel.invokeMethod<void>(
      'installApkViaPackageInstaller',
      {'apkPath': apkPath},
    );
  }

  /// Removes on-disk chapter dirs (native + JS layouts) then returns.
  ///
  /// Callers still clear `isDownloaded` in Isar. Native Mihon-style downloads
  /// live under the Dalvik `filesDir`; JS downloads use [AppStorage.support].
  /// Both are attempted so delete never leaves orphaned page files.
  static Future<void> deleteChapterFiles({
    required KeiyoushiService keiyoushi,
    required Repositories repos,
    required String sourceId,
    required String mangaUrl,
    required List<String> chapterUrls,
  }) async {
    if (chapterUrls.isEmpty) return;

    final ext = await findInstalledExtension(repos, sourceId);
    if (ext == null || !ext.isJs) {
      try {
        await keiyoushi.deleteChapters(
          sourceId: sourceId,
          mangaUrl: mangaUrl,
          chapterUrls: chapterUrls,
        );
      } catch (_) {
        // Missing dirs / unloaded extension — still wipe support-path copies.
      }
    }

    // JS downloads (and any shared support layout) always go through here.
    for (final chapterUrl in chapterUrls) {
      await _deleteSupportChapterDir(sourceId, mangaUrl, chapterUrl);
    }
  }

  Future<void> deleteIfDownloaded({
    required int mangaId,
    required int chapterId,
    required String sourceId,
    required String mangaUrl,
    required String chapterUrl,
  }) async {
    final chapter = await _repos.manga.getMangaChapterById(chapterId);
    if (chapter == null || !chapter.isDownloaded) return;

    final mgr = _downloadManager;
    if (mgr != null) {
      final queued = mgr.getQueuedByChapterUrl(sourceId, chapterUrl);
      if (queued != null) {
        await mgr.cancelQueuedDownloads([queued]);
      }
    }

    await deleteChapterFiles(
      keiyoushi: _keiyoushi,
      repos: _repos,
      sourceId: sourceId,
      mangaUrl: mangaUrl,
      chapterUrls: [chapterUrl],
    );

    await _repos.manga.markMangaChapterDownloaded(chapterId, false);
  }

  static Future<void> _deleteSupportChapterDir(
    String sourceId,
    String mangaUrl,
    String chapterUrl,
  ) async {
    final supportDir = await AppStorage.support();
    final mangaKey = _urlKey(mangaUrl);
    final chKey = _urlKey(chapterUrl);
    final mangaDir = Directory(
      '${supportDir.path}/manga/$sourceId/$mangaKey',
    );
    final chDir = Directory('${mangaDir.path}/$chKey');
    if (await chDir.exists()) {
      await chDir.delete(recursive: true);
    }
    try {
      final leftover = await mangaDir.list().toList();
      if (leftover.isEmpty && await mangaDir.exists()) {
        await mangaDir.delete();
      }
    } catch (_) {}
  }

  /// Must match [DownloadManager] / JS page cache keys (`utf8` SHA-256).
  static String _urlKey(String url) =>
      sha256.convert(utf8.encode(url)).toString().substring(0, 16);
}
