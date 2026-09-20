import 'package:shared_preferences/shared_preferences.dart';

/// Curated SharedPreferences keys that round-trip in a Koma JSON backup.
///
/// Secrets, device-local paths, and live download-runner state stay out.
class BackupSettings {
  BackupSettings._();

  static const exactKeys = <String>{
    'theme_mode',
    'sepia_mode',
    'theme_pack_id',
    'font_family',
    'google_font',
    'font_size',
    'line_height',
    'accent_index',
    'custom_accent_hex',
    'accent_from_pack',
    'follow_system_accent',
    'reading_font',
    'page_width',
    'text_align',
    'hyphenation',
    'reduced_motion',
    'default_highlight',
    'hand_mode',
    'one_hand_mode',
    'bionic_reading',
    'amoled_mode',
    'ui_font_id',
    'reading_font_id',
    'show_nsfw_extensions',
    'show_obsolete_extensions',
    'immersive_auto_hide',
    'page_style',
    'security_incognito',
    'security_app_lock',
    'security_secure_screen',
    'security_hide_notification_content',
    'tracker_update_progress_after_reading',
    'tracker_update_after_reading',
    'download_wifi_only',
    'download_charging_only',
    'download_delete_after_read',
    'download_new',
    'notify_new_chapters',
    'notify_extension_updates',
    'explore_compact_manga_rails',
    'extension_auto_update_enabled',
    'library_is_grid_view',
    'library_show_source_pills',
    'library_minimal_cards',
    'library_show_unread_badge',
    'library_show_continue_button',
    'library_grid_columns',
    'library_card_variant',
    'library_auto_update_enabled',
    'library_auto_update_interval_hours',
    'library_auto_update_interval_minutes',
    'library_update_last_checked_at_ms',
    'library_update_wifi_only',
    'library_update_charging_only',
    'library_update_skip_completed',
    'library_update_skip_with_unread',
    'library_update_skip_not_started',
    'library_update_include_category_ids',
    'library_update_exclude_category_ids',
    'group_download_rules_json',
    'category_download_rules_json',
    'reading_goals_daily_minutes',
    'reading_goals_weekly_days',
    'tts_controls_placement',
    'tts_remember_selection',
    'tts_engine',
    'tts_voice_id',
    'tts_rate',
    'tts_pitch',
    'tts_optimistic',
    'text_progress_pill_enabled',
    'text_progress_pill_placement',
    'reader_settings',
    'user_display_name',
    'user_preferred_genres',
    'onboarding_completed',
  };

  static const _doubleKeys = <String>{
    'font_size',
    'line_height',
    'page_width',
    'tts_rate',
    'tts_pitch',
  };

  static bool isIncluded(String key) {
    if (exactKeys.contains(key)) return true;
    // Per-title manga reader prefs (`reader_42`).
    if (key.startsWith('reader_') && key != 'reader_settings') return true;
    return false;
  }

  static Future<Map<String, Object>> dump() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!isIncluded(key)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      out[key] = value;
    }
    return out;
  }

  static Future<int> restore(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    var written = 0;
    for (final entry in data.entries) {
      if (!isIncluded(entry.key)) continue;
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is num) {
        if (_doubleKeys.contains(entry.key)) {
          await prefs.setDouble(entry.key, value.toDouble());
        } else {
          await prefs.setInt(entry.key, value.round());
        }
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(
          entry.key,
          value.map((e) => e.toString()).toList(),
        );
      } else {
        continue;
      }
      written++;
    }
    return written;
  }
}
