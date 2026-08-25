import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../app_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads the update APK and hands it to the system package installer.
///
/// On Android, download runs in a WorkManager foreground worker
/// ([AppUpdateDownloadJob] — Mihon parity) so backgrounding the app does not
/// cancel the transfer. Other platforms fall back to an in-process HTTP stream.
class AppUpdateInstaller {
  AppUpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  static const _channel = MethodChannel('com.koma.koma/system');
  static const apkMime = 'application/vnd.android.package-archive';

  final http.Client _client;

  File? _apkFile;
  static const _apkName = 'update.apk';

  File? get apkFile => _apkFile;

  Future<Directory> _cacheDir() async {
    if (AppStorage.usesCustomRoot) {
      final dir = Directory('${(await AppStorage.documents()).path}/updates');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    if (!kIsWeb && Platform.isAndroid) {
      final dirs = await getExternalCacheDirectories();
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    return getTemporaryDirectory();
  }

  Future<File> downloadApk(
    String downloadLink, {
    void Function(int progress)? onProgress,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      return _downloadApkNative(downloadLink, onProgress: onProgress);
    }
    return _downloadApkHttp(downloadLink, onProgress: onProgress);
  }

  /// Mihon-style WorkManager + dataSync foreground service download.
  Future<File> _downloadApkNative(
    String downloadLink, {
    void Function(int progress)? onProgress,
  }) async {
    await _channel.invokeMethod<void>('startAppUpdateDownload', {
      'url': downloadLink,
    });
    return awaitNativeDownload(onProgress: onProgress);
  }

  /// Polls WorkManager until the APK job finishes (or fails). Used both after
  /// enqueue and when restoring an in-flight download after process death.
  Future<File> awaitNativeDownload({
    void Function(int progress)? onProgress,
  }) async {
    while (true) {
      final map = await nativeDownloadSnapshot() ?? {};
      final state = (map['state'] as String? ?? 'IDLE').toUpperCase();
      final progress = (map['progress'] as num?)?.round() ?? 0;
      onProgress?.call(progress.clamp(0, 100));

      if (state == 'SUCCEEDED' || map['apkReady'] == true) {
        final path = map['apkPath'] as String?;
        if (path == null || path.isEmpty) {
          throw StateError('Update APK missing after download');
        }
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          throw StateError('Update APK empty after download');
        }
        onProgress?.call(100);
        _apkFile = file;
        return file;
      }
      if (state == 'FAILED' || state == 'CANCELLED') {
        throw StateError('Update download $state');
      }
      // IDLE with no work yet — keep waiting briefly after enqueue.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<Map<String, dynamic>?> nativeDownloadSnapshot() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'getAppUpdateDownloadState',
      );
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<File> _downloadApkHttp(
    String downloadLink, {
    void Function(int progress)? onProgress,
  }) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_apkName');
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', Uri.parse(downloadLink));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Download failed (${response.statusCode})',
        uri: request.url,
      );
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    var savedProgress = 0;
    var lastTick = 0;

    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          final progress = (100 * (received / total)).round().clamp(0, 100);
          final now = DateTime.now().millisecondsSinceEpoch;
          if (progress > savedProgress && now - lastTick > 200) {
            savedProgress = progress;
            lastTick = now;
            onProgress(progress);
          }
        }
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();

    onProgress?.call(100);
    _apkFile = file;
    return file;
  }

  Future<void> installUpdate([File? file]) async {
    final apk = file ?? _apkFile;
    if (apk == null || !await apk.exists()) {
      throw StateError('Update APK not downloaded');
    }
    await _channel.invokeMethod<void>('installApk', {
      'apkPath': apk.path,
    });
  }

  Future<void> deleteDownloadedApk() async {
    _apkFile = null;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('cancelAppUpdateDownload');
      } catch (_) {}
    }
    try {
      final leftover = File('${(await _cacheDir()).path}/$_apkName');
      if (await leftover.exists()) await leftover.delete();
    } catch (_) {}
    // Native job writes to externalCacheDir/update.apk — wipe if present.
    try {
      final dirs = await getExternalCacheDirectories();
      final dir = dirs?.isNotEmpty == true ? dirs!.first : null;
      if (dir != null) {
        final native = File('${dir.path}/$_apkName');
        if (await native.exists()) await native.delete();
      }
    } catch (_) {}
  }

  /// Returns a finished update APK left in cache from a prior session.
  Future<File?> cachedApkFile() async {
    final snap = await nativeDownloadSnapshot();
    final path = snap?['apkPath'] as String?;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && await file.length() > 0) return file;
    }
    // Fallback: external cache / custom updates dir without WorkInfo.
    try {
      final dirs = await getExternalCacheDirectories();
      if (dirs != null && dirs.isNotEmpty) {
        final native = File('${dirs.first.path}/$_apkName');
        if (await native.exists() && await native.length() > 0) return native;
      }
    } catch (_) {}
    final dir = await _cacheDir();
    final file = File('${dir.path}/$_apkName');
    if (!await file.exists()) return null;
    final len = await file.length();
    return len > 0 ? file : null;
  }

  void adoptCachedApk(File file) {
    _apkFile = file;
  }
}
