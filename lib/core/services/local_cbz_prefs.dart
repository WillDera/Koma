import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs for the user-chosen local manga / CBZ import folder.
class LocalCbzPrefs {
  LocalCbzPrefs._();

  static const folderPathKey = 'local_cbz_folder_path';

  /// Series folder / archive URLs the user removed from the library.
  /// Quiet rescans skip these so deleted CBZs don't return (and keep history).
  static const excludedSeriesUrlsKey = 'local_cbz_excluded_series_urls';

  static Future<String?> folderPath([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getString(folderPathKey)?.trim();
    return v != null && v.isNotEmpty ? v : null;
  }

  static Future<void> setFolderPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(folderPathKey);
    } else {
      await prefs.setString(folderPathKey, trimmed);
    }
  }

  static String normalizeSeriesUrl(String url) =>
      p.normalize(url.trim());

  static Future<Set<String>> excludedSeriesUrls([
    SharedPreferences? prefs,
  ]) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getStringList(excludedSeriesUrlsKey) ?? const [];
    return {
      for (final u in raw)
        if (u.trim().isNotEmpty) normalizeSeriesUrl(u),
    };
  }

  static Future<void> excludeSeriesUrl(String url) async {
    final normalized = normalizeSeriesUrl(url);
    if (normalized.isEmpty) return;
    final store = await SharedPreferences.getInstance();
    final next = await excludedSeriesUrls(store)..add(normalized);
    await store.setStringList(excludedSeriesUrlsKey, next.toList());
  }

  /// Allow a series back into the library (explicit import / add).
  static Future<void> includeSeriesUrl(String url) async {
    final normalized = normalizeSeriesUrl(url);
    if (normalized.isEmpty) return;
    final store = await SharedPreferences.getInstance();
    final next = await excludedSeriesUrls(store)..remove(normalized);
    await store.setStringList(excludedSeriesUrlsKey, next.toList());
  }

  static Future<bool> isSeriesExcluded(String url) async {
    final normalized = normalizeSeriesUrl(url);
    if (normalized.isEmpty) return false;
    return (await excludedSeriesUrls()).contains(normalized);
  }
}
