import 'package:flutter/foundation.dart';

import '../../utils/language.dart';
import 'app_release.dart';
import 'app_release_service.dart';

/// Mihon [GetApplicationRelease] parity: compare the installed version against
/// GitHub `/releases/latest` and report whether an update is available.
class GetApplicationRelease {
  GetApplicationRelease(this._service);

  final AppReleaseService _service;

  Future<AppUpdateResult> awaitCheck(AppUpdateArguments arguments) async {
    final release = await _service.latest(arguments);
    if (release == null) return const AppUpdateResult.noNewUpdate();

    final isNew = _isNewVersion(
      versionName: arguments.versionName,
      versionTag: release.version,
      buildNumber: arguments.buildNumber,
    );
    if (isNew) return AppUpdateResult.newUpdate(release);
    return const AppUpdateResult.noNewUpdate();
  }

  /// Compares semver segments via [compareVersions], then build numbers when
  /// semver matches. Tags like `v2.37.33+300` must not be digit-stripped
  /// (that incorrectly yields `2.37.33300`).
  @visibleForTesting
  static bool isNewVersion({
    required String versionName,
    required String versionTag,
    String? buildNumber,
  }) =>
      _isNewVersion(
        versionName: versionName,
        versionTag: versionTag,
        buildNumber: buildNumber,
      );

  static bool _isNewVersion({
    required String versionName,
    required String versionTag,
    String? buildNumber,
  }) {
    final semverCmp = compareVersions(versionName, versionTag);
    if (semverCmp > 0) return false;
    if (semverCmp < 0) return true;

    final remoteBuild = _buildNumber(versionTag);
    final localBuild =
        int.tryParse(buildNumber ?? '') ?? _buildNumber(versionName);
    return remoteBuild > localBuild;
  }

  static int _buildNumber(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus < 0) return 0;
    return int.tryParse(s.substring(plus + 1)) ?? 0;
  }
}

class AppUpdateArguments {
  const AppUpdateArguments({
    required this.versionName,
    required this.repository,
    this.buildNumber,
    this.forceCheck = false,
  });

  final String versionName;
  final String repository;
  final String? buildNumber;
  final bool forceCheck;
}

sealed class AppUpdateResult {
  const AppUpdateResult();
  const factory AppUpdateResult.newUpdate(AppRelease release) = NewAppUpdate;
  const factory AppUpdateResult.noNewUpdate() = NoNewAppUpdate;
}

final class NewAppUpdate extends AppUpdateResult {
  const NewAppUpdate(this.release);
  final AppRelease release;
}

final class NoNewAppUpdate extends AppUpdateResult {
  const NoNewAppUpdate();
}
