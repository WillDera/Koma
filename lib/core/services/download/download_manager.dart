import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_storage.dart';
import 'package:workmanager/workmanager.dart';

import '../../../eval/dispatch_service.dart';
import '../../../eval/models/m_chapter.dart';
import '../../repositories/repositories.dart';
import '../extension_source_resolve.dart';
import '../download_prefs.dart';
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

String _urlKey(String url) =>
    sha256.convert(utf8.encode(url)).toString().substring(0, 16);

/// Mihon-faithful chapter download queue (DownloadManager + Downloader).
///
/// Concurrent downloads across distinct [sourceId] groups (max 3). WorkManager
/// one-off drains the same [DownloadStore] when the UI runner is idle.
///
/// Mihon APKs stream through [KeiyoushiService.downloadChapters]; JS sources
/// resolve page lists via [ExtensionDispatchService] and save JPGs locally.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required KeiyoushiService keiyoushi,
    ExtensionDispatchService? extensionService,
    Repositories? repositories,
    DownloadStore? store,
  })  : _keiyoushi = keiyoushi,
        _dispatch = extensionService ??
            ExtensionDispatchService(keiyoushiService: keiyoushi),
        _repos = repositories,
        _store = store ?? DownloadStore();

  final KeiyoushiService _keiyoushi;
  final ExtensionDispatchService _dispatch;
  final Repositories? _repos;
  final DownloadStore _store;

  static const downloadTaskName = 'com.koma.download_chapters';
  static const _maxConcurrent = 3;

  final List<ChapterDownload> _queue = [];
  bool _running = false;
  bool _paused = false;
  int _orderCounter = 0;
  final Set<DownloadAbortController> _activeAborts = {};
  final Set<String> _activeSourceIds = {};
  final Map<String, Future<void>> _inFlight = {};

  List<ChapterDownload> get queue => List.unmodifiable(_queue);
  bool get isRunning => _running;
  bool get isPaused => _paused;
  int get pendingCount =>
      _queue.where((d) => d.status != DownloadState.downloaded).length;

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
    await _store.setRunner('none');
    notifyListeners();
    if (autoStart &&
        !_paused &&
        _queue.any((d) => d.status == DownloadState.queue)) {
      await startDownloads(retryErrors: false);
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
      await startDownloads(retryErrors: false);
    }
  }

  Future<void> startDownloads({bool retryErrors = true}) async {
    _paused = false;
    await _store.setPaused(false);
    for (final d in _queue) {
      if (d.status == DownloadState.downloading) {
        d.status = DownloadState.queue;
      } else if (retryErrors && d.status == DownloadState.error) {
        d.status = DownloadState.queue;
      }
    }
    await _persist();
    notifyListeners();
    if (_running || !_queue.any((d) => d.status == DownloadState.queue)) {
      return;
    }
    await _store.setRunner('ui');
    unawaited(runUntilIdle(runner: 'ui'));
  }

  Future<void> runUntilIdle({required String runner}) =>
      _runLoop(runner: runner);

  Future<void> scheduleBackgroundIfNeeded() async {
    if (_paused) return;
    final hasQueued = _queue.any((d) => d.status == DownloadState.queue);
    if (!hasQueued) return;
    await _scheduleWorkManager();
  }

  Future<void> pauseDownloads() async {
    _paused = true;
    await _store.setPaused(true);
    for (final abort in _activeAborts) {
      abort.abort();
    }
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
    for (final abort in _activeAborts) {
      abort.abort();
    }
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
      for (final abort in _activeAborts) {
        abort.abort();
      }
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
        if (!await DownloadPrefs.canDownloadNow()) {
          await Future<void>.delayed(const Duration(seconds: 15));
          continue;
        }

        final slots = _maxConcurrent - _inFlight.length;
        var started = 0;
        for (final d in _queue) {
          if (started >= slots) break;
          if (d.status != DownloadState.queue) continue;
          if (_activeSourceIds.contains(d.sourceId)) continue;
          if (_inFlight.containsKey(d.chapterKey)) continue;
          _activeSourceIds.add(d.sourceId);
          final key = d.chapterKey;
          _inFlight[key] = _downloadOne(d).whenComplete(() {
            _activeSourceIds.remove(d.sourceId);
            _inFlight.remove(key);
          });
          started++;
        }

        if (_inFlight.isEmpty) {
          final waiting = _queue.any((d) => d.status == DownloadState.queue);
          if (!waiting) break;
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }

        await Future.any(_inFlight.values);
      }
      if (_inFlight.isNotEmpty) {
        await Future.wait(_inFlight.values);
      }
    } finally {
      _running = false;
      _activeAborts.clear();
      _activeSourceIds.clear();
      _inFlight.clear();
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
    _activeAborts.add(abort);
    try {
      if (!_chapterMemoLooksReady(download.chapterMemo)) {
        await _ensureChapterMemo(download);
      }

      final isJs = await _isJsSource(download.sourceId);
      final bool ok;
      if (isJs) {
        ok = await _downloadOneJs(download, abort);
      } else {
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
        ok = result.containsKey(download.chapterUrl);
      }

      if (abort.isAborted || _paused) {
        download.status = DownloadState.queue;
        await _persist();
        notifyListeners();
        return;
      }
      if (ok) {
        download.status = DownloadState.downloaded;
        await _markDownloaded(download);
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
      _activeAborts.remove(abort);
    }
  }

  Future<bool> _isJsSource(String sourceId) async {
    final repos = _repos;
    if (repos == null) return false;
    final ext = await findInstalledExtension(repos, sourceId);
    return ext?.isJs ?? false;
  }

  /// JS path: dispatch getPageList + HTTP-save JPGs under the Mihon layout.
  Future<bool> _downloadOneJs(
    ChapterDownload download,
    DownloadAbortController abort,
  ) async {
    final repos = _repos;
    if (repos == null) return false;

    final source = await resolveExtensionMSource(repos, download.sourceId);
    final pagesWrapped = await _dispatch.getPageList(
      source,
      MChapter(
        url: download.chapterUrl,
        name: download.chapterName,
        memo: download.chapterMemo.isNotEmpty ? download.chapterMemo : null,
      ),
    );
    final pages = [
      for (final group in pagesWrapped)
        for (final p in group.pages)
          if (p.url.trim().isNotEmpty) p,
    ];
    if (pages.isEmpty) return false;

    download.pagesTotal = pages.length;
    download.pagesDone = 0;
    notifyListeners();

    final supportDir = await AppStorage.support();
    final mangaKey = _urlKey(download.mangaUrl);
    final chKey = _urlKey(download.chapterUrl);
    final chDir = Directory(
      '${supportDir.path}/manga/${download.sourceId}/$mangaKey/$chKey',
    );
    await chDir.create(recursive: true);

    final client = http.Client();
    abort.attach(client);
    try {
      for (var i = 0; i < pages.length; i++) {
        if (abort.isAborted || _paused) return false;
        final page = pages[i];
        final file = File('${chDir.path}/${page.index}.jpg');
        if (!await file.exists() || await file.length() == 0) {
          final req = http.Request('GET', Uri.parse(page.url));
          if (page.headers != null) {
            req.headers.addAll(page.headers!);
          }
          final streamed = await client.send(req).timeout(
                const Duration(seconds: 60),
              );
          if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
            throw Exception('JS page download HTTP ${streamed.statusCode}');
          }
          final bytes = await streamed.stream.toBytes();
          await file.writeAsBytes(bytes, flush: true);
        }
        download.pagesDone = i + 1;
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
        unawaited(_persist());
      }
      return !abort.isAborted && !_paused;
    } finally {
      client.close();
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
        await repos.manga.markMangaChapterDownloaded(download.chapterId!, true);
      }
    } catch (_) {}
  }

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
      return true;
    }
    return true;
  }

  Future<void> _ensureChapterMemo(ChapterDownload download) async {
    await _hydrateChapterMemo(download);
    if (_chapterMemoLooksReady(download.chapterMemo)) return;
    if (!download.mangaUrl.contains('/')) {
      download.chapterMemo = jsonEncode({'mangaId': download.mangaUrl});
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _hydrateChapterMemo(ChapterDownload download) async {
    final repos = _repos;
    try {
      if (repos != null) {
        final source = await resolveExtensionMSource(repos, download.sourceId);
        final list = await _dispatch.getChapterList(
          source,
          download.mangaUrl,
          memo: download.mangaMemo.isNotEmpty ? download.mangaMemo : null,
        );
        for (final ch in list) {
          if (ch.url != download.chapterUrl) continue;
          final memo = coerceMemoJson(ch.memo);
          if (memo != null && memo.isNotEmpty) {
            download.chapterMemo = memo;
            await _persist();
            notifyListeners();
          }
          break;
        }
        return;
      }
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
    } catch (_) {}
  }

  Future<void> _persist() => _store.save(_queue);

  Future<void> _scheduleWorkManager() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final constraints = DownloadPrefs.workConstraints(
        await DownloadPrefs.loadDeviceConstraints(),
      );
      await Workmanager().registerOneOffTask(
        downloadTaskName,
        downloadTaskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: constraints,
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
