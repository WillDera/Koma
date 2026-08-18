import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../isar/collections/source_pref_value.dart';

/// Dual-write JS/Dart extension prefs to Isar alongside PrefsCache.
class SourcePrefStore {
  SourcePrefStore._();

  static Isar? _isar;

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
}
