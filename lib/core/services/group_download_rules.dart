import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-group auto-download preference (over global download-new).
enum GroupDownloadRule {
  inherit,
  always,
  never,
  unreadOnly,
}

/// Resolved download behavior for a manga given its library group(s).
enum GroupDownloadBehavior {
  skip,
  downloadAll,
  downloadUnreadOnly,
}

/// Prefs + resolution for library-group download rules.
class GroupDownloadRules {
  GroupDownloadRules._();

  static const prefsKey = 'group_download_rules_json';

  /// Legacy key from the short-lived category-based rules (same JSON shape).
  static const legacyPrefsKey = 'category_download_rules_json';

  static GroupDownloadRule parseRule(String? name) {
    for (final r in GroupDownloadRule.values) {
      if (r.name == name) return r;
    }
    return GroupDownloadRule.inherit;
  }

  static Future<Map<int, GroupDownloadRule>> load([
    SharedPreferences? prefs,
  ]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(prefsKey) ?? p.getString(legacyPrefsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <int, GroupDownloadRule>{};
      for (final e in decoded.entries) {
        final id = int.tryParse(e.key.toString());
        if (id == null) continue;
        out[id] = parseRule(e.value?.toString());
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<void> save(
    Map<int, GroupDownloadRule> rules, [
    SharedPreferences? prefs,
  ]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final encoded = {
      for (final e in rules.entries) '${e.key}': e.value.name,
    };
    await p.setString(prefsKey, jsonEncode(encoded));
    await p.remove(legacyPrefsKey);
  }

  /// Priority: any `never` → skip; any `always` → download all; any
  /// `unreadOnly` → unread only; otherwise fall through to [globalDownloadNew].
  static GroupDownloadBehavior resolveRule({
    required List<int> groupIds,
    required bool globalDownloadNew,
    Map<int, GroupDownloadRule> rules = const {},
  }) {
    var sawAlways = false;
    var sawUnreadOnly = false;
    for (final id in groupIds) {
      final rule = rules[id] ?? GroupDownloadRule.inherit;
      if (rule == GroupDownloadRule.never) {
        return GroupDownloadBehavior.skip;
      }
      if (rule == GroupDownloadRule.always) sawAlways = true;
      if (rule == GroupDownloadRule.unreadOnly) sawUnreadOnly = true;
    }
    if (sawAlways) return GroupDownloadBehavior.downloadAll;
    if (sawUnreadOnly) return GroupDownloadBehavior.downloadUnreadOnly;
    return globalDownloadNew
        ? GroupDownloadBehavior.downloadAll
        : GroupDownloadBehavior.skip;
  }
}
