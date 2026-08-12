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
    );
    if (isNew) return AppUpdateResult.newUpdate(release);
    return const AppUpdateResult.noNewUpdate();
  }

  /// Removes prefixes like `v` / `r`, then compares dotted semver numerically.
  static bool _isNewVersion({
    required String versionName,
    required String versionTag,
  }) {
    final newVersion = versionTag.replaceAll(RegExp(r'[^\d.]'), '');
    final oldVersion = versionName.replaceAll(RegExp(r'[^\d.]'), '');
    if (newVersion.isEmpty || oldVersion.isEmpty) return false;

    final newSemVer =
        newVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final oldSemVer =
        oldVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = newSemVer.length > oldSemVer.length
        ? newSemVer.length
        : oldSemVer.length;

    for (var i = 0; i < len; i++) {
      final n = i < newSemVer.length ? newSemVer[i] : 0;
      final o = i < oldSemVer.length ? oldSemVer[i] : 0;
      if (n > o) return true;
      if (n < o) return false;
    }
    return false;
  }
}

class AppUpdateArguments {
  const AppUpdateArguments({
    required this.versionName,
    required this.repository,
    this.forceCheck = false,
  });

  final String versionName;
  final String repository;
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
