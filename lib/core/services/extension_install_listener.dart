import 'package:flutter/services.dart';

import 'extension_manager.dart';

/// Listens for Android extension package / PackageInstaller events.
class ExtensionInstallListener {
  ExtensionInstallListener._();

  static const _channel = MethodChannel('com.koma.koma/extensions');

  static void init(ExtensionManager manager) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onExtensionPackageChanged':
        case 'onPackageInstallerStatus':
          await manager.reloadAll();
          return null;
        default:
          return null;
      }
    });
  }
}
