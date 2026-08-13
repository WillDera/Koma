import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_release_service.dart';
import 'get_application_release.dart';

/// Mihon [AppUpdateChecker] parity — GitHub repo for Koma releases.
class AppUpdateChecker {
  AppUpdateChecker({
    AppReleaseService? service,
    this.repository = defaultRepository,
  }) : _getRelease = GetApplicationRelease(service ?? AppReleaseService());

  static const defaultRepository = 'WillDera/koma';

  final GetApplicationRelease _getRelease;
  final String repository;

  /// Whether in-app APK updates are supported on this platform.
  static bool get updaterEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AppUpdateResult> checkForUpdate({bool forceCheck = false}) async {
    if (!updaterEnabled) return const AppUpdateResult.noNewUpdate();

    final info = await PackageInfo.fromPlatform();
    return _getRelease.awaitCheck(
      AppUpdateArguments(
        versionName: info.version,
        buildNumber: info.buildNumber,
        repository: repository,
        forceCheck: forceCheck,
      ),
    );
  }
}
