import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';

import '../isar/collections/source_pref_value.dart';

/// Dual-write JS/Dart extension prefs to Isar alongside PrefsCache.
class SourcePrefStore {
  SourcePrefStore._();

  static Isar? _isar;
  static const _apkChannel = MethodChannel('com.koma.koma/source_prefs');

  static void bind(Isar isar) => _isar = isar;

  static Future<void> put(String sourceId, String key, dynamic value) async {
    final isar = _isar;
    if (isar == null) return;
    final encoded = jsonEncode(value);
    final storageKey = SourcePrefValue.composeKey(sourceId, key);
    await isar.writeTxn(() async {
      await isar.sourcePrefValues.put(
        SourcePrefValue(
          storageKey: storageKey,
          sourceId: sourceId,
          prefKey: key,
          valueJson: encoded,
        ),
      );
    });
  }

  static dynamic get(String sourceId, String key) {
    final isar = _isar;
    if (isar == null) return null;
    final storageKey = SourcePrefValue.composeKey(sourceId, key);
    final row =
        isar.sourcePrefValues.getByStorageKeySync(storageKey);
    if (row == null) return null;
    try {
      return jsonDecode(row.valueJson);
    } catch (_) {
      return row.valueJson;
    }
  }

  /// All Isar-backed source prefs for JSON backup.
  static Future<List<Map<String, dynamic>>> exportAll() async {
    final isar = _isar;
    if (isar == null) return const [];
    final rows = await isar.sourcePrefValues.where().findAll();
    return [
      for (final r in rows)
        {
          'sourceId': r.sourceId,
          'prefKey': r.prefKey,
          'valueJson': r.valueJson,
        },
    ];
  }

  /// Restore Isar source prefs from backup rows (best-effort upsert).
  static Future<int> importAll(List<dynamic> rows) async {
    final isar = _isar;
    if (isar == null || rows.isEmpty) return 0;
    var written = 0;
    await isar.writeTxn(() async {
      for (final raw in rows) {
        if (raw is! Map) continue;
        final sourceId = raw['sourceId']?.toString() ?? '';
        final prefKey = raw['prefKey']?.toString() ?? '';
        final valueJson = raw['valueJson']?.toString() ?? '';
        if (sourceId.isEmpty || prefKey.isEmpty) continue;
        await isar.sourcePrefValues.put(
          SourcePrefValue(
            storageKey: SourcePrefValue.composeKey(sourceId, prefKey),
            sourceId: sourceId,
            prefKey: prefKey,
            valueJson: valueJson,
          ),
        );
        written++;
      }
    });
    return written;
  }

  /// Dump Mihon APK SharedPreferences whose name starts with `source_`.
  /// Returns null on non-Android or failure.
  ///
  /// Uses [Platform.isAndroid] (not [defaultTargetPlatform]) so unit tests
  /// without a WidgetsBinding can still export JSON backups.
  static Future<Map<String, dynamic>?> exportApkSourcePrefs() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _apkChannel.invokeMethod<dynamic>('exportAllSourcePrefs');
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  /// Restore Mihon APK SharedPreferences map (name → {key: value}).
  static Future<void> importApkSourcePrefs(Map<String, dynamic>? data) async {
    if (data == null || data.isEmpty) return;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _apkChannel.invokeMethod('importSourcePrefs', data);
    } catch (_) {}
  }
}
