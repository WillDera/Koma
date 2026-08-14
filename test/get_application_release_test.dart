import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/services/app_update/app_release.dart';
import 'package:koma/core/services/app_update/app_release_service.dart';
import 'package:koma/core/services/app_update/app_update_manager.dart';
import 'package:koma/core/services/app_update/get_application_release.dart';

void main() {
  group('GetApplicationRelease._isNewVersion', () {
    test('same semver and build (v2.37.33+300) is not an update', () {
      expect(
        GetApplicationRelease.isNewVersion(
          versionName: '2.37.33',
          versionTag: 'v2.37.33+300',
          buildNumber: '300',
        ),
        isFalse,
      );
    });

    test('higher remote semver is an update', () {
      expect(
        GetApplicationRelease.isNewVersion(
          versionName: '2.37.33',
          versionTag: 'v2.37.34',
          buildNumber: '300',
        ),
        isTrue,
      );
    });

    test('same semver with higher remote build is an update', () {
      expect(
        GetApplicationRelease.isNewVersion(
          versionName: '2.37.33',
          versionTag: 'v2.37.33+301',
          buildNumber: '300',
        ),
        isTrue,
      );
    });

    test('mislabeled GitHub tag vs older baked APK is still an update', () {
      expect(
        GetApplicationRelease.isNewVersion(
          versionName: '2.37.37',
          versionTag: 'v2.37.40+307',
          buildNumber: '304',
        ),
        isTrue,
      );
    });

    test('installed newer than remote is not an update', () {
      expect(
        GetApplicationRelease.isNewVersion(
          versionName: '2.38.0',
          versionTag: 'v2.37.33+300',
          buildNumber: '300',
        ),
        isFalse,
      );
    });
  });

  group('AppUpdateManager.isStaleCachedRelease', () {
    const cached = AppRelease(
      version: 'v2.37.39+306',
      info: '',
      releaseLink: '',
      downloadLink: '',
    );

    test('cached APK matching the running app is stale', () {
      expect(
        AppUpdateManager.isStaleCachedRelease(
          cached,
          versionName: '2.37.39',
          buildNumber: '306',
        ),
        isTrue,
      );
    });

    test('cached APK newer than the running app is kept', () {
      expect(
        AppUpdateManager.isStaleCachedRelease(
          cached,
          versionName: '2.37.38',
          buildNumber: '305',
        ),
        isFalse,
      );
    });
  });

  group('AppReleaseService.pickApkUrl', () {
    test('prefers versioned koma-*.apk over app-release.apk', () {
      expect(
        AppReleaseService.pickApkUrl([
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://example.com/app-release.apk',
          },
          {
            'name': 'koma-2.37.41+308.apk',
            'browser_download_url': 'https://example.com/koma-2.37.41+308.apk',
          },
        ]),
        'https://example.com/koma-2.37.41+308.apk',
      );
    });
  });
}
