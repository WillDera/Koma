import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// SharedPreferences keys + defaults for library chapter polling
/// (Mihon [LibraryPreferences] / [DownloadPreferences] parity, sans categories).
class LibraryUpdatePrefs {
  LibraryUpdatePrefs._();

  // ── Device constraints (background WorkManager only) ─────────────────
  static const keyWifiOnly = 'library_update_wifi_only';
  static const keyChargingOnly = 'library_update_charging_only';

  // ── Manga skip filters (Mihon autoUpdateMangaRestrictions) ───────────
  /// Skip titles with `status == completed` (Mihon `manga_ongoing`).
  static const keySkipCompleted = 'library_update_skip_completed';

  /// Skip titles that still have unread chapters (Mihon `manga_fully_read`).
  static const keySkipWithUnread = 'library_update_skip_with_unread';

  /// Skip titles the user has not started reading (Mihon `manga_started`).
  static const keySkipNotStarted = 'library_update_skip_not_started';

  // ── Auto-download (Mihon `download_new`) ─────────────────────────────
  static const keyDownloadNew = 'download_new';

  // ── Category filters (Mihon library update categories) ─────────────
  /// When non-empty, only manga in at least one of these category ids are polled.
  static const keyIncludeCategoryIds = 'library_update_include_category_ids';

  /// Manga in any of these category ids are skipped.
  static const keyExcludeCategoryIds = 'library_update_exclude_category_ids';

  /// Mihon defaults: Wi‑Fi only on; charging off.
  static const defaultWifiOnly = true;
  static const defaultChargingOnly = false;

  /// Mihon defaults for smart-update restriction set (all three we support).
  static const defaultSkipCompleted = true;
  static const defaultSkipWithUnread = true;
  static const defaultSkipNotStarted = true;

  static const defaultDownloadNew = false;

  static Future<LibraryUpdateMangaRestrictions> loadMangaRestrictions() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryUpdateMangaRestrictions(
      skipCompleted:
          prefs.getBool(keySkipCompleted) ?? defaultSkipCompleted,
      skipWithUnread:
          prefs.getBool(keySkipWithUnread) ?? defaultSkipWithUnread,
      skipNotStarted:
          prefs.getBool(keySkipNotStarted) ?? defaultSkipNotStarted,
    );
  }

  static Future<LibraryUpdateDeviceConstraints> loadDeviceConstraints() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryUpdateDeviceConstraints(
      wifiOnly: prefs.getBool(keyWifiOnly) ?? defaultWifiOnly,
      chargingOnly: prefs.getBool(keyChargingOnly) ?? defaultChargingOnly,
    );
  }

  static Future<bool> isDownloadNewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDownloadNew) ?? defaultDownloadNew;
  }

  static Future<LibraryUpdateCategoryFilters> loadCategoryFilters() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryUpdateCategoryFilters(
      includeCategoryIds: _readIdList(prefs, keyIncludeCategoryIds),
      excludeCategoryIds: _readIdList(prefs, keyExcludeCategoryIds),
    );
  }

  static Future<void> saveCategoryFilters(LibraryUpdateCategoryFilters f) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyIncludeCategoryIds,
      jsonEncode(f.includeCategoryIds),
    );
    await prefs.setString(
      keyExcludeCategoryIds,
      jsonEncode(f.excludeCategoryIds),
    );
  }

  static List<int> _readIdList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((e) => (e as num).toInt()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Builds WorkManager [Constraints] for the periodic library poll.
  /// Manual "Check now" / in-app timer never use these.
  static Constraints workConstraints(LibraryUpdateDeviceConstraints c) {
    return Constraints(
      networkType:
          c.wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      requiresCharging: c.chargingOnly,
    );
  }
}

class LibraryUpdateDeviceConstraints {
  const LibraryUpdateDeviceConstraints({
    required this.wifiOnly,
    required this.chargingOnly,
  });

  final bool wifiOnly;
  final bool chargingOnly;
}

class LibraryUpdateMangaRestrictions {
  const LibraryUpdateMangaRestrictions({
    required this.skipCompleted,
    required this.skipWithUnread,
    required this.skipNotStarted,
  });

  final bool skipCompleted;
  final bool skipWithUnread;
  final bool skipNotStarted;

  static const none = LibraryUpdateMangaRestrictions(
    skipCompleted: false,
    skipWithUnread: false,
    skipNotStarted: false,
  );
}

class LibraryUpdateCategoryFilters {
  const LibraryUpdateCategoryFilters({
    this.includeCategoryIds = const [],
    this.excludeCategoryIds = const [],
  });

  final List<int> includeCategoryIds;
  final List<int> excludeCategoryIds;

  /// Returns true when [mangaCategoryIds] should be skipped for polling.
  bool shouldSkipManga(List<int> mangaCategoryIds) {
    if (excludeCategoryIds.isNotEmpty) {
      for (final id in mangaCategoryIds) {
        if (excludeCategoryIds.contains(id)) return true;
      }
    }
    if (includeCategoryIds.isNotEmpty) {
      if (mangaCategoryIds.isEmpty) return true;
      for (final id in mangaCategoryIds) {
        if (includeCategoryIds.contains(id)) return false;
      }
      return true;
    }
    return false;
  }
}
