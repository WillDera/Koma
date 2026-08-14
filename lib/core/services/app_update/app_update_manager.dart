import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notification_service.dart';
import 'app_release.dart';
import 'app_update_installer.dart';
import 'get_application_release.dart';

enum AppUpdateStage { idle, available, downloading, downloaded, failed }

typedef InstalledAppVersion = ({String versionName, String buildNumber});

/// Global app-update download state. Survives closing [NewUpdateSheet] and
/// drives the system notification progress bar (chapter download parity).
class AppUpdateManager extends ChangeNotifier {
  AppUpdateManager({
    AppUpdateInstaller? installer,
    Future<InstalledAppVersion> Function()? installedVersion,
  })  : _installer = installer ?? AppUpdateInstaller(),
        _installedVersion = installedVersion ?? _packageInfoVersion;

  static const _prefsReleaseKey = 'app_update_pending_release';

  final AppUpdateInstaller _installer;
  final Future<InstalledAppVersion> Function() _installedVersion;

  static Future<InstalledAppVersion> _packageInfoVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (versionName: info.version, buildNumber: info.buildNumber);
  }

  AppUpdateStage _stage = AppUpdateStage.idle;
  int _progress = 0;
  AppRelease? _release;
  bool _downloadRunning = false;

  AppUpdateStage get stage => _stage;
  int get progress => _progress;
  AppRelease? get release => _release;
  bool get isDownloading => _stage == AppUpdateStage.downloading;

  /// Marks a release as available without starting a download.
  void offerUpdate(AppRelease release) {
    if (_stage == AppUpdateStage.downloading) return;
    if (_stage == AppUpdateStage.downloaded &&
        _release?.version == release.version) {
      return;
    }
    _release = release;
    _stage = AppUpdateStage.available;
    _progress = 0;
    notifyListeners();
  }

  /// Starts (or resumes showing) a background APK download.
  Future<void> startDownload() async {
    final release = _release;
    if (release == null || _downloadRunning) return;

    _downloadRunning = true;
    _stage = AppUpdateStage.downloading;
    _progress = 0;
    notifyListeners();
    unawaited(
      NotificationService.instance.notifyAppUpdateProgress(
        progress: 0,
        version: release.version,
      ),
    );

    try {
      await _installer.downloadApk(
        release.downloadLink,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
          unawaited(
            NotificationService.instance.notifyAppUpdateProgress(
              progress: p,
              version: release.version,
            ),
          );
        },
      );
      _progress = 100;
      _stage = AppUpdateStage.downloaded;
      notifyListeners();
      await _persistRelease(release);
      await NotificationService.instance.notifyAppUpdateReady(release.version);
    } catch (_) {
      await _installer.deleteDownloadedApk();
      _stage = AppUpdateStage.failed;
      _progress = 0;
      notifyListeners();
      await NotificationService.instance.notifyAppUpdateError();
    } finally {
      _downloadRunning = false;
      notifyListeners();
    }
  }

  Future<void> install() => _installer.installUpdate();

  /// If a previous download finished while the app was closed, restore state.
  /// Drops the APK when that release is already running (post-install).
  Future<void> restoreCachedDownload() async {
    if (_stage == AppUpdateStage.downloading || _downloadRunning) return;
    final cached = await _installer.cachedApkFile();
    if (cached == null) {
      await _clearPersistedRelease();
      if (_stage == AppUpdateStage.downloaded) {
        _release = null;
        _stage = AppUpdateStage.idle;
        _progress = 0;
        notifyListeners();
      }
      return;
    }
    final persisted = await _loadPersistedRelease();
    if (persisted == null || await isCachedReleaseInstalled(persisted)) {
      _installer.adoptCachedApk(cached);
      clear();
      return;
    }
    _installer.adoptCachedApk(cached);
    _release = persisted;
    _stage = AppUpdateStage.downloaded;
    _progress = 100;
    notifyListeners();
  }

  /// True when [release] is already the running app (or older).
  Future<bool> isCachedReleaseInstalled(AppRelease release) async {
    final installed = await _installedVersion();
    return isStaleCachedRelease(
      release,
      versionName: installed.versionName,
      buildNumber: installed.buildNumber,
    );
  }

  @visibleForTesting
  static bool isStaleCachedRelease(
    AppRelease release, {
    required String versionName,
    required String buildNumber,
  }) {
    return !GetApplicationRelease.isNewVersion(
      versionName: versionName,
      versionTag: release.version,
      buildNumber: buildNumber,
    );
  }

  Future<void> _persistRelease(AppRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsReleaseKey,
      jsonEncode({
        'version': release.version,
        'info': release.info,
        'releaseLink': release.releaseLink,
        'downloadLink': release.downloadLink,
      }),
    );
  }

  Future<AppRelease?> _loadPersistedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsReleaseKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return AppRelease(
        version: map['version'] as String? ?? '',
        info: map['info'] as String? ?? '',
        releaseLink: map['releaseLink'] as String? ?? '',
        downloadLink: map['downloadLink'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPersistedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsReleaseKey);
  }

  void clear() {
    if (_downloadRunning) return;
    _release = null;
    _stage = AppUpdateStage.idle;
    _progress = 0;
    notifyListeners();
    unawaited(_installer.deleteDownloadedApk());
    unawaited(_clearPersistedRelease());
    unawaited(NotificationService.instance.dismissAppUpdateProgress());
  }
}
