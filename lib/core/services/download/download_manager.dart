import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../../repositories/repositories.dart';
import '../keiyoushi_service.dart';
import '../notification_service.dart';
import 'chapter_download.dart';
import 'download_store.dart';

/// Closes the active HTTP client so Dalvik NDJSON streaming aborts.
class DownloadAbortController {
  http.Client? _client;
  bool _aborted = false;

  bool get isAborted => _aborted;

  void attach(http.Client client) {
    _client = client;
    if (_aborted) {
      client.close();
    }
  }

  void abort() {
    _aborted = true;
    try {
      _client?.close();
    } catch (_) {}
  }
}

/// Mihon-faithful chapter download queue (DownloadManager + Downloader).
///
/// One chapter at a time (per-source concurrency deferred). WorkManager
/// one-off drains the same [DownloadStore] when the UI runner is idle.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required KeiyoushiService keiyoushi,
    Repositories? repositories,
    DownloadStore? store,
  })  : _keiyoushi = keiyoushi,
        _repos = repositories,
        _store = store ?? DownloadStore();

  final KeiyoushiService _keiyoushi;
  final Repositories? _repos;
  final DownloadStore _store;

  static const downloadTaskName = 'com.koma.download_chapters';

  final List<ChapterDownload> _queue = [];
  bool _running = false;
  bool _paused = false;
  int _orderCounter = 0;
  DownloadAbortController? _activeAbort;

  List<ChapterDownload> get queue => List.unmodifiable(_queue);
  bool get isRunning => _running;
  bool get isPaused => _paused;
  int get pendingCount => _queue
      .where((d) => d.status != DownloadState.downloaded)
      .length;

  ChapterDownload? getQueuedOrNull(String chapterKey) {
    for (final d in _queue) {
      if (d.chapterKey == chapterKey) return d;
    }
    return null;
  }

  ChapterDownload? getQueuedByChapterUrl(String sourceId, String chapterUrl) {
    return getQueuedOrNull('$sourceId|$chapterUrl');
  }

  /// Restore persisted queue on app start.
  Future<void> restore({bool autoStart = true}) async {
    final restored = await _store.restore();
    _paused = await _store.isPaused();
    _queue
      ..clear()
      ..addAll(restored);
    for (final d in _queue) {
      if (d.status == DownloadState.downloading) {
        d.status = DownloadState.queue;
      }
      if (d.order >= _orderCounter) _orderCounter = d.order + 1;
    }
    // Previous UI runner may have been killed mid-job.
    await _store.setRunner('none');
    notifyListeners();
    if (autoStart && !_paused && _queue.isNotEmpty) {
      await startDownloads();
    }
  }

  /// Enqueue chapters (Mihon `downloadChapters`).
  Future<void> downloadChapters({
    required String sourceId,
    required String mangaUrl,
    required String mangaTitle,
    required List<Map<String, dynamic>> chapters,
    int? mangaId,
    String? mangaMemo,
    bool autoStart = true,
  }) async {
    final existingKeys = _queue.map((d) => d.chapterKey).toSet();
    final added = <ChapterDownload>[];
    final mangaMemoJson = coerceMemoJson(mangaMemo) ?? '';
    for (final ch in chapters) {
      final url = ch['url'] as String? ?? '';
      if (url.isEmpty) continue;
      final key = '$sourceId|$url';
      if (existingKeys.contains(key)) continue;
      final name = ch['name'] as String? ?? url;
      var chapterMemo = coerceMemoJson(ch['memo']) ?? '';
      final chapterNumber = ch['chapter_number'] as num?;
      int? chapterId = (ch['id'] as num?)?.toInt();
      if (mangaId != null && _repos != null) {
        final existing =
            await _repos.manga.getMangaChapterByUrl(mangaId, url);
        chapterId ??= existing?.id;
        if (chapterMemo.isEmpty) {
          chapterMemo = coerceMemoJson(existing?.memo) ?? '';
        }
      }
      // AllAnime non-legacy: manga.url is the raw id. Persist mangaId in
      // chapter memo at enqueue so getPageList works without a hydrate race.
      if (!_chapterMemoLooksReady(chapterMemo) && !mangaUrl.contains('/')) {
        chapterMemo = jsonEncode({'mangaId': mangaUrl});
      }
      added.add(
        ChapterDownload(
          sourceId: sourceId,
          mangaUrl: mangaUrl,
          mangaTitle: mangaTitle,
          chapterUrl: url,
          chapterName: name,
          chapterMemo: chapterMemo,
          mangaMemo: mangaMemoJson,
          mangaId: mangaId,
          chapterId: chapterId,
          chapterNumber: chapterNumber,
          order: _orderCounter++,
        ),
      );
      existingKeys.add(key);
    }
    if (added.isEmpty) return;
    _queue.addAll(added);
    await _persist();
    notifyListeners();
    if (autoStart) {
      await startDownloads();
    }
  }

  Future<void> startDownloads() async {
    _paused = false;
    await _store.setPaused(false);
    for (final d in _queue) {
      if (d.status != DownloadState.downloaded) {
        d.status = DownloadState.queue;
      }
    }
    await _persist();
    notifyListeners();
    if (_running || _queue.isEmpty) return;
    // Claim the runner BEFORE WorkManager can race us. Do not schedule WM
    // here — spawning a second FlutterEngine mid-download looks like a crash.
    // WM is scheduled only when the app backgrounds ([scheduleBackgroundIfNeeded]).
    await _store.setRunner('ui');
    unawaited(runUntilIdle(runner: 'ui'));
  }

  /// Runs the download loop until the queue is idle or paused.
  /// Used by WorkManager background drain (awaited) and by [startDownloads].
  Future<void> runUntilIdle({required String runner}) =>
      _runLoop(runner: runner);

  /// Schedule a WorkManager drain when the app is backgrounded and there is
  /// still queued work the UI isolate may not finish.
  Future<void> scheduleBackgroundIfNeeded() async {
    if (_paused) return;
    final hasQueued = _queue.any((d) => d.status == DownloadState.queue);
    if (!hasQueued) return;
    await _scheduleWorkManager();
  }

  Future<void> pauseDownloads() async {
    _paused = true;
    await _store.setPaused(true);
    _activeAbort?.abort();
    for (final d in _queue) {
      if (d.status == DownloadState.downloading) {
        d.status = DownloadState.queue;
      }
    }
    await _persist();
    await _cancelWorkManager();
    await _store.setRunner('none');
    notifyListeners();
    unawaited(NotificationService.instance.notifyDownloadPaused(pendingCount));
  }

  Future<void> clearQueue() async {
    _activeAbort?.abort();
    _queue.clear();
    _paused = false;
    await _store.clear();
    await _store.setPaused(false);
    await _store.setRunner('none');
    await _cancelWorkManager();
    notifyListeners();
    await NotificationService.instance.dismissDownloadProgress();
  }

  Future<void> cancelQueuedDownloads(List<ChapterDownload> downloads) async {
    final keys = downloads.map((d) => d.chapterKey).toSet();
    final wasRunning = _running;
    if (wasRunning) {
      _activeAbort?.abort();
    }
    _queue.removeWhere((d) => keys.contains(d.chapterKey));
    await _persist();
    notifyListeners();
    if (_queue.isEmpty) {
      await _store.setRunner('none');
      await _cancelWorkManager();
      await NotificationService.instance.dismissDownloadProgress();
      return;
    }
    if (wasRunning && !_paused) {
      await startDownloads();
    }
  }

  Future<void> reorderQueue(List<ChapterDownload> ordered) async {
    _queue
      ..clear()
      ..addAll(ordered);
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].order = i;
    }
    _orderCounter = _queue.length;
    await _persist();
    notifyListeners();
  }

  Future<void> startDownloadNow(String chapterKey) async {
    final existing = getQueuedOrNull(chapterKey);
    if (existing == null) return;
    _queue.remove(existing);
    existing.status = DownloadState.queue;
    _queue.insert(0, existing);
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].order = i;
    }
    await _persist();
    notifyListeners();
    await startDownloads();
  }

  Future<void> _runLoop({required String runner}) async {
    if (_running) return;
    _running = true;
    await _store.setRunner(runner);
    try {
      while (!_paused) {
        ChapterDownload? next;
        for (final d in _queue) {
          // Mihon Downloader: only QUEUE/DOWNLOADING are active. ERROR items
          // stay until startDownloads() / retry resets them to QUEUE — otherwise
          // a permanent getPageList failure (e.g. "Refresh Chapter List") spins
          // forever.
          if (d.status == DownloadState.queue) {
            next = d;
            break;
          }
        }
        if (next == null) break;
        await _downloadOne(next);
        if (_paused) break;
      }
    } finally {
      _running = false;
      _activeAbort = null;
      final current = await _store.runner();
      if (current == runner) {
        await _store.setRunner('none');
      }
      if (_queue.isEmpty) {
        await NotificationService.instance.dismissDownloadProgress();
      } else if (_paused) {
        unawaited(
          NotificationService.instance.notifyDownloadPaused(pendingCount),
        );
      }
      notifyListeners();
    }
  }

  Future<void> _downloadOne(ChapterDownload download) async {
    download.status = DownloadState.downloading;
    download.pagesDone = 0;
    await _persist();
    notifyListeners();
    unawaited(
      NotificationService.instance.notifyDownloadProgress(
        mangaTitle: download.mangaTitle,
        chapterName: download.chapterName,
        done: download.pagesDone,
        total: download.pagesTotal,
        pending: pendingCount,
      ),
    );

    final abort = DownloadAbortController();
    _activeAbort = abort;
    try {
      // AllAnime and similar sources require chapter.memo (e.g. mangaId).
      // Stale/empty memo → "Refresh Chapter List"; hydrate once before pages.
      if (!_chapterMemoLooksReady(download.chapterMemo)) {
        await _ensureChapterMemo(download);
      }
      final result = await _keiyoushi.downloadChapters(
        sourceId: download.sourceId,
        mangaUrl: download.mangaUrl,
        chapters: [
          {
            'url': download.chapterUrl,
            'name': download.chapterName,
            'memo': download.chapterMemo,
          },
        ],
        abort: abort,
        onProgress: (chapterUrl, done, total) {
          if (chapterUrl != download.chapterUrl) return;
          download.pagesDone = done;
          download.pagesTotal = total;
          notifyListeners();
          unawaited(
            NotificationService.instance.notifyDownloadProgress(
              mangaTitle: download.mangaTitle,
              chapterName: download.chapterName,
              done: done,
              total: total,
              pending: pendingCount,
            ),
          );
          unawaited(_persist());
        },
      );
      if (abort.isAborted || _paused) {
        download.status = DownloadState.queue;
        await _persist();
        notifyListeners();
        return;
      }
      final ok = result.containsKey(download.chapterUrl);
      if (ok) {
        download.status = DownloadState.downloaded;
        await _markDownloaded(download);
        // Notify while still in queue so listeners can mark the chapter done
        // before the item disappears.
        await _persist();
        notifyListeners();
        _queue.remove(download);
        await _persist();
        notifyListeners();
      } else {
        download.status = DownloadState.error;
        await _persist();
        notifyListeners();
        unawaited(
          NotificationService.instance.notifyDownloadError(
            '${download.mangaTitle}: ${download.chapterName}',
          ),
        );
      }
    } on DownloadAbortedException {
      download.status = DownloadState.queue;
      await _persist();
      notifyListeners();
    } catch (e) {
      if (abort.isAborted || _paused) {
        download.status = DownloadState.queue;
      } else {
        download.status = DownloadState.error;
        unawaited(NotificationService.instance.notifyDownloadError('$e'));
      }
      await _persist();
      notifyListeners();
    } finally {
      if (identical(_activeAbort, abort)) {
        _activeAbort = null;
      }
    }
  }

  Future<void> _markDownloaded(ChapterDownload download) async {
    final repos = _repos;
    if (repos == null) return;
    try {
      final mangaId = download.mangaId;
      if (mangaId != null) {
        final existing = await repos.manga
            .getMangaChapterByUrl(mangaId, download.chapterUrl);
        if (existing != null) {
          await repos.manga.markMangaChapterDownloaded(existing.id, true);
          return;
        }
      }
      if (download.chapterId != null) {
        await repos.manga
            .markMangaChapterDownloaded(download.chapterId!, true);
      }
    } catch (_) {}
  }

  /// True when chapter memo is usable for getPageList.
  /// AllAnime requires `mangaId` inside the memo object.
  bool _chapterMemoLooksReady(String memo) {
    final t = memo.trim();
    if (t.isEmpty || t == '{}') return false;
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map) {
        final id = decoded['mangaId'];
        return id != null && '$id'.isNotEmpty;
      }
    } catch (_) {
      // Opaque memo string — leave as-is for non-JSON sources.
      return true;
    }
    return true;
  }

  /// Re-fetch chapter list so source memos (mangaId/slug) are fresh, then
  /// fall back to synthesizing mangaId from a non-legacy manga URL.
  Future<void> _ensureChapterMemo(ChapterDownload download) async {
    await _hydrateChapterMemo(download);
    if (_chapterMemoLooksReady(download.chapterMemo)) return;
    // AllAnime non-legacy: manga.url is the raw id (no leading '/').
    if (!download.mangaUrl.contains('/')) {
      download.chapterMemo = jsonEncode({'mangaId': download.mangaUrl});
      await _persist();
      notifyListeners();
    }
  }

  /// Re-fetch chapter list so source memos (mangaId/slug) are fresh.
  Future<void> _hydrateChapterMemo(ChapterDownload download) async {
    try {
      final list = await _keiyoushi.getChapterList(
        sourceId: download.sourceId,
        url: download.mangaUrl,
        memo: download.mangaMemo.isNotEmpty ? download.mangaMemo : null,
      );
      for (final ch in list) {
        final url = ch['url'] as String? ?? '';
        if (url != download.chapterUrl) continue;
        final memo = coerceMemoJson(ch['memo']);
        if (memo != null && memo.isNotEmpty) {
          download.chapterMemo = memo;
          await _persist();
          notifyListeners();
        }
        break;
      }
    } catch (_) {
      // Best-effort: download still proceeds and may surface the source error.
    }
  }

  Future<void> _persist() => _store.save(_queue);

  Future<void> _scheduleWorkManager() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().registerOneOffTask(
        downloadTaskName,
        downloadTaskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (_) {}
  }

  Future<void> _cancelWorkManager() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().cancelByUniqueName(downloadTaskName);
    } catch (_) {}
  }
}

/// Progress helper for manga detail rows — maps queue state → UI strings.
String? downloadProgressLabel(ChapterDownload? d) {
  if (d == null) return null;
  switch (d.status) {
    case DownloadState.queue:
      return 'queued';
    case DownloadState.downloading:
      if (d.pagesTotal > 0) return '${d.pagesDone}/${d.pagesTotal}';
      return 'queued';
    case DownloadState.error:
      return 'error';
    case DownloadState.downloaded:
      return 'done';
    case DownloadState.notDownloaded:
      return null;
  }
}
