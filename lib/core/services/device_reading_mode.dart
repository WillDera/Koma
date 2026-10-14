import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Puts the phone into a reading posture while Koma is in the foreground.
///
/// The screen stays awake. On Android, night display (the system warm
/// reading filter) is turned on when the platform allows it, and restored
/// when Koma leaves the foreground.
class DeviceReadingMode {
  DeviceReadingMode._();

  static const _channel = MethodChannel('com.koma.koma/reading_mode');

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {}
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
