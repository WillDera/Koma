import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'device_constraints.dart';
import 'library_update_prefs.dart';

/// Chapter download constraints + behaviour (Mihon [DownloadPreferences] parity).
class DownloadPrefs {
  DownloadPrefs._();

  static const keyWifiOnly = 'download_wifi_only';
  static const keyChargingOnly = 'download_charging_only';
  static const keyDeleteAfterRead = 'download_delete_after_read';

  static const defaultWifiOnly = true;
  static const defaultChargingOnly = false;
  static const defaultDeleteAfterRead = false;

  static Future<DownloadDeviceConstraints> loadDeviceConstraints() async {
    final prefs = await SharedPreferences.getInstance();
    return DownloadDeviceConstraints(
      wifiOnly: prefs.getBool(keyWifiOnly) ?? defaultWifiOnly,
      chargingOnly: prefs.getBool(keyChargingOnly) ?? defaultChargingOnly,
    );
  }

  static Future<bool> isDeleteAfterReadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDeleteAfterRead) ?? defaultDeleteAfterRead;
  }

  static Constraints workConstraints(DownloadDeviceConstraints c) {
    return LibraryUpdatePrefs.workConstraints(
      LibraryUpdateDeviceConstraints(
        wifiOnly: c.wifiOnly,
        chargingOnly: c.chargingOnly,
      ),
    );
  }

  /// Returns false when downloads must wait (Wi‑Fi / charging).
  static Future<bool> canDownloadNow() async {
    final c = await loadDeviceConstraints();
    if (!c.wifiOnly && !c.chargingOnly) return true;
    final snap = await DeviceConstraints.snapshot();
    return snap.allows(wifiOnly: c.wifiOnly, chargingOnly: c.chargingOnly);
  }
}

class DownloadDeviceConstraints {
  const DownloadDeviceConstraints({
    required this.wifiOnly,
    required this.chargingOnly,
  });

  final bool wifiOnly;
  final bool chargingOnly;
}
