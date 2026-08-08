import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mangayomi-faithful [SharedPreferences] for JS extensions
/// (`new SharedPreferences().get(key)` — **synchronous** sendMessage returns).
///
/// The previous async `getInstance()` + callback Promise API hung getPopular
/// when scripts expected mangayomi's sync prefs surface.
void injectPrefsBridge(JavascriptRuntime runtime, {required String sourceId}) {
  final prefix = 'js_src_pref:$sourceId:';

  runtime.onMessage('get', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    // Mangayomi getPreferenceValue — return stored JSON or null.
    // Sync SharedPreferences access via cached instance is async-only in
    // flutter; return null for cold miss (extensions treat as unset).
    return _PrefsCache.instance.get(prefix + key);
  });
  runtime.onMessage('getString', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    final def = list.length > 1 ? list[1]?.toString() ?? '' : '';
    return _PrefsCache.instance.getString(prefix + key, def);
  });
  runtime.onMessage('setString', (dynamic args) {
    final list = args is List ? args : <dynamic>[];
    final key = list.isNotEmpty ? list[0].toString() : '';
    final value = list.length > 1 ? list[1]?.toString() ?? '' : '';
    _PrefsCache.instance.setString(prefix + key, value);
    return null;
  });

  runtime.evaluate('''
class SharedPreferences {
    get(key) {
        return sendMessage("get", JSON.stringify([key]));
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

/// Eagerly-loaded in-memory prefs mirror so JS can call SharedPreferences
/// synchronously like mangayomi (Isar/shared_prefs is async underneath).
class _PrefsCache {
  _PrefsCache._();
  static final instance = _PrefsCache._();

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
}

/// Call before evaluating extension code so sync prefs read fresh values.
Future<void> hydrateJsPrefsCache() => _PrefsCache.instance.hydrate();
