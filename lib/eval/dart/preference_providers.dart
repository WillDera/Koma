import 'package:koma/eval/javascript/bridges/prefs_bridge.dart';
import 'package:koma/eval/models/source_preference.dart';

/// Dart-bridge preference helpers — PrefsCache-backed counterparts of
/// mangayomi `extension_preferences_providers.dart` (no Isar SourcePreference).

final Map<String, dynamic> _preferenceDefaults = {};

void cachePreferenceDefault(int sourceId, String key, dynamic value) {
  if (key.isEmpty) return;
  _preferenceDefaults['$sourceId:$key'] = value;
}

dynamic getPreferenceValue(int sourceId, String key) {
  final stored = getJsPreferenceValue('$sourceId', key);
  if (stored != null) return stored;
  final def = _preferenceDefaults['$sourceId:$key'];
  if (def != null) return def;
  // Never return null — dart_eval `null[i]` becomes
  // "Unsupported target for indexing: null".
  return '';
}

String getSourcePreferenceStringValue(
  int sourceId,
  String key,
  String defaultValue,
) {
  final stored = PrefsCache.instance.getString(
    'js_src_pref:$sourceId:$key',
    defaultValue,
  );
  return stored;
}

void setDartPreferenceValue(
  int sourceId,
  String key,
  SourcePreference preference,
) {
  final value = preference.typedValue;
  if (value != null) {
    setJsPreferenceValue('$sourceId', key, value);
    cachePreferenceDefault(sourceId, key, value);
  }
}
