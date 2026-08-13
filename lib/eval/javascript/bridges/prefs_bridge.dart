import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mangayomi-faithful [SharedPreferences] for JS extensions
/// (`new SharedPreferences().get(key)` — **synchronous** sendMessage returns).
///
/// The previous async `getInstance()` + callback Promise API hung getPopular
/// when scripts expected mangayomi's sync prefs surface.
///
/// Isar SourcePreference collection deferred — PrefsCache (SharedPreferences
/// under the hood) is the runtime truth for typed JS prefs.
void injectPrefsBridge(JavascriptRuntime runtime, {required String sourceId}) {
  runtime.onMessage('get', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    final stored = getJsPreferenceValue(sourceId, key);
    if (stored != null) return stored;
    // MangaDex et al. pass `get(key, defaultValue)` even though mangayomi's
    // bridge only forwards [key]; honour the default so `.length` never runs
    // on undefined before getSourcePreferences defaults are seeded.
    if (list.length > 1) return list[1];
    return null;
  });
  runtime.onMessage('getString', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    final def = list.length > 1 ? list[1]?.toString() ?? '' : '';
    return PrefsCache.instance.getString(_prefStorageKey(sourceId, key), def);
  });
  runtime.onMessage('setString', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    final value = list.length > 1 ? list[1]?.toString() ?? '' : '';
    PrefsCache.instance.setString(_prefStorageKey(sourceId, key), value);
    return null;
  });

  runtime.evaluate('''
class SharedPreferences {
    get(key, defaultValue) {
        var payload = arguments.length > 1 ? [key, defaultValue] : [key];
        var v = sendMessage("get", JSON.stringify(payload));
        if (v === null || v === undefined) {
            return arguments.length > 1 ? defaultValue : null;
        }
        return v;
    }
    getString(key, defaultValue) {
        return sendMessage(
            "getString",
            JSON.stringify([key, defaultValue])
        );
    }
    setString(key, defaultValue) {
        return sendMessage(
            "setString",
            JSON.stringify([key, defaultValue])
        );
    }
}
''');
}

String _prefStorageKey(String sourceId, String key) =>
    'js_src_pref:$sourceId:$key';

/// Typed read from PrefsCache (mangayomi [getPreferenceValue] counterpart for
/// the JS path — PrefsCache already stores the resolved typed value).
dynamic getJsPreferenceValue(String sourceId, String key) {
  return PrefsCache.instance.get(_prefStorageKey(sourceId, key));
}

/// Typed write into PrefsCache so subsequent JS `SharedPreferences.get` sees
/// UI updates without restart.
void setJsPreferenceValue(String sourceId, String key, dynamic value) {
  PrefsCache.instance.putJson(_prefStorageKey(sourceId, key), value);
}

/// Seed unset preference keys from `extention.getSourcePreferences()` defaults,
/// matching mangayomi's [getSourcePreferenceEntry] first-access behaviour.
void seedJsPreferenceDefaults(
  JavascriptRuntime runtime, {
  required String sourceId,
}) {
  try {
    final res = runtime.evaluate(
      'JSON.stringify(extention.getSourcePreferences())',
    );
    final raw = res.stringResult;
    if (raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is! Map) continue;
      final key = item['key']?.toString();
      if (key == null || key.isEmpty) continue;
      final fullKey = _prefStorageKey(sourceId, key);
      if (PrefsCache.instance.contains(fullKey)) continue;
      final def = _defaultFromPreferenceMap(Map<String, dynamic>.from(item));
      if (def == null) continue;
      PrefsCache.instance.putJson(fullKey, def);
    }
  } catch (_) {
    // Extensions without getSourcePreferences — ignore.
  }
}

dynamic _defaultFromPreferenceMap(Map<String, dynamic> item) {
  final multi = item['multiSelectListPreference'];
  if (multi is Map) {
    return multi['values'] ?? <dynamic>[];
  }
  final list = item['listPreference'];
  if (list is Map) {
    final values = list['entryValues'];
    final idx = (list['valueIndex'] as num?)?.toInt() ?? 0;
    if (values is List && values.isNotEmpty) {
      final i = idx.clamp(0, values.length - 1);
      return values[i];
    }
    return '';
  }
  final edit = item['editTextPreference'];
  if (edit is Map) return edit['value'];
  final check = item['checkBoxPreference'];
  if (check is Map) return check['value'];
  final sw = item['switchPreferenceCompat'];
  if (sw is Map) return sw['value'];
  return null;
}

/// Eagerly-loaded in-memory prefs mirror so JS can call SharedPreferences
/// synchronously like mangayomi (Isar/shared_prefs is async underneath).
class PrefsCache {
  PrefsCache._();
  static final instance = PrefsCache._();

  final Map<String, String> _strings = {};
  bool _hydrated = false;

  Future<void> hydrate() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('js_src_pref:')) continue;
      final v = prefs.getString(key);
      if (v != null) _strings[key] = v;
    }
    _hydrated = true;
  }

  bool contains(String key) => _strings.containsKey(key);

  dynamic get(String key) {
    final raw = _strings[key];
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String getString(String key, String def) => _strings[key] ?? def;

  void setString(String key, String value) {
    _strings[key] = value;
    // Fire-and-forget persist.
    SharedPreferences.getInstance().then((p) => p.setString(key, value));
  }

  /// Persist a JSON-encodable default (list / bool / string) like mangayomi.
  void putJson(String key, dynamic value) {
    final encoded = jsonEncode(value);
    setString(key, encoded);
  }
}

/// Call before evaluating extension code so sync prefs read fresh values.
Future<void> hydrateJsPrefsCache() => PrefsCache.instance.hydrate();
