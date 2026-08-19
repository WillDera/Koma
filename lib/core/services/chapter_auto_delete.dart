import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'app_storage.dart';

import '../repositories/repositories.dart';
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

    final ext = await findInstalledExtension(_repos, sourceId);
    if (ext == null || !ext.isJs) {
      try {
        await _keiyoushi.deleteChapters(
          sourceId: sourceId,
          mangaUrl: mangaUrl,
          chapterUrls: [chapterUrl],
        );
      } catch (_) {}
    } else {
      await _deleteJsChapterDir(sourceId, mangaUrl, chapterUrl);
    }

    await _repos.manga.markMangaChapterDownloaded(chapterId, false);
  }

  Future<void> _deleteJsChapterDir(
    String sourceId,
    String mangaUrl,
    String chapterUrl,
  ) async {
    final supportDir = await AppStorage.support();
    final mangaKey = _urlKey(mangaUrl);
    final chKey = _urlKey(chapterUrl);
    final dir = Directory(
      '${supportDir.path}/manga/$sourceId/$mangaKey/$chKey',
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String _urlKey(String url) =>
      sha256.convert(url.codeUnits).toString().substring(0, 16);
}
