import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-extension client overrides (UA, browse language filter, cover quality).
///
/// Stored in SharedPreferences so we avoid an Isar schema bump for settings
/// that are app-owned rather than extension-index metadata. [baseUrl] itself
/// remains on [ExtensionSource] and is edited separately.
class ExtensionClientSettings {
  const ExtensionClientSettings({
    this.userAgent = '',
    this.filterLanguage = '',
    this.coverQuality = CoverQuality.medium,
  });

  final String userAgent;
  /// ISO-ish language code to prefer when filtering browse results; empty = all.
  final String filterLanguage;
  final CoverQuality coverQuality;

  static String _key(String sourceId) => 'ext_client_$sourceId';

  static Future<ExtensionClientSettings> load(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sourceId));
    if (raw == null || raw.isEmpty) return const ExtensionClientSettings();
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return ExtensionClientSettings(
        userAgent: map['userAgent'] as String? ?? '',
        filterLanguage: map['filterLanguage'] as String? ?? '',
        coverQuality: CoverQuality.fromId(map['coverQuality'] as String?),
      );
    } catch (_) {
      return const ExtensionClientSettings();
    }
  }

  Future<void> save(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(sourceId),
      json.encode({
        'userAgent': userAgent,
        'filterLanguage': filterLanguage,
        'coverQuality': coverQuality.id,
      }),
    );
  }

  ExtensionClientSettings copyWith({
    String? userAgent,
    String? filterLanguage,
    CoverQuality? coverQuality,
  }) {
    return ExtensionClientSettings(
      userAgent: userAgent ?? this.userAgent,
      filterLanguage: filterLanguage ?? this.filterLanguage,
      coverQuality: coverQuality ?? this.coverQuality,
    );
  }

  /// Byte budget for [coverProvider] / thumbnail decode.
  int get coverMaxBytes => switch (coverQuality) {
        CoverQuality.low => 50 << 10,
        CoverQuality.medium => 200 << 10,
        CoverQuality.original => 2 << 20,
      };
}

enum CoverQuality {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  original('original', 'Original');

  const CoverQuality(this.id, this.label);
  final String id;
  final String label;

  static CoverQuality fromId(String? id) {
    for (final q in CoverQuality.values) {
      if (q.id == id) return q;
    }
    return CoverQuality.medium;
  }
}
