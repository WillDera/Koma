import 'dart:io';

import 'package:flutter/services.dart';

/// Live device network / power state for download gating (Mihon parity).
class DeviceConstraintsSnapshot {
  const DeviceConstraintsSnapshot({
    required this.unmetered,
    required this.charging,
  });

  final bool unmetered;
  final bool charging;

  static const allAllowed = DeviceConstraintsSnapshot(
    unmetered: true,
    charging: true,
  );

  bool allows({required bool wifiOnly, required bool chargingOnly}) {
    if (wifiOnly && !unmetered) return false;
    if (chargingOnly && !charging) return false;
    return true;
  }
}

/// Reads Android ConnectivityManager + BatteryManager via [MethodChannel].
class DeviceConstraints {
  DeviceConstraints._();

  static const _channel = MethodChannel('com.koma.koma/system');

  static Future<DeviceConstraintsSnapshot> snapshot() async {
    if (!Platform.isAndroid) return DeviceConstraintsSnapshot.allAllowed;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getDeviceConstraints',
      );
      if (raw == null) return DeviceConstraintsSnapshot.allAllowed;
      return DeviceConstraintsSnapshot(
        unmetered: raw['unmetered'] == true,
        charging: raw['charging'] == true,
      );
    } catch (_) {
      return DeviceConstraintsSnapshot.allAllowed;
    }
  }
}
