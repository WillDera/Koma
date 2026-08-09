import 'package:koma/eval/javascript/bridges/prefs_bridge.dart';
import 'package:koma/eval/models/source_preference.dart';

/// Dart-bridge preference helpers — PrefsCache-backed counterparts of
/// mangayomi `extension_preferences_providers.dart` (no Isar SourcePreference).

dynamic getPreferenceValue(int sourceId, String key) {
  // PrefsCache-backed; return null when unset (seed from getSourcePreferences).
  return getJsPreferenceValue('$sourceId', key);
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
  }
}
