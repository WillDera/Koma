import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Android 11+ all-files access for a user-chosen data folder.
class AndroidStorageAccess {
  AndroidStorageAccess._();

  static const _channel = MethodChannel('com.koma.koma/storage');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when [path] is shared storage that dart:io cannot write without
  /// [MANAGE_EXTERNAL_STORAGE] (e.g. `/storage/emulated/0/koma`).
  static bool needsAllFilesAccess(String path) {
    if (!_android) return false;
    final n = p.normalize(path);
    if (n.contains('/Android/data/')) return false;
    if (n.contains('/Android/obb/')) return false;
    if (n.startsWith('/data/')) return false;
    return n.contains('/storage/') || n.startsWith('/sdcard');
  }

  static Future<bool> hasAllFilesAccess() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestAllFilesAccess() async {
    if (!_android) return;
    await _channel.invokeMethod<void>('requestAllFilesAccess');
  }

  static Future<void> copyFile(String from, String to) async {
    if (!_android) {
      await File(from).copy(to);
      return;
    }
    await _channel.invokeMethod<void>('copyFile', {'from': from, 'to': to});
  }
}
