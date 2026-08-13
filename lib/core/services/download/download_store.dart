import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_download.dart';

/// Persists the active download queue across restarts (Mihon DownloadStore).
///
/// Prefs key stores a JSON list ordered by [ChapterDownload.order].
class DownloadStore {
  DownloadStore();

  static const _prefsKey = 'active_chapter_downloads';
  static const _pausedKey = 'chapter_downloads_paused';
  static const _runnerKey = 'chapter_download_runner'; // none | ui | wm

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<ChapterDownload>> restore() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final out = <ChapterDownload>[];
      for (final item in list) {
        if (item is Map) {
          out.add(ChapterDownload.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      out.sort((a, b) => a.order.compareTo(b.order));
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ChapterDownload> downloads) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(downloads.map((d) => d.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_prefsKey);
  }

  Future<bool> isPaused() async {
    final prefs = await _prefs;
    return prefs.getBool(_pausedKey) ?? false;
  }

  Future<void> setPaused(bool paused) async {
    final prefs = await _prefs;
    await prefs.setBool(_pausedKey, paused);
  }

  Future<String> runner() async {
    final prefs = await _prefs;
    return prefs.getString(_runnerKey) ?? 'none';
  }

  Future<void> setRunner(String runner) async {
    final prefs = await _prefs;
    await prefs.setString(_runnerKey, runner);
  }
}
