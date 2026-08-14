import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads the update APK and hands it to the system package installer
/// (Mihon [NewUpdateScreenModel] download + install parity).
class AppUpdateInstaller {
  AppUpdateInstaller({http.Client? client}) : _client = client ?? http.Client();

  static const _channel = MethodChannel('com.koma.koma/system');
  static const apkMime = 'application/vnd.android.package-archive';

  final http.Client _client;

  File? _apkFile;
  static const _apkName = 'update.apk';

  File? get apkFile => _apkFile;

  Future<Directory> _cacheDir() async {
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
    try {
      final leftover = File('${(await _cacheDir()).path}/$_apkName');
      if (await leftover.exists()) await leftover.delete();
    } catch (_) {}
  }

  /// Returns a finished update APK left in cache from a prior session.
  Future<File?> cachedApkFile() async {
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
