import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Installed app version from the APK (`pubspec.yaml` at build time).
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// e.g. `Version 2.37.41 · build 2.37.41+308`
String appVersionLabel(PackageInfo info) =>
    'Version ${info.version} · build ${info.version}+${info.buildNumber}';
